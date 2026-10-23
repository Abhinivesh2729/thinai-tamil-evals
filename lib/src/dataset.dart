import 'dart:convert';

import 'scorers/writing.dart';
import 'tamil_text.dart';

/// How a task's items are asked and scored.
enum EvalFormat {
  /// Four options, one correct. Scored on the chosen letter.
  mcq,

  /// One sentence to translate. Scored with chrF against references.
  translate,

  /// A short answer in Tamil. Scored by match against accepted answers.
  qa,

  /// Free writing to checkable rules. Scored on the rules kept.
  writing,

  /// A sentence with one mistake to fix. Scored on how much of it is fixed.
  correction,
}

/// Which way a translation task goes.
enum Direction {
  taEn('ta-en'),
  enTa('en-ta');

  final String code;
  const Direction(this.code);

  static Direction parse(String code) => values.firstWhere(
    (d) => d.code == code,
    orElse: () {
      throw FormatException('unknown direction "$code"');
    },
  );
}

/// A skill the overall score is built from, with its share of it.
class EvalAxis {
  final String id;
  final String label;
  final String labelTa;

  /// Share of the overall score, from 0 to 1. The axes of a dataset add up
  /// to 1.
  final double weight;

  const EvalAxis({
    required this.id,
    required this.label,
    required this.labelTa,
    required this.weight,
  });

  factory EvalAxis.fromJson(Map<String, Object?> json) => EvalAxis(
    id: json['id'] as String,
    label: json['label'] as String,
    labelTa: json['labelTa'] as String,
    weight: (json['weight'] as num).toDouble(),
  );
}

/// One test question.
sealed class EvalItem {
  final String id;
  const EvalItem(this.id);

  static EvalItem fromJson(EvalFormat format, Map<String, Object?> json) {
    final id = json['id'] as String;
    List<String> strings(String key) => [
      for (final s in json[key] as List) s as String,
    ];
    return switch (format) {
      EvalFormat.mcq => McqItem(
        id,
        passage: json['passage'] as String?,
        question: json['question'] as String,
        options: strings('options'),
        answer: _letterIndex(json['answer'] as String),
      ),
      EvalFormat.translate => TranslateItem(
        id,
        source: json['source'] as String,
        references: strings('references'),
      ),
      EvalFormat.qa => QaItem(
        id,
        passage: json['passage'] as String?,
        question: json['question'] as String,
        answers: strings('answers'),
      ),
      EvalFormat.writing => WritingItem(
        id,
        instruction: json['instruction'] as String,
        rules: WritingRules.fromJson(json['rules'] as Map<String, Object?>),
      ),
      EvalFormat.correction => CorrectionItem(
        id,
        source: json['source'] as String,
        reference: json['reference'] as String,
      ),
    };
  }
}

/// Option letters, in order.
const kOptionLetters = ['A', 'B', 'C', 'D'];

int _letterIndex(String letter) {
  final i = kOptionLetters.indexOf(letter);
  if (i < 0) throw FormatException('answer "$letter" is not A to D');
  return i;
}

class McqItem extends EvalItem {
  final String? passage;
  final String question;
  final List<String> options;

  /// Index of the correct option in [options].
  final int answer;

  const McqItem(
    super.id, {
    this.passage,
    required this.question,
    required this.options,
    required this.answer,
  });
}

class TranslateItem extends EvalItem {
  final String source;
  final List<String> references;

  const TranslateItem(
    super.id, {
    required this.source,
    required this.references,
  });
}

class QaItem extends EvalItem {
  final String? passage;
  final String question;
  final List<String> answers;

  const QaItem(
    super.id, {
    this.passage,
    required this.question,
    required this.answers,
  });
}

class WritingItem extends EvalItem {
  final String instruction;
  final WritingRules rules;

  const WritingItem(super.id, {required this.instruction, required this.rules});
}

class CorrectionItem extends EvalItem {
  final String source;
  final String reference;

  const CorrectionItem(
    super.id, {
    required this.source,
    required this.reference,
  });
}

/// A group of items asked and scored the same way.
class EvalTask {
  final String id;
  final String axis;
  final EvalFormat format;
  final String label;
  final String labelTa;

  /// Output cap per item. Kept tight: on a phone decoding at 25 tokens a
  /// second, every unused token of headroom a model fills with chatter is
  /// time the user waits.
  final int maxTokens;

  /// Set for [EvalFormat.translate] only.
  final Direction? direction;

  final List<EvalItem> items;

  const EvalTask({
    required this.id,
    required this.axis,
    required this.format,
    required this.label,
    required this.labelTa,
    required this.maxTokens,
    required this.items,
    this.direction,
  });

  factory EvalTask.fromJson(Map<String, Object?> json) {
    final format = EvalFormat.values.byName(json['format'] as String);
    final direction = json['direction'] as String?;
    return EvalTask(
      id: json['id'] as String,
      axis: json['axis'] as String,
      format: format,
      label: json['label'] as String,
      labelTa: json['labelTa'] as String,
      maxTokens: json['maxTokens'] as int,
      direction: direction == null ? null : Direction.parse(direction),
      items: [
        for (final i in json['items'] as List)
          EvalItem.fromJson(format, i as Map<String, Object?>),
      ],
    );
  }
}

/// A versioned set of tasks for one language.
///
/// Scores belong to a dataset version: change an item and the numbers are no
/// longer comparable with older runs, so the version must change with it.
class EvalDataset {
  final String language;
  final String version;
  final List<EvalAxis> axes;
  final List<EvalTask> tasks;

  const EvalDataset({
    required this.language,
    required this.version,
    required this.axes,
    required this.tasks,
  });

  /// Parses and validates [source]. Throws a [FormatException] listing every
  /// problem, so a bad dataset never produces a score.
  factory EvalDataset.parse(String source) {
    final EvalDataset dataset;
    try {
      final json = jsonDecode(source) as Map<String, Object?>;
      dataset = EvalDataset(
        language: json['language'] as String,
        version: json['version'] as String,
        axes: [
          for (final a in json['axes'] as List)
            EvalAxis.fromJson(a as Map<String, Object?>),
        ],
        tasks: [
          for (final t in json['tasks'] as List)
            EvalTask.fromJson(t as Map<String, Object?>),
        ],
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      // A missing or mistyped field is a malformed dataset, not a crash.
      throw FormatException('malformed dataset: $e');
    }
    final problems = dataset.validate();
    if (problems.isNotEmpty) {
      throw FormatException('invalid dataset:\n${problems.join('\n')}');
    }
    return dataset;
  }

  int get itemCount => tasks.fold(0, (n, t) => n + t.items.length);

  EvalAxis axis(String id) => axes.firstWhere((a) => a.id == id);

  /// Every rule the dataset breaks, empty when it is sound.
  List<String> validate() {
    final problems = <String>[];
    final axisIds = {for (final a in axes) a.id};
    final weights = axes.fold(0.0, (sum, a) => sum + a.weight);
    if ((weights - 1).abs() > 1e-6) {
      problems.add('axis weights add up to $weights, not 1');
    }
    final ids = <String>{};
    for (final task in tasks) {
      if (!axisIds.contains(task.axis)) {
        problems.add('${task.id}: unknown axis "${task.axis}"');
      }
      if (task.items.isEmpty) problems.add('${task.id}: no items');
      if (task.maxTokens < 1) problems.add('${task.id}: maxTokens < 1');
      if ((task.format == EvalFormat.translate) != (task.direction != null)) {
        problems.add('${task.id}: direction is for translate tasks only');
      }
      for (final item in task.items) {
        if (!ids.add(item.id)) problems.add('${item.id}: duplicate id');
        problems.addAll(_check(task, item).map((p) => '${item.id}: $p'));
      }
      if (task.format == EvalFormat.mcq) {
        problems.addAll(_checkAnswerSpread(task));
      }
    }
    return problems;
  }

  /// Correct answers must be spread over the four letters, so a model that
  /// always picks the same one scores no better than chance.
  static List<String> _checkAnswerSpread(EvalTask task) {
    final counts = List.filled(kOptionLetters.length, 0);
    for (final item in task.items) {
      counts[(item as McqItem).answer]++;
    }
    final most = counts.reduce((a, b) => a > b ? a : b);
    final least = counts.reduce((a, b) => a < b ? a : b);
    return most - least > 1
        ? ['${task.id}: answers spread unevenly over A to D $counts']
        : const [];
  }

  static List<String> _check(EvalTask task, EvalItem item) {
    final problems = <String>[];
    void tamil(String field, String? text) {
      if (text == null) return;
      if (text.trim().isEmpty) {
        problems.add('$field is empty');
      } else if (hasLetters(text) && tamilRatio(text) < kTamilScriptRatio) {
        problems.add('$field is not Tamil script');
      }
    }

    void english(String field, String text) {
      if (text.trim().isEmpty) {
        problems.add('$field is empty');
      } else if (tamilRatio(text) > 0) {
        problems.add('$field has Tamil in it');
      }
    }

    switch (item) {
      case McqItem():
        tamil('passage', item.passage);
        tamil('question', item.question);
        if (item.options.length != kOptionLetters.length) {
          problems.add('needs exactly 4 options');
        }
        if (item.options.toSet().length != item.options.length) {
          problems.add('options repeat');
        }
        for (final o in item.options) {
          tamil('option', o);
        }
      case TranslateItem():
        final taSource = task.direction == Direction.taEn;
        (taSource ? tamil : english)('source', item.source);
        if (item.references.isEmpty) problems.add('no references');
        for (final r in item.references) {
          (taSource ? english : tamil)('reference', r);
        }
      case QaItem():
        tamil('passage', item.passage);
        tamil('question', item.question);
        if (item.answers.isEmpty) problems.add('no answers');
        for (final a in item.answers) {
          if (a.trim().isEmpty) problems.add('answer is empty');
        }
      case WritingItem():
        tamil('instruction', item.instruction);
        final r = item.rules;
        if (r.minSentences < 1 || r.maxSentences < r.minSentences) {
          problems.add('sentence range ${r.minSentences}..${r.maxSentences}');
        }
        for (final w in r.mustUse) {
          tamil('mustUse', w);
        }
      case CorrectionItem():
        tamil('source', item.source);
        tamil('reference', item.reference);
        if (normalizeForMatch(item.source) ==
            normalizeForMatch(item.reference)) {
          problems.add('source has no mistake');
        }
    }
    return problems;
  }
}
