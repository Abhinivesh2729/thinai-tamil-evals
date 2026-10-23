import 'dataset.dart';
import 'scoring.dart';

/// How one item went.
class ItemResult {
  final String taskId;
  final String itemId;

  /// The model's raw reply.
  final String output;

  /// From 0 to 1.
  final double score;

  final Duration elapsed;

  const ItemResult({
    required this.taskId,
    required this.itemId,
    required this.output,
    required this.score,
    required this.elapsed,
  });

  Map<String, Object?> toJson() => {
    'task': taskId,
    'item': itemId,
    'output': output,
    'score': score,
    'ms': elapsed.inMilliseconds,
  };

  factory ItemResult.fromJson(Map<String, Object?> json) => ItemResult(
    taskId: json['task'] as String,
    itemId: json['item'] as String,
    output: json['output'] as String,
    score: (json['score'] as num).toDouble(),
    elapsed: Duration(milliseconds: json['ms'] as int),
  );
}

/// One task's result.
class TaskScore {
  final String taskId;
  final String axis;
  final EvalFormat format;

  /// Items scored.
  final int count;

  /// Mean item score, from 0 to 1. For multiple choice, the share correct.
  final double mean;

  /// From 0 to 100; see [taskScore].
  final double score;

  const TaskScore({
    required this.taskId,
    required this.axis,
    required this.format,
    required this.count,
    required this.mean,
    required this.score,
  });

  /// Items answered right, for multiple choice.
  int get correct => (mean * count).round();

  Map<String, Object?> toJson() => {
    'task': taskId,
    'axis': axis,
    'format': format.name,
    'n': count,
    'mean': mean,
    'score': score,
  };

  factory TaskScore.fromJson(Map<String, Object?> json) => TaskScore(
    taskId: json['task'] as String,
    axis: json['axis'] as String,
    format: EvalFormat.values.byName(json['format'] as String),
    count: json['n'] as int,
    mean: (json['mean'] as num).toDouble(),
    score: (json['score'] as num).toDouble(),
  );
}

/// A finished run: the overall Tamil score and everything behind it.
class EvalReport {
  final String language;
  final String datasetVersion;
  final String modelId;
  final DateTime startedAt;
  final Duration elapsed;

  /// From 0 to 100: the axis scores, weighted.
  final double overall;

  /// Axis id to score, from 0 to 100.
  final Map<String, double> axes;

  final List<TaskScore> tasks;
  final List<ItemResult> items;

  const EvalReport({
    required this.language,
    required this.datasetVersion,
    required this.modelId,
    required this.startedAt,
    required this.elapsed,
    required this.overall,
    required this.axes,
    required this.tasks,
    required this.items,
  });

  /// Scores [items] against [dataset].
  ///
  /// A task scores the mean of its items, an axis the mean of its tasks, and
  /// the overall score the axes by weight. Averaging tasks rather than items
  /// keeps a task with more items from outweighing the others on its axis.
  factory EvalReport.score({
    required EvalDataset dataset,
    required String modelId,
    required DateTime startedAt,
    required Duration elapsed,
    required List<ItemResult> items,
  }) {
    final tasks = <TaskScore>[];
    for (final task in dataset.tasks) {
      final mine = items.where((r) => r.taskId == task.id).toList();
      if (mine.isEmpty) continue;
      final mean = mine.fold(0.0, (s, r) => s + r.score) / mine.length;
      tasks.add(
        TaskScore(
          taskId: task.id,
          axis: task.axis,
          format: task.format,
          count: mine.length,
          mean: mean,
          score: taskScore(task.format, mean),
        ),
      );
    }
    final axes = <String, double>{};
    var overall = 0.0;
    var weight = 0.0;
    for (final axis in dataset.axes) {
      final mine = tasks.where((t) => t.axis == axis.id).toList();
      if (mine.isEmpty) continue;
      final score = mine.fold(0.0, (s, t) => s + t.score) / mine.length;
      axes[axis.id] = score;
      overall += axis.weight * score;
      weight += axis.weight;
    }
    return EvalReport(
      language: dataset.language,
      datasetVersion: dataset.version,
      modelId: modelId,
      startedAt: startedAt,
      elapsed: elapsed,
      overall: weight == 0 ? 0 : overall / weight,
      axes: axes,
      tasks: tasks,
      items: items,
    );
  }

  TaskScore? task(String id) {
    for (final t in tasks) {
      if (t.taskId == id) return t;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'language': language,
    'version': datasetVersion,
    'model': modelId,
    'at': startedAt.toIso8601String(),
    'ms': elapsed.inMilliseconds,
    'overall': overall,
    'axes': axes,
    'tasks': [for (final t in tasks) t.toJson()],
    'items': [for (final i in items) i.toJson()],
  };

  factory EvalReport.fromJson(Map<String, Object?> json) => EvalReport(
    language: json['language'] as String,
    datasetVersion: json['version'] as String,
    modelId: json['model'] as String,
    startedAt: DateTime.parse(json['at'] as String),
    elapsed: Duration(milliseconds: json['ms'] as int),
    overall: (json['overall'] as num).toDouble(),
    axes: {
      for (final e in (json['axes'] as Map<String, Object?>).entries)
        e.key: (e.value as num).toDouble(),
    },
    tasks: [
      for (final t in json['tasks'] as List)
        TaskScore.fromJson(t as Map<String, Object?>),
    ],
    items: [
      for (final i in json['items'] as List)
        ItemResult.fromJson(i as Map<String, Object?>),
    ],
  );
}
