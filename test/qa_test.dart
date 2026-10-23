import 'package:test/test.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

void main() {
  test('exact answer scores 1', () {
    expect(qaScore('சென்னை', ['சென்னை']), 1);
    expect(qaScore('சென்னை.', ['சென்னை']), 1);
  });

  test('a case ending on the answer still counts', () {
    expect(qaScore('சந்தைக்கு', ['சந்தை']), 1);
    expect(qaScore('அவன் சந்தைக்குச் சென்றான்', ['சந்தை']), 1);
  });

  test('a short gold word is not a stem', () {
    // Two letters begin too many words to stand for one.
    expect(qaScore('அவன்', ['அ']), 0);
  });

  test('any accepted answer will do', () {
    expect(qaScore('7', ['ஏழு', '7']), 1);
  });

  test('a long reply falls back to token F1', () {
    final s = qaScore(
      'நான் நினைக்கிறேன் அது ஒருவேளை சிவப்பு நிறச் சைக்கிள் ஆக இருக்கலாம்',
      ['சிவப்புச் சைக்கிள்'],
    );
    expect(s, greaterThan(0));
    expect(s, lessThan(1));
  });

  test('wrong and empty replies score 0', () {
    expect(qaScore('மதுரை', ['சென்னை']), 0);
    expect(qaScore('', ['சென்னை']), 0);
    expect(qaScore('சென்னை', ['']), 0);
  });
}
