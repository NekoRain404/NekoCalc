part of 'data_fit_tool_screen.dart';

extension _DataFitCards on _DataFitToolScreenState {
  Widget _inputCard() {
    final strings = DataFitStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionTitle(strings.dataAndModel)),
                IconButton(
                  tooltip: strings.sampleData,
                  onPressed: _showExampleMenu,
                  icon: const Icon(Icons.dataset_outlined),
                ),
                IconButton(
                  tooltip: strings.clearData,
                  onPressed: _clearData,
                  icon: const Icon(Icons.backspace_outlined),
                ),
                IconButton(
                  tooltip: strings.paste,
                  onPressed: _pasteClipboard,
                  icon: const Icon(Icons.content_paste),
                ),
              ],
            ),
            SegmentedButton<FitModel>(
              segments: [
                for (final model in FitModel.values)
                  ButtonSegment(value: model, label: Text(model.label)),
              ],
              selected: {_model},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _applyModel(value.first),
            ),
            if (_series.length > 1) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _selectedSeriesIndex.clamp(0, _series.length - 1),
                decoration: InputDecoration(
                  labelText: strings.fitSeries,
                  isDense: true,
                ),
                items: [
                  for (var i = 0; i < _series.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(strings.seriesPoints(_series[i].name,
                          _series[i].points.length)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _selectSeriesIndex(value);
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: ValueKey('data-fit-${widget.tool.id}-data'),
              controller: _dataController,
              minLines: 7,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: strings.dataList,
                hintText: strings.dataListHint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            _parseSummary(),
          ],
        ),
      ),
    );
  }

  Widget _parseSummary() {
    final strings = DataFitStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final current = _series[_selectedSeriesIndex];
    final text = _series.isEmpty
        ? (_error ?? strings.notParsedYet)
        : [
            strings.parsedSeries(_series.length),
            strings.points(_series.fold<int>(
                0, (sum, item) => sum + item.points.length)),
            strings.currentSeries(
                current.name, current.points.length),
          ].join(' · ');
    return Row(
      children: [
        Icon(
          _series.isEmpty ? Icons.info_outline : Icons.check_circle_outline,
          size: 17,
          color: _series.isEmpty ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _series.isEmpty ? scheme.error : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _animatedResult(Widget child, String key) {
    final result = _result;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(
            '$key-${_model.name}-$_selectedSeriesIndex-${result?.equation ?? ''}'),
        child: child,
      ),
    );
  }

  Widget _resultCard(FitResult result) {
    final strings = DataFitStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final best = _bestRecommendation;
    final bestLabel = best == null
        ? null
        : best.model == result.model
            ? strings.alreadyBestModel
            : strings.tryRecommended(best.model.label);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softPanel(context: context, highlight: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.fitOf(result.model.label),
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
          if (bestLabel != null) ...[
            const SizedBox(height: 4),
            Text(bestLabel,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 8),
          SelectableText(
            result.equation,
            style: TextStyle(
                color: scheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip('R²', formatNumber(result.rSquared, precision: 6)),
              _metricChip('RMSE', formatNumber(result.rmse, precision: 6)),
              _metricChip(strings.pointCount, result.points.length.toString()),
              if (_series.isNotEmpty)
                _metricChip(strings.seriesLabel, _series[_selectedSeriesIndex].name),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _copyEquation,
                icon: const Icon(Icons.functions, size: 18),
                label: Text(strings.copyEquation),
              ),
              if (_residualAlerts.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _copyResidualAlerts,
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: Text(strings.copyResidual),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _predictionCard(FitResult result) {
    final strings = DataFitStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasPrediction = _predictionX != null && _predictionY != null;
    final predictionText = hasPrediction
        ? strings.predictionReading(
            formatNumber(_predictionX!, precision: 6),
            formatNumber(_predictionY!, precision: 6))
        : (_predictionError ?? strings.predictionHint);
    final isOutsideRange = _predictionX == null
        ? false
        : _predictionX! < result.points.map((p) => p.x).reduce(math.min) ||
            _predictionX! > result.points.map((p) => p.x).reduce(math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionTitle(strings.prediction)),
                if (hasPrediction)
                  TextButton.icon(
                    onPressed: _copyPrediction,
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: Text(strings.copy),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('data-fit-${widget.tool.id}-prediction'),
              controller: _predictionController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: strings.predictX,
                hintText: strings.predictXHint,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _predictionController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: strings.clearPrediction,
                        onPressed: _predictionController.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasPrediction
                    ? scheme.primaryContainer.withValues(alpha: 0.32)
                    : (_predictionError == null
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.34)
                        : scheme.errorContainer.withValues(alpha: 0.24)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasPrediction
                      ? scheme.primary.withValues(alpha: 0.22)
                      : (_predictionError == null
                          ? scheme.outlineVariant
                          : scheme.error.withValues(alpha: 0.24)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasPrediction
                        ? Icons.trending_up
                        : (_predictionError == null
                            ? Icons.touch_app_outlined
                            : Icons.error_outline),
                    size: 18,
                    color: hasPrediction
                        ? scheme.primary
                        : (_predictionError == null
                            ? scheme.onSurfaceVariant
                            : scheme.error),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      predictionText,
                      style: TextStyle(
                        color: _predictionError == null
                            ? scheme.onSurface
                            : scheme.error,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isOutsideRange) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 17, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.extrapolationWarning,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recommendationCard() {
    final strings = DataFitStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final visibleRecommendations = _recommendations.take(4).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionTitle(strings.modelAdvice)),
                if (_bestRecommendation != null)
                  TextButton.icon(
                    onPressed: () => _applyModel(_bestRecommendation!.model),
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: Text(strings.applyBest),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final recommendation in visibleRecommendations)
                  ChoiceChip(
                    selected: recommendation.model == _model,
                    label: Text(_recommendationLabel(recommendation)),
                    onSelected: recommendation.available
                        ? (_) => _applyModel(recommendation.model)
                        : null,
                  ),
              ],
            ),
            if (_diagnostics.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._diagnostics.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.insights_outlined,
                          size: 17, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(line,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, height: 1.35)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_residualAlerts.isNotEmpty) ...[
              const SizedBox(height: 8),
              _residualAlertPanel(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _residualAlertPanel() {
    final strings = DataFitStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_outlined,
                  color: scheme.error, size: 18),
              const SizedBox(width: 8),
              Text(strings.residualAlerts,
                  style: TextStyle(
                      color: scheme.error, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          for (final alert in _residualAlerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                alert.label,
                style: TextStyle(color: scheme.onSurface, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text('$label  $value',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  Widget _chartCard(FitResult result) {
    final strings = DataFitStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(strings.chart),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1.55,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: RepaintBoundary(
                    key: _chartBoundaryKey,
                    child: CustomPaint(
                      painter: FitChartPainter(
                        result: result,
                        series: _series,
                        selectedSeriesIndex: _selectedSeriesIndex,
                        residualAlerts: _residualAlerts,
                        scheme: scheme,
                        legendFitSuffix: strings.legendFitSuffix,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataTableCard(FitResult result) {
    final strings = DataFitStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionTitle(strings.dataTable)),
                Text(
                  strings.seriesRows(result.points.length),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 42,
                    columnSpacing: 18,
                    headingTextStyle: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                    columns: [
                      const DataColumn(label: Text('#')),
                      const DataColumn(label: Text('x')),
                      const DataColumn(label: Text('y')),
                      const DataColumn(label: Text('ŷ')),
                      DataColumn(label: Text(strings.residual)),
                    ],
                    rows: [
                      for (var i = 0; i < result.points.length; i++)
                        _tableRow(result, i, scheme),
                    ],
                  ),
                ),
              ),
            ),
            if (_series.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _series.length; i++)
                    ChoiceChip(
                      selected: i == _selectedSeriesIndex,
                      label: Text(
                          '${_series[i].name} (${_series[i].points.length})'),
                      onSelected: (_) {
                        _selectSeriesIndex(i);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _tableRow(FitResult result, int index, ColorScheme scheme) {
    final point = result.points[index];
    final predicted = result.predictions[index].y;
    final residual = point.y - predicted;
    final isAlert = _residualAlerts.any((item) => item.index == index);
    final residualColor = residual.abs() <= result.rmse && !isAlert
        ? scheme.onSurfaceVariant
        : scheme.error;
    Text cell(String value, {Color? color}) => Text(
          value,
          style: TextStyle(
            color: color ?? scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (isAlert) {
          return scheme.errorContainer.withValues(alpha: 0.24);
        }
        return index.isEven
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.22)
            : null;
      }),
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAlert) ...[
                Icon(Icons.report_problem_outlined,
                    size: 15, color: scheme.error),
                const SizedBox(width: 4),
              ],
              cell('${index + 1}',
                  color: isAlert ? scheme.error : scheme.onSurfaceVariant),
            ],
          ),
        ),
        DataCell(cell(formatNumber(point.x, precision: 6))),
        DataCell(cell(formatNumber(point.y, precision: 6))),
        DataCell(cell(formatNumber(predicted, precision: 6))),
        DataCell(
            cell(formatNumber(residual, precision: 6), color: residualColor)),
      ],
    );
  }
}
