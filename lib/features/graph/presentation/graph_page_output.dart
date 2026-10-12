part of 'graph_page.dart';

/// 中文：**图形的「读出去」那一半**——复制、导出、粘贴，以及标记的选择与呈现。
///
///       这一族从 `graph_page.dart` 搬出来，理由与那个文件其余几次拆分一样：
///       搬之前 `graph_page.dart` 是 **829 行**，越过了 800 的硬线。
///
///       **缝在哪儿**：`graph_page.dart` 那一半负责**把图画出来**——函数列表、视窗、缩放与适配、
///       `build` 的整棵渲染树；这一半负责**把已经画好的东西读出去**：复制数据、导出 PNG、
///       粘贴工作区，以及标记的取样/查找/选中/面板。两半之间是单向的——这一半读
///       `_functions` / `_viewport` / `_markers` / `_selectedMarker`，主文件不读这一半的任何状态
///       （**这一半没有自己的状态**）。
///
///       **⚠️ 一处不是逐字节搬的，只有三行**：`setState` 是 `@protected`，**extension 里调不了**
///       （`invalid_use_of_protected_member`，实测三条）。所以那三处改成调主文件里的 `_rebuild`，
///       一个把 `setState` 包起来的普通方法。**其余 187 行逐字节未动**——
///       正文 md5 `62a903f010f4cb3790bd27fc1233f945` 是**替换前**量的，替换只动了
///       `setState(` → `_rebuild(` 这一处名字。
///
///       **为什么是 `extension` 而不是 `mixin`**：搬的全是 `_GraphPageState` 的私有方法，私有成员
///       跨库搬不动，所以只能用同一个 library 的 `part`。而 `mixin _X on _GraphPageState`
///       配上 `class _GraphPageState with _X` 是**语言禁止的**（`recursive_interface_inheritance`，
///       实测过），所以只剩 `extension ... on _GraphPageState` 这一条路。
/// English: **the graph's "read it out" half** — copy, export, paste, and a marker's selection and
///          presentation.
///
///          This family moved out of `graph_page.dart` for the same reason as the other splits in that
///          file: before the move `graph_page.dart` stood at **829 lines**, past the hard 800.
///
///          **Where the seam is**: the half left in `graph_page.dart` **draws the graph** — the function
///          list, the viewport, zoom and fit, and `build`'s whole render tree; this half **reads out what
///          has been drawn**: copying data, exporting a PNG, pasting a workspace, and a marker's
///          sampling, lookup, selection and panel. The traffic is one way — this half reads `_functions`
///          / `_viewport` / `_markers` / `_selectedMarker`, and the main file reads none of this half's
///          state (**this half has no state of its own**).
///
///          **⚠️ one spot is not a verbatim move, and it is three lines**: `setState` is `@protected`
///          and **cannot be called from an extension** (`invalid_use_of_protected_member`, three of them
///          measured). Those three now call `_rebuild` in the main file, an ordinary method wrapping
///          `setState`. **The other 187 lines did not move a character** — the 190-line body hashed to
///          `62a903f010f4cb3790bd27fc1233f945` **before** the substitution, which touched only that one
///          name, `setState(` → `_rebuild(`.
///
///          **Why an `extension` rather than a `mixin`**: what moved is all private methods of
///          `_GraphPageState`, private members cannot cross a library boundary, so only a `part` of the
///          same library will do. And `mixin _X on _GraphPageState` together with
///          `class _GraphPageState with _X` is **forbidden by the language**
///          (`recursive_interface_inheritance`, measured), which leaves `extension ... on
///          _GraphPageState` as the only shape.
extension _GraphPageOutput on _GraphPageState {

  Future<void> _copyGraphData() async {
    final strings = GraphStrings.of(context);
    await Clipboard.setData(ClipboardData(
      text: buildGraphCopyText(
        functions: _functions,
        viewport: _viewport,
        markers: _markers,
        selectedMarker: _selectedMarker,
        strings: strings,
      ),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.copiedGraphData)));
    }
  }

  Future<void> _exportGraphPng() async {
    final strings = GraphStrings.of(context);
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
        content: Text(saved ? strings.savedPng : strings.cancelledSave),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.exportFailed('$error'))),
      );
    }
  }

  Future<void> _pasteGraphData() async {
    final strings = GraphStrings.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    final paste = parseGraphWorkspacePasteText(text,
        strings: strings, degreeMode: _degreeMode);
    if (!paste.hasWorkspace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paste.summary)),
      );
      return;
    }
    final workspace = paste.workspace!;
    _rebuild(() {
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
    final strings = GraphStrings.of(context);
    await Clipboard.setData(
      ClipboardData(text: buildMarkerCopyText(_markers[selected])),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.copiedMarker)));
    }
  }

  void _centerSelectedMarker() {
    final selected = _selectedMarker;
    if (selected == null || selected < 0 || selected >= _markers.length) {
      return;
    }
    final strings = GraphStrings.of(context);
    final marker = _markers[selected];
    _rebuild(() {
      _viewport = _viewport.centerOn(marker.x, marker.y);
      _status = strings.centeredOn(markerCopyLine(marker));
    });
    _scheduleWorkspacePersist();
  }

  void _selectMarkerByOffset(int delta) {
    if (_markers.isEmpty) return;
    final current = _selectedMarker ?? 0;
    final next = (current + delta) % _markers.length;
    _rebuild(() {
      _selectedMarker = next < 0 ? next + _markers.length : next;
      _status = _markers[_selectedMarker!].info;
    });
  }

  Widget _markerPanel() {
    final strings = GraphStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedMarker == null ||
            _selectedMarker! < 0 ||
            _selectedMarker! >= _markers.length
        ? 0
        : _selectedMarker!;
    final marker = _markers[selected];
    return Container(
      // 中文：这是**顶层**面板（`graph_page.dart:465` 调用，与同层那条 `all(14)` 的 softPanel 状态条是
      //       兄弟），所以取 **14**。本应用区分层级靠**嵌套与否**：12 是**嵌套**色块的层级（4 处，全部套在
      //       卡片或对话框里），不是顶层面板的。
      // English: a **top-level** panel (`graph_page.dart:465` — a sibling, at the same nesting level, of the
      //          `all(14)` softPanel status strip), so it takes **14**. In this app the tier is decided by
      //          **nesting**: 12 is the *nested* tinted-block tier (4 sites, all inside a card or a dialog).
      padding: const EdgeInsets.all(14),
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
                tooltip: strings.previousMarker,
                onPressed: _markers.length <= 1
                    ? null
                    : () => _selectMarkerByOffset(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: strings.nextMarker,
                onPressed: _markers.length <= 1
                    ? null
                    : () => _selectMarkerByOffset(1),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: strings.copyMarker,
                onPressed: _copySelectedMarker,
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: strings.centerOnMarker,
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

  List<GraphMarker> _findZeroMarkers(GraphStrings strings) {
    return buildGraphZeroMarkers(
        functions: _functions, viewport: _viewport, strings: strings);
  }

  List<GraphMarker> _findIntersectionMarkers(GraphStrings strings) {
    return buildGraphIntersectionMarkers(
        functions: _functions, viewport: _viewport, strings: strings);
  }

  List<GraphMarker> _findExtremeMarkers(GraphStrings strings) {
    return buildGraphExtremeMarkers(
        functions: _functions, viewport: _viewport, strings: strings);
  }
}
