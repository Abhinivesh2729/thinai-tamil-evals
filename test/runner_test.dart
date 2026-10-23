import 'dart:async';

import 'package:test/test.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

/// Answers every prompt from [reply], in two deltas, recording what it saw.
class FakeGenerator implements EvalGenerator {
  final String Function(EvalPrompt prompt, int call) reply;
  final prompts = <EvalPrompt>[];
  var cancelled = 0;

  FakeGenerator(this.reply);

  @override
  Stream<String> generate(EvalPrompt prompt) {
    prompts.add(prompt);
    final text = reply(prompt, prompts.length);
    final c = StreamController<String>(onCancel: () => cancelled++);
    () async {
      await Future<void>.delayed(Duration.zero);
      final half = text.length ~/ 2;
      c.add(text.substring(0, half));
      c.add(text.substring(half));
      await c.close();
    }();
    return c.stream;
  }
}

EvalDataset _tiny() => const EvalDataset(
  language: 'ta',
  version: 't',
  axes: [
    EvalAxis(id: 'u', label: 'U', labelTa: 'உ', weight: 0.5),
    EvalAxis(id: 'e', label: 'E', labelTa: 'எ', weight: 0.5),
  ],
  tasks: [
    EvalTask(
      id: 'mcq',
      axis: 'u',
      format: EvalFormat.mcq,
      label: 'M',
      labelTa: 'ம',
      maxTokens: 1,
      items: [
        McqItem('m1', question: 'q', options: ['அ', 'ஆ', 'இ', 'ஈ'], answer: 0),
        McqItem(
          'm2',
          passage: 'ப',
          question: 'q',
          options: ['அ', 'ஆ', 'இ', 'ஈ'],
          answer: 1,
        ),
      ],
    ),
    EvalTask(
      id: 'qa',
      axis: 'e',
      format: EvalFormat.qa,
      label: 'Q',
      labelTa: 'க',
      maxTokens: 8,
      items: [
        QaItem('q1', question: 'q', answers: ['சென்னை']),
      ],
    ),
  ],
);

void main() {
  test('runs every item in order and reports scores', () async {
    final gen = FakeGenerator((p, _) => p.grammar != null ? 'A' : 'சென்னை');
    var t = 0;
    final runner = EvalRunner(
      dataset: _tiny(),
      generator: gen,
      now: () => DateTime.utc(2026, 10, 24, 0, 0, t++),
    );
    expect(runner.steps.map((s) => s.item.id), ['m1', 'm2', 'q1']);
    expect(runner.totalCost, (64 + 1) * 2 + 64 + 8);

    final events = await runner.run(modelId: 'fake').toList();
    expect(events.whereType<ItemStarted>(), hasLength(3));
    expect(events.whereType<ItemOutput>().first.text, isNotEmpty);
    final scored = events.whereType<ItemScored>().map((e) => e.result.score);
    expect(scored, [1, 0, 1]);

    final report = (events.last as RunCompleted).report;
    expect(report.modelId, 'fake');
    expect(report.datasetVersion, 't');
    expect(report.startedAt, DateTime.utc(2026, 10, 24));
    // m1 right, m2 wrong: 50% correct is 33 above chance.
    expect(report.task('mcq')!.score, closeTo(100 / 3, 1e-9));
    expect(report.task('mcq')!.correct, 1);
    expect(report.task('qa')!.score, 100);
    expect(report.task('none'), isNull);
    expect(report.overall, closeTo((100 / 3 + 100) / 2, 1e-9));
    expect(gen.prompts.first.grammar, kOptionGrammar);
    expect(gen.prompts[1].user, startsWith('ப\n\n'));
  });

  test('retries a failed item once', () async {
    var calls = 0;
    final gen = _FailingGenerator(() => ++calls == 1);
    final events = await EvalRunner(
      dataset: _tiny(),
      generator: gen,
    ).run(modelId: 'm').toList();
    expect(events.last, isA<RunCompleted>());
    expect(calls, 4);
  });

  test('a second failure ends the run with the item named', () async {
    final gen = _FailingGenerator(() => true);
    final run = EvalRunner(dataset: _tiny(), generator: gen).run(modelId: 'm');
    await expectLater(
      run,
      emitsThrough(
        emitsError(
          isA<EvalRunException>().having(
            (e) => e.toString(),
            'text',
            contains('m1'),
          ),
        ),
      ),
    );
  });

  test('cancelling stops the item in flight and makes no report', () async {
    final gen = _HangingGenerator();
    final events = <EvalEvent>[];
    final sub = EvalRunner(
      dataset: _tiny(),
      generator: gen,
    ).run(modelId: 'm').listen(events.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(gen.cancelled, isTrue);
    expect(events.whereType<RunCompleted>(), isEmpty);
  });

  test('prompts carry each format\'s limits', () {
    final ds = tamilV1();
    EvalPrompt first(String id) {
      final t = ds.tasks.firstWhere((t) => t.id == id);
      return buildPrompt(t, t.items.first);
    }

    expect(first('comprehension').grammar, kOptionGrammar);
    expect(first('comprehension').user, contains('\nD. '));
    expect(first('ta-en').system, contains('into English'));
    expect(first('en-ta').system, contains('into Tamil'));
    expect(first('qa').stop, ['\n']);
    expect(first('writing').stop, isEmpty);
    expect(first('writing').maxTokens, 96);
    expect(first('correction').system, contains('one mistake'));
  });
}

class _FailingGenerator implements EvalGenerator {
  final bool Function() fail;
  _FailingGenerator(this.fail);

  @override
  Stream<String> generate(EvalPrompt prompt) =>
      fail() ? Stream.error(StateError('boom')) : Stream.value('A');
}

class _HangingGenerator implements EvalGenerator {
  var cancelled = false;

  @override
  Stream<String> generate(EvalPrompt prompt) {
    late final StreamController<String> c;
    c = StreamController<String>(
      onListen: () => c.add('A'),
      onCancel: () => cancelled = true,
    );
    return c.stream;
  }
}
