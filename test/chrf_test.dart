import 'package:test/test.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

void main() {
  // Expected values from sacreBLEU 2.4.3, CHRF() defaults, sentence_score.
  const golden = [
    (
      'The bus came ten minutes late.',
      'The bus arrived ten minutes late.',
      64.8305,
    ),
    ('It may rain tomorrow.', 'It might rain tomorrow.', 66.3034),
    ('The sun rises in the east.', 'I drink coffee every morning.', 9.0422),
    ('என் அம்மா சமைக்கிறார்.', 'என் அம்மா சமைத்துக்கொண்டிருக்கிறார்.', 51.7486),
    (
      'ரயில் ஏழு மணிக்கு புறப்படும்.',
      'ரயில் ஏழு மணிக்குப் புறப்படும்.',
      86.5216,
    ),
    ('கேர்ட்டை அன்றும்', 'தயவுசெய்து கதவை மூடுங்கள்.', 6.006),
    ('a', 'abc', 38.4615),
    ('Hello there friend', 'Hello there friend', 100.0),
  ];

  for (final (hyp, ref, want) in golden) {
    test('matches sacreBLEU: $hyp', () {
      expect(chrf(hyp, [ref]), closeTo(want, 1e-3));
    });
  }

  test('scores 0 for an empty hypothesis or no shared letters', () {
    expect(chrf('', ['abc']), 0);
    expect(chrf('xyz', ['abc']), 0);
  });

  test('takes the best reference', () {
    expect(
      chrf('It may rain tomorrow.', ['nothing alike', 'It may rain tomorrow.']),
      100,
    );
  });

  test('ignores whitespace and decomposed vowel signs', () {
    const composed = 'கொடு';
    const decomposed = 'கொடு';
    expect(chrf(decomposed, [composed]), 100);
    expect(chrf('a b c', ['abc']), 100);
  });
}
