import '../../data/models/history_item.dart';
import '../../data/models/note_item.dart';
import 'record_filter.dart';

class RecordSearchSuggestion {
  const RecordSearchSuggestion({
    required this.text,
    required this.score,
  });

  final String text;
  final int score;
}

List<RecordSearchSuggestion> buildRecordSearchSuggestions({
  required String query,
  required Iterable<HistoryItem> history,
  required Iterable<NoteItem> notes,
  RecordTab tab = RecordTab.all,
  int limit = 4,
}) {
  final queryTokens = recordQueryTokens(query)
      .where((token) => token.length >= 3)
      .toList(growable: false);
  if (queryTokens.isEmpty || limit <= 0) return const [];
  final normalizedQuery = normalizeRecordSearchText(query);

  final ranked = <RecordSearchSuggestion>[];
  for (final phrase in _suggestionPhrases(
    history: history,
    notes: notes,
    tab: tab,
  )) {
    final suggestion = _rankPhrase(phrase, queryTokens, normalizedQuery);
    if (suggestion != null) ranked.add(suggestion);
  }
  ranked.sort((a, b) {
    final scoreOrder = b.score.compareTo(a.score);
    if (scoreOrder != 0) return scoreOrder;
    final lengthOrder = a.text.length.compareTo(b.text.length);
    if (lengthOrder != 0) return lengthOrder;
    return a.text.compareTo(b.text);
  });

  final suggestions = <RecordSearchSuggestion>[];
  final seen = <String>{};
  for (final suggestion in ranked) {
    if (!seen.add(normalizeRecordSearchText(suggestion.text))) continue;
    suggestions.add(suggestion);
    if (suggestions.length == limit) break;
  }
  return suggestions;
}

RecordSearchSuggestion? _rankPhrase(
  String phrase,
  List<String> queryTokens,
  String normalizedQuery,
) {
  final variants = _phraseVariants(phrase);
  if (variants.isEmpty) return null;
  if (variants.contains(normalizedQuery)) return null;

  var bestScore = 0;
  for (final query in queryTokens) {
    for (final candidate in variants) {
      final score = _similarityScore(query, candidate);
      if (score > bestScore) bestScore = score;
    }
  }
  if (bestScore < _minimumSuggestionScore) return null;
  return RecordSearchSuggestion(text: phrase.trim(), score: bestScore);
}

Iterable<String> _suggestionPhrases({
  required Iterable<HistoryItem> history,
  required Iterable<NoteItem> notes,
  required RecordTab tab,
}) sync* {
  if (tab != RecordTab.notes) {
    for (final item
        in history.where((item) => matchesHistoryRecord(item, tab))) {
      yield* _historyPhrases(item);
    }
  }
  if (tab != RecordTab.history) {
    for (final item in notes.where((item) => matchesNoteRecord(item, tab))) {
      yield* _notePhrases(item);
    }
  }
}

Iterable<String> _historyPhrases(HistoryItem item) sync* {
  yield item.expression;
  yield item.result;
  if (item.toolId != null) {
    yield item.toolId!;
    yield item.toolId!.replaceAll('_', ' ');
  }
  yield* _splitUsefulPhrases(item.expression);
  yield* _splitUsefulPhrases(item.result);
}

Iterable<String> _notePhrases(NoteItem item) sync* {
  yield item.title;
  yield item.description;
  yield* _splitUsefulPhrases(item.title);
  yield* _splitUsefulPhrases(item.description);
  yield* _splitUsefulPhrases(item.body);
}

Iterable<String> _splitUsefulPhrases(String value) sync* {
  final normalized = value
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll(RegExp(r'[(){}\[\]<>]'), ' ');
  for (final part in normalized.split(RegExp(r'[\s,，;；:：|/\\]+'))) {
    final phrase = part.trim();
    if (phrase.length >= 3) yield phrase;
  }
}

Set<String> _phraseVariants(String value) {
  final normalized = normalizeRecordSearchText(value);
  if (normalized.length < 3) return const {};
  return {
    normalized,
    normalized.replaceAll(' ', ''),
    ...normalized.split(' ').where((token) => token.length >= 3),
  };
}

int _similarityScore(String query, String candidate) {
  if (candidate.contains(query)) return 0;
  if (query.contains(candidate)) return 0;
  final maxLength =
      query.length > candidate.length ? query.length : candidate.length;
  if (maxLength == 0) return 0;
  final distance = _levenshteinDistance(query, candidate);
  if (distance == 1 && maxLength <= 6) return 88;
  if (distance <= 2 && maxLength >= 6) return 82;
  final similarity = 1 - distance / maxLength;
  if (similarity >= 0.78) return 76;
  if (similarity >= 0.68 && query.length >= 5 && candidate.length >= 5) {
    return 64;
  }
  return 0;
}

int _levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (index) => index);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final substitutionCost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      final insertion = current[j] + 1;
      final deletion = previous[j + 1] + 1;
      final substitution = previous[j] + substitutionCost;
      current[j + 1] = [
        insertion,
        deletion,
        substitution,
      ].reduce((left, right) => left < right ? left : right);
    }
    previous = current;
  }
  return previous.last;
}

const int _minimumSuggestionScore = 64;
