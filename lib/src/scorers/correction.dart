import '../tamil_text.dart';
import 'chrf.dart';

/// Score of a corrected sentence, from 0 to 1.
///
/// The source and the fix differ by one mistake, so plain chrF would give a
/// model that copies the sentence unchanged nearly full marks. This scores
/// how much of the gap between [source] and [reference] the reply closes:
/// an unchanged copy gets 0, the exact fix gets 1, and a reply that makes the
/// sentence worse is held at 0.
double correctionScore(String reply, String source, String reference) {
  if (normalizeForMatch(reply) == normalizeForMatch(reference)) return 1;
  final base = chrf(source, [reference]);
  final got = chrf(reply, [reference]);
  if (base >= 100) return got >= 100 ? 1 : 0;
  final gain = (got - base) / (100 - base);
  return gain.clamp(0.0, 1.0).toDouble();
}
