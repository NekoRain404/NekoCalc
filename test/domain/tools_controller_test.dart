import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tools_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/domain/usecases/recent_tool_action_result.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/recent_tool_action_message.dart';
import 'package:nekocalc/features/tools/presentation/tools_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

void main() {
  late ToolsController controller;

  setUp(() {
    controller = _controller();
  });

  // 中文：工具搜索要覆盖用户输入英文、缩写和内部 id 的真实场景。
  // English: Tool search should cover real inputs such as English words, abbreviations, and internal ids.
  test('search matches English text case-insensitively', () {
    final results = controller.search('json');

    expect(results.map((tool) => tool.id), contains('json_format'));
  });

  test('search matches tool ids', () {
    final results = controller.search('data_fit');

    expect(results.map((tool) => tool.id), contains('data_fit'));
  });

  test('search ranks direct title matches before broad matches', () {
    final results = controller.search('贷款');

    expect(results, isNotEmpty);
    expect(results.first.id, 'loan');
  });

  test('search can be constrained to a category', () {
    final results = controller.searchTools('power');

    expect(results.map((result) => result.tool.id), contains('torque_power'));

    final financeOnly = controller.searchTools(
      'power',
      category: ToolCategory.finance,
    );

    expect(financeOnly.map((result) => result.tool.id),
        contains('electricity_cost'));
    expect(
        financeOnly
            .every((result) => result.tool.category == ToolCategory.finance),
        isTrue);
    expect(financeOnly.map((result) => result.tool.id),
        isNot(contains('torque_power')));
  });

  test('search category counts summarize matches across categories', () {
    final counts = controller.searchCategoryCounts('power');

    expect(counts[ToolCategory.finance], greaterThan(0));
    expect(counts[ToolCategory.mechanical], greaterThan(0));
    expect(counts[ToolCategory.electronics], greaterThan(0));
  });

  test('search alternatives skip excluded category and honor limit', () {
    final broadAlternatives = controller.searchAlternatives(
      'power',
      excludedCategory: ToolCategory.finance,
      limit: 2,
    );
    final targetedAlternatives = controller.searchAlternatives(
      'torque power',
      excludedCategory: ToolCategory.finance,
      limit: 2,
    );

    expect(broadAlternatives, hasLength(2));
    expect(
        broadAlternatives
            .every((result) => result.tool.category != ToolCategory.finance),
        isTrue);
    expect(targetedAlternatives.first.tool.id, 'torque_power');
  });

  test('search suggestions recover likely typos without hiding real matches',
      () {
    final jsonSuggestions = controller.searchSuggestions('jsonn');
    final voltageSuggestions = controller.searchSuggestions('volatge');
    final scopedSuggestions = controller.searchSuggestions(
      'mortage',
      category: ToolCategory.finance,
    );
    final realMatches = controller.searchSuggestions('json');

    expect(jsonSuggestions.map((item) => item.text), contains('json'));
    expect(jsonSuggestions.first.tool.id, 'json_format');
    expect(voltageSuggestions.map((item) => item.text),
        anyElement(contains('voltage')));
    expect(scopedSuggestions.map((item) => item.tool.category).toSet(),
        {ToolCategory.finance});
    expect(scopedSuggestions.map((item) => item.text), contains('mortgage'));
    expect(realMatches, isEmpty);
  });

  test('search examples are scoped by category', () {
    final general = controller.searchExamples();
    final programming =
        controller.searchExamples(category: ToolCategory.programming, limit: 3);
    final finance =
        controller.searchExamples(category: ToolCategory.finance, limit: 4);

    expect(general, contains('json'));
    expect(programming, hasLength(3));
    expect(programming, contains('jwt token'));
    expect(finance, hasLength(4));
    expect(finance, contains('贷款'));
    expect(finance, isNot(contains('jwt token')));
  });

  test('load filters unavailable favorites and backfills recent tools',
      () async {
    final fakeDb = _FakeToolUsageDatabase(
      favoriteIds: {'json_format', 'legacy_tool', 'loan'},
      recentIds: [
        'legacy_recent_1',
        'json_format',
        'json_format',
        'legacy_recent_2',
        'data_fit',
        'ohms_law',
        'loan',
        'area',
        'volume',
        'mass',
        'length',
        'temperature',
        'pressure',
      ],
    );
    final state = await _controller(fakeDb).load();

    expect(state.favoriteIds, {'json_format', 'loan'});
    // 中文：**夹具里那几条换算工具的 id 今天都取不到工具了**（`area`、`volume`、`mass`、`length`、
    //       `pressure` 这 21 个并成了 `unit_convert` 一张卡），所以它们与两条 `legacy_*` 一样被过滤
    //       掉；`temperature` 仍在目录里，照旧留下。夹具不改——它要量的正是"取不到的就滤掉"。
    // English: **the converter ids in the fixture no longer resolve to a tool** (`area`, `volume`,
    //          `mass`, `length`, `pressure` — those 21 folded into the `unit_convert` card), so they
    //          are filtered out exactly like the two `legacy_*` entries; `temperature` is still in the
    //          catalogue and stays. The fixture is left alone — "what cannot be resolved is filtered
    //          out" is the very thing it measures.
    expect(state.recentIds, [
      'json_format',
      'data_fit',
      'ohms_law',
      'loan',
      'temperature',
    ]);
    expect(fakeDb.requestedRecentLimit, 24);
  });

  test('recent management returns structured remove and clear results',
      () async {
    final fakeDb = _FakeToolUsageDatabase(
      favoriteIds: const {},
      recentIds: ['json_format', 'data_fit', 'ohms_law'],
    );
    final controller = _controller(fakeDb);

    final removeResult =
        await controller.removeRecent(toolById('json_format')!);
    expect(fakeDb.removedRecentIds, ['json_format']);
    expect(removeResult.status, RecentToolActionStatus.removed);
    expect(removeResult.changed, isTrue);

    final clearResult = await controller.clearRecent();
    expect(fakeDb.clearRecentCalls, 1);
    expect(clearResult.status, RecentToolActionStatus.cleared);
    expect(clearResult.affectedCount, 2);
  });

  test('recent management reports missing and failed operations', () async {
    final fakeDb = _FakeToolUsageDatabase(
      favoriteIds: const {},
      recentIds: const [],
    );
    final controller = _controller(fakeDb);

    final missingResult =
        await controller.removeRecent(toolById('json_format')!);
    expect(missingResult.status, RecentToolActionStatus.notFound);
    expect(missingResult.changed, isFalse);

    fakeDb.throwOnClear = true;
    final failedResult = await controller.clearRecent();
    expect(failedResult.status, RecentToolActionStatus.failed);
    // 中文：句子不再住在结果上（领域对象活得比界面长），这里按呈现边缘那条路渲染——断言本身一个字
    //       没改，量到的还是同一句话。
    // English: the sentence no longer lives on the result (a domain object outlives the UI); it is
    //          rendered here through the presentation edge — the assertion itself is unchanged and
    //          measures the same sentence.
    expect(
      recentToolActionMessage(
        failedResult,
        ToolsStrings.forLanguage(AppLanguage.zh),
      ),
      contains('清空最近使用失败'),
    );
  });

  test('search matches formulas inputs and units', () {
    final formulaResults = controller.searchTools('Vin R1');
    final inputResults = controller.searchTools('电流');
    final unitResults = controller.searchTools('kWh');

    expect(formulaResults.map((result) => result.tool.id),
        contains('voltage_divider'));
    expect(inputResults.map((result) => result.tool.id), contains('ohms_law'));
    expect(unitResults.map((result) => result.tool.id),
        contains('electricity_cost'));
  });

  test('search results expose concrete match hints', () {
    final alias = controller.searchTools('curve fitting').first;
    final unit = controller.searchTools('kΩ').first;
    final title = controller.searchTools('贷款').first;
    final keyword = controller
        .searchTools('theta-ja thermal')
        .firstWhere((result) => result.tool.id == 'ldo_power');

    // 中文：**这里钉的是引擎发出来的令牌，不是屏幕上的字。** 外壳走 `ToolMatchTokens`，
    //       中文那句「命中：别名」由 `ToolsStrings` 的令牌表负责，钉在
    //       `test/features/tools_match_labels_test.dart` 里。
    // English: **What is pinned here is the token the engine emits, not the words on screen.** Chrome
    //          goes through `ToolMatchTokens`; the Chinese sentence "命中：别名" is the token table's job
    //          and is pinned in `test/features/tools_match_labels_test.dart`.
    expect(alias.tool.id, 'data_fit');
    expect(alias.matchLabel, ToolMatchTokens.alias);
    expect(alias.matchText, 'curve fitting');

    // 中文：单位那一档原先查的是 `kΩ` → `resistance_unit`；那个工具这一轮并进了 `unit_convert`，
    //       而 `kΩ` 这个记号仍在 `rc_filter` 的输入单位里，所以改钉它——命中的仍是"单位"那一档。
    // English: the unit band used to query `kΩ` → `resistance_unit`; that tool folded into
    //          `unit_convert` this round, while the `kΩ` token still lives in `rc_filter`'s input units,
    //          so it pins that one — still the unit band that matches.
    expect(unit.tool.id, 'rc_filter');
    expect(unit.matchLabel, ToolMatchTokens.unit);
    expect(unit.matchText, 'kΩ');

    expect(title.tool.id, 'loan');
    expect(title.matchLabel, ToolMatchTokens.title);
    expect(title.matchText, contains('贷款'));

    expect(keyword.matchLabel, ToolMatchTokens.keyword);
    expect(keyword.matchText, contains('theta-ja'));
  });

  test('search normalizes symbols punctuation and multi word unit queries', () {
    // 中文：**两条"平方 英尺/立方 英尺"的查询换成了 `mm2` 与 `m/s2`。** 前两条原先命中被并掉的
    //       面积/体积换算工具，今天一个结果都没有；换上的两条量的是同一件事（纯记号 + 多词/幂次
    //       查询要归一），命中的是 `wire_voltage_drop` 与 `force` 的输入单位。
    // English: **the two `平方 英尺` / `立方 英尺` queries are replaced by `mm2` and `m/s2`.** The
    //          former two used to hit the folded-away area/volume converters and return nothing today;
    //          the replacements measure the same thing (notation and multi-word or power-suffixed
    //          queries must be normalised) against `wire_voltage_drop` and `force`'s input units.
    final ohmSymbol = controller.searchTools('kΩ');
    final ohmWord = controller.searchTools('k ohm');
    final squareMillimetre = controller.searchTools('mm2');
    final metresPerSecondSquared = controller.searchTools('m/s2');
    final chineseFold = controller.searchTools('单位 换算');
    final chineseTemperatureFold = controller.searchTools('温度 换算');
    final hyphenated = controller.searchTools('theta-ja thermal');
    final slashQuery = controller.searchTools('url/query 参数');

    expect(ohmSymbol.first.tool.id, 'rc_filter');
    expect(ohmWord.first.tool.id, 'rc_filter');
    expect(squareMillimetre.first.tool.id, 'wire_voltage_drop');
    expect(metresPerSecondSquared.first.tool.id, 'force');
    expect(chineseFold.first.tool.id, 'unit_convert');
    expect(chineseTemperatureFold.first.tool.id, 'temperature');
    expect(hyphenated.first.tool.id, 'ldo_power');
    expect(slashQuery.first.tool.id, 'query_params');
  });
}

ToolsController _controller([AppDatabase? db]) {
  return ToolsController(
    toolUsageRepository: ToolUsageRepository(db ?? AppDatabase.instance),
  );
}

class _FakeToolUsageDatabase implements AppDatabase {
  _FakeToolUsageDatabase({
    required Set<String> favoriteIds,
    required List<String> recentIds,
  })  : _favoriteIds = Set<String>.from(favoriteIds),
        _recentIds = List<String>.from(recentIds);

  final Set<String> _favoriteIds;
  final List<String> _recentIds;
  int? requestedRecentLimit;
  final removedRecentIds = <String>[];
  int clearRecentCalls = 0;
  bool throwOnClear = false;

  @override
  Future<Set<String>> favoriteToolIds() async {
    return Set<String>.from(_favoriteIds);
  }

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async {
    requestedRecentLimit = limit;
    return _recentIds.take(limit).toList(growable: false);
  }

  @override
  Future<int> deleteRecentTool(String toolId) async {
    removedRecentIds.add(toolId);
    final previousCount = _recentIds.length;
    _recentIds.removeWhere((id) => id == toolId);
    return previousCount - _recentIds.length;
  }

  @override
  Future<int> clearRecentTools() async {
    if (throwOnClear) throw StateError('clear failed');
    clearRecentCalls++;
    final count = _recentIds.length;
    _recentIds.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
