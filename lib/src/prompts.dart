import 'dataset.dart';

/// GBNF grammar that allows only an option letter.
///
/// With it, a multiple-choice item costs one decoded token, and a small model
/// cannot lose marks by explaining itself instead of answering: the score is
/// about Tamil, not about following an output format.
const kOptionGrammar = 'root ::= [ABCD]';

/// What one item asks the model, and how much it may say.
class EvalPrompt {
  final String system;
  final String user;
  final int maxTokens;

  /// GBNF constraint, for generators that support one. Scoring still works
  /// without it, from the reply text.
  final String? grammar;

  /// Text that ends the reply early. Single-line answers stop at the first
  /// line break so a model's trailing explanation costs no time.
  final List<String> stop;

  const EvalPrompt({
    required this.system,
    required this.user,
    required this.maxTokens,
    this.grammar,
    this.stop = const [],
  });
}

// Instructions are in English and the content is in Tamil. That measures
// Tamil ability rather than whether a small model follows instructions given
// in Tamil, and keeps the templates the same if another language is added.
const _mcqSystem =
    'You are taking a Tamil language test. Reply with only the letter of the '
    'correct option: A, B, C or D.';
const _taEnSystem =
    'Translate the Tamil sentence into English. Reply with only the '
    'translation.';
const _enTaSystem =
    'Translate the English sentence into Tamil, in Tamil script. Reply with '
    'only the translation.';
const _qaSystem =
    'Answer the question in Tamil with a short phrase only. Do not explain.';
const _writingSystem =
    'You are a fluent Tamil writer. Reply only in Tamil script, with no '
    'English words and no title.';
const _correctionSystem =
    'The Tamil sentence below has exactly one mistake. Reply with only the '
    'corrected sentence.';

const _oneLine = ['\n'];

/// The prompt [item] of [task] is asked with.
EvalPrompt buildPrompt(EvalTask task, EvalItem item) => switch (item) {
  McqItem() => EvalPrompt(
    system: _mcqSystem,
    user: _withPassage(
      item.passage,
      'கேள்வி: ${item.question}\n\n'
      '${[for (var i = 0; i < item.options.length; i++) '${kOptionLetters[i]}. ${item.options[i]}'].join('\n')}',
    ),
    maxTokens: task.maxTokens,
    grammar: kOptionGrammar,
  ),
  TranslateItem() => EvalPrompt(
    system: task.direction == Direction.taEn ? _taEnSystem : _enTaSystem,
    user: item.source,
    maxTokens: task.maxTokens,
    stop: _oneLine,
  ),
  QaItem() => EvalPrompt(
    system: _qaSystem,
    user: _withPassage(item.passage, 'கேள்வி: ${item.question}'),
    maxTokens: task.maxTokens,
    stop: _oneLine,
  ),
  WritingItem() => EvalPrompt(
    system: _writingSystem,
    user: item.instruction,
    maxTokens: task.maxTokens,
  ),
  CorrectionItem() => EvalPrompt(
    system: _correctionSystem,
    user: item.source,
    maxTokens: task.maxTokens,
    stop: _oneLine,
  ),
};

String _withPassage(String? passage, String rest) =>
    passage == null ? rest : '$passage\n\n$rest';
