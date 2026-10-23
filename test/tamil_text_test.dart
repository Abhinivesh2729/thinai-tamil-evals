import 'package:test/test.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

void main() {
  group('normalize', () {
    test('composes the four two-part vowel signs', () {
      expect(normalize('கொ'), 'கொ');
      expect(normalize('கோ'), 'கோ');
      expect(normalize('கௌ'), 'கௌ');
      expect(normalize('ஔ'), 'ஔ');
    });

    test('drops invisible joiners and straightens punctuation', () {
      expect(normalize('அ‍ம்‌மா﻿'), 'அம்மா');
      expect(normalize('“சரி” ‘ஆம்’ a—b？'), '"சரி" \'ஆம்\' a-b?');
    });

    test('collapses whitespace and trims', () {
      expect(normalize('  நான்\n\t வந்தேன்  '), 'நான் வந்தேன்');
    });
  });

  test('normalizeForMatch lower-cases and strips punctuation', () {
    expect(normalizeForMatch('Chennai, சென்னை!'), 'chennai சென்னை');
    expect(normalizeForMatch('விடை: ஏழு.'), 'விடை ஏழு');
  });

  test('words splits match form, and is empty for blank text', () {
    expect(words('மழை, பெய்தது.'), ['மழை', 'பெய்தது']);
    expect(words(' . '), isEmpty);
  });

  test('sentenceCount counts end marks and a trailing fragment', () {
    expect(sentenceCount('ஒன்று. இரண்டு! மூன்று'), 3);
    expect(sentenceCount('ஒன்று...'), 1);
    expect(sentenceCount(''), 0);
  });

  group('tamilRatio', () {
    test('is 1 for Tamil and 0 for English', () {
      expect(tamilRatio('வணக்கம்'), 1);
      expect(tamilRatio('hello'), 0);
    });

    test('ignores digits, spaces, punctuation and joiners', () {
      expect(tamilRatio('வணக்கம் 123, “ஆம்”‍।'), 1);
    });

    test('counts other scripts against', () {
      expect(tamilRatio('అమ్మ'), 0);
      expect(tamilRatio('அa'), 0.5);
    });

    test('is 0 with no letters', () {
      expect(tamilRatio(''), 0);
      expect(tamilRatio('1330'), 0);
    });
  });

  test('hasLetters tells words from numbers', () {
    expect(hasLetters('1330'), isFalse);
    expect(hasLetters('12 மணி'), isTrue);
    expect(hasLetters('x'), isTrue);
    expect(hasLetters('ළ'), isTrue);
  });

  test('stripThink removes closed and unterminated reasoning', () {
    expect(stripThink('<think>hmm</think>\nB'), 'B');
    expect(stripThink('A <think>still going'), 'A');
    expect(stripThink('plain'), 'plain');
  });
}
