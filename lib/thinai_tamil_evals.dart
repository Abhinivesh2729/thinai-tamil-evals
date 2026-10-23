/// A small Tamil test set for language models, sized to run on a phone.
///
/// Load the bundled set with [tamilV1], give an [EvalRunner] something that
/// implements [EvalGenerator], and listen to [EvalRunner.run]. Everything here
/// is pure Dart: no Flutter, no `dart:io`. The OpenAI-compatible generator
/// that needs `dart:io` lives in `package:thinai_tamil_evals/openai.dart`.
library;

import 'src/data/ta_v1.g.dart';
import 'src/dataset.dart';

export 'src/dataset.dart';
export 'src/prompts.dart';
export 'src/report.dart';
export 'src/runner.dart';
export 'src/scorers/chrf.dart' show chrf;
export 'src/scorers/correction.dart' show correctionScore;
export 'src/scorers/lexicon.dart';
export 'src/scorers/qa.dart' show qaScore;
export 'src/scorers/writing.dart';
export 'src/scoring.dart';
export 'src/tamil_text.dart';

/// The bundled Tamil dataset, version 1: 60 items over nine tasks.
EvalDataset tamilV1() => _tamilV1 ??= EvalDataset.parse(kTamilV1Json);
EvalDataset? _tamilV1;
