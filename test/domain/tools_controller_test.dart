import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tools_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';

void main() {
  late ToolsController controller;

  setUp(() {
    controller = ToolsController(
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
    );
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
}
