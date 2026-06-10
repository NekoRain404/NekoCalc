import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/calculator_controller.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/platform/app_haptics.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/usecases/calculator_paste_result.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'widgets/math_expression_text.dart';

/// 中文：计算器主界面，UI 只负责布局和输入分发，计算逻辑留在 CalculatorController。
/// English: Main calculator screen; UI handles layout and input dispatch while calculation stays in CalculatorController.
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    required this.db,
    required this.onOpenSettings,
    required this.settings,
    this.reloadToken = 0,
    super.key,
  });

  final AppDatabase db;
  final VoidCallback onOpenSettings;
  final AppSettings settings;
  final int reloadToken;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  late final CalculatorController _controller;
  String _pad = 'Basic';
  bool _savingNote = false;

  static const List<String> _pads = ['Basic', '函数'];
  static const List<String> _functionEditKeys = ['AC', '⌫', '+/-', '='];
  static const List<String> _functionQuickKeys = ['(', ')', ',', 'Ans'];

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
    'Basic': ['(', ')', 'π', '√x'],
  };

  static const Map<String, List<String>> _functionSections = {
    '常用': ['√x', '∛x', 'x²', 'x³', 'xʸ', 'x⁻¹', 'π', 'e', 'eˣ', '10ˣ'],
    '三角': [
      'DEG',
      'RAD',
      'sin',
      'cos',
      'tan',
      'asin',
      'acos',
      'atan',
      'sinh',
      'cosh',
      'tanh',
      'cot',
      'sec',
      'csc'
    ],
    '指数对数': [
      'log₁₀',
      'ln',
      'log₂',
      'exp',
      '2ˣ',
      '|x|',
    ],
    '取整与统计': ['floor', 'ceil', 'round', 'min', 'max'],
    '整数与组合': ['x!', 'nCr', 'nPr', 'gcd', 'lcm', 'mod', 'ⁿ√x', 'atan2'],
    '角度辅助': ['deg', 'rad', '90°', '180°', '360°'],
    '常数': ['φ', '√2', 'τ', 'ln2', 'ln10', 'g', 'c', '2π', 'π/2'],
  };

  @override
  void initState() {
    super.initState();
    _controller = CalculatorController(
      historyRepository: HistoryRepository(widget.db),
      notesRepository: NotesRepository(widget.db),
      settingsRepository: SettingsRepository(widget.db),
      settings: widget.settings,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.restoreIfEnabled();
    });
  }

  @override
  void didUpdateWidget(covariant CalculatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _controller.updateSettings(widget.settings);
    }
    if (oldWidget.reloadToken != widget.reloadToken) {
      _controller.reloadSettingsAndRestore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 中文：根据可用高度动态分配显示区和键盘区，避免不同手机上按钮被挤压或溢出。
        // English: Allocate display and keypad height from available space to avoid squeezed or overflowing keys.
        final displayHeight =
            (constraints.maxHeight * 0.24).clamp(142.0, 178.0);
        final basicKeyboardHeight = _basicKeyboardHeight(constraints.maxHeight);
        final functionPanelHeight =
            _functionPanelHeight(constraints.maxHeight, displayHeight);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                children: [
                  // 中文：只让依赖控制器状态的区域重建，键盘本体不随每次输入重建。
                  // English: Rebuild only controller-dependent regions; the keypad itself does not rebuild on every input.
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _header(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: displayHeight,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => _displayCard(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _padTabs(),
                  const SizedBox(height: 8),
                  if (_pad == 'Basic')
                    SizedBox(
                        height: basicKeyboardHeight, child: _basicKeyboard())
                  else
                    SizedBox(
                        height: functionPanelHeight, child: _functionPanel()),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _memoryBar(),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _resultStatusCard(),
                  ),
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
        const Expanded(child: PageTitle(AppInfo.name)),
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
        IconToolButton(
            icon: Icons.settings_outlined,
            tooltip: '设置',
            onTap: widget.onOpenSettings),
      ],
    );
  }

  Widget _displayCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasExpression = _controller.expression.isNotEmpty;
    final hasMemory = _controller.memoryValue != 0;
    // 中文：表达式和结果分层显示，空表达式时突出当前值，输入中则突出实时结果。
    // English: Expression and result are visually separated; empty input emphasizes the current value, active input emphasizes the live result.
    final displayStyle = TextStyle(
      color: hasExpression
          ? scheme.onSurfaceVariant
          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
      fontSize: 19,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: softPanel(context: context, highlight: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statusChip(_controller.angleMode),
              const SizedBox(width: 6),
              _statusChip(hasMemory ? 'M' : 'M0',
                  muted: !hasMemory, dense: true),
              const Spacer(),
              _displayIconButton(Icons.undo, '撤销', _controller.undo,
                  enabled: _controller.canUndo),
              const SizedBox(width: 6),
              _displayIconButton(Icons.redo, '重做', _controller.redo,
                  enabled: _controller.canRedo),
              const SizedBox(width: 6),
              _displayIconButton(Icons.keyboard_arrow_left, '光标左移',
                  _controller.moveCursorLeft),
              const SizedBox(width: 6),
              _displayIconButton(Icons.keyboard_arrow_right, '光标右移',
                  _controller.moveCursorRight),
              const SizedBox(width: 6),
              _displayIconButton(Icons.edit_outlined, '编辑表达式', _editExpression),
              const SizedBox(width: 6),
              _displayIconButton(
                  Icons.backspace_outlined, '退格', _controller.backspace),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    // 中文：显示区左右半区可移动光标，保留“点编辑按钮才打开文本编辑”的交互规则。
                    // English: Left/right display halves move the cursor while full text editing remains behind the edit button.
                    if (details.localPosition.dx < constraints.maxWidth / 2) {
                      _controller.moveCursorLeft();
                    } else {
                      _controller.moveCursorRight();
                    }
                  },
                  onLongPress: _controller.moveCursorToEnd,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      reverse: true,
                      scrollDirection: Axis.horizontal,
                      child: MathExpressionText(
                        expression: _controller.expression,
                        cursorIndex: _controller.cursorIndex,
                        showCursor: true,
                        mathSymbols:
                            widget.settings.expressionDisplayMode == '数学符号',
                        style: displayStyle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hasExpression ? '= ${_controller.result}' : _controller.result,
                style: TextStyle(
                  color: _controller.hasError
                      ? Colors.red
                      : hasExpression
                          ? scheme.primary
                          : scheme.onSurface,
                  fontSize: hasExpression ? 34 : 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, {bool muted = false, bool dense = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 26,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10),
      decoration: BoxDecoration(
        color: muted ? scheme.surface : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? scheme.onSurfaceVariant : scheme.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _displayIconButton(IconData icon, String tooltip, VoidCallback onTap,
      {bool enabled = true}) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(
            icon,
            size: 17,
            color: enabled
                ? scheme.onSurfaceVariant
                : scheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  Widget _padTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _pads
            .map((label) => GestureDetector(
                  onTap: () {
                    _feedback();
                    setState(() => _pad = label);
                  },
                  child: TabPill(label: label, selected: _pad == label),
                ))
            .toList(),
      ),
    );
  }

  Widget _basicKeyboard() {
    final functionKeys = _functionGroups['Basic']!;
    return Column(
      children: [
        SizedBox(
            height: _functionRows * 44 + (_functionRows - 1) * 8,
            child: _keyGrid(functionKeys, compact: true, immediate: true)),
        const SizedBox(height: 8),
        Expanded(child: _keyGrid(_baseKeys, immediate: true)),
      ],
    );
  }

  Widget _functionPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 中文：函数页保持普通滚动布局，避免复杂分栏影响快速查找函数。
        // English: The function page stays as a simple scroll layout so functions remain easy to scan.
        return DecoratedBox(
          decoration: softPanel(context: context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  SizedBox(height: 42, child: _functionEditBar()),
                  const SizedBox(height: 8),
                  SizedBox(height: 40, child: _functionQuickBar()),
                  const SizedBox(height: 10),
                  Expanded(child: _functionSectionsView()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _functionEditBar() {
    return Row(
      children: [
        for (var index = 0; index < _functionEditKeys.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _calcKey(_functionEditKeys[index], compact: true)),
        ],
      ],
    );
  }

  Widget _functionQuickBar() {
    return Row(
      children: [
        for (var index = 0; index < _functionQuickKeys.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _calcKey(_functionQuickKeys[index], compact: true)),
        ],
      ],
    );
  }

  Widget _functionSectionsView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        // 中文：宽屏给 5 列，窄屏给 4 列，按钮尺寸稳定不随文字长度跳动。
        // English: Use five columns on wider screens and four on narrow screens with stable button sizing.
        final columns = constraints.maxWidth >= 390 ? 5 : 4;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (final section in _functionSections.entries) ...[
              _functionSectionHeader(section.key),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final key in section.value)
                    SizedBox(
                      width: itemWidth,
                      height: 42,
                      child: _calcKey(key, compact: true),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _functionSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _keyGrid(List<String> keys,
      {bool compact = false, bool immediate = false}) {
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
        return _calcKey(keys[index], compact: compact, immediate: immediate);
      },
    );
  }

  Widget _calcKey(String key, {bool compact = false, bool immediate = false}) {
    // 中文：角度模式键需要跟随 controller 刷新选中态，普通按键保持静态减少重建。
    // English: Angle mode keys listen to the controller for selected state; normal keys stay static to reduce rebuilds.
    if (key == 'DEG' || key == 'RAD') {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) =>
            _calcKeyButton(key, compact: compact, immediate: immediate),
      );
    }
    return _calcKeyButton(key, compact: compact, immediate: immediate);
  }

  Widget _calcKeyButton(String key,
      {bool compact = false, bool immediate = false}) {
    final scheme = Theme.of(context).colorScheme;
    final isSubmit = key == '=';
    final isDanger = key == 'AC';
    final isOperator = ['+', '-', '×', '÷', '^', '%'].contains(key);
    final isEdit = ['⌫', '+/-'].contains(key);
    final isMode = ['DEG', 'RAD'].contains(key);
    final selectedMode = isMode && _controller.angleMode == key;
    final backgroundColor = isSubmit
        ? scheme.primary
        : selectedMode
            ? scheme.secondaryContainer
            : isOperator
                ? scheme.primaryContainer
                : isEdit
                    ? scheme.surfaceContainerHighest
                    : scheme.surface;
    final foregroundColor = isSubmit
        ? scheme.onPrimary
        : isDanger
            ? Colors.red
            : selectedMode
                ? scheme.onSecondaryContainer
                : isOperator
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface;
    return _CalculatorKeySurface(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: isSubmit ? scheme.primary : scheme.outlineVariant,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
      immediate: immediate,
      onPressed: () => _pressKey(key),
      child: FittedBox(
        child: _keyLabel(key, compact: compact, color: foregroundColor),
      ),
    );
  }

  Widget _keyLabel(String key, {required bool compact, required Color color}) {
    // 中文：按键标签使用 RichText 显示上下标，避免把 x²、log₁₀ 退化成普通字符串。
    // English: Key labels use RichText for superscripts/subscripts instead of plain fallback text.
    final style = TextStyle(
      fontSize: compact ? 16 : 18,
      fontWeight: FontWeight.w700,
      color: color,
    );
    final scriptStyle = style.copyWith(fontSize: compact ? 10 : 12);
    InlineSpan sup(String text) => WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Transform.translate(
            offset: const Offset(0, -4),
            child: Text(text, style: scriptStyle),
          ),
        );
    InlineSpan sub(String text) => WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Transform.translate(
            offset: const Offset(0, 3),
            child: Text(text, style: scriptStyle),
          ),
        );
    TextSpan normal(String text) => TextSpan(text: text, style: style);
    final span = switch (key) {
      'x²' => TextSpan(children: [normal('x'), sup('2')]),
      'x³' => TextSpan(children: [normal('x'), sup('3')]),
      'xʸ' => TextSpan(children: [normal('x'), sup('y')]),
      'x⁻¹' => TextSpan(children: [normal('x'), sup('-1')]),
      '10ˣ' => TextSpan(children: [normal('10'), sup('x')]),
      '2ˣ' => TextSpan(children: [normal('2'), sup('x')]),
      'eˣ' => TextSpan(children: [normal('e'), sup('x')]),
      'log₁₀' => TextSpan(children: [normal('log'), sub('10')]),
      'log₂' => TextSpan(children: [normal('log'), sub('2')]),
      '√2' => TextSpan(children: [normal('√'), sup('2')]),
      '2π' => TextSpan(children: [normal('2π')]),
      'π/2' => TextSpan(children: [normal('π/2')]),
      'ⁿ√x' => TextSpan(children: [sup('n'), normal('√x')]),
      'nCr' => TextSpan(children: [normal('nC'), sub('r')]),
      'nPr' => TextSpan(children: [normal('nP'), sub('r')]),
      _ => TextSpan(text: key, style: style),
    };
    return RichText(text: span);
  }

  int get _functionRows => (_functionGroups['Basic']!.length / 4).ceil();

  Widget _memoryBar() {
    final scheme = Theme.of(context).colorScheme;
    // 中文：记忆寄存器放在键盘下方，保持主键盘区域专注输入，避免误触。
    // English: Memory controls sit below the keypad so the main keypad remains focused on input.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: softPanel(context: context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'M ${formatNumber(_controller.memoryValue, precision: widget.settings.precision)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800),
            ),
          ),
          _memoryButton('MC', _controller.memoryClear),
          _memoryButton('MR', _controller.memoryRecall),
          _memoryButton('M-', _controller.memorySubtract),
          _memoryButton('M+', _controller.memoryAdd),
        ],
      ),
    );
  }

  Widget _memoryButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: SizedBox(
        width: 48,
        height: 34,
        child: OutlinedButton(
          onPressed: () {
            _feedback();
            onTap();
          },
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _actions() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: ActionButton(
              icon: Icons.copy_outlined,
              label: '复制结果',
              onTap: _copyResult,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: ActionButton(
                  icon: Icons.refresh_outlined,
                  label: '继续使用',
                  onTap: _continueWithResult)),
          const SizedBox(width: 8),
          Expanded(
            child: ActionButton(
              icon: Icons.save_outlined,
              label: '保存笔记',
              onTap: _saveNote,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultStatusCard() {
    final scheme = Theme.of(context).colorScheme;
    final hasError = _controller.hasError;
    final color = hasError ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: softPanel(context: context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasError ? Icons.error_outline : Icons.verified_outlined,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_controller.resultStatusTitle,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  _controller.resultStatusMessage,
                  style: TextStyle(
                      color:
                          hasError ? scheme.onSurface : scheme.onSurfaceVariant,
                      height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _controller.copyText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已复制计算详情')));
  }

  void _continueWithResult() {
    if (!_controller.canContinueWithResult) {
      _showCurrentStatusSnack();
      return;
    }
    _controller.continueWithResult();
  }

  Future<void> _saveNote() async {
    // 中文：保存笔记是异步数据库写入，页面退出后不能再使用旧 context 弹提示。
    // English: Saving notes writes to SQLite asynchronously; after navigation, the old context must not show feedback.
    if (_savingNote) return;
    if (!_controller.canSaveCurrentExpression) {
      _showCurrentStatusSnack();
      return;
    }
    _savingNote = true;
    try {
      final result = await _controller.saveToNote();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      _savingNote = false;
    }
  }

  void _showCurrentStatusSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_controller.resultStatusMessage)),
    );
  }

  Future<void> _pressKey(String key) async {
    _feedback();
    // 中文：UI 按键符号在这里统一映射为解析器表达式，避免 parser 混入展示层符号。
    // English: UI key labels are mapped to parser expressions here, keeping display symbols out of the parser.
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
      case 'log₁₀':
      case 'ln':
      case 'abs':
      case '|x|':
      case 'sinh':
      case 'cosh':
      case 'tanh':
      case 'cot':
      case 'sec':
      case 'csc':
      case 'cbrt':
      case '∛x':
      case 'log2':
      case 'log₂':
      case 'fact':
      case 'x!':
      case 'floor':
      case 'ceil':
      case 'round':
      case 'deg':
      case 'rad':
        _controller.applyUnaryFunction(_functionNameForKey(key));
      case 'x²':
        _controller.append('^2');
      case 'x³':
        _controller.append('^3');
      case 'xʸ':
        _controller.append('^');
      case '√':
      case '√x':
        _controller.applyUnaryFunction('sqrt');
      case '10^x':
      case '10ˣ':
        _controller.append('10^');
      case '2^x':
      case '2ˣ':
        _controller.append('2^');
      case 'e^x':
      case 'eˣ':
        _controller.append('e^');
      case 'exp':
        _controller.append('exp(');
      case '1/x':
      case 'x⁻¹':
        _controller.append('^-1');
      case 'min':
      case 'max':
      case 'mod':
      case 'nCr':
      case 'nPr':
      case 'gcd':
      case 'lcm':
      case 'root':
      case 'ⁿ√x':
      case 'atan2':
        _controller.applyBinaryFunction(_functionNameForKey(key));
      case ',':
        _controller.append(',');
      case 'Ans':
        _controller.append(_controller.reusableResult);
      case '00':
        _controller.input('00');
      case 'π':
        _controller.append('pi');
      case 'e':
        _controller.append('e');
      case 'φ':
        _controller.append('1.61803398875');
      case 'g':
        _controller.append('9.80665');
      case 'c':
        _controller.append('299792458');
      case '√2':
        _controller.append('sqrt(2)');
      case 'τ':
        _controller.append('(2*pi)');
      case 'ln2':
        _controller.append('0.69314718056');
      case 'ln10':
        _controller.append('2.30258509299');
      case '1/2':
        _controller.append('0.5');
      case '1/3':
        _controller.append('0.3333333333');
      case '1/4':
        _controller.append('0.25');
      case '1/10':
        _controller.append('0.1');
      case '2π':
        _controller.append('2*pi');
      case 'π/2':
        _controller.append('pi/2');
      case '90°':
        _controller.append('90');
      case '180°':
        _controller.append('180');
      case '360°':
        _controller.append('360');
      case '=':
        final submitResult = await _controller.submit();
        if (mounted && submitResult.needsAttention) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(submitResult.message)));
        }
      default:
        _controller.input(key);
    }
  }

  void _feedback() {
    AppHaptics.tap(
      enabled: widget.settings.haptics,
      strength: widget.settings.hapticStrength,
    );
  }

  String _functionNameForKey(String key) {
    return switch (key) {
      'log₁₀' => 'log',
      'log₂' => 'log2',
      '|x|' => 'abs',
      '∛x' => 'cbrt',
      'x!' => 'fact',
      'nCr' => 'ncr',
      'nPr' => 'npr',
      'ⁿ√x' => 'root',
      _ => key,
    };
  }

  Future<void> _editExpression() async {
    final controller = TextEditingController(text: _controller.expression);
    final value = await showDialog<_ExpressionEditResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑表达式'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (!context.mounted) return;
              final text = data?.text?.trim();
              if (text == null || text.isEmpty) {
                final paste = CalculatorPasteResult.fromText(text ?? '');
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(paste.summary)));
                return;
              }
              Navigator.pop(context, _ExpressionEditResult.paste(text));
            },
            icon: const Icon(Icons.content_paste, size: 18),
            label: const Text('粘贴'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, const _ExpressionEditResult.clear()),
              child: const Text('清空')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _ExpressionEditResult.apply(controller.text.trim()),
            ),
            child: const Text('应用'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (value.clearRequested) {
      _controller.setExpression('');
      return;
    }
    final paste = _controller.applyPastedText(value.text);
    if (!mounted) return;
    if (!paste.hasExpression) {
      if (value.fromClipboard) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(paste.summary)));
      }
      return;
    }
    if (!value.fromClipboard && !paste.fromReport) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(paste.summary)));
  }

  double _basicKeyboardHeight(double screenHeight) {
    final preferred = screenHeight - 302;
    final rows = 5 + _functionRows;
    final minHeight = rows * 42.0 + rows * 8;
    final maxHeight = rows * 58.0 + rows * 8;
    return preferred.clamp(minHeight, maxHeight);
  }

  double _functionPanelHeight(double screenHeight, double displayHeight) {
    final reserved = displayHeight + 186;
    return (screenHeight - reserved).clamp(280.0, 420.0);
  }
}

class _CalculatorKeySurface extends StatefulWidget {
  // 中文：Basic 键盘使用按下即触发，减少“抬手才输入”的半拍延迟。
  // English: The basic keypad can fire on pointer-down to avoid the delay of waiting for tap-up.
  const _CalculatorKeySurface({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.padding,
    required this.immediate,
    required this.onPressed,
    required this.child,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final bool immediate;
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_CalculatorKeySurface> createState() => _CalculatorKeySurfaceState();
}

class _ExpressionEditResult {
  const _ExpressionEditResult._({
    required this.text,
    required this.fromClipboard,
    required this.clearRequested,
  });

  const _ExpressionEditResult.clear()
      : this._(text: '', fromClipboard: false, clearRequested: true);

  const _ExpressionEditResult.apply(String text)
      : this._(text: text, fromClipboard: false, clearRequested: false);

  const _ExpressionEditResult.paste(String text)
      : this._(text: text, fromClipboard: true, clearRequested: false);

  final String text;
  final bool fromClipboard;
  final bool clearRequested;
}

class _CalculatorKeySurfaceState extends State<_CalculatorKeySurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    return Semantics(
      button: true,
      child: Listener(
        // 中文：immediate=true 时由 Listener 触发，InkWell 只负责视觉反馈。
        // English: With immediate=true, Listener handles the action while InkWell keeps the visual feedback.
        onPointerDown: widget.immediate
            ? (_) {
                _setPressed(true);
                widget.onPressed();
              }
            : (_) => _setPressed(true),
        onPointerCancel: (_) => _setPressed(false),
        onPointerUp: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOutCubic,
          child: Material(
            color: widget.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: BorderSide(color: widget.borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.immediate ? null : widget.onPressed,
              borderRadius: borderRadius,
              child: IconTheme.merge(
                data: IconThemeData(color: widget.foregroundColor),
                child: Padding(
                  padding: widget.padding,
                  child: Center(child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
