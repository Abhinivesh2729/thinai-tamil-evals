import 'package:test/test.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

void main() {
  test('a report round-trips through JSON', () {
    final ds = tamilV1();
    final items = [
      for (final t in ds.tasks)
        for (final i in t.items)
          ItemResult(
            taskId: t.id,
            itemId: i.id,
            output: 'x',
            score: 0.5,
            elapsed: const Duration(milliseconds: 1500),
          ),
    ];
    final report = EvalReport.score(
      dataset: ds,
      modelId: 'lfm',
      startedAt: DateTime.utc(2026, 10, 24),
      elapsed: const Duration(seconds: 150),
      items: items,
    );
    final back = EvalReport.fromJson(report.toJson());
    expect(back.toJson(), report.toJson());
    expect(back.items.first.elapsed, const Duration(milliseconds: 1500));
    expect(back.tasks.first.format, EvalFormat.mcq);
    expect(back.axes.keys, ['understanding', 'expression', 'knowledge']);
  });

  test('a report of nothing scores 0 and lists no axes', () {
    final report = EvalReport.score(
      dataset: tamilV1(),
      modelId: 'm',
      startedAt: DateTime.utc(2026),
      elapsed: Duration.zero,
      items: const [],
    );
    expect(report.overall, 0);
    expect(report.axes, isEmpty);
    expect(report.tasks, isEmpty);
  });
}
