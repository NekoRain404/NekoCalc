import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/tool_capabilities.dart';
import 'data_fit_tool_screen.dart';
import 'text_tool_detail_screen.dart';
import 'tool_detail_screen.dart';

Future<void> openToolDetail({
  required BuildContext context,
  required AppDatabase db,
  required ToolDefinition tool,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) {
        if (tool.id == 'data_fit') {
          return DataFitToolScreen(db: db, tool: tool);
        }
        return tool.usesTextDetail
            ? TextToolDetailScreen(db: db, tool: tool)
            : ToolDetailScreen(db: db, tool: tool);
      },
    ),
  );
}
