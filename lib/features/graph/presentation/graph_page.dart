import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/math/expression_parser.dart';
import '../../../core/utils/expression_display_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/presentation/app_chrome.dart';

part 'graph_workspace_paste.dart';

/// 中文：函数图形页，提供函数管理、拖拽缩放，以及零点/交点/极值标记。
/// English: Function graph page with function management, pan/zoom, and zero/intersection/extrema markers.
class GraphPage extends StatefulWidget {
  const GraphPage({
    required this.db,
    required this.restoreState,
    this.reloadToken = 0,
    super.key,
  });

  final AppDatabase db;
  final bool restoreState;
  final int reloadToken;

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  late final SettingsRepository _settingsRepository =
      SettingsRepository(widget.db);
  final List<GraphFunction> _functions = defaultGraphFunctions();
  GraphViewport _viewport = defaultGraphViewport;
  List<GraphMarker> _markers = const [];
  int? _selectedMarker;
  String _status = '拖动画布平移，双指缩放';
  double _lastScale = 1;
  Timer? _workspacePersistTimer;
  int _workspaceRevision = 0;
  int _workspaceLoadToken = 0;

  @override
  void initState() {
    super.initState();
    if (widget.restoreState) unawaited(_loadWorkspace());
  }

  @override
  void didUpdateWidget(covariant GraphPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final imported = oldWidget.reloadToken != widget.reloadToken;
    if (imported) {
      if (widget.restoreState) {
        unawaited(_loadWorkspace(forceDefaultOnInvalid: true));
      } else {
        _workspacePersistTimer?.cancel();
      }
      return;
    }
    if (!oldWidget.restoreState && widget.restoreState) {
      unawaited(_persistWorkspace());
    }
    if (oldWidget.restoreState && !widget.restoreState) {
      _workspacePersistTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _workspacePersistTimer?.cancel();
    if (widget.restoreState) unawaited(_persistWorkspace());
    super.dispose();
  }

  Future<void> _addFunction() async {
    final expression = await _showFunctionDialog(
      title: '添加函数',
      initialExpression: _functions.length % 2 == 0 ? 'cos(x)' : '0.5*x + 1',
      confirmLabel: '添加',
    );
    if (expression == null) return;
    setState(() {
      _functions.add(GraphFunction(
        expression: expression,
        label: GraphFunction.labelFor(expression),
        color: _palette[_functions.length % _palette.length],
      ));
      _markers = const [];
      _selectedMarker = null;
      _status = '已添加 y = $expression';
    });
    _scheduleWorkspacePersist();
  }

  Future<String?> _showFunctionDialog({
    required String title,
    required String initialExpression,
    required String confirmLabel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _FunctionExpressionDialog(
        title: title,
        initialExpression: initialExpression,
        confirmLabel: confirmLabel,
      ),
    );
  }

  void _toggle(int index) {
    setState(() {
      _functions[index] =
          _functions[index].copyWith(visible: !_functions[index].visible);
      _markers = const [];
      _selectedMarker = null;
      _status = _functions[index].visible
          ? '已显示 ${_functions[index].label}'
          : '已隐藏 ${_functions[index].label}';
    });
    _scheduleWorkspacePersist();
  }

  Future<void> _editFunction(int index) async {
    final expression = await _showFunctionDialog(
      title: '编辑函数',
      initialExpression: _functions[index].expression,
      confirmLabel: '保存',
    );
    if (expression == null) return;
    setState(() {
      final current = _functions[index];
      _functions[index] = GraphFunction(
          expression: expression,
          label: GraphFunction.labelFor(expression),
          color: current.color,
          visible: current.visible);
      _markers = const [];
      _selectedMarker = null;
      _status = '已更新 y = $expression';
    });
    _scheduleWorkspacePersist();
  }

  void _deleteFunction(int index) {
    setState(() {
      final removed = _functions.removeAt(index);
      _markers = const [];
      _selectedMarker = null;
      _status = '已删除 ${removed.label}';
    });
    _scheduleWorkspacePersist();
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _functions.length; i++) {
        _functions[i] = _functions[i].copyWith(visible: true);
      }
      _viewport = defaultGraphViewport;
      _markers = const [];
      _selectedMarker = null;
      _status = '视图已重置';
    });
    _scheduleWorkspacePersist();
  }

  void _restoreDefaultWorkspace({required String status}) {
    _functions
      ..clear()
      ..addAll(defaultGraphFunctions());
    _viewport = defaultGraphViewport;
    _markers = const [];
    _selectedMarker = null;
    _status = status;
  }

  Future<void> _loadWorkspace({bool forceDefaultOnInvalid = false}) async {
    final token = ++_workspaceLoadToken;
    final revisionAtStart = _workspaceRevision;
    final settings = await _settingsRepository.load();
    final raw = settings[graphWorkspaceSettingKey];
    final workspace = decodeGraphWorkspace(raw);
    if (!mounted ||
        !widget.restoreState ||
        token != _workspaceLoadToken ||
        revisionAtStart != _workspaceRevision) {
      return;
    }
    if (workspace == null) {
      if (forceDefaultOnInvalid && raw != null && raw.trim().isNotEmpty) {
        setState(() {
          _restoreDefaultWorkspace(status: '图形工作区数据无效，已恢复默认视图');
        });
      }
      return;
    }
    setState(() {
      _functions
        ..clear()
        ..addAll(workspace.functions);
      _viewport = workspace.viewport;
      _markers = const [];
      _selectedMarker = null;
      _status = '已恢复上次图形工作区';
    });
  }

  void _scheduleWorkspacePersist() {
    if (!widget.restoreState) return;
    _workspaceRevision++;
    _workspacePersistTimer?.cancel();
    _workspacePersistTimer = Timer(
      const Duration(milliseconds: 260),
      () => unawaited(_persistWorkspace()),
    );
  }

  Future<void> _persistWorkspace() async {
    if (!widget.restoreState) return;
    final encoded = encodeGraphWorkspace(
      functions: _functions,
      viewport: _viewport,
    );
    await _settingsRepository.set(graphWorkspaceSettingKey, encoded);
  }

  void _zoom(double factor) {
    setState(() {
      _viewport = _viewport.zoom(factor);
      _status =
          '视图范围 x: ${_viewport.xMin.toStringAsFixed(1)} ~ ${_viewport.xMax.toStringAsFixed(1)}';
    });
    _scheduleWorkspacePersist();
  }

  void _fitVisibleY() {
    final visible = _functions.where((item) => item.visible).toList();
    if (visible.isEmpty) {
      setState(() => _status = '没有可见函数可适配');
      return;
    }
    final values = <double>[];
    const samples = 720;
    for (final function in visible) {
      for (var i = 0; i <= samples; i++) {
        final x = _viewport.xMin + i / samples * _viewport.spanX;
        final y = function.evaluate(x);
        if (y.isFinite && y.abs() < 1e8) values.add(y);
      }
    }
    if (values.length < 2) {
      setState(() => _status = '当前视图没有足够的有效采样点');
      return;
    }
    values.sort();
    final low = values[(values.length * 0.02).floor()];
    final highIndex =
        (values.length * 0.98).ceil().clamp(0, values.length - 1).toInt();
    final high = values[highIndex];
    final span = (high - low).abs();
    final paddedSpan = span < 1e-9 ? 4.0 : (span * 1.24).clamp(1.0, 200.0);
    setState(() {
      _viewport = GraphViewport(
        centerX: _viewport.centerX,
        centerY: (low + high) / 2,
        spanX: _viewport.spanX,
        spanY: paddedSpan,
      );
      _markers = const [];
      _selectedMarker = null;
      _status = '已适配当前可见曲线';
    });
    _scheduleWorkspacePersist();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            const Expanded(child: PageTitle('图形')),
            IconToolButton(
                icon: Icons.content_paste,
                tooltip: '粘贴图形数据',
                onTap: _pasteGraphData),
            const SizedBox(width: 8),
            IconToolButton(
                icon: Icons.copy_outlined,
                tooltip: '复制图形数据',
                onTap: _copyGraphData),
            const SizedBox(width: 8),
            IconToolButton(
                icon: Icons.add, tooltip: '添加函数', onTap: _addFunction),
          ],
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < _functions.length; i++) ...[
                FunctionRow(
                  function: _functions[i],
                  onToggle: () => _toggle(i),
                  onEdit: () => _editFunction(i),
                  onDelete:
                      _functions.length <= 1 ? null : () => _deleteFunction(i),
                ),
                if (i != _functions.length - 1) const Divider(height: 1),
              ],
              const Divider(height: 1),
              ListTile(
                onTap: _addFunction,
                leading: const Icon(Icons.add_circle_outline,
                    color: Color(0xFF1677FF)),
                title: const Text('添加函数',
                    style: TextStyle(color: Color(0xFF1677FF))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 380,
          decoration: softPanel(context: context),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onScaleStart: (_) => _lastScale = 1,
                onTapUp: (details) =>
                    _selectMarker(details.localPosition, size),
                onScaleUpdate: (details) {
                  if (details.pointerCount == 1) {
                    setState(() {
                      _viewport = _viewport.pan(details.focalPointDelta, size);
                      _status =
                          'x: ${_viewport.xMin.toStringAsFixed(1)} ~ ${_viewport.xMax.toStringAsFixed(1)}';
                    });
                    _scheduleWorkspacePersist();
                    return;
                  }
                  if ((details.scale - 1).abs() < 0.01) return;
                  final incremental = details.scale / _lastScale;
                  _lastScale = details.scale;
                  setState(() {
                    _viewport = _viewport.zoomAt(
                      1 / incremental,
                      details.localFocalPoint,
                      size,
                    );
                    _status =
                        '缩放 ${(12 / _viewport.spanX).toStringAsFixed(2)}x';
                  });
                  _scheduleWorkspacePersist();
                },
                onScaleEnd: (_) => _lastScale = 1,
                child: CustomPaint(
                  painter: GraphPainter(
                    functions: _functions,
                    viewport: _viewport,
                    markers: _markers,
                    selectedMarker: _selectedMarker,
                    gridColor: scheme.outlineVariant.withValues(alpha: 0.52),
                    axisColor: scheme.onSurfaceVariant,
                    labelColor: scheme.onSurfaceVariant,
                    markerLabelColor: scheme.onSurface,
                    markerLabelBackground: scheme.surface,
                    markerLabelBorder: scheme.outlineVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: softPanel(context: context, highlight: true),
          child: Center(
            child: Text(_status,
                style: TextStyle(
                    color: scheme.secondary, fontWeight: FontWeight.w800)),
          ),
        ),
        if (_markers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _markerPanel(),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: ActionButton(
                    icon: Icons.refresh, label: '重置', onTap: _reset)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.fit_screen, label: '适配', onTap: _fitVisibleY)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.zoom_in,
                    label: '放大',
                    onTap: () => _zoom(0.75))),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.zoom_out,
                    label: '缩小',
                    onTap: () => _zoom(1.35))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: ActionButton(
                    icon: Icons.adjust, label: '零点', onTap: _markZeros)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.scatter_plot_outlined,
                    label: '交点',
                    onTap: _markIntersections)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.timeline, label: '极值', onTap: _markExtremes)),
          ],
        ),
      ],
    );
  }

  void _selectMarker(Offset localPosition, Size size) {
    final selected = _nearestMarkerIndex(localPosition, size);
    if (selected != null) {
      setState(() {
        _selectedMarker = selected;
        _status = _markers[selected].info;
      });
      return;
    }
    _sampleAt(localPosition, size);
  }

  int? _nearestMarkerIndex(Offset localPosition, Size size) {
    if (_markers.isEmpty) return null;
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < _markers.length; i++) {
      final marker = _markers[i];
      final point = Offset(_viewport.toScreenX(marker.x, size),
          _viewport.toScreenY(marker.y, size));
      final distance = (point - localPosition).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestIndex == -1 || bestDistance > 26) return null;
    return bestIndex;
  }

  void _sampleAt(Offset localPosition, Size size) {
    final x = _viewport.xMin + localPosition.dx / size.width * _viewport.spanX;
    final markers = buildSampleMarkers(
      functions: _functions,
      x: x,
      yMin: _viewport.yMin,
      yMax: _viewport.yMax,
    );
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status = markers.isEmpty
          ? 'x = ${x.toStringAsFixed(6)} 处没有可见有效函数值'
          : 'x = ${x.toStringAsFixed(6)}，已取样 ${markers.length} 条曲线';
    });
  }

  void _markZeros() {
    final markers = _findZeroMarkers();
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status =
          markers.isEmpty ? '当前视图未找到零点' : '找到 ${markers.length} 个零点，点击高亮点查看详情';
    });
  }

  void _markIntersections() {
    final markers = _findIntersectionMarkers();
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status =
          markers.isEmpty ? '当前视图未找到交点' : '找到 ${markers.length} 个交点，点击高亮点查看详情';
    });
  }

  void _markExtremes() {
    final markers = _findExtremeMarkers();
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status = markers.isEmpty
          ? '当前视图没有有效极值采样'
          : '找到 ${markers.length} 个极值点，点击高亮点查看详情';
    });
  }

  Future<void> _copyGraphData() async {
    await Clipboard.setData(ClipboardData(
      text: buildGraphCopyText(
        functions: _functions,
        viewport: _viewport,
        markers: _markers,
        selectedMarker: _selectedMarker,
      ),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制图形数据')));
    }
  }

  Future<void> _pasteGraphData() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    final paste = parseGraphWorkspacePasteText(text);
    if (!paste.hasWorkspace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paste.summary)),
      );
      return;
    }
    final workspace = paste.workspace!;
    setState(() {
      _functions
        ..clear()
        ..addAll(workspace.functions);
      _viewport = workspace.viewport;
      _markers = const [];
      _selectedMarker = null;
      _status = paste.summary;
    });
    _scheduleWorkspacePersist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(paste.summary)),
    );
  }

  Future<void> _copySelectedMarker() async {
    final selected = _selectedMarker;
    if (selected == null || selected < 0 || selected >= _markers.length) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: buildMarkerCopyText(_markers[selected])),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制当前标记')));
    }
  }

  void _centerSelectedMarker() {
    final selected = _selectedMarker;
    if (selected == null || selected < 0 || selected >= _markers.length) {
      return;
    }
    final marker = _markers[selected];
    setState(() {
      _viewport = _viewport.centerOn(marker.x, marker.y);
      _status = '已居中到 ${_markerCopyLine(marker)}';
    });
    _scheduleWorkspacePersist();
  }

  void _selectMarkerByOffset(int delta) {
    if (_markers.isEmpty) return;
    final current = _selectedMarker ?? 0;
    final next = (current + delta) % _markers.length;
    setState(() {
      _selectedMarker = next < 0 ? next + _markers.length : next;
      _status = _markers[_selectedMarker!].info;
    });
  }

  Widget _markerPanel() {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedMarker == null ||
            _selectedMarker! < 0 ||
            _selectedMarker! >= _markers.length
        ? 0
        : _selectedMarker!;
    final marker = _markers[selected];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: softPanel(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: marker.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${marker.kind} ${selected + 1}/${_markers.length}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: '上一个标记',
                onPressed: _markers.length <= 1
                    ? null
                    : () => _selectMarkerByOffset(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: '下一个标记',
                onPressed: _markers.length <= 1
                    ? null
                    : () => _selectMarkerByOffset(1),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: '复制标记',
                onPressed: _copySelectedMarker,
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: '居中到标记',
                onPressed: _centerSelectedMarker,
                icon: const Icon(Icons.center_focus_strong_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _markerCopyLine(marker),
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            marker.info,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }

  List<GraphMarker> _findZeroMarkers() {
    return buildGraphZeroMarkers(functions: _functions, viewport: _viewport);
  }

  List<GraphMarker> _findIntersectionMarkers() {
    return buildGraphIntersectionMarkers(
        functions: _functions, viewport: _viewport);
  }

  List<GraphMarker> _findExtremeMarkers() {
    return buildGraphExtremeMarkers(functions: _functions, viewport: _viewport);
  }
}

class _FunctionExpressionDialog extends StatefulWidget {
  const _FunctionExpressionDialog({
    required this.title,
    required this.initialExpression,
    required this.confirmLabel,
  });

  final String title;
  final String initialExpression;
  final String confirmLabel;

  @override
  State<_FunctionExpressionDialog> createState() =>
      _FunctionExpressionDialogState();
}

class _FunctionExpressionDialogState extends State<_FunctionExpressionDialog> {
  late final TextEditingController _controller;
  String? _error;
  GraphFunctionInputPreview _preview = GraphFunctionInputPreview.empty();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialExpression);
    _preview = previewGraphFunctionInput(
      widget.initialExpression,
      color: const Color(0xFF1677FF),
    );
    _controller.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePreview);
    _controller.dispose();
    super.dispose();
  }

  void _updatePreview() {
    setState(() {
      _preview = previewGraphFunctionInput(
        _controller.text,
        color: const Color(0xFF1677FF),
      );
      if (_error != null) _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'y =',
                hintText: '例如 sin(x)、2x + 1、y = x^2 - 3x + 2',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: softPanel(context: context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_preview.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    _preview.message,
                    style: TextStyle(
                      color: _preview.isValid
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  void _submit() {
    final preview = previewGraphFunctionInput(
      _controller.text,
      color: const Color(0xFF1677FF),
    );
    if (!preview.isValid) {
      setState(() {
        _preview = preview;
        _error = preview.errorMessage;
      });
      return;
    }
    Navigator.pop(context, preview.normalizedExpression);
  }
}

class FunctionRow extends StatelessWidget {
  const FunctionRow({
    required this.function,
    required this.onToggle,
    required this.onEdit,
    this.onDelete,
    super.key,
  });

  final GraphFunction function;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.circle, color: function.color, size: 12),
      title: Text(function.label),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: function.visible ? '隐藏' : '显示',
            onPressed: onToggle,
            icon: Icon(
                function.visible ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF1677FF)),
          ),
          PopupMenuButton<String>(
            tooltip: '函数操作',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑函数')),
              PopupMenuItem(
                  value: 'delete',
                  enabled: onDelete != null,
                  child: const Text('删除函数')),
            ],
          ),
        ],
      ),
    );
  }
}

class GraphFunction {
  const GraphFunction({
    required this.expression,
    required this.label,
    required this.color,
    this.visible = true,
  });

  final String expression;
  final String label;
  final Color color;
  final bool visible;

  static String labelFor(String expression) {
    return 'y = ${formatExpressionForDisplay(
      normalizeExpression(expression),
      mathSymbols: true,
    )}';
  }

  static String normalizeExpression(String raw) {
    var expression = raw
        .trim()
        .replaceAll('−', '-')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('，', ',')
        .replaceAll('：', ':')
        .replaceAll('＝', '=');
    expression = _stripGraphAssignmentPrefix(expression).trim();
    expression = _stripGraphDomainSuffix(expression).trim();
    return ExpressionParser.normalizeExpressionInput(expression);
  }

  static String _stripGraphAssignmentPrefix(String expression) {
    final prefixed = RegExp(
      r'^(?:y(?:\s*\(\s*x\s*\))?|[a-z]\s*\(\s*x\s*\))\s*(?::=|=>|->|=|:|→|⇒)\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(expression);
    if (prefixed != null) return prefixed.group(1)!;

    final equation = _equationParts(expression);
    if (equation != null) {
      return '((${equation.left})-(${equation.right}))';
    }
    return expression;
  }

  static ({String left, String right})? _equationParts(String expression) {
    final match =
        RegExp(r'^(.*?)\s*(?:=>|⇒|=|＝)\s*(.*?)$').firstMatch(expression);
    if (match == null) return null;
    final left = match.group(1)?.trim() ?? '';
    final right = match.group(2)?.trim() ?? '';
    if (left.isEmpty || right.isEmpty) return null;
    return (left: left, right: right);
  }

  static String _stripGraphDomainSuffix(String expression) {
    final separated = RegExp(
      r'^(.*?)(?:[,;，；]\s*(?:(?:定义域|domain\b)|x\s*(?:∈|in\b|属于|范围)|for\s+x\b).*)$',
      caseSensitive: false,
    ).firstMatch(expression);
    final forX = RegExp(
      r'^(.*?)\s+for\s+x\b.*$',
      caseSensitive: false,
    ).firstMatch(expression);
    final value = separated?.group(1)?.trim() ?? forX?.group(1)?.trim();
    if (value == null || value.isEmpty) return expression;
    return value;
  }

  GraphFunction copyWith({bool? visible}) {
    return GraphFunction(
        expression: expression,
        label: label,
        color: color,
        visible: visible ?? this.visible);
  }

  double evaluate(double x) {
    try {
      // 中文：图形页复用核心表达式解析器，保证计算器和图形函数语义一致。
      // English: The graph page reuses the core expression parser so graph functions match calculator semantics.
      final parsed = _normalizeForParser(expression, x);
      return ExpressionParser(parsed, degreeMode: false).parse();
    } catch (_) {
      return double.nan;
    }
  }

  String _normalizeForParser(String raw, double x) {
    // 中文：图形页只替换变量 x，其余符号归一化和隐式乘法交给核心解析器统一处理。
    // English: Graphing only substitutes x; core parser handles symbol normalization and implicit multiplication.
    return _replaceGraphVariable(normalizeExpression(raw).toLowerCase(), x);
  }

  String _numberLiteral(double value) {
    if (value.abs() < 1e-12) return '0';
    return value
        .toStringAsFixed(12)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _replaceGraphVariable(String expression, double x) {
    final literal = '(${_numberLiteral(x)})';
    final buffer = StringBuffer();
    var index = 0;
    while (index < expression.length) {
      final radixEnd = _radixLiteralEnd(expression, index);
      if (radixEnd != null) {
        buffer.write(expression.substring(index, radixEnd));
        index = radixEnd;
        continue;
      }
      final char = expression[index];
      if (char == 'x' && _isGraphVariableAt(expression, index)) {
        buffer.write(literal);
      } else {
        buffer.write(char);
      }
      index++;
    }
    return buffer.toString();
  }

  int? _radixLiteralEnd(String expression, int index) {
    if (index + 1 >= expression.length || expression[index] != '0') {
      return null;
    }
    if (index > 0 && _isIdentifierOrDigit(expression[index - 1])) {
      return null;
    }
    final prefix = expression[index + 1];
    final radix = switch (prefix) {
      'x' => 16,
      'b' => 2,
      'o' => 8,
      _ => null,
    };
    if (radix == null) return null;

    var cursor = index + 2;
    while (cursor < expression.length) {
      final char = expression[cursor];
      if (char == '_') {
        cursor++;
        continue;
      }
      final digit = _radixDigitValue(char);
      if (digit == null || digit >= radix) break;
      cursor++;
    }
    return cursor;
  }

  int? _radixDigitValue(String char) {
    final code = char.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) return code - 0x30;
    if (code >= 0x61 && code <= 0x66) return code - 0x61 + 10;
    return null;
  }

  bool _isGraphVariableAt(String expression, int index) {
    final before = index == 0 ? null : expression[index - 1];
    final after = index + 1 >= expression.length ? null : expression[index + 1];
    return !_isAsciiLetter(before) && !_isAsciiLetter(after);
  }

  bool _isIdentifierOrDigit(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5a) ||
        (code >= 0x61 && code <= 0x7a) ||
        char == '_';
  }

  bool _isAsciiLetter(String? char) {
    if (char == null) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
  }
}

class GraphMarker {
  const GraphMarker({
    required this.x,
    required this.y,
    required this.color,
    required this.kind,
    required this.info,
  });

  final double x;
  final double y;
  final Color color;
  final String kind;
  final String info;
}

class GraphFunctionInputPreview {
  const GraphFunctionInputPreview({
    required this.rawInput,
    required this.normalizedExpression,
    required this.label,
    required this.validSampleCount,
    this.errorMessage,
  });

  factory GraphFunctionInputPreview.empty() {
    return const GraphFunctionInputPreview(
      rawInput: '',
      normalizedExpression: '',
      label: 'y =',
      validSampleCount: 0,
      errorMessage: '请输入函数表达式',
    );
  }

  final String rawInput;
  final String normalizedExpression;
  final String label;
  final int validSampleCount;
  final String? errorMessage;

  bool get isValid => errorMessage == null;

  String get message {
    if (errorMessage != null) return errorMessage!;
    return '将绘制 $label，有效采样 $validSampleCount/5';
  }
}

const String graphWorkspaceSettingKey = 'graph_workspace';
const int _graphWorkspaceVersion = 1;
const GraphViewport defaultGraphViewport =
    GraphViewport(centerX: 0, centerY: 0, spanX: 12, spanY: 12);

List<GraphFunction> defaultGraphFunctions() {
  return [
    const GraphFunction(
      expression: 'sin(x)',
      label: 'y = sin(x)',
      color: Color(0xFF1677FF),
    ),
    const GraphFunction(
      expression: 'x^2 - 3*x + 2',
      label: 'y = x² - 3x + 2',
      color: Color(0xFF7C3AED),
    ),
  ];
}

class GraphWorkspace {
  const GraphWorkspace({
    required this.functions,
    required this.viewport,
  });

  final List<GraphFunction> functions;
  final GraphViewport viewport;
}

String encodeGraphWorkspace({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
}) {
  final functionList = functions
      .where((function) => function.expression.trim().isNotEmpty)
      .toList(growable: false);
  final effectiveFunctions =
      functionList.isEmpty ? defaultGraphFunctions() : functionList;
  return jsonEncode({
    'version': _graphWorkspaceVersion,
    'viewport': viewport.toJson(),
    'functions': [
      for (final function in effectiveFunctions)
        {
          'expression': function.expression,
          'visible': function.visible,
          'color': function.color.toARGB32(),
        },
    ],
  });
}

GraphWorkspace? decodeGraphWorkspace(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final viewport =
        GraphViewport.fromJson(decoded['viewport']) ?? defaultGraphViewport;
    final rawFunctions = decoded['functions'];
    if (rawFunctions is! List) return null;
    final functions = <GraphFunction>[];
    for (var i = 0; i < rawFunctions.length; i++) {
      final function = _graphFunctionFromJson(
        rawFunctions[i],
        fallbackColor: _palette[i % _palette.length],
      );
      if (function != null) functions.add(function);
    }
    if (functions.isEmpty) return null;
    return GraphWorkspace(
      functions: List.unmodifiable(functions),
      viewport: viewport,
    );
  } catch (_) {
    return null;
  }
}

GraphFunction? _graphFunctionFromJson(
  Object? raw, {
  required Color fallbackColor,
}) {
  if (raw is! Map) return null;
  final rawExpression = raw['expression'];
  if (rawExpression is! String) return null;
  final color = _colorFromJson(raw['color']) ?? fallbackColor;
  final preview = previewGraphFunctionInput(rawExpression, color: color);
  if (!preview.isValid) return null;
  final visible = raw['visible'] is bool ? raw['visible'] as bool : true;
  return GraphFunction(
    expression: preview.normalizedExpression,
    label: preview.label,
    color: color,
    visible: visible,
  );
}

Color? _colorFromJson(Object? raw) {
  final value = switch (raw) {
    int value => value,
    num value => value.toInt(),
    String value => _parseColorString(value),
    _ => null,
  };
  if (value == null || value < 0 || value > 0xFFFFFFFF) return null;
  return Color(value);
}

int? _parseColorString(String raw) {
  var text = raw.trim();
  if (text.startsWith('#')) text = text.substring(1);
  if (text.startsWith('0x') || text.startsWith('0X')) text = text.substring(2);
  if (text.length == 6) text = 'FF$text';
  if (text.length != 8) return null;
  return int.tryParse(text, radix: 16);
}

GraphFunctionInputPreview previewGraphFunctionInput(
  String raw, {
  required Color color,
}) {
  final normalized = GraphFunction.normalizeExpression(raw);
  if (normalized.isEmpty) {
    return GraphFunctionInputPreview(
      rawInput: raw,
      normalizedExpression: normalized,
      label: 'y =',
      validSampleCount: 0,
      errorMessage: '请输入函数表达式',
    );
  }

  final probe = GraphFunction(
    expression: normalized,
    label: GraphFunction.labelFor(normalized),
    color: color,
  );
  final validSamples = [-2.0, -1.0, 0.0, 1.0, 2.0]
      .map(probe.evaluate)
      .where((value) => value.isFinite)
      .length;
  if (validSamples == 0) {
    return GraphFunctionInputPreview(
      rawInput: raw,
      normalizedExpression: normalized,
      label: probe.label,
      validSampleCount: validSamples,
      errorMessage: '表达式无法计算，请检查函数名、括号或变量 x',
    );
  }

  return GraphFunctionInputPreview(
    rawInput: raw,
    normalizedExpression: normalized,
    label: probe.label,
    validSampleCount: validSamples,
  );
}

String buildGraphCopyText({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  required Iterable<GraphMarker> markers,
  int? selectedMarker,
}) {
  final functionList = functions.toList(growable: false);
  final markerList = markers.toList(growable: false);
  final lines = <String>[
    '图形数据',
    '',
    '函数',
    if (functionList.isEmpty)
      '无'
    else
      for (var i = 0; i < functionList.length; i++) ...[
        '${i + 1}. ${functionList[i].label} (${functionList[i].visible ? '显示' : '隐藏'})',
        '   表达式: ${functionList[i].expression}',
      ],
    '',
    '视窗',
    'x: ${_formatGraphNumber(viewport.xMin)} ~ ${_formatGraphNumber(viewport.xMax)}',
    'y: ${_formatGraphNumber(viewport.yMin)} ~ ${_formatGraphNumber(viewport.yMax)}',
  ];

  if (selectedMarker != null &&
      selectedMarker >= 0 &&
      selectedMarker < markerList.length) {
    final marker = markerList[selectedMarker];
    lines.addAll([
      '',
      '当前标记',
      _markerCopyLine(marker),
      marker.info,
    ]);
  }

  lines.addAll([
    '',
    '标记',
    if (markerList.isEmpty)
      '无'
    else
      for (var i = 0; i < markerList.length; i++)
        '${i + 1}. ${_markerCopyLine(markerList[i])}',
  ]);

  return lines.join('\n');
}

String _markerCopyLine(GraphMarker marker) {
  return '${marker.kind}: x = ${_formatGraphNumber(marker.x)}, y = ${_formatGraphNumber(marker.y)}';
}

String buildMarkerCopyText(GraphMarker marker) {
  return [
    _markerCopyLine(marker),
    marker.info,
  ].join('\n');
}

String _formatGraphNumber(double value) {
  return formatNumber(value, precision: 8);
}

List<GraphMarker> buildSampleMarkers({
  required Iterable<GraphFunction> functions,
  required double x,
  required double yMin,
  required double yMax,
}) {
  final visible = functions.where((item) => item.visible).toList();
  final values = <({GraphFunction function, double y})>[];
  for (final function in visible) {
    final y = function.evaluate(x);
    if (y.isFinite && !y.isNaN && y >= yMin && y <= yMax) {
      values.add((function: function, y: y));
    }
  }
  return [
    for (var i = 0; i < values.length; i++)
      GraphMarker(
        x: x,
        y: values[i].y,
        color: values[i].function.color,
        kind: '取样',
        info: [
          'x = ${x.toStringAsFixed(6)}',
          for (final value in values)
            '${value.function.label}: y = ${value.y.toStringAsFixed(6)}',
        ].join('\n'),
      ),
  ];
}

List<GraphMarker> buildGraphZeroMarkers({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  int samples = 800,
}) {
  final visible = functions.where((item) => item.visible).toList();
  if (visible.isEmpty || !_yInViewport(0, viewport)) return const [];
  final markers = <GraphMarker>[];
  final tolerance = _rootResidualTolerance(viewport);
  final xTolerance = viewport.spanX / samples * 3;
  for (final function in visible) {
    if (_mostlyZeroAcrossViewport(
      evaluate: function.evaluate,
      viewport: viewport,
      samples: samples,
      tolerance: tolerance,
    )) {
      _addMarkerIfUnique(
        markers,
        GraphMarker(
          x: viewport.centerX,
          y: 0,
          color: function.color,
          kind: '零点',
          info: '${function.label} 与 x 轴重合\n当前视图内所有 x 都是零点',
        ),
        xTolerance,
        tolerance,
      );
      continue;
    }
    final roots = _findRootCandidates(
      evaluate: function.evaluate,
      xMin: viewport.xMin,
      xMax: viewport.xMax,
      samples: samples,
      tolerance: tolerance,
    );
    for (final root in roots) {
      final y = function.evaluate(root);
      if (!_finiteNumber(y) || y.abs() > tolerance) continue;
      _addMarkerIfUnique(
        markers,
        GraphMarker(
          x: root,
          y: 0,
          color: function.color,
          kind: '零点',
          info: '${function.label} 零点\nx = ${root.toStringAsFixed(6)}\ny = 0',
        ),
        xTolerance,
        tolerance,
      );
    }
  }
  return markers;
}

List<GraphMarker> buildGraphIntersectionMarkers({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  int samples = 800,
}) {
  final visible = functions.where((item) => item.visible).toList();
  if (visible.length < 2) return const [];
  final markers = <GraphMarker>[];
  final tolerance = _rootResidualTolerance(viewport);
  final xTolerance = viewport.spanX / samples * 3;
  // 中文：所有可见函数两两配对，避免只检查前两条曲线导致交点缺失。
  // English: Compare every visible function pair so intersections are not limited to the first two curves.
  for (var i = 0; i < visible.length; i++) {
    for (var j = i + 1; j < visible.length; j++) {
      final first = visible[i];
      final second = visible[j];
      double difference(double x) => first.evaluate(x) - second.evaluate(x);
      if (_mostlyZeroAcrossViewport(
        evaluate: difference,
        viewport: viewport,
        samples: samples,
        tolerance: tolerance,
      )) {
        final overlap = _firstVisiblePoint(first, viewport, samples);
        if (overlap != null) {
          _addMarkerIfUnique(
            markers,
            GraphMarker(
              x: overlap.$1,
              y: overlap.$2,
              color: const Color(0xFFFF8A00),
              kind: '重合',
              info: '${first.label}\n${second.label}\n两条曲线在当前视图内重合',
            ),
            xTolerance,
            tolerance,
          );
        }
        continue;
      }
      final roots = _findRootCandidates(
        evaluate: difference,
        xMin: viewport.xMin,
        xMax: viewport.xMax,
        samples: samples,
        tolerance: tolerance,
      );
      for (final root in roots) {
        final firstY = first.evaluate(root);
        final secondY = second.evaluate(root);
        if (!_finiteNumber(firstY) || !_finiteNumber(secondY)) continue;
        if ((firstY - secondY).abs() > tolerance) continue;
        final y = (firstY + secondY) / 2;
        if (!_yInViewport(y, viewport)) continue;
        _addMarkerIfUnique(
          markers,
          GraphMarker(
            x: root,
            y: y,
            color: const Color(0xFFFF8A00),
            kind: '交点',
            info:
                '${first.label}\n${second.label}\n交点 x = ${root.toStringAsFixed(6)}, y = ${y.toStringAsFixed(6)}',
          ),
          xTolerance,
          tolerance,
        );
      }
    }
  }
  return markers;
}

List<GraphMarker> buildGraphExtremeMarkers({
  required Iterable<GraphFunction> functions,
  required GraphViewport viewport,
  int samples = 1000,
}) {
  final visible = functions.where((item) => item.visible).toList();
  if (visible.isEmpty || samples < 2 || viewport.spanX <= 0) return const [];
  final markers = <GraphMarker>[];
  final step = viewport.spanX / samples;
  final xTolerance = step * 4;
  final yTolerance = math.max(1e-7, viewport.spanY.abs() * 1e-8);
  // 中文：使用相邻三点判断局部极值，再用二次插值细化点位。
  // English: Detect local extrema with three neighboring samples, then refine the point by quadratic interpolation.
  for (final function in visible) {
    var leftX = viewport.xMin;
    var leftY = function.evaluate(leftX);
    var midX = leftX + step;
    var midY = function.evaluate(midX);
    for (var rightX = midX + step;
        rightX <= viewport.xMax + step * 0.5;
        rightX += step) {
      final clampedRightX = math.min(rightX, viewport.xMax);
      final rightY = function.evaluate(clampedRightX);
      if (_finiteNumber(leftY) &&
          _finiteNumber(midY) &&
          _finiteNumber(rightY)) {
        final isMin = midY < leftY && midY <= rightY;
        final isMax = midY > leftY && midY >= rightY;
        if (isMin || isMax) {
          final refined = _quadraticVertex(
            leftX,
            leftY,
            midX,
            midY,
            clampedRightX,
            rightY,
          );
          final x = refined?.$1 ?? midX;
          final y = refined?.$2 ?? midY;
          if (_finiteNumber(x) &&
              _finiteNumber(y) &&
              x >= viewport.xMin &&
              x <= viewport.xMax &&
              _yInViewport(y, viewport)) {
            _addMarkerIfUnique(
              markers,
              GraphMarker(
                x: x,
                y: y,
                color:
                    isMin ? const Color(0xFF23B45D) : const Color(0xFFFF4D5E),
                kind: isMin ? '极小值' : '极大值',
                info:
                    '${function.label} ${isMin ? '极小值' : '极大值'}\nx = ${x.toStringAsFixed(6)}\ny = ${y.toStringAsFixed(6)}',
              ),
              xTolerance,
              yTolerance,
            );
          }
        }
      }
      if (clampedRightX >= viewport.xMax) break;
      leftX = midX;
      leftY = midY;
      midX = clampedRightX;
      midY = rightY;
    }
  }
  return markers;
}

List<double> _findRootCandidates({
  required double Function(double x) evaluate,
  required double xMin,
  required double xMax,
  required int samples,
  required double tolerance,
}) {
  if (samples <= 0 || xMax <= xMin) return const [];
  final step = (xMax - xMin) / samples;
  final xTolerance = step * 3;
  final xs = List<double>.generate(samples + 1, (index) => xMin + index * step);
  final ys = [for (final x in xs) evaluate(x)];
  final roots = <double>[];

  for (var i = 0; i < ys.length; i++) {
    final y = ys[i];
    if (_finiteNumber(y) && y.abs() <= tolerance) {
      _addRootCandidate(roots, xs[i], xTolerance);
    }
  }

  for (var i = 0; i < samples; i++) {
    final y1 = ys[i];
    final y2 = ys[i + 1];
    if (!_finiteNumber(y1) || !_finiteNumber(y2)) continue;
    if (y1.abs() <= tolerance || y2.abs() <= tolerance) continue;
    if (y1.sign == y2.sign) continue;
    final root = _bisectRoot(
      evaluate: evaluate,
      left: xs[i],
      right: xs[i + 1],
      tolerance: tolerance,
    );
    if (root != null) _addRootCandidate(roots, root, xTolerance);
  }

  for (var i = 1; i < samples; i++) {
    final left = ys[i - 1];
    final middle = ys[i];
    final right = ys[i + 1];
    if (!_finiteNumber(left) ||
        !_finiteNumber(middle) ||
        !_finiteNumber(right)) {
      continue;
    }
    if (middle.abs() > left.abs() || middle.abs() > right.abs()) continue;
    final root = _minimizeAbsoluteRoot(
      evaluate: evaluate,
      left: xs[i - 1],
      right: xs[i + 1],
      tolerance: tolerance,
    );
    if (root != null) _addRootCandidate(roots, root, xTolerance);
  }

  roots.sort();
  return List.unmodifiable(roots);
}

double? _bisectRoot({
  required double Function(double x) evaluate,
  required double left,
  required double right,
  required double tolerance,
}) {
  var a = left;
  var b = right;
  var fa = evaluate(a);
  var fb = evaluate(b);
  if (!_finiteNumber(fa) || !_finiteNumber(fb)) return null;
  if (fa.abs() <= tolerance) return a;
  if (fb.abs() <= tolerance) return b;
  if (fa.sign == fb.sign) return null;
  var bestX = fa.abs() < fb.abs() ? a : b;
  var bestY = fa.abs() < fb.abs() ? fa : fb;
  for (var i = 0; i < 60; i++) {
    final mid = (a + b) / 2;
    final fm = evaluate(mid);
    if (!_finiteNumber(fm)) return null;
    if (fm.abs() < bestY.abs()) {
      bestX = mid;
      bestY = fm;
    }
    if (fm.abs() <= tolerance) return mid;
    if (fa.sign == fm.sign) {
      a = mid;
      fa = fm;
    } else {
      b = mid;
      fb = fm;
    }
  }
  return bestY.abs() <= tolerance ? bestX : null;
}

double? _minimizeAbsoluteRoot({
  required double Function(double x) evaluate,
  required double left,
  required double right,
  required double tolerance,
}) {
  var a = left;
  var b = right;
  for (var i = 0; i < 48; i++) {
    final m1 = a + (b - a) / 3;
    final m2 = b - (b - a) / 3;
    final y1 = evaluate(m1).abs();
    final y2 = evaluate(m2).abs();
    if (!_finiteNumber(y1) || !_finiteNumber(y2)) return null;
    if (y1 < y2) {
      b = m2;
    } else {
      a = m1;
    }
  }
  final candidate = (a + b) / 2;
  final value = evaluate(candidate);
  return _finiteNumber(value) && value.abs() <= tolerance ? candidate : null;
}

bool _mostlyZeroAcrossViewport({
  required double Function(double x) evaluate,
  required GraphViewport viewport,
  required int samples,
  required double tolerance,
}) {
  var finite = 0;
  var nearZero = 0;
  final probeSamples = math.min(samples, 80);
  for (var i = 0; i <= probeSamples; i++) {
    final x = viewport.xMin + i / probeSamples * viewport.spanX;
    final y = evaluate(x);
    if (!_finiteNumber(y)) continue;
    finite++;
    if (y.abs() <= tolerance) nearZero++;
  }
  return finite >= 3 && nearZero / finite >= 0.98;
}

(double, double)? _firstVisiblePoint(
  GraphFunction function,
  GraphViewport viewport,
  int samples,
) {
  final centerY = function.evaluate(viewport.centerX);
  if (_finiteNumber(centerY) && _yInViewport(centerY, viewport)) {
    return (viewport.centerX, centerY);
  }
  for (var i = 0; i <= samples; i++) {
    final x = viewport.xMin + i / samples * viewport.spanX;
    final y = function.evaluate(x);
    if (_finiteNumber(y) && _yInViewport(y, viewport)) return (x, y);
  }
  return null;
}

void _addRootCandidate(List<double> roots, double x, double tolerance) {
  if (!_finiteNumber(x)) return;
  if (roots.any((root) => (root - x).abs() < tolerance)) return;
  roots.add(x);
}

void _addMarkerIfUnique(
  List<GraphMarker> markers,
  GraphMarker marker,
  double xTolerance,
  double yTolerance,
) {
  if (markers.any((item) =>
      (item.x - marker.x).abs() < xTolerance &&
      (item.y - marker.y).abs() < yTolerance)) {
    return;
  }
  markers.add(marker);
}

bool _finiteNumber(double value) => value.isFinite && !value.isNaN;

(double, double)? _quadraticVertex(
  double x1,
  double y1,
  double x2,
  double y2,
  double x3,
  double y3,
) {
  // 中文：用三点拟合局部抛物线，提升极值标记精度但避免引入重型数值库。
  // English: Fit a local parabola from three points for better extrema accuracy without a heavy numeric library.
  final denominator = (x1 - x2) * (x1 - x3) * (x2 - x3);
  if (denominator.abs() < 1e-12) return null;
  final a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / denominator;
  final b = (x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1) + x1 * x1 * (y2 - y3)) /
      denominator;
  if (a.abs() < 1e-12) return null;
  final x = -b / (2 * a);
  if (x < math.min(x1, x3) || x > math.max(x1, x3)) return null;
  final y = a * x * x + b * x + (y2 - a * x2 * x2 - b * x2);
  return (x, y);
}

bool _yInViewport(double y, GraphViewport viewport) {
  return y >= viewport.yMin && y <= viewport.yMax;
}

double _rootResidualTolerance(GraphViewport viewport) {
  return math.max(1e-7, viewport.spanY.abs() * 1e-8);
}

List<List<Offset>> buildGraphPlotSegments({
  required GraphFunction function,
  required GraphViewport viewport,
  required double width,
  required double height,
}) {
  if (width <= 0 || height <= 0) return const [];
  final segments = <List<Offset>>[];
  var current = <Offset>[];
  Offset? previous;
  final maxJump = height * 0.75;
  for (var i = 0; i <= width.round(); i++) {
    // 中文：按屏幕像素采样，缩放后曲线密度自然跟随可见宽度。
    // English: Sample per screen pixel so curve density follows the visible width after zooming.
    final screenX = i.toDouble();
    final x = viewport.xMin + screenX / width * viewport.spanX;
    final y = function.evaluate(x);
    final inBand = y.isFinite &&
        !y.isNaN &&
        y >= viewport.yMin - viewport.spanY &&
        y <= viewport.yMax + viewport.spanY;
    if (!inBand) {
      _finishGraphSegment(segments, current);
      current = <Offset>[];
      previous = null;
      continue;
    }
    final point = Offset(screenX, viewport.toScreenY(y, Size(width, height)));
    if (previous != null && (point.dy - previous.dy).abs() > maxJump) {
      // 中文：大跳变时断开路径，避免渐近线被错误连成竖线。
      // English: Break the path on large jumps to avoid drawing false vertical lines at asymptotes.
      _finishGraphSegment(segments, current);
      current = <Offset>[];
    }
    current.add(point);
    previous = point;
  }
  _finishGraphSegment(segments, current);
  return segments;
}

void _finishGraphSegment(List<List<Offset>> segments, List<Offset> current) {
  if (current.length >= 2) {
    segments.add(List.unmodifiable(current));
  }
}

const List<Color> _palette = [
  Color(0xFF1677FF),
  Color(0xFF7C3AED),
  Color(0xFFFF8A00),
  Color(0xFF23B45D),
  Color(0xFFFF4D5E),
];

class GraphPainter extends CustomPainter {
  const GraphPainter({
    required this.functions,
    required this.viewport,
    required this.markers,
    required this.selectedMarker,
    required this.gridColor,
    required this.axisColor,
    required this.labelColor,
    required this.markerLabelColor,
    required this.markerLabelBackground,
    required this.markerLabelBorder,
  });

  final List<GraphFunction> functions;
  final GraphViewport viewport;
  final List<GraphMarker> markers;
  final int? selectedMarker;
  final Color gridColor;
  final Color axisColor;
  final Color labelColor;
  final Color markerLabelColor;
  final Color markerLabelBackground;
  final Color markerLabelBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    // 中文：网格步长使用 1/2/5 序列，让缩放时刻度更接近工程图表习惯。
    // English: Grid steps use the 1/2/5 sequence so zoomed ticks feel like engineering charts.
    final xStep = _niceStep(viewport.spanX / 8);
    final yStep = _niceStep(viewport.spanY / 8);
    for (var x = (viewport.xMin / xStep).floor() * xStep;
        x <= viewport.xMax;
        x += xStep) {
      final sx = viewport.toScreenX(x, size);
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), grid);
      _label(canvas, textPainter, x.toStringAsFixed(_digits(xStep)),
          Offset(sx + 3, size.height - 18));
    }
    for (var y = (viewport.yMin / yStep).floor() * yStep;
        y <= viewport.yMax;
        y += yStep) {
      final sy = viewport.toScreenY(y, size);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), grid);
      _label(canvas, textPainter, y.toStringAsFixed(_digits(yStep)),
          Offset(4, sy - 16));
    }
    if (viewport.yMin <= 0 && viewport.yMax >= 0) {
      final y0 = viewport.toScreenY(0, size);
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), axis);
    }
    if (viewport.xMin <= 0 && viewport.xMax >= 0) {
      final x0 = viewport.toScreenX(0, size);
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), axis);
    }
    for (final function in functions.where((item) => item.visible)) {
      _plot(canvas, size, function);
    }
    _plotMarkers(canvas, size);
  }

  void _plot(Canvas canvas, Size size, GraphFunction function) {
    final paint = Paint()
      ..color = function.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    final segments = buildGraphPlotSegments(
      function: function,
      viewport: viewport,
      width: size.width,
      height: size.height,
    );
    for (final segment in segments) {
      for (var i = 0; i < segment.length; i++) {
        final point = segment[i];
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  void _plotMarkers(Canvas canvas, Size size) {
    // 中文：只绘制当前视窗内的标记，平移后隐藏离屏点，避免标签污染画布。
    // English: Paint only in-viewport markers so offscreen points do not pollute the canvas after panning.
    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      if (marker.x < viewport.xMin ||
          marker.x > viewport.xMax ||
          marker.y < viewport.yMin ||
          marker.y > viewport.yMax) {
        continue;
      }
      final center = Offset(viewport.toScreenX(marker.x, size),
          viewport.toScreenY(marker.y, size));
      final selected = selectedMarker == i;
      final fill = Paint()..color = marker.color;
      final halo = Paint()
        ..color = marker.color.withValues(alpha: selected ? 0.22 : 0.12);
      final stroke = Paint()
        ..color = markerLabelBackground
        ..strokeWidth = selected ? 3 : 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, selected ? 14 : 10, halo);
      canvas.drawCircle(center, selected ? 6.5 : 5, fill);
      canvas.drawCircle(center, selected ? 6.5 : 5, stroke);
      if (selected) {
        _markerLabel(canvas, marker.kind, center + const Offset(10, -28));
      }
    }
  }

  void _markerLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: markerLabelColor,
              fontSize: 11,
              fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(
        offset.dx - 6, offset.dy - 4, painter.width + 12, painter.height + 8);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = markerLabelBackground);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = markerLabelBorder
        ..style = PaintingStyle.stroke,
    );
    painter.paint(canvas, offset);
  }

  void _label(Canvas canvas, TextPainter painter, String text, Offset offset) {
    painter.text =
        TextSpan(text: text, style: TextStyle(color: labelColor, fontSize: 10));
    painter.layout();
    painter.paint(canvas, offset);
  }

  double _niceStep(double value) {
    final exponent =
        math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final fraction = value / exponent;
    final nice = fraction <= 1
        ? 1
        : fraction <= 2
            ? 2
            : fraction <= 5
                ? 5
                : 10;
    return nice * exponent;
  }

  int _digits(double step) => step < 1
      ? 2
      : step < 10
          ? 1
          : 0;

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.functions != functions ||
        oldDelegate.viewport != viewport ||
        oldDelegate.markers != markers ||
        oldDelegate.selectedMarker != selectedMarker ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.markerLabelColor != markerLabelColor ||
        oldDelegate.markerLabelBackground != markerLabelBackground ||
        oldDelegate.markerLabelBorder != markerLabelBorder;
  }
}

class GraphViewport {
  const GraphViewport({
    required this.centerX,
    required this.centerY,
    required this.spanX,
    required this.spanY,
  });

  final double centerX;
  final double centerY;
  final double spanX;
  final double spanY;

  Map<String, double> toJson() {
    return {
      'centerX': centerX,
      'centerY': centerY,
      'spanX': spanX,
      'spanY': spanY,
    };
  }

  static GraphViewport? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final centerX = _jsonDouble(raw['centerX']);
    final centerY = _jsonDouble(raw['centerY']);
    final spanX = _jsonDouble(raw['spanX']);
    final spanY = _jsonDouble(raw['spanY']);
    if (centerX == null || centerY == null || spanX == null || spanY == null) {
      return null;
    }
    if (spanX <= 0 || spanY <= 0) return null;
    return GraphViewport(
      centerX: centerX,
      centerY: centerY,
      spanX: spanX.clamp(0.5, 200).toDouble(),
      spanY: spanY.clamp(0.5, 200).toDouble(),
    );
  }

  double get xMin => centerX - spanX / 2;
  double get xMax => centerX + spanX / 2;
  double get yMin => centerY - spanY / 2;
  double get yMax => centerY + spanY / 2;

  GraphViewport zoom(double factor) {
    return zoomAt(factor, null, null);
  }

  GraphViewport zoomAt(double factor, Offset? focalPoint, Size? size) {
    final safe = factor.clamp(0.2, 5.0);
    final nextSpanX = (spanX * safe).clamp(0.5, 200).toDouble();
    final nextSpanY = (spanY * safe).clamp(0.5, 200).toDouble();
    if (focalPoint == null ||
        size == null ||
        size.width <= 0 ||
        size.height <= 0) {
      return GraphViewport(
          centerX: centerX,
          centerY: centerY,
          spanX: nextSpanX,
          spanY: nextSpanY);
    }

    final focalX = toGraphX(focalPoint.dx, size);
    final focalY = toGraphY(focalPoint.dy, size);
    final ratioX = (focalPoint.dx / size.width).clamp(0.0, 1.0);
    final ratioY = (focalPoint.dy / size.height).clamp(0.0, 1.0);
    final nextXMin = focalX - ratioX * nextSpanX;
    final nextYMax = focalY + ratioY * nextSpanY;
    return GraphViewport(
      centerX: nextXMin + nextSpanX / 2,
      centerY: nextYMax - nextSpanY / 2,
      spanX: nextSpanX,
      spanY: nextSpanY,
    );
  }

  GraphViewport pan(Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return this;
    return GraphViewport(
      centerX: centerX - delta.dx / size.width * spanX,
      centerY: centerY + delta.dy / size.height * spanY,
      spanX: spanX,
      spanY: spanY,
    );
  }

  GraphViewport centerOn(double x, double y) {
    if (!x.isFinite || !y.isFinite) return this;
    return GraphViewport(
      centerX: x,
      centerY: y,
      spanX: spanX,
      spanY: spanY,
    );
  }

  double toScreenX(double x, Size size) => (x - xMin) / spanX * size.width;

  double toScreenY(double y, Size size) => (yMax - y) / spanY * size.height;

  double toGraphX(double screenX, Size size) {
    if (size.width <= 0) return centerX;
    return xMin + screenX / size.width * spanX;
  }

  double toGraphY(double screenY, Size size) {
    if (size.height <= 0) return centerY;
    return yMax - screenY / size.height * spanY;
  }
}

double? _jsonDouble(Object? value) {
  final parsed = switch (value) {
    num value => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };
  return parsed == null || !parsed.isFinite ? null : parsed;
}
