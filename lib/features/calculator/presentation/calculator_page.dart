import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/calculator_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../shared/presentation/app_chrome.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    required this.db,
    required this.onOpenSettings,
    required this.settings,
    super.key,
  });

  final AppDatabase db;
  final VoidCallback onOpenSettings;
  final AppSettings settings;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  late final CalculatorController _controller;
  String _pad = 'Basic';

  static const List<String> _baseKeys = [
    'AC',
    '⌫',
    '%',
    '÷',
    '7',
    '8',
    '9',
    '×',
    '4',
    '5',
    '6',
    '-',
    '1',
    '2',
    '3',
    '+',
    '+/-',
    '0',
    '.',
    '=',
  ];

  static const Map<String, List<String>> _functionGroups = {
    'Basic': ['(', ')', 'π', '√'],
    'Trig': ['DEG', 'RAD', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan'],
    'Power': ['(', ')', 'x²', 'x³', '^', '√', 'abs', '10^x'],
    'Log': ['log', 'ln', 'exp', '10^x', 'e', '√', 'abs', 'π'],
    'Const': ['π', 'e', 'φ', '√2', 'g', 'c', '1/2', '1/3'],
  };

  @override
  void initState() {
    super.initState();
    _controller = CalculatorController(db: widget.db, settings: widget.settings)..addListener(_onControllerChanged);
    _controller.restoreIfEnabled();
  }

  @override
  void didUpdateWidget(covariant CalculatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _controller.updateSettings(widget.settings);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayHeight = (constraints.maxHeight * 0.24).clamp(142.0, 178.0);
        final keyboardHeight = _keyboardHeight(constraints.maxHeight, _functionRows);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 12),
                  SizedBox(height: displayHeight, child: _displayCard(context)),
                  const SizedBox(height: 10),
                  _padTabs(),
                  const SizedBox(height: 8),
                  SizedBox(height: keyboardHeight, child: _keyboard()),
                  const SizedBox(height: 10),
                  _actions(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return Row(
      children: [
        const NekoAppMark(),
        const SizedBox(width: 10),
        const Expanded(child: PageTitle('NekoCalc')),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'DEG', label: Text('DEG')),
            ButtonSegment(value: 'RAD', label: Text('RAD')),
          ],
          selected: {_controller.angleMode},
          onSelectionChanged: (value) => _controller.setAngleMode(value.first),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 8),
        IconToolButton(icon: Icons.settings_outlined, tooltip: '设置', onTap: widget.onOpenSettings),
      ],
    );
  }

  Widget _displayCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softPanel(context: context, highlight: true),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _editExpression,
                    borderRadius: BorderRadius.circular(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        reverse: true,
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          _controller.expression.isEmpty ? 'sin(30)+sqrt(13)' : _controller.expression,
                          maxLines: 1,
                          style: TextStyle(
                            color: _controller.expression.isEmpty
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurface,
                            fontSize: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(tooltip: '编辑表达式', onPressed: _editExpression, icon: const Icon(Icons.edit_outlined)),
                IconButton(tooltip: '退格', onPressed: _controller.backspace, icon: const Icon(Icons.backspace_outlined)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '= ${_controller.result}',
                style: TextStyle(
                  color: _controller.hasError ? Colors.red : Theme.of(context).colorScheme.primary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _padTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _functionGroups.keys
            .map((label) => GestureDetector(
                  onTap: () => setState(() => _pad = label),
                  child: TabPill(label: label, selected: _pad == label),
                ))
            .toList(),
      ),
    );
  }

  Widget _keyboard() {
    return Column(
      children: [
        SizedBox(height: _functionRows * 44 + (_functionRows - 1) * 8, child: _keyGrid(_functionGroups[_pad]!, compact: true)),
        const SizedBox(height: 8),
        Expanded(child: _keyGrid(_baseKeys)),
      ],
    );
  }

  Widget _keyGrid(List<String> keys, {bool compact = false}) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: compact ? 2.45 : 1.45,
      ),
      itemBuilder: (context, index) {
        final key = keys[index];
        return FilledButton(
          onPressed: () => _pressKey(key),
          style: FilledButton.styleFrom(
            backgroundColor: key == '=' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
            foregroundColor: key == '=' ? Colors.white : (key == 'AC' ? Colors.red : Theme.of(context).colorScheme.onSurface),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: key == '=' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
            ),
            elevation: 0,
          ),
          child: FittedBox(child: Text(key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        );
      },
    );
  }

  int get _functionRows => (_functionGroups[_pad]!.length / 4).ceil();

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: ActionButton(
            icon: Icons.copy_outlined,
            label: '复制结果',
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: _controller.result));
              messenger.showSnackBar(const SnackBar(content: Text('已复制结果')));
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: ActionButton(icon: Icons.refresh_outlined, label: '继续使用', onTap: _controller.continueWithResult)),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(
            icon: Icons.save_outlined,
            label: '保存笔记',
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _controller.saveToNote();
              messenger.showSnackBar(const SnackBar(content: Text('已保存到笔记')));
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pressKey(String key) async {
    if (widget.settings.haptics) HapticFeedback.selectionClick();
    switch (key) {
      case 'DEG':
      case 'RAD':
        _controller.setAngleMode(key);
      case 'sin':
      case 'cos':
      case 'tan':
      case 'asin':
      case 'acos':
      case 'atan':
      case 'log':
      case 'ln':
      case 'abs':
        _controller.append('$key(');
      case 'x²':
        _controller.append('^2');
      case 'x³':
        _controller.append('^3');
      case '√':
        _controller.append('sqrt(');
      case '10^x':
        _controller.append('10^');
      case 'exp':
        _controller.append('e^');
      case 'π':
        _controller.append('pi');
      case 'φ':
        _controller.append('1.61803398875');
      case 'g':
        _controller.append('9.80665');
      case 'c':
        _controller.append('299792458');
      case '√2':
        _controller.append('sqrt(2)');
      case '1/2':
        _controller.append('0.5');
      case '1/3':
        _controller.append('0.3333333333');
      case '=':
        await _controller.submit();
      default:
        _controller.input(key);
    }
  }

  Future<void> _editExpression() async {
    final controller = TextEditingController(text: _controller.expression);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑表达式'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '例如 1+2×3 或 sin(30)+sqrt(13)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('清空')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('应用')),
        ],
      ),
    );
    if (value == null) return;
    _controller.setExpression(value);
  }

  double _keyboardHeight(double screenHeight, int functionRows) {
    final preferred = screenHeight - 302;
    final rows = 5 + functionRows;
    final minHeight = rows * 42.0 + rows * 8;
    final maxHeight = rows * 58.0 + rows * 8;
    return preferred.clamp(minHeight, maxHeight);
  }
}
