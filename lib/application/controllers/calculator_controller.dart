import 'package:flutter/foundation.dart';

import '../../core/math/expression_parser.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/local/app_database.dart';
import '../app_settings.dart';

class CalculatorController extends ChangeNotifier {
  CalculatorController({required this.db, required AppSettings settings})
      : _settings = settings,
        angleMode = settings.angleMode;

  final AppDatabase db;
  AppSettings _settings;
  String expression = '';
  String result = '0';
  String angleMode;
  bool hasError = false;
  String? _lastSavedExpression;
  String? _lastSavedResult;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void updateSettings(AppSettings settings) {
    final angleChangedBySettings = angleMode == _settings.angleMode;
    _settings = settings;
    if (angleChangedBySettings) angleMode = settings.angleMode;
    evaluate();
    notifyListeners();
  }

  Future<void> restoreIfEnabled() async {
    if (!_settings.restoreState) return;
    final settings = await db.settings();
    expression = settings['calculator_expression'] ?? '';
    result = settings['calculator_result'] ?? '0';
    angleMode = settings['calculator_angle'] ?? _settings.angleMode;
    if (expression.isNotEmpty) evaluate();
    if (_disposed) return;
    notifyListeners();
  }

  void setAngleMode(String mode) {
    angleMode = mode;
    evaluate();
    _persistState();
    notifyListeners();
  }

  void input(String token) {
    if (token == 'AC') {
      clear();
      return;
    }
    if (token == '⌫') {
      backspace();
      return;
    }
    if (token == '=') {
      evaluate();
      notifyListeners();
      return;
    }
    if (token == '+/-') {
      _toggleSign();
    } else if (token == '%') {
      expression = _applyPercent(expression);
    } else if (_isOperator(token)) {
      expression = _appendOperator(expression, token);
    } else if (token == '.') {
      expression = _appendDecimal(expression);
    } else {
      expression += token;
    }
    _invalidateSubmitCache();
    evaluate();
    _persistState();
    notifyListeners();
  }

  void setExpression(String value) {
    expression = value;
    _invalidateSubmitCache();
    evaluate();
    _persistState();
    notifyListeners();
  }

  void append(String token) {
    expression = _appendSmart(expression, token);
    _invalidateSubmitCache();
    evaluate();
    _persistState();
    notifyListeners();
  }

  void backspace() {
    if (expression.isEmpty) return;
    expression = expression.substring(0, expression.length - 1);
    _invalidateSubmitCache();
    evaluate();
    _persistState();
    notifyListeners();
  }

  void continueWithResult() {
    if (hasError || result == '等待输入' || result == '表达式错误') return;
    expression = result;
    _invalidateSubmitCache();
    _persistState();
    notifyListeners();
  }

  void clear() {
    expression = '';
    result = '0';
    hasError = false;
    _invalidateSubmitCache();
    _persistState();
    notifyListeners();
  }

  void evaluate() {
    if (expression.trim().isEmpty) {
      result = '0';
      hasError = false;
      return;
    }
    try {
      final value = ExpressionParser(expression, degreeMode: angleMode == 'DEG').parse();
      result = formatNumber(value, precision: _settings.precision);
      hasError = false;
    } catch (_) {
      result = '等待输入';
      hasError = true;
    }
  }

  Future<bool> submit() async {
    if (expression.trim().isEmpty) return false;
    try {
      final value = ExpressionParser(expression, degreeMode: angleMode == 'DEG').parse();
      result = formatNumber(value, precision: _settings.precision);
      hasError = false;
      final duplicate = _lastSavedExpression == expression && _lastSavedResult == result;
      if (_settings.autoSaveHistory && !duplicate) {
        await db.addHistory(expression: expression, result: result);
        _lastSavedExpression = expression;
        _lastSavedResult = result;
      }
      await _persistState();
      notifyListeners();
      return true;
    } catch (_) {
      result = '表达式错误';
      hasError = true;
      notifyListeners();
      return false;
    }
  }

  Future<void> saveToNote() {
    return db.addNote('计算结果', '$expression = $result');
  }

  Future<void> _persistState() async {
    if (!_settings.restoreState) return;
    await db.setSetting('calculator_expression', expression);
    await db.setSetting('calculator_result', result);
    await db.setSetting('calculator_angle', angleMode);
  }

  void _invalidateSubmitCache() {
    _lastSavedExpression = null;
    _lastSavedResult = null;
  }

  void _toggleSign() {
    if (expression.isEmpty) {
      expression = '-';
    } else if (expression.startsWith('-(') && expression.endsWith(')')) {
      expression = expression.substring(2, expression.length - 1);
    } else {
      expression = '-($expression)';
    }
  }

  bool _isOperator(String token) => token == '+' || token == '-' || token == '×' || token == '÷' || token == '^';

  String _appendOperator(String current, String token) {
    if (current.isEmpty) return token == '-' ? '-' : current;
    if (_isOperator(current[current.length - 1])) return '${current.substring(0, current.length - 1)}$token';
    return current + token;
  }

  String _appendDecimal(String current) {
    final match = RegExp(r'(\d*\.?\d*)$').firstMatch(current);
    final tail = match?.group(0) ?? '';
    if (tail.contains('.')) return current;
    if (tail.isEmpty) return '${current}0.';
    return '$current.';
  }

  String _appendSmart(String current, String token) {
    if (current.isEmpty) return token;
    final last = current[current.length - 1];
    final startsValue = RegExp(r'^\d').hasMatch(token) ||
        token == 'pi' ||
        token == 'e' ||
        token.startsWith('sqrt(') ||
        token.startsWith('sin(') ||
        token.startsWith('cos(') ||
        token.startsWith('tan(') ||
        token.startsWith('log(') ||
        token.startsWith('ln(') ||
        token.startsWith('abs(');
    if ((RegExp(r'[0-9)]').hasMatch(last) || last == 'i') && startsValue) return '$current×$token';
    return current + token;
  }

  String _applyPercent(String current) {
    if (current.isEmpty) return current;
    final match = RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(current);
    if (match == null) return '($current)/100';
    final value = match.group(1)!;
    return '${current.substring(0, match.start)}($value/100)';
  }
}
