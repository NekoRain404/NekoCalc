import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/iterable_ext.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/calculate_tool.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'tool_widgets.dart';

class ToolDetailScreen extends StatefulWidget {
  const ToolDetailScreen({required this.db, required this.tool, super.key});

  final AppDatabase db;
  final ToolDefinition tool;

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  late final Map<String, TextEditingController> _controllers;
  List<ToolResult> _results = [];
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final input in widget.tool.inputs)
        input.key: TextEditingController(text: input.defaultValue == null ? '' : formatNumber(input.defaultValue!))
    };
    for (final controller in _controllers.values) {
      controller.addListener(_recalculate);
    }
    _loadFavorite();
    _results = calculateTool(widget.tool, _values);
  }

  Future<void> _loadFavorite() async {
    final ids = await widget.db.favoriteToolIds();
    if (mounted) setState(() => _favorite = ids.contains(widget.tool.id));
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, double> get _values => {
        for (final entry in _controllers.entries) entry.key: double.tryParse(entry.value.text.replaceAll(',', '')) ?? 0,
      };

  void _recalculate() {
    setState(() => _results = calculateTool(widget.tool, _values));
  }

  Future<void> _saveResult() async {
    final primary = _results.where((result) => result.primary).firstOrNull ?? _results.firstOrNull;
    if (primary == null) return;
    final expression = widget.tool.inputs
        .map((input) => '${input.label}=${_controllers[input.key]?.text ?? ''}${input.unit}')
        .join(', ');
    await widget.db.addHistory(
      expression: expression,
      result: '${primary.label}: ${primary.value}${primary.unit}',
      toolId: widget.tool.id,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('结果已保存到 SQLite 历史记录')));
    }
  }

  Future<void> _saveNote() async {
    final body = [
      widget.tool.description,
      ..._results.map((result) => '${result.label}: ${result.value}${result.unit}'),
      '公式：${widget.tool.formula}',
    ].join('\n');
    await widget.db.addNote(widget.tool.title, body);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到笔记')));
  }

  Future<void> _toggleFavorite() async {
    final next = !_favorite;
    await widget.db.setFavorite(widget.tool.id, next);
    setState(() => _favorite = next);
  }

  @override
  Widget build(BuildContext context) {
    final primary = _results.where((result) => result.primary).firstOrNull ?? _results.firstOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new)),
                Expanded(child: Center(child: PageTitle(widget.tool.title))),
                IconButton(
                  tooltip: '收藏',
                  onPressed: _toggleFavorite,
                  icon: Icon(_favorite ? Icons.star : Icons.star_border, color: _favorite ? Colors.amber : null),
                ),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    switch (value) {
                      case 'copy':
                        _copyResult();
                      case 'save':
                        _saveResult();
                      case 'note':
                        _saveNote();
                      case 'reset':
                        _resetInputs();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'copy', child: Text('复制结果')),
                    PopupMenuItem(value: 'save', child: Text('保存历史')),
                    PopupMenuItem(value: 'note', child: Text('保存笔记')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'reset', child: Text('重置输入')),
                  ],
                ),
              ],
            ),
            Text(widget.tool.description, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _inputCard(),
            const SizedBox(height: 12),
            if (primary != null) _primaryResult(primary),
            const SizedBox(height: 12),
            if (_results.length > 1)
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.05,
                children: _results.where((result) => !result.primary).map((result) => DetailMetric(result: result)).toList(),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('公式'),
                    Text(widget.tool.formula, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(widget.tool.explanation, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ActionButton(icon: Icons.copy_outlined, label: '复制', onTap: _copyResult)),
                const SizedBox(width: 8),
                Expanded(child: ActionButton(icon: Icons.save_outlined, label: '保存', onTap: _saveResult)),
                const SizedBox(width: 8),
                Expanded(child: ActionButton(icon: Icons.refresh_outlined, label: '重置', onTap: _resetInputs)),
                const SizedBox(width: 8),
                Expanded(child: ActionButton(icon: Icons.note_add_outlined, label: '笔记', onTap: _saveNote)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('输入参数')),
                TextButton(
                  onPressed: _resetInputs,
                  child: const Text('重置'),
                ),
              ],
            ),
            if (widget.tool.inputs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('该工具无需数字参数，请使用上方结果和操作按钮完成复制、保存或笔记记录。'),
              )
            else
              ...widget.tool.inputs.map((input) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(input.optional ? '${input.label}（可选）' : input.label)),
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _controllers[input.key],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(isDense: true, suffixText: input.unit),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  void _resetInputs() {
    for (final input in widget.tool.inputs) {
      _controllers[input.key]?.text = input.defaultValue == null ? '' : formatNumber(input.defaultValue!);
    }
  }

  Future<void> _copyResult() async {
    final text = _results.map((result) => '${result.label}: ${result.value}${result.unit}').join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制结果')));
    }
  }

  Widget _primaryResult(ToolResult primary) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softPanel(context: context, highlight: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(primary.label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  primary.value,
                  style: TextStyle(color: scheme.primary, fontSize: 34, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(primary.unit, style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
