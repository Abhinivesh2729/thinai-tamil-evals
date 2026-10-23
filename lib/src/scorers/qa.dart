import '../tamil_text.dart';

/// Shortest gold word a longer predicted word may extend with a suffix.
///
/// Below this a prefix match is too loose: a two-letter word is the start of
/// far too many others.
const _minStemRunes = 3;

/// Extra words a prediction may carry around the gold answer and still count
/// as that answer, ex. `சென்னை நகரம்` for `சென்னை`.
const _slackWords = 3;

/// Score of a short answer against the accepted [answers], from 0 to 1.
///
/// Full marks when an accepted answer appears in a short prediction;
/// otherwise the best SQuAD-style token F1. Tamil adds case endings to
/// nouns, so `சென்னையில்` answers `சென்னை`: a predicted word that starts
/// with a gold word counts as that word.
double qaScore(String prediction, List<String> answers) {
  final pred = words(prediction);
  if (pred.isEmpty) return 0;
  var best = 0.0;
  for (final a in answers) {
    final gold = words(a);
    if (gold.isEmpty) continue;
    if (pred.length <= gold.length + _slackWords && _contains(pred, gold)) {
      return 1;
    }
    final f1 = _f1(pred, gold);
    if (f1 > best) best = f1;
  }
  return best;
}

bool _matches(String predicted, String gold) =>
    predicted == gold ||
    (gold.runes.length >= _minStemRunes && predicted.startsWith(gold));

/// True when [gold] appears as a run of consecutive words in [pred].
bool _contains(List<String> pred, List<String> gold) {
  for (var i = 0; i + gold.length <= pred.length; i++) {
    var all = true;
    for (var j = 0; j < gold.length; j++) {
      if (!_matches(pred[i + j], gold[j])) {
        all = false;
        break;
      }
    }
    if (all) return true;
  }
  return false;
}

double _f1(List<String> pred, List<String> gold) {
  final unused = [...gold];
  var common = 0;
  for (final p in pred) {
    final i = unused.indexWhere((g) => _matches(p, g));
    if (i >= 0) {
      unused.removeAt(i);
      common++;
    }
  }
  if (common == 0) return 0;
  final precision = common / pred.length;
  final recall = common / gold.length;
  return 2 * precision * recall / (precision + recall);
}
