import '../tamil_text.dart';

/// Character n-gram orders chrF looks at.
const kChrfOrder = 6;

/// chrF's beta: recall counts twice as much as precision.
const kChrfBeta = 2.0;

/// Sentence-level chrF of [hypothesis] against the best of [references],
/// from 0 to 100.
///
/// Matches sacreBLEU's chrF (n = 6, beta = 2, whitespace removed): precision
/// and recall are averaged over the orders both sides have n-grams for, then
/// combined into an F-score. Character n-grams suit Tamil, where one word
/// carries what English spreads over several, so a translation with the right
/// stem and a different suffix still earns partial credit.
double chrf(String hypothesis, List<String> references) {
  var best = 0.0;
  for (final r in references) {
    final s = _chrf(hypothesis, r);
    if (s > best) best = s;
  }
  return best;
}

double _chrf(String hypothesis, String reference) {
  final hyp = _chars(hypothesis);
  final ref = _chars(reference);
  var precision = 0.0;
  var recall = 0.0;
  var effectiveOrder = 0;
  for (var n = 1; n <= kChrfOrder; n++) {
    final h = _ngrams(hyp, n);
    final r = _ngrams(ref, n);
    final hypCount = _total(h);
    final refCount = _total(r);
    if (hypCount == 0 || refCount == 0) continue;
    var matches = 0;
    h.forEach((gram, count) {
      final other = r[gram];
      if (other != null) matches += count < other ? count : other;
    });
    precision += matches / hypCount;
    recall += matches / refCount;
    effectiveOrder++;
  }
  if (effectiveOrder == 0) return 0;
  precision /= effectiveOrder;
  recall /= effectiveOrder;
  if (precision + recall == 0) return 0;
  const factor = kChrfBeta * kChrfBeta;
  return 100 *
      (1 + factor) *
      precision *
      recall /
      (factor * precision + recall);
}

List<int> _chars(String s) =>
    normalize(s).replaceAll(' ', '').runes.toList(growable: false);

Map<String, int> _ngrams(List<int> chars, int n) {
  final out = <String, int>{};
  for (var i = 0; i + n <= chars.length; i++) {
    final gram = String.fromCharCodes(chars.sublist(i, i + n));
    out[gram] = (out[gram] ?? 0) + 1;
  }
  return out;
}

int _total(Map<String, int> grams) => grams.values.fold(0, (sum, c) => sum + c);
