import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_strings.dart';

void main() {
  test('encodes decodes and applies per tool input drafts', () {
    final ohms = toolCatalog.firstWhere((item) => item.id == 'ohms_law');
    final divider =
        toolCatalog.firstWhere((item) => item.id == 'voltage_divider');

    final encoded = ToolDetailController.encodeDraft(
      tool: ohms,
      rawValues: {
        'current': '10 mA',
        'resistance': '4.7kΩ',
        'tol': '1%',
        'unknown': 'ignored',
      },
    );

    expect(
        ToolDetailController.draftSettingKey(ohms.id), 'tool_draft_ohms_law');
    expect(
      ToolDetailController.decodeDraft(tool: divider, raw: encoded),
      isNull,
    );

    final decoded = ToolDetailController.decodeDraft(tool: ohms, raw: encoded);
    expect(decoded, {
      'current': '10 mA',
      'resistance': '4.7kΩ',
      'tol': '1%',
    });
    expect(
        ToolDetailController.decodeDraft(tool: ohms, raw: 'bad json'), isNull);

    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: ohms,
    strings: ToolDetailStrings.toolDetailZh,
    );

    final applied = controller.applyRawInputValues(decoded!);

    expect(applied['current'], '10 mA');
    expect(applied['resistance'], '4.7kΩ');
    expect(applied['tol'], '1%');
    expect(controller.values['current'], closeTo(0.01, 1e-12));
    expect(controller.values['resistance'], closeTo(4700, 1e-9));
    expect(controller.values['tol'], 1);
    expect(controller.primary?.value, '47');
    expect(controller.inputErrors, isEmpty);
  });

  test('component markings drive engineering tool calculations', () {
    final dividerTool =
        toolCatalog.firstWhere((item) => item.id == 'voltage_divider');
    final divider = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: dividerTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    divider.updateValues({
      'vin': '12V',
      'r1': '4k7',
      'r2': '10k',
      'load': '0',
      'tol': '1%',
    });

    expect(divider.values['r1'], closeTo(4.7, 1e-12));
    expect(divider.values['r2'], closeTo(10, 1e-12));
    expect(divider.primary?.value, '8.1633');

    final rcTool = toolCatalog.firstWhere((item) => item.id == 'rc_filter');
    final rc = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: rcTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    rc.updateValues({
      'r': '4k7',
      'c': '104',
      'tol': '5%',
    });

    expect(rc.values['r'], closeTo(4.7, 1e-12));
    expect(rc.values['c'], closeTo(100, 1e-9));
    expect(rc.primary?.label, '截止频率 fc');
    expect(rc.inputErrors, isEmpty);

    // 中文：**`dbm` 工具已并入 `rms_peak`**，这一段跟着换到那个工具上，断言形状逐条保留：
    //       `1W` 按 50Ω dBm 单位解析成 30dBm、主结果是峰值电压、结果里有 50Ω 那一族、没有输入错误。
    // English: **the `dbm` tool is merged into `rms_peak`**, so this block moves to that tool with the
    //          same assertions: `1W` parses to 30 dBm in the 50Ω dBm unit, the primary result is the
    //          peak voltage, the 50Ω family is among the rows, and there are no input errors.
    final rmsTool = toolCatalog.firstWhere((item) => item.id == 'rms_peak');
    final rms = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: rmsTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    // 中文：**`rms_peak` 的 Vrms 有默认值 1，会压过 dBm**，所以先把那一格清空再填 dBm——
    //       这正是用户在这个工具上走 dBm 那一路时要做的动作。
    // English: **`rms_peak`'s Vrms has a default of 1 and would outrank the dBm**, so that cell is
    //          cleared first — exactly what a user does on this tool to take the dBm path.
    rms.updateValues({'vrms': '', 'dbm50': '1W'});

    expect(rms.values['dbm50'], closeTo(30, 1e-12));
    expect(rms.primary?.label, 'Vpeak');
    expect(rms.primary?.value, '10');
    expect(rms.results.map((result) => result.label), contains('50Ω dBm'));
    expect(rms.results.map((result) => result.label), contains('Vpp'));
    expect(rms.inputErrors, isEmpty);
  });

  test('AWG wire gauge drives voltage drop calculations', () {
    final tool =
        toolCatalog.firstWhere((item) => item.id == 'wire_voltage_drop');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'current': '5A',
      'length': '3m',
      'area': 'AWG18',
      'voltage': '12V',
    });

    expect(controller.values['area'], closeTo(0.823, 0.002));
    expect(controller.primary?.label, '压降');
    expect(controller.primary?.value, isNot('0'));
    expect(controller.inputErrors, isEmpty);
  });

  test('conductor wire formats drive voltage drop calculations', () {
    final tool =
        toolCatalog.firstWhere((item) => item.id == 'wire_voltage_drop');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'current': '5A',
      'length': '3m',
      'area': '7/0.2mm',
      'voltage': '12V',
    });

    expect(controller.values['area'], closeTo(0.219911, 1e-6));
    expect(controller.primary?.label, '压降');
    expect(controller.primary?.value, isNot('0'));
    expect(controller.inputErrors, isEmpty);
  });

  test('composite duration input drives time based tool calculations', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'motion');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'speed': '10m/s',
      'time': '2h30m',
    });

    expect(controller.values['speed'], closeTo(10, 1e-12));
    expect(controller.values['time'], closeTo(9000, 1e-9));
    expect(controller.primary?.label, '距离');
    expect(controller.primary?.value, '90000');
    expect(controller.inputErrors, isEmpty);

    controller.updateValue('time', '1:30');
    expect(controller.values['time'], closeTo(90, 1e-12));
    expect(controller.primary?.value, '900');
    expect(controller.inputErrors, isEmpty);
  });

  test('Chinese unit aliases drive real tool calculations', () {
    final motionTool = toolCatalog.firstWhere((item) => item.id == 'motion');
    final motion = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: motionTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    motion.updateValues({
      'speed': '72公里/小时',
      'time': '30秒',
    });

    expect(motion.values['speed'], closeTo(20, 1e-9));
    expect(motion.values['time'], closeTo(30, 1e-12));
    expect(motion.primary?.value, '600');
    expect(motion.inputErrors, isEmpty);

    final forceTool = toolCatalog.firstWhere((item) => item.id == 'force');
    final force = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: forceTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    force.updateValues({
      'mass': '2公斤',
      'acc': '9.8米/秒²',
    });

    expect(force.values['mass'], closeTo(2, 1e-12));
    expect(force.values['acc'], closeTo(9.8, 1e-12));
    expect(force.primary?.value, '19.6');
    expect(force.inputErrors, isEmpty);

    final temperatureTool =
        toolCatalog.firstWhere((item) => item.id == 'temperature');
    final temperature = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: temperatureTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    temperature.updateValue('value', '77华氏度');
    expect(temperature.values['value'], closeTo(25, 1e-12));
    expect(temperature.primary?.value, '25');
    expect(temperature.results.map((result) => result.value), contains('77'));
    expect(
        temperature.results.map((result) => result.value), contains('536.67'));
    expect(temperature.inputErrors, isEmpty);
  });

  test('composite Chinese units drive material and flow calculations', () {
    final materialTool =
        toolCatalog.firstWhere((item) => item.id == 'material_weight');
    final material = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: materialTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    material.updateValues({
      'length': '1米',
      'width': '10厘米',
      'thickness': '10毫米',
      'density': '7850kg/m³',
    });

    expect(material.values['length'], closeTo(1000, 1e-9));
    expect(material.values['width'], closeTo(100, 1e-9));
    expect(material.values['thickness'], closeTo(10, 1e-12));
    expect(material.values['density'], closeTo(7.85, 1e-12));
    expect(material.primary?.label, '重量');
    expect(material.primary?.value, '7.85');
    expect(material.inputErrors, isEmpty);

    final flowTool =
        toolCatalog.firstWhere((item) => item.id == 'flow_velocity');
    final flow = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: flowTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    flow.updateValues({
      'flow': '1.2立方米/小时',
      'diameter': '20毫米',
    });

    expect(flow.values['flow'], closeTo(20, 1e-9));
    expect(flow.values['diameter'], closeTo(20, 1e-12));
    expect(flow.primary?.label, '平均流速');
    expect(flow.inputErrors, isEmpty);

    flow.updateValues({
      'flow': '10 CFM',
      'diameter': '20毫米',
    });

    expect(flow.values['flow'], closeTo(283.16846592, 1e-8));
    expect(flow.inputErrors, isEmpty);
  });

  test('engineering unit aliases drive mechanical calculations', () {
    final pressureTool =
        toolCatalog.firstWhere((item) => item.id == 'pressure_force');
    final pressure = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: pressureTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    pressure.updateValues({
      'pressure': '6公斤力/平方厘米',
      'area': '2平方英寸',
    });

    expect(pressure.values['pressure'], closeTo(0.588399, 1e-6));
    expect(pressure.values['area'], closeTo(12.9032, 1e-4));
    expect(pressure.primary?.label, '作用力');
    expect(pressure.inputErrors, isEmpty);

    final torqueTool =
        toolCatalog.firstWhere((item) => item.id == 'torque_power');
    final torque = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: torqueTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    torque.updateValues({
      'torque': '20lb-ft',
      'rpm': '3000rpm',
    });

    expect(torque.values['torque'], closeTo(27.11635896, 1e-8));
    expect(torque.primary?.label, '功率');
    expect(torque.inputErrors, isEmpty);

    final ldoTool = toolCatalog.firstWhere((item) => item.id == 'ldo_power');
    final ldo = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: ldoTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    ldo.updateValues({
      'vin': '5V',
      'vout': '3.3V',
      'current': '500mA',
      'iq': '5mA',
      'dropout': '0.25V',
      'theta': '60 K/W',
      'ambient': '40℃',
      'maxJunction': '85℃',
    });

    expect(ldo.values['current'], closeTo(500, 1e-9));
    expect(ldo.values['iq'], closeTo(5, 1e-9));
    expect(ldo.values['dropout'], closeTo(0.25, 1e-12));
    expect(ldo.values['theta'], closeTo(60, 1e-12));
    expect(ldo.values['ambient'], closeTo(40, 1e-12));
    expect(ldo.primary?.label, '功耗');
    expect(ldo.primary?.value, '0.875');
    expect(ldo.results.map((result) => result.label), contains('热余量'));
    expect(ldo.results.map((result) => result.label), contains('静态损耗'));
    expect(ldo.insights.join('\n'), contains('热余量为负'));
    expect(ldo.inputErrors, isEmpty);

    final thermalTool =
        toolCatalog.firstWhere((item) => item.id == 'thermal_rise');
    final thermal = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: thermalTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    thermal.updateValues({
      'power': '1.5W',
      'theta': '60 K/W',
      'ambient': '40℃',
      'maxJunction': '85℃',
    });

    expect(thermal.values['power'], closeTo(1.5, 1e-12));
    expect(thermal.values['theta'], closeTo(60, 1e-12));
    expect(thermal.primary?.label, '结温估算');
    expect(thermal.primary?.value, '130');
    expect(thermal.results.map((result) => result.label), contains('热余量'));
    expect(thermal.insights.join('\n'), contains('热余量为负'));
    expect(thermal.inputErrors, isEmpty);

    final beamTool =
        toolCatalog.firstWhere((item) => item.id == 'beam_bending');
    final beam = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: beamTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    beam.updateValues({
      'load': '10kgf',
      'length': '1000mm',
      'elastic': '200000MPa',
      'inertia': '1in⁴',
    });

    expect(beam.values['load'], closeTo(98.0665, 1e-9));
    expect(beam.values['length'], closeTo(1, 1e-12));
    expect(beam.values['elastic'], closeTo(200, 1e-12));
    expect(beam.values['inertia'], closeTo(41.62314256, 1e-8));
    expect(beam.primary?.label, '最大挠度');
    expect(beam.inputErrors, isEmpty);
  });

  test('finance battery and product spec formats drive real calculations', () {
    final batteryTool =
        toolCatalog.firstWhere((item) => item.id == 'battery_life');
    final battery = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: batteryTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    battery.updateValues({
      'capacity': '3Ah',
      'current': '250 milliamps',
      'efficiency': '90%',
    });

    expect(battery.values['capacity'], closeTo(3000, 1e-9));
    expect(battery.values['current'], closeTo(250, 1e-9));
    expect(battery.values['voltage'], closeTo(3.7, 1e-12));
    expect(battery.primary?.label, '续航时间');
    expect(battery.primary?.value, '10.8');
    expect(battery.inputErrors, isEmpty);

    battery.updateValues({
      'capacity': '18.5Wh',
      'current': '2.5W',
      'voltage': '5V',
      'efficiency': '90%',
    });

    expect(battery.values['capacity'], closeTo(3700, 1e-9));
    expect(battery.values['current'], closeTo(500, 1e-9));
    expect(battery.values['voltage'], closeTo(5, 1e-12));
    expect(battery.primary?.label, '续航时间');
    expect(battery.primary?.value, '6.66');
    expect(battery.results.map((result) => result.label), contains('标称能量'));
    expect(battery.results.map((result) => result.label), contains('负载功率'));
    expect(battery.inputErrors, isEmpty);

    final adcTool =
        toolCatalog.firstWhere((item) => item.id == 'adc_resolution');
    final adc = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: adcTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    adc.updateValues({
      'vref': '3.3VDC',
      'bits': '12-bit',
    });

    expect(adc.values['vref'], closeTo(3.3, 1e-12));
    expect(adc.values['bits'], closeTo(12, 1e-12));
    expect(adc.primary?.label, 'LSB');
    expect(adc.inputErrors, isEmpty);

    final discountTool =
        toolCatalog.firstWhere((item) => item.id == 'discount');
    final discount = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: discountTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    discount.updateValues({
      'price': '¥299',
      'discount': '85%',
    });

    expect(discount.values['price'], closeTo(299, 1e-12));
    expect(discount.values['discount'], closeTo(85, 1e-12));
    expect(discount.primary?.label, '到手价');
    expect(discount.primary?.value, '254.15');
    expect(discount.inputErrors, isEmpty);

    final dataTool = toolCatalog.firstWhere((item) => item.id == 'data_size');
    final dataSize = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: dataTool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    dataSize.updateValue('value', '1.5 MiB');
    expect(dataSize.values['value'], closeTo(1572864, 1e-9));
    expect(dataSize.primary?.label, 'B');
    expect(dataSize.results.map((result) => result.value), contains('1.5'));
    expect(dataSize.results.map((result) => result.label), contains('MiB'));
    expect(dataSize.results.map((result) => result.label), contains('GiB'));
    expect(dataSize.results.map((result) => result.label), contains('TiB'));
    expect(dataSize.inputErrors, isEmpty);
  });
}
