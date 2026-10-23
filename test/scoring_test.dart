import 'package:test/test.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

void main() {
  const item = McqItem(
    'm',
    question: 'கேள்வி?',
    options: ['சென்னை', 'மதுரை', 'கோவை', 'சேலம்'],
    answer: 1,
  );

  group('parseChoice', () {
    test('reads a bare or bracketed letter', () {
      expect(parseChoice('B', item), 1);
      expect(parseChoice(' (C) because', item), 2);
      expect(parseChoice('D.', item), 3);
    });

    test('reads a labelled answer', () {
      expect(parseChoice('The answer is: b', item), 1);
      expect(parseChoice('சரியான விடை: A', item), 0);
    });

    test('reads the text of exactly one option', () {
      expect(parseChoice('அது மதுரை நகரம்', item), 1);
      expect(parseChoice('சென்னை அல்லது மதுரை', item), isNull);
    });

    test('skips reasoning and gives up on nothing', () {
      expect(parseChoice('<think>A or B?</think>B', item), 1);
      expect(parseChoice('தெரியவில்லை', item), isNull);
    });
  });

  test('answerText drops reasoning and a trailing explanation', () {
    expect(answerText('<think>x</think>சென்னை\n\nஏனெனில்...'), 'சென்னை');
    expect(answerText('ஒன்று'), 'ஒன்று');
  });

  test('scoreItem scores every format', () {
    expect(scoreItem(item, 'B'), 1);
    expect(scoreItem(item, 'A'), 0);
    expect(
      scoreItem(
        const TranslateItem('t', source: 's', references: ['It may rain.']),
        'It may rain.',
      ),
      1,
    );
    expect(
      scoreItem(
        const QaItem('q', question: 'q', answers: ['சென்னை']),
        'சென்னை',
      ),
      1,
    );
    expect(
      scoreItem(
        const WritingItem(
          'w',
          instruction: 'i',
          rules: WritingRules(minSentences: 1, maxSentences: 1),
        ),
        'மழை பெய்தது.',
      ),
      1,
    );
    expect(
      scoreItem(
        const CorrectionItem(
          'c',
          source: 'அவள் வந்தான்.',
          reference: 'அவள் வந்தாள்.',
        ),
        'அவள் வந்தாள்.',
      ),
      1,
    );
  });

  group('taskScore', () {
    test('multiple choice is skill above chance', () {
      expect(taskScore(EvalFormat.mcq, 0.25), 0);
      expect(taskScore(EvalFormat.mcq, 0.1), 0);
      expect(taskScore(EvalFormat.mcq, 1), 100);
      expect(taskScore(EvalFormat.mcq, 0.625), closeTo(50, 1e-9));
    });

    test('translation is chrF above the floor', () {
      expect(taskScore(EvalFormat.translate, kChrfFloor / 100), 0);
      expect(taskScore(EvalFormat.translate, 1), 100);
    });

    test('other formats are the mean as a percentage', () {
      expect(taskScore(EvalFormat.qa, 0.5), 50);
      expect(taskScore(EvalFormat.writing, 0), 0);
    });
  });
}
