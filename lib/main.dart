import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/platform/qalculate_smoke_test.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NekoCalcApp());
  // 中文：临时诊断，见 qalculate_smoke_test.dart。刻意不 await：启动不能被引擎拖住，
  //       而且这一步只是为了往日志里留一行证据，不影响任何现有行为。
  // English: Temporary diagnostic, see qalculate_smoke_test.dart. Deliberately not awaited —
  //          startup must not be held up by the engine, and this only leaves one line of
  //          evidence in the log without touching any existing behaviour.
  unawaited(runQalculateSmokeTest());
}
