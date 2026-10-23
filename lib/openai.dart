/// An [EvalGenerator] for any OpenAI-compatible chat endpoint: Thinai's own
/// server on a phone, Ollama, llama.cpp's server, or a hosted API.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'thinai_tamil_evals.dart';

class OpenAiGenerator implements EvalGenerator {
  /// Base URL up to and including `/v1`, ex. `http://127.0.0.1:11434/v1`.
  final Uri endpoint;
  final String model;
  final String? apiKey;

  /// Whether to send [EvalPrompt.grammar]. llama.cpp servers take it; hosted
  /// APIs reject unknown fields, so it can be turned off.
  final bool sendGrammar;

  final HttpClient _client;

  OpenAiGenerator({
    required this.endpoint,
    required this.model,
    this.apiKey,
    this.sendGrammar = true,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  @override
  Stream<String> generate(EvalPrompt prompt) {
    HttpClientRequest? request;
    late final StreamController<String> out;
    out = StreamController<String>(
      onListen: () async {
        try {
          request = await _client.postUrl(
            endpoint.resolve('${endpoint.path}/chat/completions'),
          );
          final req = request!;
          req.headers.contentType = ContentType.json;
          if (apiKey != null) {
            req.headers.set('authorization', 'Bearer $apiKey');
          }
          req.add(utf8.encode(jsonEncode(body(prompt))));
          final res = await req.close();
          if (res.statusCode != 200) {
            final text = await utf8.decodeStream(res);
            throw HttpException('HTTP ${res.statusCode}: $text');
          }
          await for (final line
              in res.transform(utf8.decoder).transform(const LineSplitter())) {
            if (!line.startsWith('data:')) continue;
            final data = line.substring(5).trim();
            if (data == '[DONE]') break;
            final delta = _delta(data);
            if (delta.isNotEmpty) out.add(delta);
          }
        } on Object catch (e, st) {
          if (!out.isClosed) out.addError(e, st);
        }
        await out.close();
      },
      onCancel: () => request?.abort(),
    );
    return out.stream;
  }

  /// The request body for [prompt]: greedy decoding, so a run repeats, and
  /// thinking off, since reasoning would multiply the run time and measure
  /// something other than Tamil.
  Map<String, Object?> body(EvalPrompt prompt) => {
    'model': model,
    'stream': true,
    'temperature': 0,
    'max_tokens': prompt.maxTokens,
    'enable_thinking': false,
    'messages': [
      {'role': 'system', 'content': prompt.system},
      {'role': 'user', 'content': prompt.user},
    ],
    if (prompt.stop.isNotEmpty) 'stop': prompt.stop,
    if (sendGrammar && prompt.grammar != null) 'grammar': prompt.grammar,
  };

  void close() => _client.close(force: true);
}

String _delta(String data) {
  final json = jsonDecode(data);
  if (json is! Map) return '';
  final choices = json['choices'];
  if (choices is! List || choices.isEmpty) return '';
  final first = choices.first;
  if (first is! Map) return '';
  final delta = first['delta'];
  if (delta is! Map) return '';
  final content = delta['content'];
  return content is String ? content : '';
}
