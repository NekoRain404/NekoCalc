part of 'data_fit_tool_screen.dart';

extension _DataFitActions on _DataFitToolScreenState {
  Widget _actions() {
    // 中文：复制、保存历史、保存笔记保持同一行，符合工具页统一操作区。
    // English: Copy, save history, and save note share one row to match the common tool action layout.
    final strings = DataFitStrings.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ActionButton(
                icon: Icons.copy_outlined,
                label: strings.copy,
                onTap: _copyResult,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActionButton(
                icon: Icons.save_outlined,
                label: strings.save,
                onTap: _saveHistory,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActionButton(
                icon: Icons.note_add_outlined,
                label: strings.note,
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
                label: Text(strings.exportCsv),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportChartPng,
                icon: const Icon(Icons.image_outlined),
                label: Text(strings.saveChart),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportCsv() async {
    final strings = DataFitStrings.of(context);
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
        SnackBar(
            content: Text(
                saved ? strings.csvExported : strings.csvExportCancelled)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.csvExportFailed('$error'))),
      );
    }
  }

  Future<void> _exportChartPng() async {
    final strings = DataFitStrings.of(context);
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
        SnackBar(
            content: Text(saved ? strings.chartSaved : strings.chartSaveCancelled)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.chartSaveFailed('$error'))),
      );
    }
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    final strings = DataFitStrings.of(context);
    final paste = parseDataFitPasteText(text, copy: strings.fit);
    if (!paste.hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paste.summaryIn(strings.fit))),
      );
      return;
    }
    _applyPastedData(paste);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(paste.summaryIn(strings.fit))),
    );
  }

  Future<void> _showExampleMenu() async {
    final strings = DataFitStrings.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.show_chart_outlined),
              title: Text(strings.sampleMultiColumn),
              subtitle: Text(strings.sampleMultiColumnNote),
              onTap: () => Navigator.pop(context, 'multi'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(strings.sampleHeader),
              subtitle: Text(strings.sampleHeaderNote),
              onTap: () => Navigator.pop(context, 'spreadsheet'),
            ),
            ListTile(
              leading: const Icon(Icons.percent_outlined),
              title: Text(strings.sampleLocalized),
              subtitle: Text(strings.sampleLocalizedNote),
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
    final strings = DataFitStrings.of(context);
    final result = _result;
    if (result == null) return _error ?? strings.noFitResult;
    // 中文：复制内容包含原始数据，便于把拟合结论贴到笔记或外部文档后仍可复核。
    // English: Copied text includes raw data so the fitted result remains auditable in notes or external docs.
    return [
      widget.tool.title,
      if (_series.isNotEmpty)
        strings.copySeries(_series[_selectedSeriesIndex].name),
      result.summaryIn(strings.fit),
      if (_predictionCopyText() != null) ...[
        '',
        _predictionCopyText()!,
      ],
      '',
      strings.copyModelAdvice,
      ..._recommendationLines(),
      '',
      strings.copyDiagnostics,
      ..._diagnostics,
      if (_residualAlerts.isNotEmpty) ...[
        '',
        strings.copyResidualHeading,
        ..._residualAlerts.map((item) => item.labelIn(strings.fit)),
      ],
      '',
      strings.copyData,
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
    final strings = DataFitStrings.of(context);
    final result = recommendation.result;
    if (result == null) {
      return strings
          .modelUnavailable(fitModelLabelIn(strings.fit, recommendation.model));
    }
    return '${fitModelLabelIn(strings.fit, recommendation.model)}'
        '  R² ${formatNumber(result.rSquared, precision: 4)}';
  }

  List<String> _recommendationLines() {
    final strings = DataFitStrings.of(context);
    return _recommendations.take(4).map((recommendation) {
      final result = recommendation.result;
      if (result == null) {
        return '${fitModelLabelIn(strings.fit, recommendation.model)}: '
            '${recommendation.warning ?? strings.unavailable}';
      }
      return '${fitModelLabelIn(strings.fit, recommendation.model)}: '
          'R²=${formatNumber(result.rSquared, precision: 6)}, '
          'RMSE=${formatNumber(result.rmse, precision: 6)}';
    }).toList(growable: false);
  }

  String? _predictionCopyText() {
    if (_predictionX == null || _predictionY == null) return null;
    return DataFitStrings.of(context).copyPrediction(
        formatNumber(_predictionX!, precision: 6),
        formatNumber(_predictionY!, precision: 6));
  }

  Future<void> _copyEquation() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.equation));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DataFitStrings.of(context).equationCopied)));
    }
  }

  Future<void> _copyResidualAlerts() async {
    if (_residualAlerts.isEmpty) return;
    final strings = DataFitStrings.of(context);
    await Clipboard.setData(ClipboardData(
      text: [
        strings.copyResidualHeading,
        ..._residualAlerts.map((item) => item.labelIn(strings.fit)),
      ].join('\n'),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.residualCopied)));
    }
  }

  Future<void> _copyPrediction() async {
    final text = _predictionCopyText();
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DataFitStrings.of(context).predictionCopied)));
    }
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _copyText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DataFitStrings.of(context).resultCopied)));
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
        // 中文：回执在**呈现边缘**翻译（`tool_save_message.dart`）——领域层只给令牌，字在
        //       `ToolsStrings` 里（三屏同源，理由见 `data_fit_tool_screen.dart` 的文件头）。
        //       这里从前印的是 `save.message`。
        // English: the receipt is translated **at the presentation edge**
        //          (`tool_save_message.dart`) — the domain hands over the token and the words live in
        //          `ToolsStrings` (one source for three screens; the reason is at the head of
        //          `data_fit_tool_screen.dart`). This used to print `save.message`.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toolSaveMessage(save, ToolsStrings.of(context)),
            ),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toolSaveMessage(save, ToolsStrings.of(context)),
            ),
          ),
        );
      }
    } finally {
      _savingNote = false;
    }
  }

  Future<ToolSaveResult> _saveHistoryResult() async {
    final strings = DataFitStrings.of(context);
    final result = _result;
    if (result == null) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.history,
        summary: _error ?? strings.needFitFirst,
      );
    }
    try {
      final historyId = await _historyRepository.saveToolResult(
        toolId: widget.tool.id,
        expression: strings.historyExpression(
            fitModelLabelIn(strings.fit, result.model),
            _dataController.text.trim()),
        result: result.summaryIn(strings.fit),
        // 中文：拟合小结是**本地化拼出来的**，形状不是 `标签: 值`，重渲染不了——原样显示。
        // English: the fit summary is **assembled localised** and is not `label: value`, so it cannot
        //          be re-rendered — shown as it stands.
        resultKind: HistoryResultKind.opaque,
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
        summary: _error ?? DataFitStrings.of(context).needFitFirst,
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
