import 'dart:convert';
import 'dart:io';

import 'package:thinai_tamil_evals/openai.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

const _usage = '''
Runs the Tamil test set against an OpenAI-compatible endpoint.

  dart run thinai_tamil_evals --endpoint http://127.0.0.1:11434/v1 \\
      --model lfm2.5-350m-q8_0 [--out report.json] [--api-key KEY] [--no-grammar]
''';

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final endpoint = arg('endpoint');
  final model = arg('model');
  if (endpoint == null || model == null || args.contains('--help')) {
    stdout.write(_usage);
    exit(endpoint == null || model == null ? 64 : 0);
  }
  final generator = OpenAiGenerator(
    endpoint: Uri.parse(endpoint),
    model: model,
    apiKey: arg('api-key'),
    sendGrammar: !args.contains('--no-grammar'),
  );
  final runner = EvalRunner(dataset: tamilV1(), generator: generator);
  final total = runner.steps.length;
  try {
    await for (final event in runner.run(modelId: model)) {
      switch (event) {
        case ItemScored(:final step, :final result):
          final out = result.output.replaceAll('\n', ' ');
          stdout.writeln(
            '${(step.index + 1).toString().padLeft(2)}/$total '
            '${step.item.id} ${result.score.toStringAsFixed(2)} '
            '${(result.elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s  $out',
          );
        case RunCompleted(:final report):
          stdout.writeln('');
          for (final t in report.tasks) {
            stdout.writeln(
              '${t.taskId.padRight(14)} ${t.score.toStringAsFixed(1).padLeft(5)}  (n=${t.count})',
            );
          }
          report.axes.forEach(
            (a, s) => stdout.writeln(
              '${a.padRight(14)} ${s.toStringAsFixed(1).padLeft(5)}',
            ),
          );
          stdout.writeln(
            'Tamil score    ${report.overall.toStringAsFixed(1).padLeft(5)}  '
            'in ${(report.elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
          );
          final out = arg('out');
          if (out != null) {
            File(out).writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(report.toJson()),
            );
          }
        default:
      }
    }
  } finally {
    generator.close();
  }
}
