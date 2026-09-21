import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/local/app_database.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/platform/document_export_channel.dart';
import '../../../core/utils/render_export.dart';
import '../models/graph_models.dart';
export '../models/graph_models.dart';
import 'graph_function_expression_dialog.dart';
export 'graph_function_expression_dialog.dart';
import 'graph_painter.dart';
export 'graph_painter.dart';
import 'graph_workspace_paste.dart';
export 'graph_workspace_paste.dart';
import '../../../shared/presentation/app_chrome.dart';

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
  final GlobalKey _graphBoundaryKey = GlobalKey();

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
        color: graphPalette[_functions.length % graphPalette.length],
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
      builder: (context) => FunctionExpressionDialog(
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
                icon: Icons.image_outlined,
                tooltip: '导出图形 PNG',
                onTap: _exportGraphPng),
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
                  key: ValueKey(_functions[i].expression),
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
                child: RepaintBoundary(
                    key: _graphBoundaryKey,
                    child: CustomPaint(
                      painter: GraphPainter(
                        functions: _functions,
                        viewport: _viewport,
                        markers: _markers,
                        selectedMarker: _selectedMarker,
                        gridColor:
                            scheme.outlineVariant.withValues(alpha: 0.52),
                        axisColor: scheme.onSurfaceVariant,
                        labelColor: scheme.onSurfaceVariant,
                        markerLabelColor: scheme.onSurface,
                        markerLabelBackground: scheme.surface,
                        markerLabelBorder: scheme.outlineVariant,
                      ),
                      child: const SizedBox.expand(),
                    )),
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

  Future<void> _exportGraphPng() async {
    try {
      final bytes = await captureBoundaryPng(_graphBoundaryKey);
      final saved = await DocumentExportChannel.exportBytes(
        fileName:
            buildExportFileName(prefix: 'nekocalc_graph', extension: 'png'),
        mimeType: 'image/png',
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved ? '图形已保存为 PNG' : '已取消保存图形'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出图形失败：$error')),
      );
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
      _status = '已居中到 ${markerCopyLine(marker)}';
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
            markerCopyLine(marker),
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
