import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/local/app_database.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/platform/document_export_channel.dart';
import '../../../core/utils/render_export.dart';
import '../models/graph_models.dart';
export '../models/graph_models.dart';
import '../models/graph_strings.dart';
import 'graph_function_expression_dialog.dart';
export 'graph_function_expression_dialog.dart';
import 'graph_painter.dart';
export 'graph_painter.dart';
import 'graph_workspace_paste.dart';
export 'graph_workspace_paste.dart';
import '../../../shared/presentation/app_chrome.dart';

part 'graph_page_output.dart';

class GraphPage extends StatefulWidget {
  const GraphPage({
    required this.db,
    required this.restoreState,
    this.angleMode = 'RAD',
    this.reloadToken = 0,
    super.key,
  });

  final AppDatabase db;
  final bool restoreState;

  /// 中文：**应用当前的角度单位**（`'DEG'` / `'RAD'`），由外壳从 `AppSettings` 里递下来——与
  ///       `restoreState` 同一个来源、同一种形状。判据与计算页逐字一致（`angleMode == 'DEG'`），
  ///       图形页每求一次值都按它走，所以 `sin(90)` 在两边是同一个答案。
  /// English: **the app's current angle unit** (`'DEG'` / `'RAD'`), handed down by the shell from
  ///          `AppSettings` — the same source and the same shape as `restoreState`. The test is
  ///          character-for-character the calculator page's (`angleMode == 'DEG'`), and every
  ///          evaluation here follows it, so `sin(90)` is one answer on both sides.
  final String angleMode;

  final int reloadToken;

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  late final SettingsRepository _settingsRepository =
      SettingsRepository(widget.db);
  final List<GraphFunction> _functions = [];

  /// 中文：**当前角度单位是不是角度制。** 判据与计算页那条逐字相同（`angleMode == 'DEG'`），
  ///       值是外壳从设置里递下来的，所以图形页与计算器认的是同一个开关。
  /// English: **whether the current angle unit is degrees.** The test is character-for-character the
  ///          calculator page's (`angleMode == 'DEG'`) and the value is handed down from settings by
  ///          the shell, so the graph page and the calculator read the same switch.
  bool get _degreeMode => widget.angleMode == 'DEG';

  /// 中文：**把当前角度单位盖在一批函数上。** `_functions` 里每一个函数都必须带着它——求值发生在
  ///       画曲线、解标记、适配 y 窗口三条路径上，它们手里只有一个 [GraphFunction]；工作区恢复与
  ///       粘贴那条路已经把模式传进解析器了，这个方法是给"不是从线和格式里来"的那些来源用的：
  ///       默认函数、以及**角度单位本身换掉的时候**（那时已经画出来的每个函数都要重盖，否则曲线
  ///       会继续按旧单位画）。
  /// English: **stamps the current angle unit onto a batch of functions.** Every function in
  ///          `_functions` must carry it: evaluation happens on three paths (plotting, marker solving,
  ///          fitting the y window) and each holds nothing but a [GraphFunction]. The workspace-restore
  ///          and paste routes already pass the mode into the parser; this method covers the sources
  ///          that do **not** come from the wire — the default functions, and **a change of the angle
  ///          unit itself**, when every function already on screen has to be re-stamped or the curves
  ///          keep drawing under the old unit.
  List<GraphFunction> _withAngleMode(Iterable<GraphFunction> functions) => [
        for (final function in functions)
          function.copyWith(degreeMode: _degreeMode),
      ];

  GraphViewport _viewport = defaultGraphViewport;
  List<GraphMarker> _markers = const [];
  int? _selectedMarker;

  /// 中文：状态栏那一句。**`null` 表示"还没发生任何事"，渲染时回落到 `panHint`。** 存 `String?`
  ///       而不是在 `initState` 里查表，是因为表要等 `context`（`didChangeDependencies` 之后才有），
  ///       而默认态必须逐字节是今天那句 `拖动画布平移，双指缩放`。每个 handler 在 `context` 可用时
  ///       查表并写入具体文案，只有这一条初值留空、由 `build` 兜底。
  /// English: the status bar sentence. **`null` means "nothing has happened yet" and falls back to
  ///          `panHint` at render time.** It is a `String?` rather than a table lookup in `initState`
  ///          because the table needs `context` (only available after `didChangeDependencies`), and the
  ///          default state must stay byte-identical to today's `拖动画布平移，双指缩放`. Every handler
  ///          looks the table up while `context` is available and stores a concrete sentence; only this
  ///          initial value stays empty and is covered by `build`.
  String? _status;
  double _lastScale = 1;
  Timer? _workspacePersistTimer;
  int _workspaceRevision = 0;
  int _workspaceLoadToken = 0;
  final GlobalKey _graphBoundaryKey = GlobalKey();

  /// 中文：**`setState` 的一个普通外壳。** `setState` 是 `@protected`，**extension 里调不了**
  ///       （`invalid_use_of_protected_member`，实测三条）。`graph_page_output.dart` 里那三处
  ///       要重绘，但它们搬进 `part` 之后就不在 `State` 的子类里了，所以从这里过一道。
  ///       **这不是绕开什么，是把"语言不许"换成"一个看得见的方法"**——那三处的调用者因此
  ///       与其余 187 行一样能整体搬走。理由与量到的三条警告写在那个文件的文件头。
  /// English: **a plain wrapper around `setState`.** `setState` is `@protected` and **cannot be called
  ///          from an extension** (`invalid_use_of_protected_member`, three of them measured). The
  ///          three repaint sites in `graph_page_output.dart` need it, but once they move into a `part`
  ///          they are no longer inside a subclass of `State`, so they come through here. **This is not
  ///          routing around anything — it turns "the language forbids it" into a visible method**, which
  ///          is what lets those three sites move whole with the other 187 lines. The reasoning and the
  ///          three measured warnings are on that file's head.
  void _rebuild(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _functions.addAll(_withAngleMode(defaultGraphFunctions()));
    if (widget.restoreState) unawaited(_loadWorkspace());
  }

  @override
  void didUpdateWidget(covariant GraphPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.angleMode != widget.angleMode) {
      // 中文：**角度单位换了，屏幕上的东西要跟着换。** 逐个函数重盖新单位——曲线、标记与 y 窗口
      //       适配都只认函数身上那一个字段；已经解出来的标记是旧单位下的解，留着就是错的，一并撤掉。
      //       这里不调 `setState`：`didUpdateWidget` 之后框架马上就会重建这一帧，直接改即可。
      // English: **the angle unit changed, so what is on screen has to change with it.** Every
      //          function is re-stamped — the curve, the markers and the y-window fit all read that one
      //          field on the function; and the markers already solved are solutions under the old
      //          unit, so keeping them would be wrong and they go too. No `setState` here: the
      //          framework rebuilds this frame right after `didUpdateWidget`, so a direct write is
      //          enough.
      final restamped = _withAngleMode(_functions);
      _functions
        ..clear()
        ..addAll(restamped);
      _markers = const [];
      _selectedMarker = null;
    }
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
    final strings = GraphStrings.of(context);
    final expression = await _showFunctionDialog(
      title: strings.addFunction,
      initialExpression: _functions.length % 2 == 0 ? 'cos(x)' : '0.5*x + 1',
      confirmLabel: strings.addConfirm,
    );
    if (expression == null) return;
    setState(() {
      _functions.add(GraphFunction(
        expression: expression,
        label: GraphFunction.labelFor(expression),
        color: graphPalette[_functions.length % graphPalette.length],
        degreeMode: _degreeMode,
      ));
      _markers = const [];
      _selectedMarker = null;
      _status = strings.addedFunction(expression);
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
        degreeMode: _degreeMode,
      ),
    );
  }

  void _toggle(int index) {
    final strings = GraphStrings.of(context);
    setState(() {
      _functions[index] =
          _functions[index].copyWith(visible: !_functions[index].visible);
      _markers = const [];
      _selectedMarker = null;
      _status = _functions[index].visible
          ? strings.shownFunction(_functions[index].label)
          : strings.hiddenFunction(_functions[index].label);
    });
    _scheduleWorkspacePersist();
  }

  Future<void> _editFunction(int index) async {
    final strings = GraphStrings.of(context);
    final expression = await _showFunctionDialog(
      title: strings.editFunction,
      initialExpression: _functions[index].expression,
      confirmLabel: strings.saveConfirm,
    );
    if (expression == null) return;
    setState(() {
      final current = _functions[index];
      _functions[index] = GraphFunction(
          expression: expression,
          label: GraphFunction.labelFor(expression),
          color: current.color,
          visible: current.visible,
          degreeMode: _degreeMode);
      _markers = const [];
      _selectedMarker = null;
      _status = strings.updatedFunction(expression);
    });
    _scheduleWorkspacePersist();
  }

  void _deleteFunction(int index) {
    final strings = GraphStrings.of(context);
    setState(() {
      final removed = _functions.removeAt(index);
      _markers = const [];
      _selectedMarker = null;
      _status = strings.deletedFunction(removed.label);
    });
    _scheduleWorkspacePersist();
  }

  void _reset() {
    final strings = GraphStrings.of(context);
    setState(() {
      for (var i = 0; i < _functions.length; i++) {
        _functions[i] = _functions[i].copyWith(visible: true);
      }
      _viewport = defaultGraphViewport;
      _markers = const [];
      _selectedMarker = null;
      _status = strings.viewReset;
    });
    _scheduleWorkspacePersist();
  }

  void _restoreDefaultWorkspace({required String status}) {
    _functions
      ..clear()
      ..addAll(_withAngleMode(defaultGraphFunctions()));
    _viewport = defaultGraphViewport;
    _markers = const [];
    _selectedMarker = null;
    _status = status;
  }

  Future<void> _loadWorkspace({bool forceDefaultOnInvalid = false}) async {
    // 中文：**`initState` 也会走到这里，那时 `context` 还不许查表**（`dependOnInheritedWidgetOfExactType`
    //       在 `initState` 完成前调用会断言失败）。这里只用到 `strings` 的两句**事后**文案
    //       （`invalidWorkspace` / `restoredWorkspace`），所以先记下"要不要写、写哪一格"，等
    //       `await` 回来、`context` 可用之后（`build` 与 `didChangeDependencies` 都已跑过）再查表。
    //       查表只发生在 `await` 之后这一条路径上，`initState` 路径根本不查。
    // English: **`initState` reaches here too, and at that point `context` may not look up a table**
    //          (`dependOnInheritedWidgetOfExactType` asserts when called before `initState` finishes).
    //          Only two **post-hoc** sentences are needed here (`invalidWorkspace` /
    //          `restoredWorkspace`), so remember which one to write and look the table up after the
    //          `await`, by which time `context` is usable (`build` and `didChangeDependencies` have
    //          already run). The lookup happens only on that post-`await` path; the `initState` path
    //          never looks anything up.
    final token = ++_workspaceLoadToken;
    final revisionAtStart = _workspaceRevision;
    final settings = await _settingsRepository.load();
    final raw = settings[graphWorkspaceSettingKey];
    if (!mounted) return;
    final strings = GraphStrings.of(context);
    final workspace =
        decodeGraphWorkspace(raw, strings: strings, degreeMode: _degreeMode);
    if (!mounted ||
        !widget.restoreState ||
        token != _workspaceLoadToken ||
        revisionAtStart != _workspaceRevision) {
      return;
    }
    if (workspace == null) {
      if (forceDefaultOnInvalid && raw != null && raw.trim().isNotEmpty) {
        setState(() {
          _restoreDefaultWorkspace(status: strings.invalidWorkspace);
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
      _status = strings.restoredWorkspace;
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
    final strings = GraphStrings.of(context);
    setState(() {
      _viewport = _viewport.zoom(factor);
      _status = strings.viewRange(
        _viewport.xMin.toStringAsFixed(1),
        _viewport.xMax.toStringAsFixed(1),
      );
    });
    _scheduleWorkspacePersist();
  }

  void _fitVisibleY() {
    final strings = GraphStrings.of(context);
    final visible = _functions.where((item) => item.visible).toList();
    if (visible.isEmpty) {
      setState(() => _status = strings.noVisibleFunction);
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
      setState(() => _status = strings.notEnoughSamples);
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
      _status = strings.fittedVisible;
    });
    _scheduleWorkspacePersist();
  }

  @override
  Widget build(BuildContext context) {
    final strings = GraphStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            Expanded(child: PageTitle(strings.pageTitle)),
            IconToolButton(
                icon: Icons.content_paste,
                tooltip: strings.pasteTooltip,
                onTap: _pasteGraphData),
            const SizedBox(width: 8),
            IconToolButton(
                icon: Icons.copy_outlined,
                tooltip: strings.copyTooltip,
                onTap: _copyGraphData),
            const SizedBox(width: 8),
            IconToolButton(
                icon: Icons.image_outlined,
                tooltip: strings.exportPngTooltip,
                onTap: _exportGraphPng),
            const SizedBox(width: 8),
            IconToolButton(
                icon: Icons.add,
                tooltip: strings.addFunction,
                onTap: _addFunction),
          ],
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < _functions.length; i++) ...[
                FunctionRow(
                  key: ValueKey(_functions[i].expression),
                  function: _functions[i],
                  strings: strings,
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
                leading: Icon(Icons.add_circle_outline, color: scheme.primary),
                title: Text(strings.addFunction,
                    style: TextStyle(color: scheme.primary)),
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
                      _status = strings.panRange(
                        _viewport.xMin.toStringAsFixed(1),
                        _viewport.xMax.toStringAsFixed(1),
                      );
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
                    _status = strings
                        .zoomed((12 / _viewport.spanX).toStringAsFixed(2));
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
            child: Text(_status ?? strings.panHint,
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
                    icon: Icons.refresh, label: strings.reset, onTap: _reset)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.fit_screen,
                    label: strings.fit,
                    onTap: _fitVisibleY)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.zoom_in,
                    label: strings.zoomIn,
                    onTap: () => _zoom(0.75))),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.zoom_out,
                    label: strings.zoomOut,
                    onTap: () => _zoom(1.35))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: ActionButton(
                    icon: Icons.adjust,
                    label: strings.zerosButton,
                    onTap: _markZeros)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.scatter_plot_outlined,
                    label: strings.intersectionsButton,
                    onTap: _markIntersections)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.timeline,
                    label: strings.extremesButton,
                    onTap: _markExtremes)),
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
    final strings = GraphStrings.of(context);
    final x = _viewport.xMin + localPosition.dx / size.width * _viewport.spanX;
    final markers = buildSampleMarkers(
      functions: _functions,
      x: x,
      yMin: _viewport.yMin,
      yMax: _viewport.yMax,
      strings: strings,
    );
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status = markers.isEmpty
          ? strings.sampleNone(x.toStringAsFixed(6))
          : strings.sampleDone(x.toStringAsFixed(6), markers.length);
    });
  }

  void _markZeros() {
    final strings = GraphStrings.of(context);
    final markers = _findZeroMarkers(strings);
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status = markers.isEmpty
          ? strings.noZeros
          : strings.foundZeros(markers.length);
    });
  }

  void _markIntersections() {
    final strings = GraphStrings.of(context);
    final markers = _findIntersectionMarkers(strings);
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status = markers.isEmpty
          ? strings.noIntersections
          : strings.foundIntersections(markers.length);
    });
  }

  void _markExtremes() {
    final strings = GraphStrings.of(context);
    final markers = _findExtremeMarkers(strings);
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status = markers.isEmpty
          ? strings.noExtremes
          : strings.foundExtremes(markers.length);
    });
  }

}

class FunctionRow extends StatelessWidget {
  const FunctionRow({
    required this.function,
    required this.strings,
    required this.onToggle,
    required this.onEdit,
    this.onDelete,
    super.key,
  });

  final GraphFunction function;
  final GraphStrings strings;
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
            tooltip: function.visible ? strings.hide : strings.show,
            onPressed: onToggle,
            icon: Icon(
                function.visible ? Icons.visibility : Icons.visibility_off,
                color: Theme.of(context).colorScheme.primary),
          ),
          PopupMenuButton<String>(
            tooltip: strings.functionActions,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(strings.editFunction)),
              PopupMenuItem(
                  value: 'delete',
                  enabled: onDelete != null,
                  child: Text(strings.deleteFunction)),
            ],
          ),
        ],
      ),
    );
  }
}
