import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tool_search_engine.dart';
import 'package:nekocalc/domain/entities/tool_category.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tools_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**「命中：XXX」那一行的护栏。** 它问三件事：
///       1. **中文那一行逐字节没动**——默认语言是中文，屏幕上那十个标签必须与接入令牌之前一字
///          不差。逐条写出来，这一份就是"默认态不变"的证据本身（与 `tools_strings_test.dart`
///          同一套做法）。
///       2. **内容是透传，不是令牌**——`tool.group` 与分类名在自己的层已经翻好，这里再翻一次就是
///          错的；所以它们在两种语言下**都等于目录里的原文**。这条不是抽查：整个目录逐条过。
///       3. **令牌与内容不可能撞上**，而且**类里声明的每个令牌都配上了字**——后半条读源码，
///          所以它不是自证：加了令牌忘了配字，这里当场红，而不是等屏幕上露出 `命中：new_token`。
/// English: **The guard for the "Matched: …" line.** It asks three things:
///          1. **The Chinese line did not move by a byte** — the default language is Chinese, so the ten
///             labels on screen must read exactly as they did before tokens existed. Written out entry
///             by entry: this list **is** the evidence for "the default state does not change" (the same
///             shape as `tools_strings_test.dart`).
///          2. **Content passes through, it is not tokenised** — `tool.group` and the category names are
///             already translated at their own layer, so translating them here would be wrong; hence in
///             **both** languages they equal the catalogue's own text. Not a sample: every entry of the
///             catalogue goes through.
///          3. **Tokens cannot collide with content**, and **every token the class declares has words
///             here** — the second half reads the source, so it is not self-certifying: declare a token
///             and forget its words and this goes red, instead of `Matched: new_token` reaching a screen.
void main() {
  final zh = ToolsStrings.forLanguage(AppLanguage.zh);
  final en = ToolsStrings.forLanguage(AppLanguage.en);

  // 中文：**旧字面量的原文。** 左边是 `tool_search_engine.dart` 在令牌化之前直接写死的那十个，
  //       右边是今天该发出来的令牌。改这个表等于改默认语言屏幕上的字，那是这一轮不许发生的事。
  // English: **The old literals, as they stood.** The left column is what
  //          `tool_search_engine.dart` hard-coded before tokens; the right column is the token emitted
  //          today. Editing this table edits what the default language shows, which this round must not
  //          do.
  const legacyChrome = <String, String>{
    '标题': ToolMatchTokens.title,
    '工具 ID': ToolMatchTokens.toolId,
    '说明': ToolMatchTokens.description,
    '公式': ToolMatchTokens.formula,
    '解释': ToolMatchTokens.explanation,
    '别名': ToolMatchTokens.alias,
    '输入项': ToolMatchTokens.input,
    '单位': ToolMatchTokens.unit,
    '参数': ToolMatchTokens.parameter,
    '关键词': ToolMatchTokens.keyword,
  };

  const englishChrome = <String, String>{
    ToolMatchTokens.title: 'Title',
    ToolMatchTokens.toolId: 'Tool ID',
    ToolMatchTokens.description: 'Description',
    ToolMatchTokens.formula: 'Formula',
    ToolMatchTokens.explanation: 'Explanation',
    ToolMatchTokens.alias: 'Alias',
    ToolMatchTokens.input: 'Input',
    ToolMatchTokens.unit: 'Unit',
    ToolMatchTokens.parameter: 'Parameter',
    ToolMatchTokens.keyword: 'Keyword',
  };

  test('中文那一行与令牌化之前逐字节相同', () {
    for (final entry in legacyChrome.entries) {
      expect(zh.match(entry.value), '命中：${entry.key}',
          reason: '${entry.value} 在中文下必须还是「命中：${entry.key}」');
      expect(zh.matchWithText(entry.value, 'x'), '命中：${entry.key} · x',
          reason: '${entry.value} 带上命中原文也必须逐字节相同');
    }
  });

  test('英文那一行十个标签都是英文，没有一个汉字', () {
    final cjk = RegExp(r'[一-鿿　-〿＀-￯]');
    for (final entry in englishChrome.entries) {
      final label = en.matchLabels[entry.key];
      expect(label, entry.value, reason: '${entry.key} 的英文标签');
      expect(cjk.hasMatch(label!), isFalse,
          reason: '${entry.key} 的英文标签里不许有汉字：$label');
      expect(en.match(entry.key), 'Matched: ${entry.value}');
      expect(en.matchWithText(entry.key, 'x'), 'Matched: ${entry.value} · x');
    }
  });

  test('类里声明的每个令牌都配上了字，两个语言一张键表', () {
    final declared = _declaredMatchTokens();
    expect(zh.matchLabels.keys.toSet(), declared,
        reason: '中文令牌表的键必须与 ToolMatchTokens 声明的常量一一对应');
    expect(en.matchLabels.keys.toSet(), declared,
        reason: '英文令牌表的键必须与中文那把一模一样');
    expect(legacyChrome.values.toSet(), declared,
        reason: '上面那张旧字面量表漏了令牌：新增令牌时它也得跟上');
    for (final key in declared) {
      final label = zh.matchLabels[key]!;
      expect(label, isNotEmpty);
      expect(label, isNot(key),
          reason: '表里出现了值等于键的条目，那条其实没翻：$key');
    }
  });

  test('内容不是令牌：分组名与分类名原样透传，两种语言同一个字', () {
    final content = <String>{
      for (final tool in toolCatalog) tool.group,
      for (final category in ToolCategory.values) category.title,
      for (final category in ToolCategory.values) category.subtitle,
    };
    expect(content.length, greaterThan(ToolCategory.values.length),
        reason: '目录里应当同时有分组名与分类名，否则这条测试其实什么都没问');

    for (final value in content) {
      expect(zh.matchLabels.containsKey(value), isFalse,
          reason: '$value 是内容，不该被令牌表收进去');
      expect(en.matchLabels.containsKey(value), isFalse,
          reason: '$value 是内容，英文表里也不该有它');
      expect(zh.match(value), '命中：$value');
      expect(en.match(value), 'Matched: $value',
          reason: '$value 是内容，英文界面下必须原样照用，而不是翻成别的东西');
    }
  });

  test('引擎到界面：外壳翻成英文，内容两种语言一个样', () {
    final alias = ToolSearch.searchTools('curve fitting').first;
    expect(alias.matchLabel, ToolMatchTokens.alias);
    expect(zh.matchWithText(alias.matchLabel, alias.matchText),
        '命中：别名 · curve fitting');
    expect(en.matchWithText(alias.matchLabel, alias.matchText),
        'Matched: Alias · curve fitting');

    // 中文：**内容那一路走的是真结果，不是构造出来的字。** `贷款` 的第二条命中分组名
    //       （`财务与商业`），英文界面下它必须仍然是那五个汉字。
    // English: **The content branch goes through a real result, not a hand-made string.** The second
    //          hit for `贷款` matches on the group name (`财务与商业`), which must stay exactly those
    //          five characters in the English interface.
    final grouped = ToolSearch.searchTools('贷款')
        .firstWhere((result) => result.matchLabel == '财务与商业');
    expect(en.match(grouped.matchLabel), 'Matched: 财务与商业');
  });
}

/// 中文：**从源码里数令牌，不从这里再抄一份。** 抄一份的话，两边一起漏就没人发现；
///       读源码则"声明了但没配字"当场可见。取的是**常量的值**（`toolId` 的 `'tool_id'`），
///       因为两张表的键是值不是常量名。
/// English: **Counts the tokens from the source rather than copying the list again.** A copy can drift
///          silently along with the class; reading the source makes "declared but never given words"
///          visible on the spot. It takes the constants' **values** (`toolId`'s `'tool_id'`), because
///          the tables are keyed by value rather than by constant name.
Set<String> _declaredMatchTokens() {
  final source = File('lib/application/controllers/tool_search_engine.dart');
  expect(source.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
  final classBody =
      RegExp(r'class ToolMatchTokens \{(.*?)\n\}', dotAll: true)
          .firstMatch(source.readAsStringSync())
          ?.group(1);
  expect(classBody, isNotNull, reason: '找不到 ToolMatchTokens 的类体');
  final declared = RegExp(r"static const String \w+ = '([^']*)';")
      .allMatches(classBody!)
      .map((match) => match.group(1)!)
      .toSet();
  expect(declared, isNotEmpty, reason: 'ToolMatchTokens 里应当有常量声明');
  return declared;
}
