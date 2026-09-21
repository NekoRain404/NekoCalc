import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/usecases/data_fit.dart';
import 'number_formatter.dart';

String buildExportFileName({
  required String prefix,
  required String extension,
  DateTime? now,
}) {
  final sanitizedPrefix = prefix
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s*_\s*'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final timestamp = now ?? DateTime.now();
  final stamp = '${timestamp.year.toString().padLeft(4, '0')}'
      '${timestamp.month.toString().padLeft(2, '0')}'
      '${timestamp.day.toString().padLeft(2, '0')}_'
      '${timestamp.hour.toString().padLeft(2, '0')}'
      '${timestamp.minute.toString().padLeft(2, '0')}'
      '${timestamp.second.toString().padLeft(2, '0')}';
  final normalizedExtension =
      extension.startsWith('.') ? extension : '.$extension';
  return '${sanitizedPrefix.isEmpty ? 'nekocalc' : sanitizedPrefix}_$stamp${normalizedExtension.toLowerCase()}';
}

String buildFitCsvExport({
  required String seriesName,
  required FitResult result,
}) {
  final rows = <List<String>>[
    ['series', 'model', 'equation', 'r_squared', 'rmse'],
    [
      seriesName,
      result.model.name,
      result.equation,
      formatNumber(result.rSquared, precision: 12),
      formatNumber(result.rmse, precision: 12),
    ],
    const [],
    ['index', 'x', 'y', 'predicted', 'residual'],
    for (var index = 0; index < result.points.length; index++)
      [
        '${index + 1}',
        formatNumber(result.points[index].x, precision: 12),
        formatNumber(result.points[index].y, precision: 12),
        formatNumber(result.predictions[index].y, precision: 12),
        formatNumber(
          result.points[index].y - result.predictions[index].y,
          precision: 12,
        ),
      ],
  ];
  return '\uFEFF${rows.map((row) => row.map(_csvCell).join(',')).join('\n')}\n';
}

String _csvCell(String value) {
  if (!value.contains(RegExp('[,\\n\\r"]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

Uint8List encodeExportText(String value) =>
    Uint8List.fromList(utf8.encode(value));

Future<Uint8List> captureBoundaryPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 2,
}) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('当前图表尚未完成渲染');
  }
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('无法编码图表图片');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
