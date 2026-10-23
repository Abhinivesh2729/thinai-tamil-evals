# thinai_tamil_evals

How good is a language model at Tamil? This package answers with one number from 0 to 100, plus the scores behind it, from a test small enough to run **on a phone**.

It is the evaluation behind the Tamil score in [Thinai](https://github.com/Abhinivesh2729/Thinai), and it works the same against any OpenAI-compatible server.

## What it tests

60 hand-written items in nine tasks, grouped into three skills:

| Skill (weight) | Task | Items | Scored by |
|---|---|---|---|
| **Understanding** (40%) | Reading (வாசிப்பு) | 8 | Multiple choice |
| | Grammar (இலக்கணம்) | 8 | Multiple choice |
| | Context and idioms (சூழல்) | 8 | Multiple choice |
| | Tamil → English | 6 | chrF |
| **Expression** (40%) | English → Tamil | 6 | chrF |
| | Short answers (சிறு விடை) | 8 | Match against accepted answers |
| | Writing (எழுதுதல்) | 6 | Rules a program can check |
| | Correction (பிழை திருத்தம்) | 4 | Share of the mistake fixed |
| **Knowledge** (20%) | Tamil knowledge (தமிழ் அறிவு) | 6 | Multiple choice |

A task scores the mean of its items, a skill the mean of its tasks, and the Tamil score the skills by weight.

**Scores are skill above guessing.** A model picking letters at random gets 25% of multiple choice right, and any English sentence earns about 15 chrF against a reference. Both count as 0, so a model that knows no Tamil scores near 0, not near 25.

## Built for phones

On a Realme with a MediaTek Dimensity, LFM2.5-350M reads about 180 tokens a second and writes about 20, and its tokenizer spends about 2 tokens on every Tamil letter. The set is shaped around that:

- **Multiple choice costs one token.** A GBNF grammar (`root ::= [ABCD]`) allows only an option letter, so a small model can't lose marks by explaining itself.
- **Every prompt is short**, under 340 characters. A test enforces this, so prompt and reply fit a 1024-token context.
- **Output caps are tight**, and one-line answers stop at the first line break.
- **Decoding is greedy, with thinking off**, so a run repeats exactly.

A full run of LFM2.5-350M on that phone takes about 160 seconds.

## Use

```dart
import 'package:thinai_tamil_evals/thinai_tamil_evals.dart';

class MyGenerator implements EvalGenerator {
  @override
  Stream<String> generate(EvalPrompt prompt) {
    // prompt.system, prompt.user, prompt.maxTokens, prompt.grammar, prompt.stop
    ...
  }
}

final runner = EvalRunner(dataset: tamilV1(), generator: MyGenerator());
await for (final event in runner.run(modelId: 'my-model')) {
  switch (event) {
    case ItemScored(:final step, :final result):
      print('${step.index + 1}/${runner.steps.length} ${result.score}');
    case RunCompleted(:final report):
      print('Tamil score ${report.overall.toStringAsFixed(1)}');
    default:
  }
}
```

The core is pure Dart, with no Flutter and no `dart:io`. To stop a run, cancel the subscription.

### Against a server

```bash
dart run thinai_tamil_evals --endpoint http://127.0.0.1:11434/v1 --model gemma-3-1b --out report.json
```

This works with Thinai's server on a phone (use `adb forward tcp:11434 tcp:11434`), llama.cpp's `llama-server` and Ollama. Hosted APIs reject the `grammar` field, so pass `--no-grammar`; the letter is then read from the reply text.

## The dataset

`data/ta/v1.json` is the source of truth. After editing it, run `dart run tool/embed_dataset.dart`; a test fails if the embedded copy drifts. Loading validates every item: four distinct options, answers spread over A to D, Tamil fields in Tamil script, English fields free of it, and a real mistake in every correction item.

Scores belong to a dataset version. If you change an item, bump `version`.

All items were written for this set and are released under MIT. None is copied from public benchmarks, so they are unlikely to be in a model's training data. Every change to an item should be checked by a fluent Tamil reader other than its author.

## Limits

- **Samples are small.** 8 multiple-choice items gives roughly ±15 points on one task. Compare overall scores, and treat gaps under 10 points as noise.
- **Writing is checked by rules, not judged.** The rules: Tamil script, sentence count, required words, everyday vocabulary, no looping. They tell real Tamil from noise, but not good prose from plain prose.

## Development

```bash
dart test
dart analyze
```

## Licence

MIT
