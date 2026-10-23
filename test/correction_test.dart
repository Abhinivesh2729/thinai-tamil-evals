import 'package:test/test.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

void main() {
  const src = 'அவள் ஒரு பாடல் பாடினான்.';
  const ref = 'அவள் ஒரு பாடல் பாடினாள்.';

  test('the exact fix scores 1', () {
    expect(correctionScore(ref, src, ref), 1);
    expect(correctionScore('அவள் ஒரு பாடல் பாடினாள்', src, ref), 1);
  });

  test('an unchanged copy scores 0', () {
    expect(correctionScore(src, src, ref), 0);
  });

  test('a worse sentence is held at 0', () {
    expect(correctionScore('அவள்கிறைகள்கள்', src, ref), 0);
  });

  test('a partial fix earns part credit', () {
    const longSrc = 'நான் நேற்று பள்ளிக்குச் செல்வேன்.';
    const longRef = 'நான் நேற்று பள்ளிக்குச் சென்றேன்.';
    final s = correctionScore(
      'நான் நேற்று பள்ளிக்குச் சென்றான்.',
      longSrc,
      longRef,
    );
    expect(s, greaterThan(0));
    expect(s, lessThan(1));
  });

  test('a source equal to its reference still scores sensibly', () {
    expect(correctionScore('x', 'abc', 'abc'), 0);
    expect(correctionScore('a bc', 'abc', 'abc'), 1);
  });
}
