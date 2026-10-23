import 'package:test/test.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

void main() {
  const one = WritingRules(minSentences: 1, maxSentences: 2, mustUse: ['மழை']);

  test('a real sentence that keeps every rule scores 1', () {
    expect(writingScore('மழை பெய்தால் மண் வாசனை வீசும்.', one), 1);
  });

  test('each rule is checked on its own', () {
    final checks = writingChecks('வெயில் அடிக்கிறது.', one);
    expect(
      {for (final c in checks) c.rule: c.passed},
      {
        'tamil-script': true,
        'sentences': true,
        'uses:மழை': false,
        'no-loop': true,
      },
    );
    expect(writingScore('வெயில் அடிக்கிறது.', one), 0.75);
  });

  test('too many sentences fails the sentence rule', () {
    expect(
      writingScore('மழை வந்தது. மழை நின்றது. மழை மீண்டும் வந்தது.', one),
      0.75,
    );
  });

  test('a looping reply fails the loop rule', () {
    final loop = List.filled(6, 'மழை பெய்தது நல்ல').join(' ');
    final checks = writingChecks(loop, one);
    expect(checks.firstWhere((c) => c.rule == 'no-loop').passed, isFalse);
  });

  test('another script scores 0', () {
    expect(writingScore('Rain is falling today.', one), 0);
    expect(writingScore('ළලුතු සින්තී වේරුණුමුතුලට', one), 0);
  });

  test('Tamil letters that are not words score 0', () {
    // A real reply from a 350M model with a byte-level tokenizer.
    const noise = 'நன்றிப்பைகள்கின் அன்றேட்டுங்கள்';
    expect(
      writingScore(
        noise,
        const WritingRules(
          minSentences: 1,
          maxSentences: 2,
          mustUse: ['நன்றி'],
        ),
      ),
      0,
    );
  });

  test('rules round-trip through JSON', () {
    final back = WritingRules.fromJson(one.toJson());
    expect(back.mustUse, ['மழை']);
    expect(back.maxSentences, 2);
    expect(
      const WritingRules(
        minSentences: 1,
        maxSentences: 1,
      ).toJson().containsKey('mustUse'),
      isFalse,
    );
    expect(
      WritingRules.fromJson({'minSentences': 1, 'maxSentences': 1}).mustUse,
      isEmpty,
    );
  });

  group('common words', () {
    test(
      'a stem with an ending counts, a stem with a second word does not',
      () {
        expect(isCommonWord('பள்ளிக்குச்'), isTrue);
        expect(isCommonWord('நன்றிப்பைகள்கின்'), isFalse);
        expect(isCommonWord('மழை'), isTrue);
      },
    );

    test('ratio is 0 with no words', () {
      expect(commonWordRatio(const []), 0);
      expect(commonWordRatio(['மழை', 'க்ஷ்ஷ']), 0.5);
    });
  });
}
