import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/controllers/text_tool_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../shared/presentation/app_chrome.dart';

class TextToolDetailScreen extends StatefulWidget {
  const TextToolDetailScreen({
    required this.db,
    required this.tool,
    super.key,
  });

  final AppDatabase db;
  final ToolDefinition tool;

  @override
  State<TextToolDetailScreen> createState() => _TextToolDetailScreenState();
}

class _TextToolDetailScreenState extends State<TextToolDetailScreen> {
  late final TextEditingController _inputController;
  late final TextEditingController _formulaController;
  late final TextEditingController _aController;
  late final TextEditingController _bController;
  late final TextEditingController _cController;
  final TextToolController _toolController = const TextToolController();
  String _result = '';
  String _detail = '';

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: _defaultInput(widget.tool.id));
    _formulaController = TextEditingController(text: 'a * b + c');
    _aController = TextEditingController(text: '12');
    _bController = TextEditingController(text: '3');
    _cController = TextEditingController(text: '5');
    for (final controller in [_inputController, _formulaController, _aController, _bController, _cController]) {
      controller.addListener(_recalculate);
    }
    _recalculate();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _formulaController.dispose();
    _aController.dispose();
    _bController.dispose();
    _cController.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      final output = _toolController.calculate(
        toolId: widget.tool.id,
        input: _inputController.text,
        formula: _formulaController.text,
        a: _aController.text,
        b: _bController.text,
        c: _cController.text,
      );
      _result = output.primary;
      _detail = output.detail;
    });
  }

  Future<void> _saveHistory() async {
    await widget.db.addHistory(
      expression: '${widget.tool.title}: ${_mainInputText()}',
      result: _result,
      toolId: widget.tool.id,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('结果已保存到 SQLite 历史记录')));
    }
  }

  Future<void> _saveNote() async {
    await widget.db.addNote(widget.tool.title, '${_mainInputText()}\n\n$_result\n\n$_detail');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到笔记')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.tool.id == 'custom_formula';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              children: [
                IconToolButton(
                  icon: Icons.arrow_back_ios_new,
                  tooltip: '返回',
                  onTap: () => Navigator.pop(context),
                ),
                Expanded(child: Center(child: PageTitle(widget.tool.title))),
                IconToolButton(
                  icon: Icons.refresh_outlined,
                  tooltip: '重置',
                  onTap: _reset,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(widget.tool.description, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(isCustom ? '公式与变量' : '输入'),
                    if (isCustom) ...[
                      TextField(
                        controller: _formulaController,
                        decoration: const InputDecoration(labelText: '公式', hintText: '例如 a * b + sqrt(c)'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _smallField('a', _aController)),
                          const SizedBox(width: 8),
                          Expanded(child: _smallField('b', _bController)),
                          const SizedBox(width: 8),
                          Expanded(child: _smallField('c', _cController)),
                        ],
                      ),
                    ] else
                      TextField(
                        controller: _inputController,
                        minLines: widget.tool.id == 'json_format' ? 6 : 2,
                        maxLines: 10,
                        decoration: InputDecoration(
                          hintText: _hintText(widget.tool.id),
                          alignLabelWithHint: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: softPanel(context: context, highlight: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主结果', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SelectableText(
                    _result,
                    style: TextStyle(color: scheme.primary, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('详细结果'),
                    SelectableText(_detail, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ActionButton(icon: Icons.copy_outlined, label: '复制', onTap: _copyResult)),
                const SizedBox(width: 8),
                Expanded(child: ActionButton(icon: Icons.save_outlined, label: '保存', onTap: _saveHistory)),
                const SizedBox(width: 8),
                Expanded(child: ActionButton(icon: Icons.refresh_outlined, label: '重置', onTap: _reset)),
                const SizedBox(width: 8),
                Expanded(child: ActionButton(icon: Icons.note_add_outlined, label: '笔记', onTap: _saveNote)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  void _reset() {
    _inputController.text = _defaultInput(widget.tool.id);
    _formulaController.text = 'a * b + c';
    _aController.text = '12';
    _bController.text = '3';
    _cController.text = '5';
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: '$_result\n\n$_detail'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制结果')));
    }
  }

  String _mainInputText() {
    if (widget.tool.id == 'custom_formula') {
      return '${_formulaController.text}; a=${_aController.text}, b=${_bController.text}, c=${_cController.text}';
    }
    return _inputController.text;
  }

  String _defaultInput(String id) {
    return switch (id) {
      'base_convert' => '0xFF',
      'timestamp' => (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'color_convert' => '#5B47FF',
      'base64' => 'NekoCalc',
      'url_codec' => 'NekoCalc 工具箱',
      'json_format' => '{"name":"NekoCalc","tools":["calculator","units","notes"]}',
      'ascii_unicode' => 'NekoCalc',
      'bitwise' => '12 5',
      'checksum' => 'NekoCalc',
      'uuid' => '',
      'jwt_decode' => 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJOZWtvQ2FsYyIsImV4cCI6MTg5MzQ1NjAwMH0.signature',
      'query_params' => 'https://example.com/search?q=NekoCalc&page=1',
      'html_entities' => '<div class="name">NekoCalc & Tools</div>',
      'regex_test' => r'\d+\nNekoCalc 2026 build 42',
      'text_stats' => 'NekoCalc\n全能计算工具箱',
      'csv_json' => 'name,category\nNekoCalc,calculator\nGraph,tool',
      'fnv_crc' => 'NekoCalc',
      _ => '',
    };
  }

  String _hintText(String id) {
    return switch (id) {
      'base_convert' => '输入 255、0xFF 或 0b11111111',
      'timestamp' => '输入秒级或毫秒级时间戳',
      'color_convert' => '输入 #5B47FF',
      'base64' => '输入文本或 Base64',
      'url_codec' => '输入普通文本或 URL 编码文本',
      'json_format' => '输入 JSON 文本',
      'ascii_unicode' => '输入要查询的字符',
      'bitwise' => '输入两个整数，例如 12 5、0xFF 0b1010',
      'checksum' => '输入要计算校验和的文本',
      'uuid' => '无需输入，打开即生成 UUID',
      'jwt_decode' => '输入 JWT token',
      'query_params' => '输入 URL 或 a=1&b=2',
      'html_entities' => '输入 HTML 或实体文本',
      'regex_test' => '第一行正则，后续行测试文本',
      'text_stats' => '输入要统计的文本',
      'csv_json' => '首行为表头，后续为 CSV/TSV 数据',
      'fnv_crc' => '输入要哈希/校验的文本',
      _ => '输入内容',
    };
  }
}
