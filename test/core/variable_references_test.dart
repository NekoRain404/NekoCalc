import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/core/math/variable_references.dart';

/// 中文：把变量替换后的文本交给**旧解析器**，看它算出什么。这条路上最危险的错值就是
///       `2x` → `24`，所以下面第一组测试**不只是比字符串，还要比那个数**。
/// English: Hand the resolved text to the **legacy parser** and see what it computes. The wrong value
///          this path can manufacture is `2x` → `24`, so the first group below compares **the number,
///          not only the string**.
double _legacyValue(String source) =>
    ExpressionParser(source, degreeMode: false).parse();

void main() {
  group('变量替换：并置乘法不会变成另一个数', () {
    test('`2x`（x=4）算出来是 8，不是 24', () {
      final resolved = resolveVariableReferences('2x', {'x': '4'});
      expect(_legacyValue(resolved), 8);
      expect(resolved, '2(4)');
    });

    test('括号是强制的——负值也一样', () {
      expect(resolveVariableReferences('2x', {'x': '-4'}), '2(-4)');
      expect(_legacyValue(resolveVariableReferences('2x', {'x': '-4'})), -8);
    });

    test('前缀、后缀、幂、除法四种邻接都成立', () {
      expect(_legacyValue(resolveVariableReferences('x^2', {'x': '4'})), 16);
      expect(_legacyValue(resolveVariableReferences('x!', {'x': '4'})), 24);
      expect(_legacyValue(resolveVariableReferences('-x', {'x': '4'})), -4);
      expect(_legacyValue(resolveVariableReferences('1/x', {'x': '4'})), 0.25);
    });

    test('一处出现多次，每一处都换', () {
      expect(resolveVariableReferences('x+x', {'x': '4'}), '(4)+(4)');
      expect(_legacyValue(resolveVariableReferences('x+x', {'x': '4'})), 8);
    });

    test('`x` 单独一个也换，相邻的 x 与 y 各换各的', () {
      expect(resolveVariableReferences('x', {'x': '4'}), '(4)');
      expect(
        resolveVariableReferences('x+y', {'x': '4', 'y': '5'}),
        '(4)+(5)',
      );
    });

    test('大写拼法经归一化之后是同一个变量', () {
      expect(resolveVariableReferences('2X', {'x': '4'}), '2(4)');
    });
  });

  group('变量替换：只有真的变量才换（判据是语法树，不是正则）', () {
    const values = <String, String>{'x': '4', 'y': '5'};

    test('名字里含 x 的函数名一个字符都不动', () {
      expect(resolveVariableReferences('exp(2)', values), 'exp(2)');
      expect(resolveVariableReferences('max(1,2)', values), 'max(1,2)');
      expect(_legacyValue(resolveVariableReferences('max(1,2)', values)), 2);
    });

    test('`xy`/`x2`/`2x3` 是别的名字，不是 x 加别的东西', () {
      expect(resolveVariableReferences('xy', values), 'xy');
      expect(resolveVariableReferences('x2', values), 'x2');
      expect(resolveVariableReferences('2x3', values), '2x3');
    });

    test('`ans` 不是变量，一个字符都不动', () {
      expect(resolveVariableReferences('2ans', values), '2ans');
    });

    test('单位名不是变量，`5 km to mi` 原样', () {
      expect(resolveVariableReferences('5 km to mi', values), '5 km to mi');
    });

    test('科学计数法赢了变量绑定：`2x10^3` 仍然是 2000', () {
      expect(resolveVariableReferences('2x10^3', values), '2x10^3');
      expect(_legacyValue('2x10^3'), 2000);
    });

    test('没有绑定值（空表）时输入逐字节返回', () {
      const source = '2x+x^2-sin(x)';
      expect(resolveVariableReferences(source, const {}), source);
    });

    test('表里没有的名字（未绑定的变量）原样留着', () {
      expect(resolveVariableReferences('2x+y', {'x': '4'}), '2(4)+y');
      expect(resolveVariableReferences('2y', {'x': '4'}), '2y');
    });

    test('解析不了的输入不换——拿不准就什么都不做', () {
      const broken = '2x+';
      expect(resolveVariableReferences(broken, values), broken);
    });
  });

  group('变量替换：引擎自己绑定变量的调用整段跳过', () {
    const values = <String, String>{'x': '4', 'y': '5'};

    test('键盘插进去的四条微积分调用，绑了 x 之后一字不变', () {
      for (final source in <String>[
        'sum(x,1,10,x)',
        'product(x,1,5,x)',
        'integrate(x^2,0,1,x)',
        'limit(sin(x)/x,0,x)',
      ]) {
        expect(resolveVariableReferences(source, values), source,
            reason: '$source 的 x 是那个调用自己的变量，不是用户的 x');
      }
    });

    test('`diff` 同样在词表里、同样绑定变量，也跳过', () {
      expect(resolveVariableReferences('diff(x^2,x)', values), 'diff(x^2,x)');
    });

    test('调用之外的那个 x 照换——阴影只覆盖调用里面', () {
      expect(
        resolveVariableReferences('x+sum(x,1,10,x)', values),
        '(4)+sum(x,1,10,x)',
      );
    });

    test('别的调用不跳过：`sqrt(x)` 的 x 就是用户的 x', () {
      expect(resolveVariableReferences('sqrt(x)', values), 'sqrt((4))');
      expect(
        _legacyValue(resolveVariableReferences('sqrt(x)', values)),
        2,
      );
    });
  });

  group('变量替换与另外两个消费者看到的是同一份文本', () {
    test('翻译器读得懂替换后的表达式（不是「翻译不了」）', () {
      final resolved = resolveVariableReferences('2x+1', {'x': '4'});
      expect(engineExpressionFor(resolved), isA<TranslatedExpression>());
    });

    test('归一化之后的形态是稳定的：再归一化一次不再变化', () {
      for (final resolved in <String>[
        resolveVariableReferences('2x', {'x': '4'}),
        resolveVariableReferences('x^2', {'x': '4'}),
        resolveVariableReferences('2x+1', {'x': '4'}),
      ]) {
        final once = ExpressionParser.normalizeExpressionInput(resolved);
        expect(ExpressionParser.normalizeExpressionInput(once), once,
            reason: '$resolved 归一化之后不是不动点，两个消费者就可能看出两份输入');
      }
    });
  });
}
