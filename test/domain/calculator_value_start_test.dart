import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/variable_references.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**「这个插入物是不是一个值的开头」这条判据**——`append` 据它决定「前面补 `×`」（隐式乘法）
///       还是「直接接」。
///
///       这一组钉三样东西，三样都不能少：
///
///       1. **判据的每一条分支。** 判据现在是一条语法规则（`名字(` 开头即值），它有三条早退
///          （数字开头、`pi`/`e`、`(` 开头）与最后那条正则。**每一条都单独钉住**，包括**反例**——
///          `pi/2` 不该被 `pi` 那条捞走、`e^` 不该被 `e` 那条捞走、`inf`/`i`/`x`/`y` 都不是值。
///          只测正例的守卫会在「判据放宽到什么都认」时继续绿。
///       2. **旧行为逐字节不变。** 「这是加法，不许改已经工作的键」这句话只有对着**完整的插入物
///          清单**逐条比对才算数，所以下面那张表把每一个能到达 `append` 的 token 都写死了
///          （`ins:` 分支的字面量、面板的常数、变量面板的两个名字、以及 `STAT`/回归/拟合那
///          十格）。**改这条判据的人，先看这张表**：表里任何一行变了，就是一次要解释的行为改变。
///       3. **这一轮修的那一类确实修好了**，而且**是「前缀」不是「整串」**——`mean(5,12)` 这种
///          **完整的**调用必须算作值开头。把判据写成锚在 `(` 上的 `^[A-Za-z_][A-Za-z_0-9]*\($`
///          就会在这里红：那正是被否掉的那个写法。
///
/// English: **the "is this insertion the start of a value?" criterion** — what `append` reads to
///          choose between prefixing a `×` (implicit multiplication) and appending plainly.
///
///          This group pins three things, and none of them is optional:
///
///          1. **Every branch of the criterion.** It is now one syntax rule (`name(` opens a value)
///             with three early returns (leading digit, `pi`/`e`, leading `(`) and the regex at the
///             end. **Each is pinned on its own, counterexamples included** — `pi/2` must not be
///             caught by the `pi` branch, `e^` must not be caught by the `e` branch, and
///             `inf`/`i`/`x`/`y` are not values. A guard that only tests the positive cases stays
///             green on the day the criterion is widened to accept everything.
///          2. **The old behaviour, byte for byte.** "This is an addition; no working key changes"
///             only means something against the **complete list of insertions**, so the table below
///             writes down every token that can reach `append` (the `ins:` literals, the sheet's
///             constants, the variable sheet's two names, and the ten `STAT`/regression/fit cells).
///             **Anyone changing this criterion looks at that table first**: any row moving is a
///             behaviour change that has to be explained.
///          3. **The class this round exists for is really fixed, and the rule is a **prefix**, not
///             the whole string** — a **complete** call such as `mean(5,12)` has to count as a value
///             start. Writing the rule as `^[A-Za-z_][A-Za-z_0-9]*\($` (anchored on the `(`) turns
///             that row red, which is exactly why that spelling was rejected.
void main() {
  /// 中文：`12` 之后接上这个 token，屏幕上应当出现的**整条表达式**。
  ///
  ///       分组：「补 `×`」「直接接」「修好的那一类」——分组本身就是这张表要说的话。
  ///
  /// English: the **whole expression** that must appear on screen after `12` is followed by this
  ///          token. Grouped by "gets a `×`", "plain append", "the class this round fixed" — the
  ///          grouping is itself part of what the table says.
  const getsImplicitProduct = <String, String>{
    // 数字与常数：`^\d` 那条。
    '90': '12×90',
    '180': '12×180',
    '360': '12×360',
    '1.61803398875': '12×1.61803398875',
    '0.69314718056': '12×0.69314718056',
    '2.30258509299': '12×2.30258509299',
    '9.80665': '12×9.80665',
    '299792458': '12×299792458',
    '2^': '12×2^',
    '2*pi': '12×2*pi',
    // `pi`/`e` 那条（**精确匹配**，所以 `pi/2`/`e^` 不在这里，见下面那张表）。
    'pi': '12×pi',
    'e': '12×e',
    // `(` 那条。
    '(2*pi)': '12×(2*pi)',
    // `名字(` 那条——**旧表里就有的那些**（行为与改动前逐字节相同）。
    'sqrt(2)': '12×sqrt(2)',
    'rand()': '12×rand()',
    'sum(x,1,10,x)': '12×sum(x,1,10,x)',
    'product(x,1,5,x)': '12×product(x,1,5,x)',
    'integrate(x^2,0,1,x)': '12×integrate(x^2,0,1,x)',
    'limit(sin(x)/x,0,x)': '12×limit(sin(x)/x,0,x)',
    'log(8,2)': '12×log(8,2)',
    // `名字(` 那条——**旧表漏掉的**（这一轮修好的那一类）。
    'matrix(2,2,1,2,3,4)': '12×matrix(2,2,1,2,3,4)',
    'mean(5,12)': '12×mean(5,12)',
    'median(1,2,3,4)': '12×median(1,2,3,4)',
    'stdev(1,2,3,4)': '12×stdev(1,2,3,4)',
    'var(1,2,3,4)': '12×var(1,2,3,4)',
    'pearson(matrix(2,4,1,2,3,4,5,6,7,8))':
        '12×pearson(matrix(2,4,1,2,3,4,5,6,7,8))',
    'covar(matrix(2,4,1,2,3,4,5,6,7,8))':
        '12×covar(matrix(2,4,1,2,3,4,5,6,7,8))',
    'spearman(matrix(2,4,1,2,3,4,5,6,7,8))':
        '12×spearman(matrix(2,4,1,2,3,4,5,6,7,8))',
    'linearfit(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))':
        '12×linearfit(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))',
    'quadraticfit(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))':
        '12×quadraticfit(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))',
    'cubicfit(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))':
        '12×cubicfit(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))',
  };

  /// 中文：`12` 之后接上这个 token，**一个字符都不加**。
  ///
  ///       每一条都是**反例**，不是凑数：`^2`/`^-1`/`^`/`10^`/`e^` 是幂的后半截（`12×^2` 不是
  ///       表达式）；`pi/2` 证明 `pi` 那条是**精确匹配**（它接上去得到 `12pi/2`，一个 `×` 都没有）；
  ///       `e^` 同理证明 `e` 那条也是精确匹配；`inf`/`i`/`x`/`y` 是常数与变量，它们在两边都是
  ///       隐式乘法，而这两条路都由解析器自己读，`append` 不加任何东西。
  ///
  /// English: after `12`, these tokens add **not one character**. Every row is a **counterexample**
  ///          rather than padding: `^2`/`^-1`/`^`/`10^`/`e^` are the tail half of a power (`12×^2` is
  ///          not an expression); `pi/2` shows the `pi` branch is an **exact** match (it appends to
  ///          give `12pi/2`, with no `×` at all), and `e^` shows the same for `e`; `inf`/`i`/`x`/`y`
  ///          are constants and variables, which both readers treat as implicit products by
  ///          themselves, so `append` adds nothing.
  const appendedPlainly = <String, String>{
    '^2': '12^2',
    '^3': '12^3',
    '^-1': '12^-1',
    '^': '12^',
    '10^': '12×10^', // 数字开头——被第一条捞走，**不是**不补的那一类。
    'e^': '12e^',
    'pi/2': '12pi/2',
    'inf': '12inf',
    'i': '12i',
    'x': '12x',
    'y': '12y',
  };

  test('补 × 的那一类：整张表逐字节', () {
    for (final entry in getsImplicitProduct.entries) {
      final controller = _controller(_FakeDatabase());
      controller.setExpression('12');
      controller.append(entry.key);
      expect(controller.expression, entry.value,
          reason: '12 之后插 ${entry.key}');
      controller.dispose();
    }
  });

  test('不补的那一类：整张表逐字节', () {
    for (final entry in appendedPlainly.entries) {
      final controller = _controller(_FakeDatabase());
      controller.setExpression('12');
      controller.append(entry.key);
      expect(controller.expression, entry.value,
          reason: '12 之后插 ${entry.key}');
      controller.dispose();
    }
  });

  test('空表达式上插什么都不加 ×（三条早退与第一条正则都到不了）', () {
    for (final token in <String>[
      ...getsImplicitProduct.keys,
      ...appendedPlainly.keys,
    ]) {
      final controller = _controller(_FakeDatabase());
      controller.append(token);
      expect(controller.expression, token, reason: '空输入上插 $token');
      controller.dispose();
    }
  });

  test('今天到达 append 的 token 里，没有一个是光秃秃的 `name(`', () {
    // 中文：**这一条是「锚必须去掉」那个论证的前提**，所以它自己也得有守卫。`_startsValue` 的注释
    //       里写着「锚死之后它只认光秃秃的 `name(`，而今天没有一个 token 长成那样」——如果哪天有人
    //       加了一颗插 `name(` 的键，那句话就不成立了，这里会先红。
    //       `rand()` 是边界：它有括号但**没有实参**，也一样不匹配。
    // English: **this is the premise of the "the anchor has to go" argument**, so it gets a guard of
    //          its own. `_startsValue`'s note says "anchored, it accepts only a bare `name(`, and not
    //          one token today is shaped like that" — if someone later adds a key inserting `name(`,
    //          that sentence stops being true and this goes red first. `rand()` is the boundary case:
    //          it has brackets but **no arguments**, and fails to match just the same.
    const anchoredSpelling = r'^[A-Za-z_][A-Za-z_0-9]*\($';
    final tokens = <String>[
      ...getsImplicitProduct.keys,
      ...appendedPlainly.keys,
      'rand()',
      'mean(5,12)',
      'linearfit(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))',
    ];
    for (final token in tokens) {
      expect(RegExp(anchoredSpelling).hasMatch(token), isFalse,
          reason: '$token 长成了光秃秃的 `name(`——那条被否掉的锚定判据会因此复活');
    }
  });

  test('判据认的是前缀，不是整串——完整的调用也算值的开头', () {
    // 中文：这条正是被否掉的那个写法（`^[A-Za-z_][A-Za-z_0-9]*\($`）会红的地方：那种写法只认
    //       光秃秃的 `name(`。
    // English: this is the row the rejected spelling (`^[A-Za-z_][A-Za-z_0-9]*\($`) fails: it only
    //          accepts a bare `name(`.
    for (final token in <String>[
      'mean(5,12)',
      'sum(x,1,10,x)',
      'linearfit(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))',
    ]) {
      expect(token.endsWith('('), isFalse,
          reason: '$token 不是「以 ( 结尾」，所以锚在 ( 上的判据认不出它');
      final controller = _controller(_FakeDatabase());
      controller.setExpression('12');
      controller.append(token);
      expect(controller.expression, '12×$token');
      controller.dispose();
    }
  });

  test('左边以字母结尾时也补 ×（变量与虚数单位）', () {
    // 中文：这一条不是形状问题。左邻是字母时，不加 `×` 会把两个名字**粘成一个**：翻译层把
    //       `xmean(1,2,3,4)` 读成名字叫 `xmean` 的一次调用，回 **不可翻译**，于是回落旧解析器、
    //       屏幕上报错；`x×mean(1,2,3,4)` 译成 `((x)*(mean(1,2,3,4)))`，算得出。
    // English: this is not about looks. With a letter on the left, omitting the `×` **glues two
    //          names into one**: the translation layer reads `xmean(1,2,3,4)` as a call named
    //          `xmean`, answers **untranslatable**, and the screen ends up on an error from the
    //          legacy parser, while `x×mean(1,2,3,4)` translates to `((x)*(mean(1,2,3,4)))` and
    //          evaluates.
    for (final left in <String>[...kBindableVariableNames, 'i']) {
      final controller = _controller(_FakeDatabase());
      controller.setExpression(left);
      controller.append('mean(5,12)');
      expect(controller.expression, '$left×mean(5,12)');
      controller.dispose();
    }
  });

  test('一元函数那条路（_wrapTrailingValue）不受这条判据影响', () {
    // 中文：`√x`/`sin` 那些键走的是 `applyUnaryFunction`，插的是 `名字(实参)`，**不经过**
    //       `_appendSmart`，所以这条判据碰不到它们。这一条钉住那个「碰不到」：`12` 上按 `√x`
    //       得到的仍然是 `sqrt(12)`——**外面不补 `×`**，因为这里不是并排，是套住。
    // English: the `√x`/`sin` keys travel `applyUnaryFunction`, which inserts `name(argument)` and
    //          **does not pass through** `_appendSmart`, so this criterion cannot reach them. This
    //          pins that "cannot reach": with `12` on screen, `√x` still gives `sqrt(12)` — **no `×`
    //          outside** it, because this is wrapping rather than juxtaposition.
    final controller = _controller(_FakeDatabase());
    controller.setExpression('12');
    controller.applyUnaryFunction('sqrt');
    expect(controller.expression, 'sqrt(12)');
    controller.dispose();
  });

  test('STAT 面板那四格：数据集非空时插的是数据集的数，一样补 ×', () async {
    // 中文：**真机复现的那条**在 HANDOVER 里写的是 `12mean(5,12)`——这一条就是它的自动化版本：
    //       数据集 {5,12}，光标处已有 `12`，按 `mean` 那一格。
    // English: **the device reproduction** HANDOVER records as `12mean(5,12)`, in automated form: a
    //          dataset of {5,12}, `12` already on screen, the `mean` cell tapped.
    final controller = _controller(_FakeDatabase());
    for (final value in <String>['5', '12']) {
      controller.setExpression(value);
      await controller.submit();
      controller.addDatasetValue();
    }
    for (final function in <String>['mean', 'median', 'stdev', 'var']) {
      final cell = _controller(_FakeDatabase());
      for (final value in <String>['5', '12']) {
        cell.setExpression(value);
        await cell.submit();
        cell.addDatasetValue();
      }
      cell.setExpression('12');
      cell.append(cell.statisticsCall(function));
      expect(cell.expression, '12×$function(5,12)');
      cell.dispose();
    }
    controller.dispose();
  });

  test('回归与拟合那六格：插进整条调用，一样补 ×', () async {
    final controller = _controller(_FakeDatabase());
    for (final value in <String>['1', '2', '3', '4', '5', '6', '7', '8']) {
      controller.setExpression(value);
      await controller.submit();
      controller.addDatasetValue();
    }
    for (final function in <String>['pearson', 'covar', 'spearman']) {
      controller.setExpression('12');
      controller.append(controller.regressionCall(function)!);
      expect(controller.expression,
          '12×$function(matrix(2,4,1,2,3,4,5,6,7,8))');
    }
    for (final function in <String>[
      'linearfit',
      'quadraticfit',
      'cubicfit',
    ]) {
      controller.setExpression('12');
      controller.append(controller.fitCall(function)!);
      expect(controller.expression,
          '12×$function(matrix(1,4,1,2,3,4),matrix(1,4,5,6,7,8))');
    }
    controller.dispose();
  });
}

CalculatorController _controller(
  _FakeDatabase db, {
  AppSettings settings = const AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: false,
    autoSaveHistory: false,
    angleMode: 'RAD',
    precision: 6,
    themeModeLabel: '跟随系统',
    expressionDisplayMode: '数学符号',
  ),
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: settings,
  );
}

class _FakeDatabase implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
