/// Tamil text handling shared by the scorers.
///
/// Models write the same visible text in more than one way: a two-part vowel
/// sign as one code point or two, stray zero-width joiners, curly quotes. Left
/// alone, those make an exact match fail on answers a reader would call
/// identical, so everything is normalised before it is compared.
library;

/// Two-part vowel signs and the single code point NFC composes them to.
///
/// Only the Tamil compositions NFC would make, written out by hand so the
/// package needs no Unicode dependency.
const _compositions = {
  'ொ': 'ொ', // ெ + ா = ொ
  'ோ': 'ோ', // ே + ா = ோ
  'ௌ': 'ௌ', // ெ + ௗ = ௌ
  'ஔ': 'ஔ', // ஒ + ௗ = ஔ
};

const _punctuationMap = {
  '‘': "'",
  '’': "'",
  '“': '"',
  '”': '"',
  '–': '-',
  '—': '-',
  '。': '.',
  '，': ',',
  '：': ':',
  '？': '?',
  '！': '!',
};

final _invisible = RegExp('[​‌‍﻿]');
final _whitespace = RegExp(r'\s+');
final _punctuation = RegExp(r'''[.,!?;:'"()\[\]{}\-–—…।॥/\\*_`~]''');
final _sentenceEnd = RegExp(r'[.!?।]+');

/// The text with Tamil vowel signs composed, invisible joiners dropped,
/// curly punctuation made plain and whitespace collapsed.
String normalize(String s) {
  var out = s;
  _compositions.forEach((from, to) => out = out.replaceAll(from, to));
  out = out.replaceAll(_invisible, '');
  _punctuationMap.forEach((from, to) => out = out.replaceAll(from, to));
  return out.replaceAll(_whitespace, ' ').trim();
}

/// [normalize], then lower-cased and stripped of punctuation: the form two
/// short answers are compared in.
String normalizeForMatch(String s) => normalize(s)
    .toLowerCase()
    .replaceAll(_punctuation, ' ')
    .replaceAll(_whitespace, ' ')
    .trim();

/// Words of [s] in match form.
///
/// Suffixes are kept on purpose. Without a morphological analyser, stripping
/// them would do more harm than good; the QA scorer allows a suffix instead
/// (see `qa.dart`).
List<String> words(String s) {
  final t = normalizeForMatch(s);
  return t.isEmpty ? const [] : t.split(' ');
}

/// Sentences in [s], counted by their end marks. Text after the last mark
/// counts as one more sentence.
int sentenceCount(String s) {
  final parts = normalize(
    s,
  ).split(_sentenceEnd).where((p) => p.trim().isNotEmpty);
  return parts.length;
}

bool _isTamilLetter(int c) => c >= 0x0B80 && c <= 0x0BFF;

bool _isLatinLetter(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

/// True when [s] has a letter of any script, not only digits and marks.
bool hasLetters(String s) => s.runes.any(
  (c) => _isTamilLetter(c) || _isLatinLetter(c) || c > 0x7F && !_isSymbol(c),
);

/// Share of the letters in [s] that are Tamil script, from 0 to 1.
///
/// Digits, punctuation and spaces are not letters and do not count either
/// way. Letters of other scripts count against. A string with no letters
/// gives 0.
double tamilRatio(String s) {
  var tamil = 0;
  var letters = 0;
  for (final c in s.runes) {
    if (_isTamilLetter(c)) {
      tamil++;
      letters++;
    } else if (_isLatinLetter(c) || c > 0x7F && !_isSymbol(c)) {
      letters++;
    }
  }
  return letters == 0 ? 0 : tamil / letters;
}

/// Non-ASCII code points that are not letters: general punctuation, the
/// Devanagari danda the Tamil block borrows, and invisible joiners.
bool _isSymbol(int c) =>
    (c >= 0x2000 && c <= 0x206F) ||
    c == 0x0964 ||
    c == 0x0965 ||
    c == 0xFEFF ||
    (c >= 0x3000 && c <= 0x303F) ||
    (c >= 0xFF00 && c <= 0xFF65);

/// Removes a `<think>…</think>` block, which reasoning models put before the
/// answer, and an unterminated one at the end.
String stripThink(String s) => s
    .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
    .replaceAll(RegExp(r'<think>[\s\S]*$'), '')
    .trim();
