import 'dart:math' as math;

import '../../core/units/unit_converter.dart';
import '../../core/utils/number_formatter.dart';
import '../entities/tool_definition.dart';

List<ToolResult> calculateTool(ToolDefinition tool, Map<String, double> v) {
  switch (tool.kind) {
    case ToolKind.quadratic:
      final a = v['a'] ?? 0;
      final b = v['b'] ?? 0;
      final c = v['c'] ?? 0;
      if (a == 0) return const [ToolResult('错误', 'a 不能为 0', '', primary: true)];
      final d = b * b - 4 * a * c;
      final xv = -b / (2 * a);
      final yv = a * xv * xv + b * xv + c;
      if (d < 0) {
        return [
          ToolResult('判别式 Δ', formatNumber(d), '', primary: true),
          const ToolResult('实根', '无', ''),
          ToolResult('顶点', '(${formatNumber(xv)}, ${formatNumber(yv)})', ''),
          ToolResult('对称轴', 'x=${formatNumber(xv)}', ''),
        ];
      }
      final root = math.sqrt(d);
      final x1 = (-b + root) / (2 * a);
      final x2 = (-b - root) / (2 * a);
      return [
        ToolResult('解 (x1, x2)', '${formatNumber(x1)}  ${formatNumber(x2)}', '',
            primary: true),
        ToolResult('判别式 Δ', formatNumber(d), ''),
        ToolResult('顶点', '(${formatNumber(xv)}, ${formatNumber(yv)})', ''),
        ToolResult('对称轴', 'x=${formatNumber(xv)}', ''),
      ];
    case ToolKind.linearSystem:
      final a1 = v['a1'] ?? 0, b1 = v['b1'] ?? 0, c1 = v['c1'] ?? 0;
      final a2 = v['a2'] ?? 0, b2 = v['b2'] ?? 0, c2 = v['c2'] ?? 0;
      final d = a1 * b2 - a2 * b1;
      if (d == 0) return const [ToolResult('解', '无唯一解', '', primary: true)];
      final x = (c1 * b2 - c2 * b1) / d;
      final y = (a1 * c2 - a2 * c1) / d;
      return [
        ToolResult('解 (x, y)', '${formatNumber(x)}  ${formatNumber(y)}', '',
            primary: true),
        ToolResult('D', formatNumber(d), ''),
        ToolResult('验证 1', formatNumber(a1 * x + b1 * y), ''),
        ToolResult('验证 2', formatNumber(a2 * x + b2 * y), ''),
      ];
    case ToolKind.percentage:
      final base = v['base'] ?? 0;
      final rate = v['rate'] ?? 0;
      final newValue = v['newValue'] ?? 0;
      final value = base * rate / 100;
      final change = base == 0 ? 0 : (newValue - base) / base * 100;
      return [
        ToolResult('百分比结果', formatNumber(value), '', primary: true),
        ToolResult('增加后', formatNumber(base + value), ''),
        ToolResult('减少后', formatNumber(base - value), ''),
        ToolResult('变化率', formatNumber(change), '%'),
      ];
    case ToolKind.exponentialLog:
      final x = v['x'] ?? 0, y = v['y'] ?? 0;
      return [
        ToolResult('x^y', formatNumber(math.pow(x, y).toDouble()), '',
            primary: true),
        ToolResult('ln(x)', x <= 0 ? '无效' : formatNumber(math.log(x)), ''),
        ToolResult('log10(x)',
            x <= 0 ? '无效' : formatNumber(math.log(x) / math.ln10), ''),
        ToolResult('e^x', formatNumber(math.exp(x)), ''),
      ];
    case ToolKind.linearEquation:
      final a = v['a'] ?? 0;
      final b = v['b'] ?? 0;
      return [
        ToolResult('解 x', a == 0 ? '无唯一解' : formatNumber(-b / a), '',
            primary: true),
        ToolResult('a', formatNumber(a), ''),
        ToolResult('b', formatNumber(b), ''),
      ];
    case ToolKind.proportion:
      final a = v['a'] ?? 0, b = v['b'] ?? 0, c = v['c'] ?? 0;
      return [
        ToolResult('x', a == 0 ? '无效' : formatNumber(b * c / a), '',
            primary: true),
        ToolResult('比例', '$a:$b = $c:x', ''),
      ];
    case ToolKind.combination:
      final n = (v['n'] ?? 0).round();
      final k = (v['k'] ?? 0).round();
      final valid = n >= 0 && k >= 0 && k <= n;
      final c = valid ? _factorial(n) / (_factorial(k) * _factorial(n - k)) : 0;
      final a = valid ? _factorial(n) / _factorial(n - k) : 0;
      return [
        ToolResult('组合 C(n,k)', valid ? formatNumber(c) : '无效', '',
            primary: true),
        ToolResult('排列 A(n,k)', valid ? formatNumber(a) : '无效', ''),
      ];
    case ToolKind.probability:
      final p1 = (v['p1'] ?? 0) / 100, p2 = (v['p2'] ?? 0) / 100;
      final both = p1 * p2;
      final either = p1 + p2 - both;
      return [
        ToolResult('至少一个发生', formatNumber(either * 100), '%', primary: true),
        ToolResult('同时发生', formatNumber(both * 100), '%'),
        ToolResult('都不发生', formatNumber((1 - p1) * (1 - p2) * 100), '%'),
      ];
    case ToolKind.statistics:
      final values = [v['x1'] ?? 0, v['x2'] ?? 0, v['x3'] ?? 0];
      final mean = values.reduce((a, b) => a + b) / values.length;
      final minValue = values.reduce(math.min);
      final maxValue = values.reduce(math.max);
      final variance = values
              .map((item) => math.pow(item - mean, 2))
              .reduce((a, b) => a + b) /
          (values.length - 1);
      return [
        ToolResult('平均值', formatNumber(mean), '', primary: true),
        ToolResult('最小值', formatNumber(minValue), ''),
        ToolResult('最大值', formatNumber(maxValue), ''),
        ToolResult('样本标准差', formatNumber(math.sqrt(variance)), ''),
      ];
    case ToolKind.matrix:
      final a = v['a'] ?? 0, b = v['b'] ?? 0, c = v['c'] ?? 0, d = v['d'] ?? 0;
      final determinant = a * d - b * c;
      final trace = a + d;
      final discriminant = trace * trace - 4 * determinant;
      final inverse = determinant == 0
          ? '不可逆'
          : '[${formatNumber(d / determinant)}, ${formatNumber(-b / determinant)}; ${formatNumber(-c / determinant)}, ${formatNumber(a / determinant)}]';
      return [
        ToolResult('行列式 det', formatNumber(determinant), '', primary: true),
        ToolResult('迹 tr', formatNumber(trace), ''),
        ToolResult('判别项', formatNumber(discriminant), ''),
        ToolResult('逆矩阵', inverse, ''),
      ];
    case ToolKind.complex:
      final a = v['a'] ?? 0, b = v['b'] ?? 0, c = v['c'] ?? 0, d = v['d'] ?? 0;
      return [
        ToolResult(
            'z1 + z2', '${formatNumber(a + c)} ${_signedImag(b + d)}i', '',
            primary: true),
        ToolResult(
            'z1 - z2', '${formatNumber(a - c)} ${_signedImag(b - d)}i', ''),
        ToolResult(
            'z1 × z2',
            '${formatNumber(a * c - b * d)} ${_signedImag(a * d + b * c)}i',
            ''),
        ToolResult('|z1|', formatNumber(math.sqrt(a * a + b * b)), ''),
      ];
    case ToolKind.vector:
      final x1 = v['x1'] ?? 0,
          y1 = v['y1'] ?? 0,
          x2 = v['x2'] ?? 0,
          y2 = v['y2'] ?? 0;
      final dot = x1 * x2 + y1 * y2;
      final cross = x1 * y2 - y1 * x2;
      final len1 = math.sqrt(x1 * x1 + y1 * y1),
          len2 = math.sqrt(x2 * x2 + y2 * y2);
      final cos =
          len1 == 0 || len2 == 0 ? 0 : (dot / (len1 * len2)).clamp(-1.0, 1.0);
      return [
        ToolResult('点积', formatNumber(dot), '', primary: true),
        ToolResult('叉积 z', formatNumber(cross), ''),
        ToolResult('夹角', formatNumber(math.acos(cos) * 180 / math.pi), 'deg'),
        ToolResult(
            '|A| / |B|', '${formatNumber(len1)} / ${formatNumber(len2)}', ''),
      ];
    case ToolKind.triangle:
      final a = v['a'] ?? 0, b = v['b'] ?? 0, c = v['c'] ?? 0;
      final valid = a + b > c && a + c > b && b + c > a;
      if (!valid) return const [ToolResult('三角形', '无效边长', '', primary: true)];
      final s = (a + b + c) / 2;
      final area = math.sqrt(s * (s - a) * (s - b) * (s - c));
      final angleA =
          math.acos(((b * b + c * c - a * a) / (2 * b * c)).clamp(-1.0, 1.0)) *
              180 /
              math.pi;
      final angleB =
          math.acos(((a * a + c * c - b * b) / (2 * a * c)).clamp(-1.0, 1.0)) *
              180 /
              math.pi;
      return [
        ToolResult('面积', formatNumber(area), '', primary: true),
        ToolResult('周长', formatNumber(a + b + c), ''),
        ToolResult(
            '角 A/B/C',
            '${formatNumber(angleA)} / ${formatNumber(angleB)} / ${formatNumber(180 - angleA - angleB)}',
            'deg'),
      ];
    case ToolKind.circle:
      final r = v['r'] ?? 0;
      return [
        ToolResult('面积', formatNumber(math.pi * r * r), '', primary: true),
        ToolResult('周长', formatNumber(2 * math.pi * r), ''),
        ToolResult('直径', formatNumber(2 * r), ''),
      ];
    case ToolKind.scaleRatio:
      final value = v['value'] ?? 0, from = v['from'] ?? 0, to = v['to'] ?? 0;
      final scaled = from == 0 ? 0 : value * to / from;
      return [
        ToolResult('缩放后', formatNumber(scaled), '', primary: true),
        ToolResult('缩放比例', from == 0 ? '0' : formatNumber(to / from), 'x'),
        ToolResult(
            '面积比例',
            from == 0 ? '0' : formatNumber(math.pow(to / from, 2).toDouble()),
            'x'),
      ];
    case ToolKind.ohmsLaw:
      final i = v['current'] ?? 0;
      final r = v['resistance'] ?? 0;
      final tol = ((v['tol'] ?? 0).abs()) / 100;
      final voltage = i * r;
      return [
        ToolResult('电压 V', formatNumber(voltage), 'V', primary: true),
        ToolResult('功率 P', formatNumber(voltage * i), 'W'),
        ToolResult('电流', formatNumber(i * 1000), 'mA'),
        ToolResult(
            '电压范围', _range(voltage * (1 - tol), voltage * (1 + tol)), 'V'),
        ToolResult('功率范围',
            _range(voltage * i * (1 - tol), voltage * i * (1 + tol)), 'W'),
      ];
    case ToolKind.voltageDivider:
      final vin = v['vin'] ?? 0;
      final r1 = (v['r1'] ?? 0) * 1000;
      final r2 = (v['r2'] ?? 0) * 1000;
      final loadK = v['load'] ?? 0;
      final tol = v['tol'] ?? 0;
      final load = loadK <= 0 ? 0 : loadK * 1000;
      final lower = load <= 0 ? r2 : 1 / (1 / r2 + 1 / load);
      final vout = vin * lower / (r1 + lower);
      final current = vin / (r1 + lower);
      return [
        ToolResult('输出电压 Vout', formatNumber(vout, precision: 4), 'V',
            primary: true),
        ToolResult('分压电流', formatNumber(current * 1000), 'mA'),
        ToolResult('总功耗', formatNumber(vin * current * 1000), 'mW'),
        ToolResult(
            '误差范围',
            '${formatNumber(vout * (1 - tol / 100))}~${formatNumber(vout * (1 + tol / 100))}',
            'V'),
      ];
    case ToolKind.rcFilter:
      final r = (v['r'] ?? 0) * 1000;
      final c = (v['c'] ?? 0) * 1e-9;
      final tol = ((v['tol'] ?? 0).abs()) / 100;
      if (r == 0 || c == 0) {
        return const [ToolResult('截止频率', '0', 'Hz', primary: true)];
      }
      final fc = 1 / (2 * math.pi * r * c);
      final low = 1 / (2 * math.pi * r * (1 + tol) * c * (1 + tol));
      final high = 1 /
          (2 *
              math.pi *
              r *
              (1 - tol).clamp(0.0001, 1) *
              c *
              (1 - tol).clamp(0.0001, 1));
      return [
        ToolResult('截止频率 fc', formatNumber(fc), 'Hz', primary: true),
        ToolResult('时间常数 τ', formatNumber(r * c * 1000), 'ms'),
        ToolResult('10fc', formatNumber(fc * 10), 'Hz'),
        ToolResult('fc范围', _range(low, high), 'Hz'),
      ];
    case ToolKind.dbm:
      final dbm = v['dbm'] ?? 0;
      final mw = math.pow(10, dbm / 10).toDouble();
      return [
        ToolResult('功率', formatNumber(mw), 'mW', primary: true),
        ToolResult('瓦特', formatNumber(mw / 1000), 'W'),
        ToolResult('dBW', formatNumber(dbm - 30), 'dBW'),
      ];
    case ToolKind.resistorNetwork:
      final r1 = v['r1'] ?? 0, r2 = v['r2'] ?? 0;
      final tol = ((v['tol'] ?? 0).abs()) / 100;
      final parallel = r1 + r2 == 0 ? 0 : r1 * r2 / (r1 + r2);
      final series = r1 + r2;
      return [
        ToolResult('串联等效', formatNumber(series), 'Ω', primary: true),
        ToolResult('并联等效', formatNumber(parallel), 'Ω'),
        ToolResult('串联范围', _range(series * (1 - tol), series * (1 + tol)), 'Ω'),
        ToolResult(
            '并联范围', _range(parallel * (1 - tol), parallel * (1 + tol)), 'Ω'),
      ];
    case ToolKind.capacitorNetwork:
      final c1 = v['c1'] ?? 0, c2 = v['c2'] ?? 0;
      final tol = ((v['tol'] ?? 0).abs()) / 100;
      final series = c1 + c2 == 0 ? 0 : c1 * c2 / (c1 + c2);
      final parallel = c1 + c2;
      return [
        ToolResult('并联等效', formatNumber(parallel), 'nF', primary: true),
        ToolResult('串联等效', formatNumber(series), 'nF'),
        ToolResult(
            '并联范围', _range(parallel * (1 - tol), parallel * (1 + tol)), 'nF'),
        ToolResult(
            '串联范围', _range(series * (1 - tol), series * (1 + tol)), 'nF'),
      ];
    case ToolKind.inductorNetwork:
      final l1 = v['l1'] ?? 0, l2 = v['l2'] ?? 0;
      final tol = ((v['tol'] ?? 0).abs()) / 100;
      final parallel = l1 + l2 == 0 ? 0 : l1 * l2 / (l1 + l2);
      final series = l1 + l2;
      return [
        ToolResult('串联等效', formatNumber(series), 'mH', primary: true),
        ToolResult('并联等效', formatNumber(parallel), 'mH'),
        ToolResult(
            '串联范围', _range(series * (1 - tol), series * (1 + tol)), 'mH'),
        ToolResult(
            '并联范围', _range(parallel * (1 - tol), parallel * (1 + tol)), 'mH'),
      ];
    case ToolKind.ledResistor:
      final vin = v['vin'] ?? 0,
          vf = v['vf'] ?? 0,
          currentMa = v['current'] ?? 0;
      final vfTol = (v['vfTol'] ?? 0).abs();
      final current = currentMa / 1000;
      final resistance = current == 0 ? 0 : (vin - vf) / current;
      final minR = current == 0 ? 0.0 : (vin - vf - vfTol) / current;
      final maxR = current == 0 ? 0.0 : (vin - vf + vfTol) / current;
      return [
        ToolResult('限流电阻', formatNumber(resistance), 'Ω', primary: true),
        ToolResult(
            '功耗', formatNumber(current * current * resistance * 1000), 'mW'),
        ToolResult('推荐功率',
            current * current * resistance > 0.125 ? '≥ 1/4W' : '≥ 1/8W', ''),
        ToolResult('电阻范围', _range(minR, maxR), 'Ω'),
      ];
    case ToolKind.opAmpGain:
      final rin = v['rin'] ?? 0, rf = v['rf'] ?? 0, vin = v['vin'] ?? 0;
      final ratio = rin == 0 ? 0 : rf / rin;
      return [
        ToolResult('同相增益', formatNumber(1 + ratio), '倍', primary: true),
        ToolResult('反相增益', formatNumber(-ratio), '倍'),
        ToolResult('同相输出', formatNumber(vin * (1 + ratio)), 'V'),
        ToolResult('反相输出', formatNumber(vin * -ratio), 'V'),
      ];
    case ToolKind.adcResolution:
      final vref = v['vref'] ?? 0;
      final bits = (v['bits'] ?? 0).round();
      final codes = math.pow(2, bits).toDouble();
      final lsb = codes <= 1 ? 0 : vref / (codes - 1);
      return [
        ToolResult('LSB', formatNumber(lsb * 1000), 'mV', primary: true),
        ToolResult('量化误差', formatNumber(lsb * 500), 'mV'),
        ToolResult('码数', formatNumber(codes), ''),
      ];
    case ToolKind.rmsPeak:
      final vrms = v['vrms'] ?? 0;
      final vpeak = vrms * math.sqrt2;
      return [
        ToolResult('Vpeak', formatNumber(vpeak), 'V', primary: true),
        ToolResult('Vpp', formatNumber(vpeak * 2), 'V'),
        ToolResult('Vrms', formatNumber(vrms), 'V'),
      ];
    case ToolKind.lcResonance:
      final l = (v['l'] ?? 0) * 1e-6;
      final c = (v['c'] ?? 0) * 1e-9;
      final f = l <= 0 || c <= 0 ? 0 : 1 / (2 * math.pi * math.sqrt(l * c));
      return [
        ToolResult('谐振频率', formatNumber(f), 'Hz', primary: true),
        ToolResult('kHz', formatNumber(f / 1000), 'kHz'),
        ToolResult('周期', f == 0 ? '0' : formatNumber(1 / f * 1000000), 'μs'),
      ];
    case ToolKind.dcdcFeedback:
      final vref = v['vref'] ?? 0,
          rtop = v['rtop'] ?? 0,
          rbottom = v['rbottom'] ?? 0;
      final output = rbottom == 0 ? 0 : vref * (1 + rtop / rbottom);
      return [
        ToolResult('输出电压', formatNumber(output), 'V', primary: true),
        ToolResult('分压比', formatNumber(rbottom == 0 ? 0 : rtop / rbottom), ''),
        ToolResult('反馈电压', formatNumber(vref), 'V'),
      ];
    case ToolKind.ldoPower:
      final vin = v['vin'] ?? 0,
          vout = v['vout'] ?? 0,
          current = (v['current'] ?? 0) / 1000;
      final loss = (vin - vout) * current;
      return [
        ToolResult('功耗', formatNumber(loss), 'W', primary: true),
        ToolResult('效率', vin == 0 ? '0' : formatNumber(vout / vin * 100), '%'),
        ToolResult('输出功率', formatNumber(vout * current), 'W'),
        ToolResult('温升/50℃W', formatNumber(loss * 50), '℃'),
      ];
    case ToolKind.capacitorCharge:
      final vin = v['vin'] ?? 0,
          r = (v['r'] ?? 0) * 1000,
          c = (v['c'] ?? 0) * 1e-6,
          time = v['time'] ?? 0;
      final tau = r * c;
      final vc = tau == 0 ? 0 : vin * (1 - math.exp(-time / tau));
      return [
        ToolResult('电容电压', formatNumber(vc), 'V', primary: true),
        ToolResult('时间常数 τ', formatNumber(tau), 's'),
        ToolResult('约 99% 时间', formatNumber(tau * 5), 's'),
      ];
    case ToolKind.batteryLife:
      final capacity = v['capacity'] ?? 0,
          current = v['current'] ?? 0,
          eta = (v['efficiency'] ?? 100) / 100;
      final hours = current == 0 ? 0 : capacity / current * eta;
      return [
        ToolResult('续航时间', formatNumber(hours), 'h', primary: true),
        ToolResult('天数', formatNumber(hours / 24), 'day'),
        ToolResult('可用容量', formatNumber(capacity * eta), 'mAh'),
      ];
    case ToolKind.pcbCurrent:
      final widthMil = (v['width'] ?? 0) / 0.0254;
      final thicknessMil = (v['copper'] ?? 0) * 1.378;
      final area = widthMil * thicknessMil;
      final rise = v['rise'] ?? 0;
      final current = area <= 0 || rise <= 0
          ? 0
          : 0.048 * math.pow(rise, 0.44) * math.pow(area, 0.725);
      return [
        ToolResult('估算电流', formatNumber(current), 'A', primary: true),
        ToolResult('截面积', formatNumber(area), 'mil²'),
        ToolResult('保守 70%', formatNumber(current * 0.7), 'A'),
      ];
    case ToolKind.wireVoltageDrop:
      final current = v['current'] ?? 0,
          length = v['length'] ?? 0,
          area = v['area'] ?? 0,
          voltage = v['voltage'] ?? 0;
      final resistance = area == 0 ? 0 : 0.0175 * length * 2 / area;
      final drop = current * resistance;
      return [
        ToolResult('压降', formatNumber(drop), 'V', primary: true),
        ToolResult('压降比例',
            voltage == 0 ? '0' : formatNumber(drop / voltage * 100), '%'),
        ToolResult('线阻', formatNumber(resistance), 'Ω'),
        ToolResult('线损', formatNumber(drop * current), 'W'),
      ];
    case ToolKind.timer555:
      final ra = (v['ra'] ?? 0) * 1000,
          rb = (v['rb'] ?? 0) * 1000,
          c = (v['c'] ?? 0) * 1e-6;
      final high = 0.693 * (ra + rb) * c;
      final low = 0.693 * rb * c;
      final period = high + low;
      return [
        ToolResult('频率', period == 0 ? '0' : formatNumber(1 / period), 'Hz',
            primary: true),
        ToolResult('高电平时间', formatNumber(high * 1000), 'ms'),
        ToolResult('低电平时间', formatNumber(low * 1000), 'ms'),
        ToolResult(
            '占空比', period == 0 ? '0' : formatNumber(high / period * 100), '%'),
      ];
    case ToolKind.thermalRise:
      final power = v['power'] ?? 0,
          theta = v['theta'] ?? 0,
          ambient = v['ambient'] ?? 0;
      final rise = power * theta;
      return [
        ToolResult('结温估算', formatNumber(ambient + rise), '℃', primary: true),
        ToolResult('温升', formatNumber(rise), '℃'),
        ToolResult('环境温度', formatNumber(ambient), '℃'),
      ];
    case ToolKind.gearRatio:
      final z1 = v['z1'] ?? 0,
          z2 = v['z2'] ?? 0,
          rpm = v['rpm'] ?? 0,
          torque = v['torque'] ?? 0;
      final eta = (v['efficiency'] ?? 100) / 100;
      if (z1 == 0) return const [ToolResult('传动比', '0', '', primary: true)];
      final ratio = z2 / z1;
      return [
        ToolResult('传动比 i', formatNumber(ratio), '', primary: true),
        ToolResult('输出转速', formatNumber(rpm / ratio), 'rpm'),
        ToolResult('输出扭矩', formatNumber(torque * ratio * eta), 'N·m'),
        const ToolResult('旋转方向', '相反', ''),
      ];
    case ToolKind.torquePower:
      final torque = v['torque'] ?? 0, rpm = v['rpm'] ?? 0;
      final kw = torque * rpm / 9550;
      return [
        ToolResult('功率', formatNumber(kw), 'kW', primary: true),
        ToolResult('马力', formatNumber(kw * 1.34102), 'hp'),
        ToolResult('角速度', formatNumber(rpm * 2 * math.pi / 60), 'rad/s'),
      ];
    case ToolKind.spring:
      final k = v['k'] ?? 0, x = v['x'] ?? 0;
      return [
        ToolResult('弹簧力', formatNumber(k * x), 'N', primary: true),
        ToolResult('储能', formatNumber(0.5 * k * x * x / 1000), 'J'),
        ToolResult('刚度', formatNumber(k * 1000), 'N/m'),
      ];
    case ToolKind.cylinder:
      final pressure = (v['pressure'] ?? 0) * 1e6;
      final bore = (v['bore'] ?? 0) / 1000;
      final rod = (v['rod'] ?? 0) / 1000;
      final area = math.pi * bore * bore / 4;
      final rodArea = math.pi * rod * rod / 4;
      return [
        ToolResult('推出力', formatNumber(pressure * area), 'N', primary: true),
        ToolResult('拉回力', formatNumber(pressure * (area - rodArea)), 'N'),
        ToolResult('有效面积', formatNumber(area * 1e6), 'mm²'),
      ];
    case ToolKind.force:
      final mass = v['mass'] ?? 0, acc = v['acc'] ?? 0;
      return [
        ToolResult('力', formatNumber(mass * acc), 'N', primary: true),
        ToolResult('等效重量', formatNumber(mass * acc / 9.80665), 'kgf'),
      ];
    case ToolKind.pulleyRatio:
      final d1 = v['d1'] ?? 0, d2 = v['d2'] ?? 0, rpm = v['rpm'] ?? 0;
      final ratio = d2 == 0 ? 0 : d1 / d2;
      return [
        ToolResult('输出转速', formatNumber(rpm * ratio), 'rpm', primary: true),
        ToolResult('速度比', formatNumber(ratio), ''),
      ];
    case ToolKind.screwLead:
      final lead = v['lead'] ?? 0, rpm = v['rpm'] ?? 0;
      final mmMin = lead * rpm;
      return [
        ToolResult('线速度', formatNumber(mmMin), 'mm/min', primary: true),
        ToolResult('每秒位移', formatNumber(mmMin / 60), 'mm/s'),
      ];
    case ToolKind.pressureForce:
      final pressure = (v['pressure'] ?? 0) * 1e6;
      final area = (v['area'] ?? 0) * 1e-4;
      return [
        ToolResult('作用力', formatNumber(pressure * area), 'N', primary: true),
        ToolResult('等效重量', formatNumber(pressure * area / 9.80665), 'kgf'),
      ];
    case ToolKind.friction:
      final normal = v['normal'] ?? 0, mu = v['mu'] ?? 0;
      return [
        ToolResult('摩擦力', formatNumber(normal * mu), 'N', primary: true),
        ToolResult('摩擦系数', formatNumber(mu), ''),
      ];
    case ToolKind.inclinedPlane:
      final mass = v['mass'] ?? 0,
          angle = (v['angle'] ?? 0) * math.pi / 180,
          mu = v['mu'] ?? 0;
      final weight = mass * 9.80665;
      final normal = weight * math.cos(angle);
      final parallel = weight * math.sin(angle);
      final friction = mu * normal;
      return [
        ToolResult('沿斜面分力', formatNumber(parallel), 'N', primary: true),
        ToolResult('法向力', formatNumber(normal), 'N'),
        ToolResult('摩擦力', formatNumber(friction), 'N'),
        ToolResult('净下滑力', formatNumber(parallel - friction), 'N'),
      ];
    case ToolKind.beamBending:
      final load = v['load'] ?? 0, length = v['length'] ?? 0;
      final elastic = (v['elastic'] ?? 0) * 1e9;
      final inertia = (v['inertia'] ?? 0) * 1e-8;
      final deflection = elastic == 0 || inertia == 0
          ? 0
          : load * math.pow(length, 3) / (48 * elastic * inertia);
      return [
        ToolResult('最大挠度', formatNumber(deflection * 1000), 'mm',
            primary: true),
        ToolResult('最大弯矩', formatNumber(load * length / 4), 'N·m'),
        ToolResult('刚度 F/δ',
            deflection == 0 ? '0' : formatNumber(load / deflection), 'N/m'),
      ];
    case ToolKind.stressStrain:
      final force = v['force'] ?? 0,
          area = (v['area'] ?? 0) * 1e-6,
          elastic = (v['elastic'] ?? 0) * 1e9;
      final stress = area == 0 ? 0 : force / area;
      final strain = elastic == 0 ? 0 : stress / elastic;
      return [
        ToolResult('应力', formatNumber(stress / 1e6), 'MPa', primary: true),
        ToolResult('应变', formatNumber(strain), ''),
        ToolResult('微应变', formatNumber(strain * 1000000), 'με'),
      ];
    case ToolKind.sectionArea:
      final diameter = v['diameter'] ?? 0,
          outer = v['outer'] ?? 0,
          inner = v['inner'] ?? 0;
      final width = v['width'] ?? 0, height = v['height'] ?? 0;
      return [
        ToolResult(
            '圆截面积', formatNumber(math.pi * diameter * diameter / 4), 'mm²',
            primary: true),
        ToolResult('管截面积',
            formatNumber(math.pi * (outer * outer - inner * inner) / 4), 'mm²'),
        ToolResult('矩形截面积', formatNumber(width * height), 'mm²'),
      ];
    case ToolKind.safetyFactor:
      final strength = v['strength'] ?? 0, stress = v['stress'] ?? 0;
      final factor = stress == 0 ? 0 : strength / stress;
      return [
        ToolResult('安全系数', formatNumber(factor), '', primary: true),
        ToolResult('余量', formatNumber(strength - stress), 'MPa'),
        ToolResult(
            '判断',
            factor >= 2
                ? '较安全'
                : factor >= 1
                    ? '临界'
                    : '失效风险',
            ''),
      ];
    case ToolKind.flowVelocity:
      final flow = (v['flow'] ?? 0) / 1000 / 60;
      final diameter = (v['diameter'] ?? 0) / 1000;
      final area = math.pi * diameter * diameter / 4;
      final speed = area == 0 ? 0 : flow / area;
      return [
        ToolResult('平均流速', formatNumber(speed), 'm/s', primary: true),
        ToolResult('截面积', formatNumber(area * 1000000), 'mm²'),
        ToolResult('流量', formatNumber(flow * 3600), 'm³/h'),
      ];
    case ToolKind.materialWeight:
      final length = v['length'] ?? 0,
          width = v['width'] ?? 0,
          thickness = v['thickness'] ?? 0,
          density = v['density'] ?? 0;
      final volumeCm3 = length * width * thickness / 1000;
      final massKg = volumeCm3 * density / 1000;
      return [
        ToolResult('重量', formatNumber(massKg), 'kg', primary: true),
        ToolResult('体积', formatNumber(volumeCm3), 'cm³'),
        ToolResult('重量', formatNumber(massKg * 2.20462), 'lb'),
      ];
    case ToolKind.loan:
      final principal = (v['amount'] ?? 0) * 10000;
      final monthlyRate = (v['rate'] ?? 0) / 100 / 12;
      final months = ((v['years'] ?? 0) * 12).round();
      if (months == 0) return const [ToolResult('月供', '0', '元', primary: true)];
      final factor = math.pow(1 + monthlyRate, months).toDouble();
      final payment = monthlyRate == 0
          ? principal / months
          : principal * monthlyRate * factor / (factor - 1);
      return [
        ToolResult('每月还款额', formatNumber(payment), '元', primary: true),
        ToolResult('总利息', formatNumber(payment * months - principal), '元'),
        ToolResult('总还款额', formatNumber(payment * months), '元'),
        ToolResult('还款期数', months.toString(), '期'),
      ];
    case ToolKind.annuity:
      final payment = v['payment'] ?? 0,
          rate = (v['rate'] ?? 0) / 100,
          years = v['years'] ?? 0,
          perYear = (v['perYear'] ?? 1).round();
      final n = (years * perYear).round();
      final r = perYear == 0 ? 0 : rate / perYear;
      final fv = r == 0 ? payment * n : payment * (math.pow(1 + r, n) - 1) / r;
      return [
        ToolResult('终值', formatNumber(fv.toDouble()), '元', primary: true),
        ToolResult('累计投入', formatNumber(payment * n), '元'),
        ToolResult('收益', formatNumber(fv - payment * n), '元'),
      ];
    case ToolKind.installment:
      final price = v['price'] ?? 0,
          fee = (v['fee'] ?? 0) / 100,
          months = (v['months'] ?? 0).round();
      final total = price * (1 + fee);
      return [
        ToolResult(
            '每期付款', months == 0 ? '0' : formatNumber(total / months), '元',
            primary: true),
        ToolResult('手续费', formatNumber(price * fee), '元'),
        ToolResult('总支付', formatNumber(total), '元'),
      ];
    case ToolKind.breakEven:
      final fixed = v['fixed'] ?? 0,
          price = v['price'] ?? 0,
          variable = v['variable'] ?? 0;
      final margin = price - variable;
      final quantity = margin <= 0 ? 0 : fixed / margin;
      return [
        ToolResult('平衡销量', formatNumber(quantity), '件', primary: true),
        ToolResult('边际贡献', formatNumber(margin), '元/件'),
        ToolResult(
            '边际率', price == 0 ? '0' : formatNumber(margin / price * 100), '%'),
      ];
    case ToolKind.electricityCost:
      final power = (v['power'] ?? 0) / 1000,
          hours = v['hours'] ?? 0,
          days = v['days'] ?? 0,
          price = v['price'] ?? 0;
      final energy = power * hours * days;
      return [
        ToolResult('费用', formatNumber(energy * price), '元', primary: true),
        ToolResult('用电量', formatNumber(energy), 'kWh'),
        ToolResult('日均费用',
            days == 0 ? '0' : formatNumber(energy * price / days), '元/天'),
      ];
    case ToolKind.compound:
      final principal = v['principal'] ?? 0;
      final rate = (v['rate'] ?? 0) / 100;
      final years = v['years'] ?? 0;
      final fv = principal * math.pow(1 + rate, years);
      return [
        ToolResult('终值', formatNumber(fv.toDouble()), '元', primary: true),
        ToolResult('收益', formatNumber(fv - principal), '元'),
        ToolResult(
            '收益率',
            formatNumber(
                principal == 0 ? 0 : (fv - principal) / principal * 100),
            '%'),
      ];
    case ToolKind.profitMargin:
      final cost = v['cost'] ?? 0, price = v['price'] ?? 0;
      final profit = price - cost;
      return [
        ToolResult('利润', formatNumber(profit), '元', primary: true),
        ToolResult(
            '毛利率', formatNumber(price == 0 ? 0 : profit / price * 100), '%'),
        ToolResult(
            '加价率', formatNumber(cost == 0 ? 0 : profit / cost * 100), '%'),
      ];
    case ToolKind.roi:
      final gain = v['gain'] ?? 0, cost = v['cost'] ?? 0;
      return [
        ToolResult('ROI',
            formatNumber(cost == 0 ? 0 : (gain - cost) / cost * 100), '%',
            primary: true),
        ToolResult('净收益', formatNumber(gain - cost), '元'),
        ToolResult('回报倍数', formatNumber(cost == 0 ? 0 : gain / cost), 'x'),
      ];
    case ToolKind.discount:
      final price = v['price'] ?? 0, discount = v['discount'] ?? 0;
      final finalPrice = price * discount / 100;
      return [
        ToolResult('到手价', formatNumber(finalPrice), '元', primary: true),
        ToolResult('节省', formatNumber(price - finalPrice), '元'),
      ];
    case ToolKind.tax:
      final net = v['net'] ?? 0, rate = (v['rate'] ?? 0) / 100;
      return [
        ToolResult('含税金额', formatNumber(net * (1 + rate)), '元', primary: true),
        ToolResult('税额', formatNumber(net * rate), '元'),
        ToolResult(
            '不含税反推', formatNumber(rate == -1 ? 0 : net / (1 + rate)), '元'),
      ];
    case ToolKind.inflation:
      final amount = v['amount'] ?? 0,
          rate = (v['rate'] ?? 0) / 100,
          years = v['years'] ?? 0;
      final future = amount * math.pow(1 + rate, years);
      return [
        ToolResult('未来等值', formatNumber(future.toDouble()), '元', primary: true),
        ToolResult(
            '购买力折现', formatNumber(amount / math.pow(1 + rate, years)), '元'),
      ];
    case ToolKind.npv:
      final initial = v['initial'] ?? 0, rate = (v['rate'] ?? 0) / 100;
      final cf1 = v['cf1'] ?? 0, cf2 = v['cf2'] ?? 0, cf3 = v['cf3'] ?? 0;
      final npv = cf1 / (1 + rate) +
          cf2 / math.pow(1 + rate, 2) +
          cf3 / math.pow(1 + rate, 3) -
          initial;
      return [
        ToolResult('NPV', formatNumber(npv), '元', primary: true),
        ToolResult('总现金流', formatNumber(cf1 + cf2 + cf3), '元'),
      ];
    case ToolKind.length:
      return _unitResults(v['value'] ?? 0,
          {'m': 1, 'cm': 100, 'mm': 1000, 'in': 39.3701, 'ft': 3.28084});
    case ToolKind.area:
      return _unitResults(v['value'] ?? 0,
          {'m²': 1, 'cm²': 10000, 'mm²': 1000000, 'ft²': 10.7639});
    case ToolKind.volume:
      return _unitResults(
          v['value'] ?? 0, {'m³': 1, 'L': 1000, 'mL': 1000000, 'ft³': 35.3147});
    case ToolKind.mass:
      return _unitResults(
          v['value'] ?? 0, {'kg': 1, 'g': 1000, 'mg': 1000000, 'lb': 2.20462});
    case ToolKind.pressure:
      return _unitResults(v['value'] ?? 0, {
        'Pa': 1,
        'kPa': 0.001,
        'MPa': 0.000001,
        'bar': 0.00001,
        'psi': 0.000145038
      });
    case ToolKind.speed:
      return _unitResults(v['value'] ?? 0,
          {'m/s': 1, 'km/h': 3.6, 'mph': 2.23694, 'ft/s': 3.28084});
    case ToolKind.temperature:
      final c = v['value'] ?? 0;
      return [
        ToolResult('℃', formatNumber(c), '℃', primary: true),
        ToolResult('℉', formatNumber(c * 9 / 5 + 32), '℉'),
        ToolResult('K', formatNumber(c + 273.15), 'K'),
      ];
    case ToolKind.voltage:
      return _unitResults(v['value'] ?? 0,
          {'V': 1, 'mV': 1000, 'kV': 0.001, 'μV': 1000000, 'MV': 0.000001});
    case ToolKind.frequency:
      return _unitResults(v['value'] ?? 0,
          {'Hz': 1, 'kHz': 0.001, 'MHz': 0.000001, 'GHz': 0.000000001});
    case ToolKind.dataSize:
      return _unitResults(v['value'] ?? 0,
          {'B': 1, 'KB': 1 / 1024, 'MB': 1 / 1048576, 'GB': 1 / 1073741824});
    case ToolKind.timeUnit:
      return _unitResults(v['value'] ?? 0,
          {'s': 1, 'min': 1 / 60, 'h': 1 / 3600, 'day': 1 / 86400});
    case ToolKind.accelerationUnit:
      return _unitResults(
          v['value'] ?? 0, {'m/s²': 1, 'g': 1 / 9.80665, 'ft/s²': 3.28084});
    case ToolKind.forceUnit:
      return _unitResults(v['value'] ?? 0,
          {'N': 1, 'kN': 0.001, 'kgf': 1 / 9.80665, 'lbf': 0.224809});
    case ToolKind.powerUnit:
      final watts = v['value'] ?? 0;
      return [
        ToolResult('W', formatNumber(watts), 'W', primary: true),
        ToolResult('kW', formatNumber(watts * 0.001), 'kW'),
        ToolResult('hp', formatNumber(watts * 0.00134102), 'hp'),
        ToolResult(
            'dBm',
            watts <= 0
                ? '无效'
                : formatNumber(10 * math.log(watts * 1000) / math.ln10),
            'dBm'),
      ];
    case ToolKind.energyUnit:
      return _unitResults(v['value'] ?? 0,
          {'J': 1, 'kJ': 0.001, 'Wh': 1 / 3600, 'kWh': 1 / 3600000});
    case ToolKind.angleUnit:
      return _unitResults(
          v['value'] ?? 0, {'deg': 1, 'rad': math.pi / 180, 'turn': 1 / 360});
    case ToolKind.currentUnit:
      return _unitResults(v['value'] ?? 0, {'A': 1, 'mA': 1000, 'μA': 1000000});
    case ToolKind.resistanceUnit:
      return _unitResults(
          v['value'] ?? 0, {'Ω': 1, 'kΩ': 0.001, 'MΩ': 0.000001});
    case ToolKind.capacitanceUnit:
      return _unitResults(v['value'] ?? 0,
          {'F': 1, 'μF': 1000000, 'nF': 1000000000, 'pF': 1000000000000});
    case ToolKind.inductanceUnit:
      return _unitResults(v['value'] ?? 0, {'H': 1, 'mH': 1000, 'μH': 1000000});
    case ToolKind.torqueUnit:
      return _unitResults(v['value'] ?? 0,
          {'N·m': 1, 'kgf·m': 1 / 9.80665, 'lbf·ft': 0.737562});
    case ToolKind.flowUnit:
      return _unitResults(
          v['value'] ?? 0, {'L/min': 1, 'm³/h': 0.06, 'GPM': 0.264172});
    case ToolKind.motion:
      final speed = v['speed'] ?? 0, time = v['time'] ?? 0;
      return [
        ToolResult('距离', formatNumber(speed * time), 'm', primary: true),
        ToolResult('速度', formatNumber(speed * 3.6), 'km/h'),
        ToolResult('时间', formatNumber(time), 's'),
      ];
    case ToolKind.freeFall:
      final height = v['height'] ?? 0, g = v['g'] ?? 9.80665;
      final t = g <= 0 || height < 0 ? 0 : math.sqrt(2 * height / g);
      return [
        ToolResult('落地时间', formatNumber(t), 's', primary: true),
        ToolResult('末速度', formatNumber(g * t), 'm/s'),
        ToolResult('末速度', formatNumber(g * t * 3.6), 'km/h'),
      ];
    case ToolKind.workPower:
      final work = (v['force'] ?? 0) * (v['distance'] ?? 0);
      final time = v['time'] ?? 0;
      return [
        ToolResult('功', formatNumber(work), 'J', primary: true),
        ToolResult('平均功率', time == 0 ? '0' : formatNumber(work / time), 'W'),
        ToolResult('kWh', formatNumber(work / 3600000), 'kWh'),
      ];
    case ToolKind.kineticEnergy:
      final mass = v['mass'] ?? 0,
          speed = v['speed'] ?? 0,
          height = v['height'] ?? 0;
      final ek = 0.5 * mass * speed * speed;
      final ep = mass * 9.80665 * height;
      return [
        ToolResult('总能量', formatNumber(ek + ep), 'J', primary: true),
        ToolResult('动能', formatNumber(ek), 'J'),
        ToolResult('势能', formatNumber(ep), 'J'),
      ];
    case ToolKind.density:
      final mass = v['mass'] ?? 0, volume = v['volume'] ?? 0;
      final density = volume == 0 ? 0 : mass / volume;
      return [
        ToolResult('密度', formatNumber(density), 'kg/m³', primary: true),
        ToolResult('g/cm³', formatNumber(density / 1000), 'g/cm³'),
      ];
    case ToolKind.concentration:
      final mass = v['mass'] ?? 0,
          volume = v['volume'] ?? 0,
          molarMass = v['molarMass'] ?? 0;
      final gl = volume == 0 ? 0 : mass / volume;
      final mol = volume == 0 || molarMass == 0 ? 0 : mass / molarMass / volume;
      return [
        ToolResult('质量浓度', formatNumber(gl), 'g/L', primary: true),
        ToolResult('mg/mL', formatNumber(gl), 'mg/mL'),
        ToolResult('摩尔浓度', formatNumber(mol), 'mol/L'),
      ];
    case ToolKind.idealGas:
      final n = v['n'] ?? 0, temp = v['temp'] ?? 0, volumeL = v['volume'] ?? 0;
      final pressure =
          volumeL == 0 ? 0 : n * 8.314462618 * temp / (volumeL / 1000);
      return [
        ToolResult('压力', formatNumber(pressure / 1000), 'kPa', primary: true),
        ToolResult('压力', formatNumber(pressure / 101325), 'atm'),
      ];
    case ToolKind.heat:
      final q = (v['mass'] ?? 0) * (v['specific'] ?? 0) * (v['delta'] ?? 0);
      return [
        ToolResult('热量', formatNumber(q), 'J', primary: true),
        ToolResult('kJ', formatNumber(q / 1000), 'kJ'),
        ToolResult('Wh', formatNumber(q / 3600), 'Wh'),
      ];
    case ToolKind.wavelength:
      final speed = v['speed'] ?? 0, frequency = v['frequency'] ?? 0;
      final wavelength = frequency == 0 ? 0 : speed / frequency;
      return [
        ToolResult('波长', formatNumber(wavelength), 'm', primary: true),
        ToolResult(
            '周期', frequency == 0 ? '0' : formatNumber(1 / frequency), 's'),
        ToolResult('频率', formatNumber(frequency), 'Hz'),
      ];
    case ToolKind.halfLife:
      final initial = v['initial'] ?? 0,
          half = v['half'] ?? 0,
          time = v['time'] ?? 0;
      final remaining = half <= 0 ? 0 : initial * math.pow(0.5, time / half);
      return [
        ToolResult('剩余量', formatNumber(remaining.toDouble()), '',
            primary: true),
        ToolResult('剩余比例',
            initial == 0 ? '0' : formatNumber(remaining / initial * 100), '%'),
        ToolResult('衰减量', formatNumber(initial - remaining), ''),
      ];
    case ToolKind.ph:
      final h = v['h'] ?? 0;
      final ph = h <= 0 ? double.nan : -math.log(h) / math.ln10;
      return [
        ToolResult('pH', ph.isNaN ? '无效' : formatNumber(ph), '', primary: true),
        ToolResult('pOH', ph.isNaN ? '无效' : formatNumber(14 - ph), ''),
      ];
    case ToolKind.bmi:
      final weight = v['weight'] ?? 0, heightM = (v['height'] ?? 0) / 100;
      final bmi = heightM == 0 ? 0 : weight / (heightM * heightM);
      final label = bmi < 18.5
          ? '偏瘦'
          : bmi < 24
              ? '正常'
              : bmi < 28
                  ? '超重'
                  : '肥胖';
      return [
        ToolResult('BMI', formatNumber(bmi), '', primary: true),
        ToolResult('区间', label, ''),
        ToolResult('正常体重上限', formatNumber(24 * heightM * heightM), 'kg'),
      ];
    case ToolKind.fuelEconomy:
      final distance = v['distance'] ?? 0,
          fuel = v['fuel'] ?? 0,
          price = v['price'] ?? 0;
      final l100 = distance == 0 ? 0 : fuel / distance * 100;
      final cost = fuel * price;
      return [
        ToolResult('百公里油耗', formatNumber(l100), 'L/100km', primary: true),
        ToolResult('总费用', formatNumber(cost), '元'),
        ToolResult('每公里成本', distance == 0 ? '0' : formatNumber(cost / distance),
            '元/km'),
      ];
    case ToolKind.staticOnly:
      return const [ToolResult('文本工具', '请使用文本详情页', '', primary: true)];
  }
}

double _factorial(int n) {
  var result = 1.0;
  for (var i = 2; i <= n; i++) {
    result *= i;
  }
  return result;
}

String _signedImag(double value) {
  final sign = value < 0 ? '-' : '+';
  return '$sign ${formatNumber(value.abs())}';
}

String _range(double a, double b) {
  final low = math.min(a, b);
  final high = math.max(a, b);
  return '${formatNumber(low)} ~ ${formatNumber(high)}';
}

List<ToolResult> _unitResults(double value, Map<String, double> factors) {
  return UnitConverter(factors)
      .convert(value)
      .map((conversion) => ToolResult(
            conversion.unit,
            formatNumber(conversion.value),
            conversion.unit,
            primary: conversion.unit == factors.keys.first,
          ))
      .toList();
}
