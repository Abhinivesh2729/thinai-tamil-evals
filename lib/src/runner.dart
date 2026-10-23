import 'dart:async';

import 'dataset.dart';
import 'prompts.dart';
import 'report.dart';
import 'scoring.dart';

/// Anything that can answer a prompt: an on-device engine, an HTTP endpoint,
/// or a fake in a test.
abstract interface class EvalGenerator {
  /// Streams the reply to [prompt] as text deltas, then closes.
  ///
  /// Cancelling the subscription must stop generation: that is how a run is
  /// stopped mid-item.
  Stream<String> generate(EvalPrompt prompt);
}

/// One item to ask, in run order.
class EvalStep {
  final EvalTask task;
  final EvalItem item;

  /// Index in the run, from 0.
  final int index;

  const EvalStep(this.task, this.item, this.index);

  /// Rough relative cost, for time estimates: a fixed share for reading the
  /// prompt plus the output cap, in output-token equivalents.
  ///
  /// Fitted to LFM2.5-350M on a mid-range phone, where a multiple-choice
  /// item (one output token) took 2.3 s and a 96-token writing item 5.5 s:
  /// reading a short Tamil prompt costs about as much as writing 64 tokens.
  int get cost => _promptCost + task.maxTokens;

  static const _promptCost = 64;
}

/// Something that happened during a run.
sealed class EvalEvent {
  const EvalEvent();
}

class ItemStarted extends EvalEvent {
  final EvalStep step;
  const ItemStarted(this.step);
}

/// The reply so far, for a live preview.
class ItemOutput extends EvalEvent {
  final EvalStep step;
  final String text;
  const ItemOutput(this.step, this.text);
}

class ItemScored extends EvalEvent {
  final EvalStep step;
  final ItemResult result;
  const ItemScored(this.step, this.result);
}

class RunCompleted extends EvalEvent {
  final EvalReport report;
  const RunCompleted(this.report);
}

/// Thrown into the run stream when an item fails twice in a row.
class EvalRunException implements Exception {
  final EvalStep step;
  final Object cause;
  const EvalRunException(this.step, this.cause);

  @override
  String toString() => 'item ${step.item.id} failed: $cause';
}

/// Asks every item of a dataset, one at a time, and scores the replies.
///
/// Items run in dataset order, one after another. That keeps a run
/// deterministic, and an on-device engine serves one request at a time
/// anyway. Consecutive items of a task share a system prompt, which lets an
/// engine with a prompt cache skip re-reading it.
class EvalRunner {
  final EvalDataset dataset;
  final EvalGenerator generator;

  /// Times items and the run. Injected so tests control time.
  final Stopwatch Function() _stopwatch;
  final DateTime Function() _now;

  EvalRunner({
    required this.dataset,
    required this.generator,
    Stopwatch Function()? stopwatch,
    DateTime Function()? now,
  }) : _stopwatch = stopwatch ?? Stopwatch.new,
       _now = now ?? DateTime.now;

  /// Every item, in run order.
  late final List<EvalStep> steps = [
    for (final task in dataset.tasks)
      for (final item in task.items) (task, item),
  ].indexed.map((e) => EvalStep(e.$2.$1, e.$2.$2, e.$1)).toList();

  int get totalCost => steps.fold(0, (sum, s) => sum + s.cost);

  /// Runs every item and ends with a [RunCompleted].
  ///
  /// Cancel the subscription to stop: the item in flight is cancelled at
  /// once and no report is made, since a score from part of the set would
  /// mislead. An item whose generation fails is retried once; a second
  /// failure ends the stream with an [EvalRunException].
  Stream<EvalEvent> run({required String modelId}) {
    late final StreamController<EvalEvent> out;
    StreamSubscription<String>? current;
    Completer<String?>? pending;
    var cancelled = false;

    // Asks one prompt; completes with the reply, or null when the run was
    // cancelled while it was in flight.
    Future<String?> ask(EvalStep step, EvalPrompt prompt) {
      final done = pending = Completer<String?>();
      final buffer = StringBuffer();
      current = generator
          .generate(prompt)
          .listen(
            (delta) {
              if (delta.isEmpty) return;
              buffer.write(delta);
              out.add(ItemOutput(step, buffer.toString()));
            },
            onError: (Object e, StackTrace st) {
              if (!done.isCompleted) done.completeError(e, st);
            },
            onDone: () {
              if (!done.isCompleted) done.complete(buffer.toString());
            },
            cancelOnError: true,
          );
      return done.future;
    }

    Future<void> drive() async {
      final startedAt = _now();
      final total = _stopwatch()..start();
      final results = <ItemResult>[];
      for (final step in steps) {
        out.add(ItemStarted(step));
        final prompt = buildPrompt(step.task, step.item);
        final watch = _stopwatch()..start();
        String? reply;
        Object? failure;
        for (var attempt = 0; attempt < 2 && reply == null; attempt++) {
          try {
            reply = await ask(step, prompt);
          } on Object catch (e) {
            failure = e;
          }
          if (cancelled) return;
        }
        if (reply == null) {
          out.addError(EvalRunException(step, failure!));
          await out.close();
          return;
        }
        final result = ItemResult(
          taskId: step.task.id,
          itemId: step.item.id,
          output: reply,
          score: scoreItem(step.item, reply),
          elapsed: watch.elapsed,
        );
        results.add(result);
        out.add(ItemScored(step, result));
      }
      out.add(
        RunCompleted(
          EvalReport.score(
            dataset: dataset,
            modelId: modelId,
            startedAt: startedAt,
            elapsed: total.elapsed,
            items: results,
          ),
        ),
      );
      await out.close();
    }

    out = StreamController<EvalEvent>(
      onListen: drive,
      // Not awaited: a generator stops its work when its stream is
      // cancelled, synchronously, so there is nothing left worth waiting for.
      onCancel: () {
        cancelled = true;
        final p = pending;
        if (p != null && !p.isCompleted) p.complete(null);
        unawaited(current?.cancel());
      },
    );
    return out.stream;
  }
}
