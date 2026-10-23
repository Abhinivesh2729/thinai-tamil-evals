import '../tamil_text.dart';
import 'lexicon.dart';

/// Below this share of Tamil letters a reply is not Tamil writing at all, and
/// the other checks are not worth passing.
const kMinTamilRatio = 0.5;

/// Share of Tamil letters a reply needs to pass the script check.
const kTamilScriptRatio = 0.9;

/// Share of common words below which a reply is letters, not Tamil. See
/// [kCommonTamil].
const kMinCommonWords = 0.34;

/// Share of distinct word trigrams below which a reply is looping.
const kMinDistinctTrigrams = 0.7;

/// What a writing task asks for, each part checkable by a program.
///
/// A writing score from a model judge would need a second, bigger model on
/// the phone. Rules like these are the IFEval approach: they cannot tell good
/// prose from plain prose, but they do tell whether a model can follow a
/// Tamil instruction and write real, non-repeating Tamil.
class WritingRules {
  final int minSentences;
  final int maxSentences;

  /// Word stems the reply must use. A stem matches any word starting with
  /// it, so `பறவை` is met by `பறவைகள்`.
  final List<String> mustUse;

  const WritingRules({
    required this.minSentences,
    required this.maxSentences,
    this.mustUse = const [],
  });

  factory WritingRules.fromJson(Map<String, Object?> json) => WritingRules(
    minSentences: json['minSentences'] as int,
    maxSentences: json['maxSentences'] as int,
    mustUse: [
      for (final w in json['mustUse'] as List? ?? const []) w as String,
    ],
  );

  Map<String, Object?> toJson() => {
    'minSentences': minSentences,
    'maxSentences': maxSentences,
    if (mustUse.isNotEmpty) 'mustUse': mustUse,
  };
}

/// One rule and whether the reply kept it.
class WritingCheck {
  final String rule;
  final bool passed;
  const WritingCheck(this.rule, this.passed);
}

/// Every check [rules] makes of [reply], in a fixed order.
List<WritingCheck> writingChecks(String reply, WritingRules rules) {
  final text = normalize(reply);
  final ws = words(text);
  final sentences = sentenceCount(text);
  return [
    WritingCheck('tamil-script', tamilRatio(text) >= kTamilScriptRatio),
    WritingCheck(
      'sentences',
      sentences >= rules.minSentences && sentences <= rules.maxSentences,
    ),
    for (final stem in rules.mustUse)
      WritingCheck(
        'uses:$stem',
        ws.any((w) => w.startsWith(normalizeForMatch(stem))),
      ),
    WritingCheck('no-loop', _distinctTrigrams(ws) >= kMinDistinctTrigrams),
  ];
}

/// Share of [WritingRules] the reply keeps, from 0 to 1, or 0 when it is
/// not readable Tamil: mostly another script, or Tamil letters that do not
/// make everyday words.
double writingScore(String reply, WritingRules rules) {
  if (tamilRatio(reply) < kMinTamilRatio) return 0;
  if (commonWordRatio(words(reply)) < kMinCommonWords) return 0;
  final checks = writingChecks(reply, rules);
  return checks.where((c) => c.passed).length / checks.length;
}

double _distinctTrigrams(List<String> ws) {
  if (ws.length < 3) return 1;
  final grams = <String>{};
  final total = ws.length - 2;
  for (var i = 0; i < total; i++) {
    grams.add('${ws[i]} ${ws[i + 1]} ${ws[i + 2]}');
  }
  return grams.length / total;
}
