import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';

void main() {
  const controller = TextToolController();

  test('color converter accepts shorthand rgba and argb hex', () {
    final shortHex =
        controller.calculate(toolId: 'color_convert', input: '#5bf');
    final rgba = controller.calculate(
        toolId: 'color_convert', input: 'rgba(91, 71, 255, 0.5)');
    final cssRgb = controller.calculate(
        toolId: 'color_convert', input: 'rgb(91 71 255 / 50%)');
    final percentRgb = controller.calculate(
        toolId: 'color_convert', input: 'rgb(100% 0% 50%)');
    final argb =
        controller.calculate(toolId: 'color_convert', input: '#805B47FF');
    final prefixedArgb =
        controller.calculate(toolId: 'color_convert', input: '0xff5b47ff');

    expect(shortHex.primary, 'rgb(85, 187, 255)');
    expect(shortHex.detail, contains('HEX: #55BBFF'));
    expect(shortHex.detail, contains('HSL:'));
    expect(shortHex.insights, contains('输入识别为 3 位 HEX 颜色。'));

    expect(rgba.primary, contains('rgba(91, 71, 255'));
    expect(rgba.detail, contains('ARGB: #805B47FF'));
    expect(rgba.insights.join('\n'), contains('包含透明度'));

    expect(cssRgb.primary, contains('rgba(91, 71, 255'));
    expect(cssRgb.detail, contains('Alpha: 128'));
    expect(cssRgb.insights, contains('输入识别为 RGBA 颜色。'));

    expect(percentRgb.primary, 'rgb(255, 0, 128)');
    expect(percentRgb.detail, contains('HEX: #FF0080'));

    expect(argb.primary, contains('rgba(91, 71, 255'));
    expect(argb.detail, contains('Alpha: 128'));
    expect(argb.insights, contains('输入识别为 ARGB HEX 颜色。'));

    expect(prefixedArgb.primary, 'rgb(91, 71, 255)');
    expect(prefixedArgb.detail, contains('ARGB: #FF5B47FF'));
  });

  test('color converter accepts mobile and labeled color formats', () {
    final flutterColor = controller.calculate(
      toolId: 'color_convert',
      input: 'Color(0x805B47FF)',
    );
    final argbTuple = controller.calculate(
      toolId: 'color_convert',
      input: 'ARGB: 128, 91, 71, 255',
    );
    final labeledRgb = controller.calculate(
      toolId: 'color_convert',
      input: 'r=91 g=71 b=255 a=50%',
    );
    final labeledHex = controller.calculate(
      toolId: 'color_convert',
      input: '色值: 5B47FF',
    );

    expect(flutterColor.primary, contains('rgba(91, 71, 255'));
    expect(flutterColor.detail, contains('ARGB: #805B47FF'));
    expect(flutterColor.insights,
        contains('输入识别为 Flutter/Android Color(0xAARRGGBB) 色值。'));

    expect(argbTuple.primary, contains('rgba(91, 71, 255'));
    expect(argbTuple.detail, contains('Alpha: 128'));
    expect(argbTuple.insights, contains('输入识别为 ARGB 通道列表。'));

    expect(labeledRgb.primary, contains('rgba(91, 71, 255'));
    expect(labeledRgb.detail, contains('Alpha: 128'));
    expect(labeledRgb.insights, contains('输入识别为标签式 RGBA 颜色。'));

    expect(labeledHex.primary, 'rgb(91, 71, 255)');
    expect(labeledHex.detail, contains('HEX: #5B47FF'));
    expect(labeledHex.insights, contains('输入识别为带标签 HEX 色值。'));
  });

  test('color converter accepts hsl hsla and named colors', () {
    final hsl = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(250, 100%, 60%)',
    );
    final hsla = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(250 100% 60% / 50%)',
    );
    final turnHue = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(0.5turn 100% 50%)',
    );
    final radHue = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(3.141592653589793rad 100% 50%)',
    );
    final gradHue = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(200grad 100% 50%)',
    );
    final named = controller.calculate(
      toolId: 'color_convert',
      input: 'rebeccapurple',
    );
    final transparent = controller.calculate(
      toolId: 'color_convert',
      input: 'transparent',
    );
    final dodgerBlue = controller.calculate(
      toolId: 'color_convert',
      input: 'dodgerblue',
    );
    final slateGray = controller.calculate(
      toolId: 'color_convert',
      input: 'slategrey',
    );

    expect(hsl.primary, 'rgb(85, 51, 255)');
    expect(hsl.detail, contains('HEX: #5533FF'));
    expect(hsl.insights, contains('输入识别为 HSL 颜色。'));

    expect(hsla.primary, contains('rgba(85, 51, 255'));
    expect(hsla.detail, contains('Alpha: 128'));
    expect(hsla.insights, contains('输入识别为 HSLA 颜色。'));

    expect(turnHue.primary, 'rgb(0, 255, 255)');
    expect(radHue.primary, 'rgb(0, 255, 255)');
    expect(gradHue.primary, 'rgb(0, 255, 255)');

    expect(named.primary, 'rgb(102, 51, 153)');
    expect(named.detail, contains('HEX: #663399'));
    expect(named.insights, contains('输入识别为 CSS 命名颜色 rebeccapurple。'));

    expect(transparent.primary, contains('rgba(0, 0, 0'));
    expect(transparent.detail, contains('Alpha: 0'));

    expect(dodgerBlue.primary, 'rgb(30, 144, 255)');
    expect(dodgerBlue.detail, contains('HEX: #1E90FF'));
    expect(dodgerBlue.insights, contains('输入识别为 CSS 命名颜色 dodgerblue。'));

    expect(slateGray.primary, 'rgb(112, 128, 144)');
    expect(slateGray.detail, contains('HEX: #708090'));
    expect(slateGray.insights, contains('输入识别为 CSS 命名颜色 slategrey。'));
  });

  test('timestamp converter accepts iso and local date strings', () {
    final iso = controller.calculate(
      toolId: 'timestamp',
      input: '2026-06-08T09:30:00Z',
    );
    final local = controller.calculate(
      toolId: 'timestamp',
      input: '2026/06/08 09:30:00',
    );
    final decimalSeconds = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000.123s',
    );
    final millis = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123ms',
    );
    final chinese = controller.calculate(
      toolId: 'timestamp',
      input: '2026年6月8日 09:30:00',
    );

    expect(iso.primary, contains('2026'));
    expect(iso.detail, contains('秒级时间戳:'));
    expect(iso.detail, contains('ISO UTC:'));
    expect(iso.detail, contains('星期:'));
    expect(iso.detail, contains('年内第'));
    expect(iso.insights, contains('输入识别为日期时间文本。'));

    expect(local.primary, contains('2026-06-08'));
    expect(local.insights, contains('输入识别为本地日期时间。'));

    expect(decimalSeconds.detail, contains('毫秒时间戳: 1700000000123'));
    expect(decimalSeconds.insights, contains('输入识别为带单位的秒级时间戳。'));
    expect(millis.detail, contains('毫秒时间戳: 1700000000123'));
    expect(millis.insights, contains('输入识别为带单位的毫秒时间戳。'));
    expect(chinese.primary, contains('2026-06-08'));
    expect(chinese.insights, contains('输入识别为本地日期时间。'));
  });

  test('timestamp converter accepts pasted labeled and compact variants', () {
    final offset = controller.calculate(
      toolId: 'timestamp',
      input: '2026-06-08 09:30:00 +0800',
    );
    final compactDateTime = controller.calculate(
      toolId: 'timestamp',
      input: '20260608093000',
    );
    final compactDate = controller.calculate(
      toolId: 'timestamp',
      input: '20260608',
    );
    final labeled = controller.calculate(
      toolId: 'timestamp',
      input: 'created_at: 2026年6月8日 09时30分05秒',
    );
    final json = controller.calculate(
      toolId: 'timestamp',
      input: '{"event":"login","timestamp":"1700000000.123s"}',
    );

    expect(offset.detail, contains('ISO UTC: 2026-06-08T01:30:00.000Z'));
    expect(offset.insights, contains('输入识别为日期时间文本。'));

    expect(compactDateTime.primary, contains('2026-06-08'));
    expect(compactDateTime.detail, contains('09:30:00'));
    expect(compactDateTime.insights, contains('输入识别为紧凑本地日期时间。'));

    expect(compactDate.primary, contains('2026-06-08'));
    expect(compactDate.detail, contains('00:00:00'));

    expect(labeled.primary, contains('2026-06-08'));
    expect(labeled.detail, contains('09:30:05'));
    expect(labeled.insights.join('\n'), contains('标签文本'));

    expect(json.detail, contains('毫秒时间戳: 1700000000123'));
    expect(json.insights.join('\n'), contains('JSON 字段'));
  });

  test('timestamp converter accepts rfc and named timezone date strings', () {
    final rfc = controller.calculate(
      toolId: 'timestamp',
      input: 'Mon, 08 Jun 2026 09:30:00 GMT',
    );
    final labeledHeader = controller.calculate(
      toolId: 'timestamp',
      input: 'Date: Mon, 08 Jun 2026 09:30:00 GMT',
    );
    final gmtSuffix = controller.calculate(
      toolId: 'timestamp',
      input: '2026-06-08 09:30:00 GMT',
    );
    final beijingPrefix = controller.calculate(
      toolId: 'timestamp',
      input: '北京时间 2026-06-08 09:30:00',
    );
    final englishMonthOffset = controller.calculate(
      toolId: 'timestamp',
      input: '08 Jun 2026 09:30:00 +0800',
    );

    expect(rfc.detail, contains('ISO UTC: 2026-06-08T09:30:00.000Z'));
    expect(rfc.insights, contains('输入识别为日期时间文本。'));

    expect(labeledHeader.detail, contains('ISO UTC: 2026-06-08T09:30:00.000Z'));
    expect(labeledHeader.insights.join('\n'), contains('标签文本'));

    expect(gmtSuffix.detail, contains('ISO UTC: 2026-06-08T09:30:00.000Z'));

    expect(beijingPrefix.detail, contains('ISO UTC: 2026-06-08T01:30:00.000Z'));

    expect(englishMonthOffset.detail,
        contains('ISO UTC: 2026-06-08T01:30:00.000Z'));
  });

  test('timestamp converter accepts microsecond and nanosecond epochs', () {
    final micro = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123456',
    );
    final nano = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123456789',
    );
    final explicitMicro = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123456us',
    );
    final explicitNano = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123456789ns',
    );

    expect(micro.detail, contains('毫秒时间戳: 1700000000123'));
    expect(micro.insights, contains('输入识别为微秒级时间戳。'));

    expect(nano.detail, contains('毫秒时间戳: 1700000000123'));
    expect(nano.insights, contains('输入识别为纳秒级时间戳。'));

    expect(explicitMicro.detail, contains('毫秒时间戳: 1700000000123'));
    expect(explicitMicro.insights, contains('输入识别为带单位的微秒时间戳。'));

    expect(explicitNano.detail, contains('毫秒时间戳: 1700000000123'));
    expect(explicitNano.insights, contains('输入识别为带单位的纳秒时间戳。'));
  });
}
