part of 'data_fit_tool_screen.dart';

extension _DataFitActions on _DataFitToolScreenState {
  Widget _actions() {
    // 中文：复制、保存历史、保存笔记保持同一行，符合工具页统一操作区。
    // English: Copy, save history, and save note share one row to match the common tool action layout.
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ActionButton(
                icon: Icons.copy_outlined,
                label: '复制',
                onTap: _copyResult,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActionButton(
                icon: Icons.save_outlined,
                label: '保存',
                onTap: _saveHistory,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActionButton(
                icon: Icons.note_add_outlined,
                label: '笔记',
                onTap: _saveNote,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('导出 CSV'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportChartPng,
                icon: const Icon(Icons.image_outlined),
                label: const Text('保存图表'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportCsv() async {
    final result = _result;
    if (result == null || _series.isEmpty) return;
    try {
      final saved = await DocumentExportChannel.exportBytes(
        fileName: buildExportFileName(prefix: 'nekocalc_fit', extension: 'csv'),
        mimeType: 'text/csv',
        bytes: encodeExportText(buildFitCsvExport(
          seriesName: _series[_selectedSeriesIndex].name,
          result: result,
        )),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved ? '拟合数据已导出为 CSV' : '已取消导出 CSV')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出 CSV 失败：$error')),
      );
    }
  }

  Future<void> _exportChartPng() async {
    if (_result == null) return;
    try {
      final bytes = await captureBoundaryPng(_chartBoundaryKey);
      final saved = await DocumentExportChannel.exportBytes(
        fileName:
            buildExportFileName(prefix: 'nekocalc_fit_chart', extension: 'png'),
        mimeType: 'image/png',
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved ? '拟合图表已保存为 PNG' : '已取消保存图表')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存图表失败：$error')),
      );
    }
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    final paste = parseDataFitPasteText(text);
    if (!paste.hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paste.summary)),
      );
      return;
    }
    _applyPastedData(paste);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(paste.summary)),
    );
  }

  Future<void> _showExampleMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.show_chart_outlined),
              title: const Text('多列示例'),
              subtitle: const Text('一列 x，多列 y，适合对比多组数据'),
              onTap: () => Navigator.pop(context, 'multi'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('表头示例'),
              subtitle: const Text('兼容从表格粘贴的 x,y1,y2 表头'),
              onTap: () => Navigator.pop(context, 'spreadsheet'),
            ),
            ListTile(
              leading: const Icon(Icons.percent_outlined),
              title: const Text('本地化数字示例'),
              subtitle: const Text('全角数字、百分号会自动规范化'),
              onTap: () => Navigator.pop(context, 'localized'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'spreadsheet':
        _applyDataSample(
          _DataFitToolScreenState._spreadsheetExample,
          model: FitModel.linear,
        );
      case 'localized':
        _applyDataSample(
          _DataFitToolScreenState._localizedExample,
          model: FitModel.linear,
        );
      default:
        _applyDataSample(
          _DataFitToolScreenState._defaultData,
          model: FitModel.linear,
        );
    }
  }

  String _copyText() {
    final result = _result;
    if (result == null) return _error ?? '无有效拟合结果';
    // 中文：复制内容包含原始数据，便于把拟合结论贴到笔记或外部文档后仍可复核。
    // English: Copied text includes raw data so the fitted result remains auditable in notes or external docs.
    return [
      widget.tool.title,
      if (_series.isNotEmpty) '数据组: ${_series[_selectedSeriesIndex].name}',
      result.summary,
      if (_predictionCopyText() != null) ...[
        '',
        _predictionCopyText()!,
      ],
      '',
      '模型建议:',
      ..._recommendationLines(),
      '',
      '诊断:',
      ..._diagnostics,
      if (_residualAlerts.isNotEmpty) ...[
        '',
        '疑似异常点:',
        ..._residualAlerts.map((item) => item.label),
      ],
      '',
      '数据:',
      _dataController.text.trim(),
    ].join('\n');
  }

  FitRecommendation? get _bestRecommendation {
    for (final recommendation in _recommendations) {
      if (recommendation.available && recommendation.result != null) {
        return recommendation;
      }
    }
    return null;
  }

  String _recommendationLabel(FitRecommendation recommendation) {
    final result = recommendation.result;
    if (result == null) return '${recommendation.model.label}不可用';
    return '${recommendation.model.label}  R² ${formatNumber(result.rSquared, precision: 4)}';
  }

  List<String> _recommendationLines() {
    return _recommendations.take(4).map((recommendation) {
      final result = recommendation.result;
      if (result == null) {
        return '${recommendation.model.label}: ${recommendation.warning ?? '不可用'}';
      }
      return '${recommendation.model.label}: R²=${formatNumber(result.rSquared, precision: 6)}, RMSE=${formatNumber(result.rmse, precision: 6)}';
    }).toList(growable: false);
  }

  String? _predictionCopyText() {
    if (_predictionX == null || _predictionY == null) return null;
    return '预测: x=${formatNumber(_predictionX!, precision: 6)}, y=${formatNumber(_predictionY!, precision: 6)}';
  }

  Future<void> _copyEquation() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.equation));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制方程')));
    }
  }

  Future<void> _copyResidualAlerts() async {
    if (_residualAlerts.isEmpty) return;
    await Clipboard.setData(ClipboardData(
      text: ['疑似异常点:', ..._residualAlerts.map((item) => item.label)].join('\n'),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制异常点')));
    }
  }

  Future<void> _copyPrediction() async {
    final text = _predictionCopyText();
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制预测')));
    }
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _copyText()));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制结果')));
    }
  }

  Future<void> _saveHistory() async {
    // 中文：保存动作防重入，避免快速连点生成重复历史记录。
    // English: Guard save action re-entry to prevent duplicate history rows from rapid taps.
    if (_savingHistory) return;
    _savingHistory = true;
    try {
      final save = await _saveHistoryResult();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(save.message)));
      }
    } finally {
      _savingHistory = false;
    }
  }

  Future<void> _saveNote() async {
    // 中文：笔记写入可能经过 SQLite，快速连点时只保留第一个请求。
    // English: Note writes go through SQLite; rapid repeated taps keep only the first request.
    if (_savingNote) return;
    _savingNote = true;
    try {
      final save = await _saveNoteResult();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(save.message)));
      }
    } finally {
      _savingNote = false;
    }
  }

  Future<ToolSaveResult> _saveHistoryResult() async {
    final result = _result;
    if (result == null) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.history,
        summary: _error ?? '请先得到有效拟合结果',
      );
    }
    try {
      final historyId = await _historyRepository.saveToolResult(
        toolId: widget.tool.id,
        expression: '${result.model.label}拟合: ${_dataController.text.trim()}',
        result: result.summary,
      );
      if (historyId <= 0) {
        return ToolSaveResult.notWritten(ToolSaveTarget.history);
      }
      return ToolSaveResult.savedHistory(historyId);
    } catch (error) {
      return ToolSaveResult.failed(
        target: ToolSaveTarget.history,
        error: error,
      );
    }
  }

  Future<ToolSaveResult> _saveNoteResult() async {
    if (_result == null) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.note,
        summary: _error ?? '请先得到有效拟合结果',
      );
    }
    try {
      final noteId = await _notesRepository.create(
        title: widget.tool.title,
        body: _copyText(),
        description: widget.tool.description,
      );
      if (noteId <= 0) return ToolSaveResult.notWritten(ToolSaveTarget.note);
      return ToolSaveResult.savedNote(noteId);
    } catch (error) {
      return ToolSaveResult.failed(
        target: ToolSaveTarget.note,
        error: error,
      );
    }
  }
}
