import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thinai_tamil_evals/src/data/ta_v1.g.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

import '../tool/embed_dataset.dart' as embed;

Map<String, Object?> _base() =>
    jsonDecode(File('data/ta/v1.json').readAsStringSync())
        as Map<String, Object?>;

List<Map<String, Object?>> _tasks(Map<String, Object?> d) =>
    (d['tasks'] as List).cast<Map<String, Object?>>();

List<Map<String, Object?>> _items(Map<String, Object?> task) =>
    (task['items'] as List).cast<Map<String, Object?>>();

Map<String, Object?> _task(Map<String, Object?> d, String id) =>
    _tasks(d).firstWhere((t) => t['id'] == id);

Matcher _rejects(String problem) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', contains(problem)),
);

void main() {
  test('the bundled dataset loads and is sound', () {
    final ds = tamilV1();
    expect(ds.language, 'ta');
    expect(ds.version, '1.0.0');
    expect(ds.itemCount, 60);
    expect(ds.tasks, hasLength(9));
    expect(ds.validate(), isEmpty);
    expect(identical(tamilV1(), ds), isTrue);
    expect(ds.axis('knowledge').weight, 0.2);
  });

  test('the embedded copy matches data/ta/v1.json', () {
    final json = File('data/ta/v1.json').readAsStringSync();
    expect(kTamilV1Json, json, reason: 'run: dart run tool/embed_dataset.dart');
    expect(
      File('lib/src/data/ta_v1.g.dart').readAsStringSync(),
      embed.render(json),
    );
  });

  test('every prompt fits a small context', () {
    // LFM2 spends about 2.2 tokens per Tamil letter. Kept under this, every
    // prompt plus its reply fits a 1024-token window.
    const maxChars = 340;
    for (final task in tamilV1().tasks) {
      for (final item in task.items) {
        final p = buildPrompt(task, item);
        expect(p.user.length, lessThanOrEqualTo(maxChars), reason: item.id);
      }
    }
  });

  group('rejects', () {
    void expectProblem(
      void Function(Map<String, Object?> d) edit,
      String problem,
    ) {
      final d = _base();
      edit(d);
      expect(() => EvalDataset.parse(jsonEncode(d)), _rejects(problem));
    }

    test('malformed JSON fields', () {
      expect(() => EvalDataset.parse('{"language": 1}'), _rejects('malformed'));
      expect(() => EvalDataset.parse('not json'), throwsFormatException);
    });

    test('weights not adding up to 1', () {
      expectProblem((d) => (d['axes'] as List).removeLast(), 'weights');
    });

    test('an unknown axis, an empty task, a bad cap', () {
      expectProblem((d) => _task(d, 'qa')['axis'] = 'nope', 'unknown axis');
      expectProblem((d) => _task(d, 'qa')['items'] = <Object>[], 'no items');
      expectProblem((d) => _task(d, 'qa')['maxTokens'] = 0, 'maxTokens');
      expectProblem((d) => _task(d, 'qa')['direction'] = 'ta-en', 'direction');
      expectProblem(
        (d) => _task(d, 'qa')['direction'] = 'xx',
        'unknown direction',
      );
    });

    test('duplicate ids', () {
      expectProblem(
        (d) => _items(_task(d, 'qa'))[1]['id'] = 'q01',
        'duplicate',
      );
    });

    test('broken multiple choice', () {
      expectProblem(
        (d) => _items(_task(d, 'grammar'))[0]['answer'] = 'E',
        'not A to D',
      );
      expectProblem(
        (d) => (_items(_task(d, 'grammar'))[0]['options'] as List).removeLast(),
        '4 options',
      );
      expectProblem((d) {
        final o = _items(_task(d, 'grammar'))[0]['options'] as List;
        o[1] = o[0];
      }, 'options repeat');
      expectProblem((d) {
        for (final i in _items(_task(d, 'grammar'))) {
          i['answer'] = 'A';
        }
      }, 'unevenly');
      expectProblem(
        (d) => _items(_task(d, 'grammar'))[0]['question'] = 'English only',
        'not Tamil',
      );
      expectProblem(
        (d) => _items(_task(d, 'grammar'))[0]['question'] = ' ',
        'empty',
      );
    });

    test('translation in the wrong script or without references', () {
      expectProblem(
        (d) => _items(_task(d, 'ta-en'))[0]['references'] = ['தமிழ்'],
        'has Tamil',
      );
      expectProblem(
        (d) => _items(_task(d, 'ta-en'))[0]['references'] = [' '],
        'empty',
      );
      expectProblem(
        (d) => _items(_task(d, 'en-ta'))[0]['references'] = <Object>[],
        'no references',
      );
    });

    test('QA without answers', () {
      expectProblem(
        (d) => _items(_task(d, 'qa'))[0]['answers'] = <Object>[],
        'no answers',
      );
      expectProblem(
        (d) => _items(_task(d, 'qa'))[0]['answers'] = [''],
        'answer is empty',
      );
    });

    test('writing with a bad sentence range or English stem', () {
      expectProblem(
        (d) =>
            (_items(_task(d, 'writing'))[0]['rules'] as Map)['maxSentences'] =
                0,
        'sentence range',
      );
      expectProblem(
        (d) => (_items(_task(d, 'writing'))[0]['rules'] as Map)['mustUse'] = [
          'rain',
        ],
        'mustUse',
      );
    });

    test('a correction with no mistake', () {
      expectProblem((d) {
        final i = _items(_task(d, 'correction'))[0];
        i['source'] = i['reference'];
      }, 'no mistake');
    });
  });

  test('Direction codes', () {
    expect(Direction.parse('en-ta'), Direction.enTa);
    expect(Direction.taEn.code, 'ta-en');
  });
}
