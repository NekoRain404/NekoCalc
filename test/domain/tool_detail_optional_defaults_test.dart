import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_strings.dart';

void main() {
  test('optional empty inputs are omitted from numeric tool values', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'statistics');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'x1': '10',
      'x2': '20',
      'x3': '30',
      'x4': '40',
      'x5': '',
    });
    expect(controller.values.keys, contains('x4'));
    expect(controller.values.keys, isNot(contains('x5')));

    controller.updateValue('x4', '');
    expect(controller.values.keys, isNot(contains('x4')));
    expect(controller.inputErrors, isEmpty);

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(valuesByLabel['样本数'], '3');
    expect(valuesByLabel['平均值'], '20');
    expect(controller.inputSummary(), contains('x4: 未填写'));
    expect(controller.inputSummary(), isNot(contains('x4: 0')));
  });

  test('optional defaults can be cleared for reverse solving tools', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'concentration');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    expect(controller.values.keys, contains('volume'));

    controller.updateValues({
      'mass': '5',
      'volume': '',
      'molarMass': '58.44',
      'massConcentration': '10',
      'molarity': '',
    });

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('volume')));
    expect(valuesByLabel['溶液体积 L'], '0.5');
    expect(valuesByLabel['输入来源'], '溶质量+质量浓度');
  });

  test('ideal gas optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'ideal_gas');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'n': '',
      'temp': '273.15',
      'volume': '22.41396954',
      'pressure': '101.325',
    });

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('n')));
    expect(valuesByLabel['物质的量'], startsWith('1'));
    expect(valuesByLabel['输入来源'], '压力+温度+体积');
  });

  test('wavelength optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'wavelength');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'speed': '343',
      'frequency': '',
      'wavelength': '0.343',
    });

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('frequency')));
    expect(valuesByLabel['频率'], '1000');
    expect(valuesByLabel['输入来源'], '波速+波长');
  });

  test('heat optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'heat');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'mass': '1',
      'specific': '4186',
      'delta': '',
      'heat': '41860',
    });

    final valuesByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('delta')));
    expect(valuesByLabel['温度变化'], '10');
    expect(valuesByLabel['输入来源'], '热量+质量+比热容');
  });

  test('half life optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'half_life');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'initial': '100',
      'half': '6',
      'time': '',
      'remaining': '',
      'remainingRatio': '25%',
    });

    final timeByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('time')));
    expect(controller.values['remainingRatio'], 25);
    expect(timeByLabel['经过时间'], '12');
    expect(timeByLabel['输入来源'], '初始量+半衰期+剩余比例');

    controller.updateValues({
      'initial': '100',
      'half': '',
      'time': '12h',
      'remaining': '25',
      'remainingRatio': '',
    });

    final halfByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('half')));
    expect(halfByLabel['半衰期'], '6');
    expect(halfByLabel['输入来源'], '初始量+经过时间+剩余量');
  });

  test('fuel economy optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'fuel_economy');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'distance': '500 km',
      'fuel': '',
      'consumption': '6 L/100km',
      'price': '8元/升',
      'tank': '50L',
      'annualDistance': '',
      'co2': '',
    });

    final fuelByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('fuel')));
    expect(controller.values['consumption'], 6);
    expect(controller.values['price'], 8);
    expect(fuelByLabel['燃油'], '30');
    expect(fuelByLabel['满箱续航'], startsWith('833.333'));
    expect(fuelByLabel['输入来源'], '里程+百公里油耗');

    controller.updateValues({
      'distance': '',
      'fuel': '30L',
      'consumption': '6升/百公里',
      'price': '8',
      'tank': '',
      'annualDistance': '15000km',
      'co2': '2.31kg/L',
    });

    final distanceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('distance')));
    expect(distanceByLabel['里程'], '500');
    expect(distanceByLabel['年燃油费用'], '7200');
    expect(distanceByLabel['CO2每公里'], startsWith('138.6'));
    expect(distanceByLabel['输入来源'], '燃油+百公里油耗');
  });

  test('electricity cost optional defaults can be cleared for reverse solving',
      () {
    final tool =
        toolCatalog.firstWhere((item) => item.id == 'electricity_cost');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'power': '',
      'hours': '3h',
      'days': '30天',
      'price': '0.6元/kWh',
      'targetCost': '43.2元',
    });

    final powerByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('power')));
    expect(powerByLabel['功率'], '800');
    expect(powerByLabel['输入来源'], '目标费用+每日使用+天数+电价');

    controller.updateValues({
      'power': '800W',
      'hours': '3h',
      'days': '30天',
      'price': '',
      'targetCost': '43.2元',
    });

    final priceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('price')));
    expect(priceByLabel['电价'], '0.6');
    expect(priceByLabel['输入来源'], '目标费用+功率+每日使用+天数');
  });

  test('break even optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'break_even');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'fixed': '',
      'price': '120元',
      'variable': '70元',
      'targetQuantity': '1000件',
    });

    final fixedByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('fixed')));
    expect(fixedByLabel['固定成本'], '50000');
    expect(fixedByLabel['输入来源'], '目标销量+单价+单位变动成本');

    controller.updateValues({
      'fixed': '50000元',
      'price': '',
      'variable': '70元',
      'targetQuantity': '1000件',
    });

    final priceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('price')));
    expect(priceByLabel['单价'], '120');
    expect(priceByLabel['输入来源'], '目标销量+固定成本+单位变动成本');
  });

  test('compound optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'compound');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'principal': '',
      'rate': '5%',
      'years': '10年',
      'target': '16288.946267元',
    });

    final principalByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('principal')));
    expect(controller.values['rate'], 5);
    expect(principalByLabel['本金'], startsWith('10000'));
    expect(principalByLabel['输入来源'], '目标终值+年化收益+年限');

    controller.updateValues({
      'principal': '10000元',
      'rate': '',
      'years': '10年',
      'target': '16288.946267元',
    });

    final rateByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('rate')));
    expect(rateByLabel['年化收益率'], startsWith('5'));
    expect(rateByLabel['输入来源'], '本金+目标终值+年限');
  });

  test('roi optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'roi');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'gain': '',
      'cost': '10000元',
      'roi': '25%',
      'years': '2年',
    });

    final gainByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('gain')));
    expect(controller.values['roi'], 25);
    expect(gainByLabel['收益'], '12500');
    expect(gainByLabel['年化ROI'], startsWith('11.803'));
    expect(gainByLabel['输入来源'], '投入+ROI');

    controller.updateValues({
      'gain': '12500元',
      'cost': '',
      'roi': '25%',
      'years': '',
    });

    final costByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('cost')));
    expect(costByLabel['投入'], '10000');
    expect(costByLabel['输入来源'], '收益+ROI');
  });

  test('discount optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'discount');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'price': '299元',
      'discount': '',
      'finalPrice': '254.15元',
    });

    final discountByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('discount')));
    expect(discountByLabel['折扣率'], '85');
    expect(discountByLabel['输入来源'], '原价+到手价');

    controller.updateValues({
      'price': '',
      'discount': '85%',
      'finalPrice': '254.15元',
    });

    final priceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('price')));
    expect(controller.values['discount'], 85);
    expect(priceByLabel['原价'], '299');
    expect(priceByLabel['输入来源'], '折扣+到手价');
  });

  test('tax optional defaults can be cleared for reverse solving', () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'tax');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'net': '',
      'rate': '13%',
      'gross': '1130元',
    });

    final netByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('net')));
    expect(controller.values['rate'], 13);
    expect(netByLabel['不含税反推'], '1000');
    expect(netByLabel['输入来源'], '含税金额+税率');

    controller.updateValues({
      'net': '1000元',
      'rate': '',
      'gross': '1130元',
    });

    final rateByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('rate')));
    expect(rateByLabel['税率'], '13');
    expect(rateByLabel['输入来源'], '税前金额+含税金额');
  });

  // 中文：**这条原来量的是 `inflation` 工具**（`amount` / `future` 那套键）。它并进 `compound` 之后，
  //       同两条反推路径改在合并后的工具上量（键名 `principal` / `target`），并且**多断言了随它搬过来的
  //       两行购买力输出**——所以它不是上面那条 `compound` 用例的重复：那两行只有这里量得到。
  //       反推的判据（可选项清空、另一条分支接手、输入来源那一句）一条没改。
  // English: **this used to measure the `inflation` tool** (`amount` / `future` keys). After the merge the
  //          same two back-solve paths are measured on the merged tool (keys `principal` / `target`) and
  //          **it asserts the two purchasing-power rows that came with it** — so it is not a duplicate of
  //          the `compound` case above: those two rows are measured only here. The back-solve criteria
  //          (clear the optional input, the other branch takes over, the `输入来源` sentence) are unchanged.
  test('compound optional defaults clear for reverse solving with buying power',
      () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'compound');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'principal': '',
      'rate': '3%',
      'years': '10年',
      'target': '13439.163793元',
    });

    final amountByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('principal')));
    expect(controller.values['rate'], 3);
    expect(amountByLabel['本金'], startsWith('10000'));
    expect(amountByLabel['购买力折现'], startsWith('7440.939'));
    expect(amountByLabel['购买力损失'], startsWith('2559.060'));
    expect(amountByLabel['输入来源'], '目标终值+年化收益+年限');

    controller.updateValues({
      'principal': '10000元',
      'rate': '',
      'years': '10年',
      'target': '13439.163793元',
    });

    final rateByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('rate')));
    expect(rateByLabel['年化收益率'], startsWith('3'));
    expect(rateByLabel['输入来源'], '本金+目标终值+年限');
  });

  test('profit margin optional defaults can be cleared for reverse solving',
      () {
    final tool = toolCatalog.firstWhere((item) => item.id == 'profit_margin');
    final controller = ToolDetailController(
      historyRepository: HistoryRepository(AppDatabase.instance),
      notesRepository: NotesRepository(AppDatabase.instance),
      toolUsageRepository: ToolUsageRepository(AppDatabase.instance),
      tool: tool,
    strings: ToolDetailStrings.toolDetailZh,
    );

    controller.updateValues({
      'cost': '80元',
      'price': '',
      'margin': '33.3333333333%',
      'profit': '',
    });

    final priceByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('price')));
    expect(controller.values['margin'], closeTo(33.3333333333, 1e-9));
    expect(priceByLabel['售价'], startsWith('120'));
    expect(priceByLabel['输入来源'], '成本+目标毛利率');

    controller.updateValues({
      'cost': '',
      'price': '120元',
      'margin': '',
      'profit': '40元',
    });

    final costByLabel = {
      for (final result in controller.results) result.label: result.value,
    };
    expect(controller.values.keys, isNot(contains('cost')));
    expect(costByLabel['成本'], '80');
    expect(costByLabel['输入来源'], '售价+目标利润');
  });
}
