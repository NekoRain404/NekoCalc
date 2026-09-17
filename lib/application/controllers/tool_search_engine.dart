import '../../domain/entities/tool_category.dart';
import 'tool_search_data.dart';
import '../../domain/entities/tool_definition.dart';
import '../../domain/usecases/tool_catalog.dart';

part 'tool_search_aliases_a.dart';
part 'tool_search_aliases_b.dart';
part 'tool_search_aliases_c.dart';

/// 搜索引擎 — 从 ToolsController 提取的纯静态搜索逻辑。
class ToolSearch {
  ToolSearch._();

  /// 按查询文本搜索工具，返回排序结果。
  static List<ToolSearchResult> searchTools(String query, {ToolCategory? category}) {
    final normalized = normalizeSearchText(query);
    final queryVariants = searchTextVariants(query).toList();
    final candidates = toolCatalog
        .where((tool) => category == null || tool.category == category)
        .map((tool) => rankTool(tool, normalized, queryVariants))
        .where((result) => normalized.isEmpty || result.score > 0)
        .toList();
    candidates.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      if (a.tool.featured != b.tool.featured) return a.tool.featured ? -1 : 1;
      final categoryOrder =
          a.tool.category.index.compareTo(b.tool.category.index);
      if (categoryOrder != 0) return categoryOrder;
      return a.tool.title.compareTo(b.tool.title);
    });
    return candidates;
  }

  /// 统计各分类的搜索命中数。
  static Map<ToolCategory, int> searchCategoryCounts(String query) {
    final counts = {for (final category in ToolCategory.values) category: 0};
    for (final result in searchTools(query)) {
      counts[result.tool.category] = (counts[result.tool.category] ?? 0) + 1;
    }
    return counts;
  }

  /// 搜索替代工具（排除指定分类）。
  static List<ToolSearchResult> searchAlternatives(
    String query, {
    required ToolCategory excludedCategory,
    int limit = 4,
  }) {
    if (normalizeSearchText(query).isEmpty || limit <= 0) return const [];
    return searchTools(query)
        .where((result) => result.tool.category != excludedCategory)
        .take(limit)
        .toList(growable: false);
  }

  /// 生成搜索建议。
  static List<ToolSearchSuggestion> searchSuggestions(
    String query, {
    ToolCategory? category,
    int limit = 4,
  }) {
    final normalized = normalizeSearchText(query);
    if (normalized.length < 3 || limit <= 0) return const [];
    if (searchTools(query, category: category).isNotEmpty) return const [];

    final queryVariants = searchTextVariants(query)
        .where((variant) => variant.length >= 3)
        .toSet()
        .toList(growable: false);
    if (queryVariants.isEmpty) return const [];

    final ranked = <ToolSearchSuggestion>[];
    for (final tool in toolCatalog) {
      if (category != null && tool.category != category) continue;
      for (final phrase in suggestionPhrases(tool)) {
        final suggestion = rankSuggestion(
          phrase: phrase,
          tool: tool,
          queryVariants: queryVariants,
        );
        if (suggestion != null) ranked.add(suggestion);
      }
    }

    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      final textOrder = a.text.length.compareTo(b.text.length);
      if (textOrder != 0) return textOrder;
      return a.text.compareTo(b.text);
    });

    final suggestions = <ToolSearchSuggestion>[];
    final seenTexts = <String>{};
    final seenTools = <String>{};
    for (final suggestion in ranked) {
      if (!seenTexts.add(suggestion.text)) continue;
      if (!seenTools.add(suggestion.tool.id) &&
          suggestion.score < strongSuggestionScore) {
        continue;
      }
      suggestions.add(suggestion);
      if (suggestions.length == limit) break;
    }
    return suggestions;
  }

  /// 获取搜索示例。
  static List<String> searchExamples({ToolCategory? category, int limit = 6}) {
    final examples = ToolSearchData.searchExamplesByCategory[category] ?? ToolSearchData.generalSearchExamples;
    return examples.take(limit).toList(growable: false);
  }

  static ToolSearchResult rankTool(
    ToolDefinition tool,
    String query,
    List<String> queryVariants,
  ) {
    if (query.isEmpty) {
      return ToolSearchResult(
        tool: tool,
        matchLabel: tool.group,
        matchText: tool.category.title,
        score: 1,
      );
    }

    final checks = <({String text, String label, int score})>[
      (text: tool.title, label: '标题', score: 100),
      (text: tool.id.replaceAll('_', ' '), label: '工具 ID', score: 94),
      (text: tool.id, label: '工具 ID', score: 92),
      (text: tool.description, label: '说明', score: 76),
      (text: tool.formula, label: '公式', score: 72),
      (text: tool.explanation, label: '解释', score: 62),
      (text: tool.group, label: tool.group, score: 58),
      (text: tool.category.title, label: tool.category.title, score: 54),
      (text: tool.category.subtitle, label: tool.category.title, score: 50),
      ...searchAliases(tool).map(
        (alias) => (text: alias, label: '别名', score: 86),
      ),
      ...tool.inputs.expand((input) => [
            (text: input.label, label: '输入项', score: 68),
            (text: input.unit, label: '单位', score: 56),
            (text: input.key, label: '参数', score: 52),
          ]),
    ];

    var bestScore = 0;
    var bestLabel = '';
    var bestText = '';
    for (final check in checks) {
      for (final value in searchTextVariants(check.text)) {
        for (final variant in queryVariants) {
          if (variant.isEmpty) continue;
          if (value == variant) {
            final score = check.score + 32;
            if (score > bestScore) {
              bestScore = score;
              bestLabel = check.label;
              bestText = check.text;
            }
          } else if (value.startsWith(variant)) {
            final score = check.score + 18;
            if (score > bestScore) {
              bestScore = score;
              bestLabel = check.label;
              bestText = check.text;
            }
          } else if (value.contains(variant)) {
            if (check.score > bestScore) {
              bestScore = check.score;
              bestLabel = check.label;
              bestText = check.text;
            }
          }
        }
      }
    }

    final tokenMatchResult = tokenMatch(tool, queryVariants);
    final tokenScore = tokenMatchResult?.score ?? 0;
    if (tokenScore > 0 && tokenScore > bestScore) {
      bestScore = tokenScore;
      bestLabel = '关键词';
      bestText = tokenMatchResult?.text ?? '';
    }

    return ToolSearchResult(
      tool: tool,
      matchLabel: bestLabel,
      matchText: compactMatchText(bestText),
      score: bestScore == 0 ? 0 : bestScore + (tool.featured ? 3 : 0),
    );
  }

  static List<String> searchAliases(ToolDefinition tool) {
    final aliases = <String>[
      tool.title.replaceAll('/', ' '),
      tool.description.replaceAll('/', ' '),
    ];
  _addToolSearchAliasesA(tool.id, aliases);
  _addToolSearchAliasesB(tool.id, aliases);
  _addToolSearchAliasesC(tool.id, aliases);
    aliases.addAll(ToolSearchData.unitSearchAliases[tool.id] ?? const []);
    return aliases;
  }

  static TokenMatch? tokenMatch(ToolDefinition tool, Iterable<String> queries) {
    final fields = [
      tool.title,
      tool.description,
      tool.formula,
      tool.explanation,
      tool.group,
      tool.category.title,
      tool.category.subtitle,
      tool.id,
      ...searchAliases(tool),
      ...tool.inputs.expand((input) => [input.label, input.unit, input.key]),
    ];
    final haystack = fields.expand(searchTextVariants).join(' ');
    TokenMatch? best;
    for (final query in queries) {
      final tokens = query
          .split(RegExp(r'[\s_+\-/,]+'))
          .where((token) => token.length >= 2)
          .toSet()
          .toList();
      if (tokens.length < 2) continue;
      final matched = tokens.where(haystack.contains).length;
      if (matched < tokens.length) continue;
      final score = (44 + matched * 4).clamp(0, 70);
      final text = bestTokenMatchText(fields, tokens, fallback: query);
      if (best == null || score > best.score) {
        best = TokenMatch(score: score, text: text);
      }
    }
    return best;
  }

  static String bestTokenMatchText(
    List<String> fields,
    List<String> tokens, {
    required String fallback,
  }) {
    for (final field in fields) {
      final variants = searchTextVariants(field).toList(growable: false);
      if (tokens
          .every((token) => variants.any((value) => value.contains(token)))) {
        return field;
      }
    }
    return fallback;
  }

  static String compactMatchText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 34) return normalized;
    return '${normalized.substring(0, 33)}…';
  }

  static Iterable<String> suggestionPhrases(ToolDefinition tool) sync* {
    final phrases = <String>[
      tool.title,
      tool.id.replaceAll('_', ' '),
      tool.group,
      tool.category.title,
      ...searchAliases(tool),
      ...tool.inputs.expand((input) => [input.label, input.key, input.unit]),
    ];
    final seen = <String>{};
    for (final phrase in phrases) {
      for (final segment in suggestionSegments(phrase)) {
        if (segment.length < 2) continue;
        if (seen.add(normalizeSearchText(segment))) yield segment;
      }
    }
  }

  static Iterable<String> suggestionSegments(String phrase) sync* {
    final normalized = phrase.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return;
    yield normalized;
    for (final segment in normalized.split(RegExp(r'[\s_+\-/,=()]+'))) {
      final trimmed = segment.trim();
      if (trimmed.isNotEmpty) yield trimmed;
    }
  }

  static ToolSearchSuggestion? rankSuggestion({
    required String phrase,
    required ToolDefinition tool,
    required List<String> queryVariants,
  }) {
    var bestScore = 0;
    for (final candidate in searchTextVariants(phrase)) {
      if (candidate.length < 3) continue;
      for (final query in queryVariants) {
        final score = suggestionScore(query: query, candidate: candidate);
        if (score > bestScore) bestScore = score;
      }
    }
    if (bestScore < minimumSuggestionScore) return null;
    return ToolSearchSuggestion(
      text: phrase,
      tool: tool,
      score: bestScore + (tool.featured ? 2 : 0),
    );
  }

  static int suggestionScore({required String query, required String candidate}) {
    if (candidate == query) return 100;
    if (candidate.startsWith(query) || query.startsWith(candidate)) return 86;
    if (candidate.contains(query) || query.contains(candidate)) return 78;
    final distance = levenshteinDistance(query, candidate);
    final maxLength =
        query.length > candidate.length ? query.length : candidate.length;
    if (maxLength == 0) return 0;
    final similarity = 1 - distance / maxLength;
    if (similarity >= 0.78) return 72;
    if (similarity >= 0.66 && query.length >= 5 && candidate.length >= 5) {
      return 62;
    }
    return 0;
  }

  static int levenshteinDistance(String a, String b) {
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

  static Iterable<String> searchTextVariants(String value) {
    final normalized = normalizeSearchText(value);
    if (normalized.isEmpty) return const [];

    final asciiUnit = normalized
        .replaceAll('平方', ' square ')
        .replaceAll('立方', ' cubic ')
        .replaceAll('²', '2')
        .replaceAll('³', '3')
        .replaceAll('⁴', '4')
        .replaceAll('^2', '2')
        .replaceAll('^3', '3')
        .replaceAll('^4', '4')
        .replaceAll('°c', 'degc')
        .replaceAll('℃', 'degc')
        .replaceAll('°f', 'degf')
        .replaceAll('℉', 'degf')
        .replaceAll('°r', 'degr')
        .replaceAll('μ', 'u')
        .replaceAll('µ', 'u')
        .replaceAll('Ω', 'ohm')
        .replaceAll('ω', 'ohm')
        .replaceAll('欧姆', 'ohm')
        .replaceAll('·', '*');
    final compactUnit = asciiUnit.replaceAll(RegExp(r'[\s*/.·-]+'), '');
    final noPunctuation = asciiUnit.replaceAll(RegExp(r'[_+\-/,]+'), ' ');
    return {
      normalized,
      asciiUnit,
      compactUnit,
      noPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim(),
    };
  }

  static String normalizeSearchText(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('　', ' ')
        .replaceAll('／', '/')
        .replaceAll('＊', '*')
        .replaceAll('×', '*');
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }
}

const int minimumSuggestionScore = 62;
const int strongSuggestionScore = 78;


class ToolsState {
  const ToolsState({
    required this.favoriteIds,
    required this.recentIds,
  });

  final Set<String> favoriteIds;
  final List<String> recentIds;
}

class ToolSearchResult {
  const ToolSearchResult({
    required this.tool,
    required this.matchLabel,
    required this.matchText,
    required this.score,
  });

  final ToolDefinition tool;
  final String matchLabel;
  final String matchText;
  final int score;
}

class ToolSearchSuggestion {
  const ToolSearchSuggestion({
    required this.text,
    required this.tool,
    required this.score,
  });

  final String text;
  final ToolDefinition tool;
  final int score;
}

class TokenMatch {
  const TokenMatch({required this.score, required this.text});

  final int score;
  final String text;
}
