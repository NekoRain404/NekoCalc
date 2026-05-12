import 'package:flutter/foundation.dart';

import '../../core/math/expression_parser.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../app_settings.dart';

class CalculatorController extends ChangeNotifier {
  CalculatorController({
    required this.historyRepository,
    required this.notesRepository,
    required this.settingsRepository,
    required AppSettings settings,
  })  : _settings = settings,
        angleMode = settings.angleMode;

  final HistoryRepository historyRepository;
  final NotesRepository notesRepository;
  final SettingsRepository settingsRepository;
  AppSettings _settings;
  String expression = '';
  String result = '0';
  String angleMode;
  int cursorIndex = 0;
  double memoryValue = 0;
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
    final settings = await settingsRepository.load();
    expression = settings['calculator_expression'] ?? '';
    cursorIndex = expression.length;
    result = settings['calculator_result'] ?? '0';
    angleMode = settings['calculator_angle'] ?? _settings.angleMode;
    memoryValue = double.tryParse(settings['calculator_memory'] ?? '') ?? 0;
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
      _replaceAroundCursor(_applyPercent(expressionBeforeCursor));
    } else if (_isOperator(token)) {
      _replaceAroundCursor(_appendOperator(expressionBeforeCursor, token));
    } else if (token == '.') {
      _replaceAroundCursor(_appendDecimal(expressionBeforeCursor));
    } else {
      _insert(token);
    }
    _invalidateSubmitCache();
    evaluate();
    notifyListeners();
  }

  void setExpression(String value) {
    expression = value;
    cursorIndex = expression.length;
    _invalidateSubmitCache();
    evaluate();
    notifyListeners();
  }

  void append(String token) {
    final nextPrefix = _appendSmart(expressionBeforeCursor, token);
    _replaceAroundCursor(nextPrefix);
    _invalidateSubmitCache();
    evaluate();
    notifyListeners();
  }

  void applyUnaryFunction(String name) {
    final nextPrefix = _wrapTrailingValue(expressionBeforeCursor, name);
    _replaceAroundCursor(nextPrefix);
    _invalidateSubmitCache();
    evaluate();
    notifyListeners();
  }

  void applyBinaryFunction(String name) {
    final nextPrefix =
        _wrapTrailingValue(expressionBeforeCursor, name, binary: true);
    _replaceAroundCursor(nextPrefix);
    _invalidateSubmitCache();
    evaluate();
    notifyListeners();
  }

  void backspace() {
    if (expression.isEmpty || cursorIndex == 0) return;
    expression = expression.substring(0, cursorIndex - 1) +
        expression.substring(cursorIndex);
    cursorIndex--;
    _invalidateSubmitCache();
    evaluate();
    notifyListeners();
  }

  void continueWithResult() {
    if (hasError || result == '等待输入' || result == '表达式错误') return;
    expression = result;
    cursorIndex = expression.length;
    _invalidateSubmitCache();
    notifyListeners();
  }

  void clear() {
    expression = '';
    cursorIndex = 0;
    result = '0';
    hasError = false;
    _invalidateSubmitCache();
    notifyListeners();
  }

  void evaluate() {
    if (expression.trim().isEmpty) {
      result = '0';
      hasError = false;
      return;
    }
    try {
      final value =
          ExpressionParser(expression, degreeMode: angleMode == 'DEG').parse();
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
      final value =
          ExpressionParser(expression, degreeMode: angleMode == 'DEG').parse();
      result = formatNumber(value, precision: _settings.precision);
      hasError = false;
      final duplicate =
          _lastSavedExpression == expression && _lastSavedResult == result;
      if (_settings.autoSaveHistory && !duplicate) {
        await historyRepository.saveCalculation(
            expression: expression, result: result);
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
    return notesRepository.create(
        title: '计算结果',
        body: '$expression = $result',
        description: '由计算器保存的表达式结果');
  }

  Future<void> memoryAdd() async {
    memoryValue += _currentNumericValue();
    await _persistState();
    notifyListeners();
  }

  Future<void> memorySubtract() async {
    memoryValue -= _currentNumericValue();
    await _persistState();
    notifyListeners();
  }

  Future<void> memoryRecall() async {
    expression = formatNumber(memoryValue, precision: _settings.precision);
    cursorIndex = expression.length;
    _invalidateSubmitCache();
    evaluate();
    await _persistState();
    notifyListeners();
  }

  Future<void> memoryClear() async {
    memoryValue = 0;
    await _persistState();
    notifyListeners();
  }

  String get reusableResult {
    if (hasError || result == '等待输入' || result == '表达式错误') return '0';
    return result.replaceAll(',', '');
  }

  String get expressionBeforeCursor => expression.substring(0, cursorIndex);

  String get expressionAfterCursor => expression.substring(cursorIndex);

  void moveCursorLeft() {
    if (cursorIndex == 0) return;
    cursorIndex--;
    notifyListeners();
  }

  void moveCursorRight() {
    if (cursorIndex >= expression.length) return;
    cursorIndex++;
    notifyListeners();
  }

  void moveCursorToStart() {
    if (cursorIndex == 0) return;
    cursorIndex = 0;
    notifyListeners();
  }

  void moveCursorToEnd() {
    if (cursorIndex == expression.length) return;
    cursorIndex = expression.length;
    notifyListeners();
  }

  Future<void> _persistState() async {
    if (!_settings.restoreState) return;
    await settingsRepository.setMany({
      'calculator_expression': expression,
      'calculator_result': result,
      'calculator_angle': angleMode,
      'calculator_memory': memoryValue.toString(),
    });
  }

  double _currentNumericValue() {
    try {
      if (expression.trim().isNotEmpty) {
        return ExpressionParser(expression, degreeMode: angleMode == 'DEG')
            .parse();
      }
      return double.tryParse(result.replaceAll(',', '')) ?? 0;
    } catch (_) {
      return double.tryParse(result.replaceAll(',', '')) ?? 0;
    }
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
    cursorIndex = expression.length;
  }

  void _insert(String token) {
    expression = expression.substring(0, cursorIndex) +
        token +
        expression.substring(cursorIndex);
    cursorIndex += token.length;
  }

  void _replaceAroundCursor(String prefix) {
    expression = prefix + expressionAfterCursor;
    cursorIndex = prefix.length;
  }

  bool _isOperator(String token) =>
      token == '+' ||
      token == '-' ||
      token == '×' ||
      token == '÷' ||
      token == '^';

  String _appendOperator(String current, String token) {
    if (current.isEmpty) return token == '-' ? '-' : current;
    if (_isOperator(current[current.length - 1])) {
      return '${current.substring(0, current.length - 1)}$token';
    }
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
    final endsValue = RegExp(r'[0-9A-Za-z)]').hasMatch(last);
    final startsValue = _startsValue(token);
    if (endsValue && startsValue) {
      return '$current×$token';
    }
    return current + token;
  }

  String _wrapTrailingValue(String current, String name,
      {bool binary = false}) {
    final suffix = binary ? ',' : ')';
    if (current.isEmpty || _endsWithOpenInput(current)) return '$current$name(';
    final range = _trailingValueRange(current);
    if (range == null) return '$current$name(';
    final value = current.substring(range.start, range.end);
    return '${current.substring(0, range.start)}$name($value$suffix';
  }

  bool _endsWithOpenInput(String current) {
    final last = current[current.length - 1];
    return _isOperator(last) || last == '(' || last == ',';
  }

  ({int start, int end})? _trailingValueRange(String current) {
    var end = current.length;
    while (end > 0 && current[end - 1].trim().isEmpty) {
      end--;
    }
    if (end == 0) return null;
    final last = current[end - 1];
    if (last == ')') {
      final groupStart = _matchingGroupStart(current, end - 1);
      if (groupStart == null) return null;
      final functionStart = _functionNameStart(current, groupStart);
      return (start: functionStart ?? groupStart, end: end);
    }
    var start = end;
    while (start > 0 && RegExp(r'[A-Za-z0-9.]').hasMatch(current[start - 1])) {
      start--;
    }
    if (start == end) return null;
    return (start: start, end: end);
  }

  int? _matchingGroupStart(String current, int closeIndex) {
    var depth = 0;
    for (var i = closeIndex; i >= 0; i--) {
      if (current[i] == ')') depth++;
      if (current[i] == '(') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  int? _functionNameStart(String current, int openIndex) {
    var start = openIndex;
    while (start > 0 && RegExp(r'[A-Za-z0-9]').hasMatch(current[start - 1])) {
      start--;
    }
    return start == openIndex ? null : start;
  }

  bool _startsValue(String token) {
    if (RegExp(r'^\d').hasMatch(token)) return true;
    if (token == 'pi' || token == 'e') return true;
    if (token.startsWith('(')) return true;
    const functionPrefixes = [
      'sqrt(',
      'cbrt(',
      'sin(',
      'cos(',
      'tan(',
      'asin(',
      'acos(',
      'atan(',
      'sinh(',
      'cosh(',
      'tanh(',
      'cot(',
      'sec(',
      'csc(',
      'log(',
      'log2(',
      'ln(',
      'exp(',
      'abs(',
      'fact(',
      'floor(',
      'ceil(',
      'round(',
      'deg(',
      'rad(',
      'min(',
      'max(',
      'mod(',
      'ncr(',
      'npr(',
      'gcd(',
      'lcm(',
      'root(',
      'atan2(',
    ];
    return functionPrefixes.any(token.startsWith);
  }

  String _applyPercent(String current) {
    if (current.isEmpty) return current;
    final match = RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(current);
    if (match == null) return '($current)/100';
    final value = match.group(1)!;
    return '${current.substring(0, match.start)}($value/100)';
  }
}
