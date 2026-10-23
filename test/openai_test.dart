import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thinai_tamil_evals/openai.dart';
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

void main() {
  late HttpServer server;
  late List<Map<String, Object?>> bodies;
  late List<String?> auth;
  var status = 200;

  setUp(() async {
    bodies = [];
    auth = [];
    status = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      bodies.add(
        jsonDecode(await utf8.decodeStream(req)) as Map<String, Object?>,
      );
      auth.add(req.headers.value('authorization'));
      req.response.statusCode = status;
      if (status != 200) {
        req.response.write('nope');
      } else {
        for (final chunk in [
          {
            'choices': [
              {
                'delta': {'content': 'சென்'},
              },
            ],
          },
          {
            'choices': [
              {'delta': {}},
            ],
          },
          {'choices': []},
          [1],
          {
            'choices': [1],
          },
          {
            'choices': [
              {'delta': 1},
            ],
          },
          {
            'choices': [
              {
                'delta': {'content': 'னை'},
              },
            ],
          },
        ]) {
          req.response.write('data: ${jsonEncode(chunk)}\n\n');
        }
        req.response.write(': keep-alive\n\ndata: [DONE]\n\n');
      }
      await req.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  OpenAiGenerator gen({String? key, bool grammar = true}) => OpenAiGenerator(
    endpoint: Uri.parse('http://127.0.0.1:${server.port}/v1'),
    model: 'm',
    apiKey: key,
    sendGrammar: grammar,
  );

  const prompt = EvalPrompt(
    system: 's',
    user: 'u',
    maxTokens: 4,
    grammar: kOptionGrammar,
    stop: ['\n'],
  );

  test('streams content deltas and sends a greedy request', () async {
    final g = gen(key: 'k');
    expect(await g.generate(prompt).join(), 'சென்னை');
    g.close();
    final body = bodies.single;
    expect(body['temperature'], 0);
    expect(body['max_tokens'], 4);
    expect(body['enable_thinking'], false);
    expect(body['grammar'], kOptionGrammar);
    expect(body['stop'], ['\n']);
    expect((body['messages'] as List).first, {
      'role': 'system',
      'content': 's',
    });
    expect(auth.single, 'Bearer k');
  });

  test('can leave the grammar and stop out', () async {
    final g = gen(grammar: false);
    await g
        .generate(const EvalPrompt(system: 's', user: 'u', maxTokens: 1))
        .drain<void>();
    g.close();
    expect(bodies.single.containsKey('grammar'), isFalse);
    expect(bodies.single.containsKey('stop'), isFalse);
    expect(auth.single, isNull);
  });

  test('an HTTP error surfaces as a stream error', () async {
    status = 500;
    final g = gen();
    await expectLater(g.generate(prompt), emitsError(isA<HttpException>()));
    g.close();
  });

  test('cancelling aborts the request', () async {
    final g = gen();
    final sub = g.generate(prompt).listen((_) {});
    await sub.cancel();
    g.close();
  });
}
