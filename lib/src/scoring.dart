import 'dataset.dart';
import 'scorers/chrf.dart';
import 'scorers/correction.dart';
import 'scorers/qa.dart';
import 'scorers/writing.dart';
import 'tamil_text.dart';

/// Chance of guessing a four-option question right.
const kMcqChance = 0.25;

/// chrF an unrelated sentence in the right language earns, from shared
/// letters alone. Measured on the v1 references against each other: 12 for
/// English, 14 for Tamil.
const kChrfFloor = 15.0;

final _leadingLetter = RegExp(r'^\s*[\(\[]?([A-D])(?:[\)\].:]|\s|$)');
final _answerLetter = RegExp(
  r'(?:answer|விடை)\s*(?:is)?\s*[:：]?\s*\(?([A-D])\b',
  caseSensitive: false,
);

/// The option [reply] chose, or null when it names none.
///
/// A grammar-constrained reply is a bare letter. The other rules are for
/// generators without grammar support: a leading letter, `Answer: B`, or the
/// text of exactly one option.
int? parseChoice(String reply, McqItem item) {
  final text = normalize(stripThink(reply));
  final lead = _leadingLetter.firstMatch(text);
  if (lead != null) return kOptionLetters.indexOf(lead.group(1)!);
  final labelled = _answerLetter.firstMatch(text);
  if (labelled != null) {
    return kOptionLetters.indexOf(labelled.group(1)!.toUpperCase());
  }
  final said = normalizeForMatch(text);
  final named = [
    for (var i = 0; i < item.options.length; i++)
      if (said.contains(normalizeForMatch(item.options[i]))) i,
  ];
  return named.length == 1 ? named.single : null;
}

/// The reply as a scorer reads it: reasoning removed, first paragraph only,
/// since a trailing explanation is not part of the answer.
String answerText(String reply) {
  final text = stripThink(reply).trim();
  final end = text.indexOf(RegExp(r'\n\s*\n'));
  return normalize(end < 0 ? text : text.substring(0, end));
}

/// Score of [reply] to [item], from 0 to 1.
double scoreItem(EvalItem item, String reply) => switch (item) {
  McqItem() => parseChoice(reply, item) == item.answer ? 1 : 0,
  TranslateItem() => chrf(answerText(reply), item.references) / 100,
  QaItem() => qaScore(answerText(reply), item.answers),
  WritingItem() => writingScore(stripThink(reply), item.rules),
  CorrectionItem() => correctionScore(
    answerText(reply),
    item.source,
    item.reference,
  ),
};

/// A task's score from 0 to 100 given the mean of its item scores.
///
/// Scores are skill above guessing. A model picking at random gets 25% of
/// multiple choice right, and any English sentence shares enough letters
/// with a reference to earn about 15 chrF; neither is a step towards knowing
/// Tamil. So guessing scores 0, a perfect run 100, and the scale between is
/// linear.
double taskScore(EvalFormat format, double mean) => switch (format) {
  EvalFormat.mcq => _above(mean, kMcqChance),
  EvalFormat.translate => _above(mean, kChrfFloor / 100),
  _ => 100 * mean,
};

double _above(double mean, double floor) =>
    100 * ((mean - floor) / (1 - floor)).clamp(0.0, 1.0).toDouble();
