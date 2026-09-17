part of 'calculator_controller.dart';

/// 中文：**回归图上取样几个点。**
///
///       这是我定的数，不是从来源抄来的——写下来是为了不让它被当成规格：HiPER 的帮助文本只说
///       「你会看到一条回归函数的图与所有的点」，没有说那条线画多少个点。
///
///       它之所以存在，是**取样要问引擎**（见 [CalculatorController.regressionCurveFor]）：一个点
///       一次调用，所以这个数就是**打开一次图要发几次引擎调用**。24 是量着屏幕定的——一张卡片宽度
///       的图上 24 段折线，三次曲线相邻两点的偏差在亚像素量级，再多看不出区别，而每多一个点就多
///       一发跨语言调用。
///
///       代价明说：一个**卡死**的引擎下，取样是**串行**的（见那里的注释），所以最坏情况是一发
///       超时就收手（`engineTimeout`，5 秒），不是 24 发。
///
/// English: **how many points the regression graph samples.**
///
///          This is my number, not one copied from a source — it is written down so it is not mistaken
///          for a specification: HiPER's help text only says "you will see a graph of regression
///          function and all points" and never says how many points the line has.
///
///          It matters because **sampling asks the engine** (see
///          [CalculatorController.regressionCurveFor]): one call per point, so this number *is* how
///          many engine calls opening the graph costs. 24 was measured against the screen — on a
///          card-wide plot the chord of a cubic over 24 segments is off by less than a pixel, more
///          points look identical, and each extra point is one more cross-language call.
///
///          The price, said plainly: against a **wedged** engine the sampling is **serial** (see the
///          note there), so the worst case is one timeout and it stops (`engineTimeout`, 5 seconds),
///          not 24.
const int kRegressionGraphCurveSamples = 24;

/// 中文：**引擎给回来的一条拟合曲线。**
///
///       它带的三个东西各有用处，不是装饰：
///       - [function]：这条曲线是哪一个拟合（`linearfit`/`quadraticfit`/`cubicfit`）——三个格子
///         可以先后被选，没有它，一张旧图上的曲线说不清是谁的；
///       - [xs]：**我们自己挑的**取样位置（屏幕上那个 x 窗口里等距的 24 个）；
///       - [ys]：**引擎给的**每一个 `xs` 上的值，与 [xs] 一一对应、长度相同。
///
///       **`ys` 里的每一个数都是引擎算的，不是我们插值的**：取样走的是
///       `replace(<那条拟合调用>,x,<数>)`（实测见 [CalculatorController.regressionCurveFor]），
///       所以一条三次拟合的曲线上每一个点都由引擎在**那一条拟合函数**上求值得到。图上两个取样点
///       之间画的是直线——**折线是画法，不是拟合**，两者别混。
///
/// English: **one fitted curve as the engine returned it.**
///
///          Its three parts each earn their place:
///          - [function]: which fit this curve is (`linearfit`/`quadraticfit`/`cubicfit`) — the three
///            cells can be chosen one after another, and without it an old plot's curve cannot say
///            whose it is;
///          - [xs]: the sample positions **we** chose (24 evenly spaced across the on-screen x
///            window);
///          - [ys]: the values **the engine gave** at each `xs`, one for one, same length.
///
///          **Every number in `ys` is the engine's, not an interpolation of ours**: the sampling runs
///          `replace(<that fit call>,x,<number>)` (measured — see
///          [CalculatorController.regressionCurveFor]), so every point of a cubic fit's curve is the
///          engine evaluating **that fitted function**. Between two samples the plot draws a straight
///          line — **the polyline is a drawing, not a fit**, and the two must not be confused.
@immutable
class RegressionCurve {
  RegressionCurve({
    required this.function,
    required List<double> xs,
    required List<double> ys,
  })  : xs = List<double>.unmodifiable(xs),
        ys = List<double>.unmodifiable(ys);

  /// 中文：哪一个拟合给出的这条曲线。
  /// English: which fit produced this curve.
  final String function;

  /// 中文：取样位置（x），从左到右。
  /// English: the sample positions (x), left to right.
  final List<double> xs;

  /// 中文：引擎在每一个 [xs] 上给出的值（y）。长度与 [xs] 相同。
  /// English: the value the engine gave at each [xs] (y). Same length as [xs].
  final List<double> ys;
}

/// 中文：**要一条拟合曲线的两种结果**——画得出来的那一条，或者**画不出来的那一句话**。
///
///       做成一个类型而不是「返回 `null` 再让界面自己编一句」，理由与本仓库另外几处逐字相同
///       （`addDatasetValue` 的返回值、`memoryAdd`、`baseReadout`）：
///       **判定在控制器里、界面在别处**。界面拿到 `null` 就只能写死一句自己的话，而那句话迟早
///       与这里的判定漂开——尤其这一处有**两种**画不出来的原因（对数不够 / 引擎没答），
///       它们要说的话不一样。
///
/// English: **the two outcomes of asking for a fitted curve** — the curve that can be drawn, or
///          **the sentence saying why not**.
///
///          A type rather than "return `null` and let the screen invent a sentence", for byte-for-byte
///          the reason this repository gives elsewhere (`addDatasetValue`'s return value, `memoryAdd`,
///          `baseReadout`): **the judgement is in the controller and the screen is elsewhere**. Given
///          a `null` the screen could only hard-code a sentence of its own, and that sentence would
///          sooner or later drift — especially here, where there are **two** reasons a curve cannot
///          be drawn (too few pairs / the engine did not answer) and they have different sentences.
@immutable
class RegressionCurveOutcome {
  /// 中文：画得出来那一条。除 [curve] 外一切为 null。
  /// English: the one that can be drawn. Everything but [curve] is null.
  const RegressionCurveOutcome.drawn(RegressionCurve this.curve) : refusal = null;

  /// 中文：画不出来，[refusal] 是给用户看的那句话。
  /// English: it cannot be drawn, and [refusal] is the sentence written for the user.
  const RegressionCurveOutcome.refused(String this.refusal) : curve = null;

  /// 中文：引擎给出的曲线；画不出来时为 null。
  /// English: the curve the engine gave; null when it cannot be drawn.
  final RegressionCurve? curve;

  /// 中文：画不出来时对用户说的那句话；画得出来时为 null。
  /// English: what the user is told when it cannot be drawn; null when it can.
  final String? refusal;
}

/// 中文：**回归图那两个读数的一句话**——「一条拟合曲线要几对值」这一半。
///
///       它单独抽出来是因为**两处要用同一句话**：`STAT` 面板拟合那一行的读数
///       （`fitStatusMessage`，后面还接一条「此刻会插哪条调用」）与回归图面板里那一行（**不能**
///       接那条调用——那个面板什么都不插）。写两遍必然漂，而且漂的正是「几对值」这个用户唯一
///       能据以补数据的数字。
///
/// English: **the first half of both readings about fitting** — "how many pairs a fitted curve
///          needs".
///
///          It is factored out because **two places need that one sentence**: the fit row's reading on
///          the `STAT` sheet (`fitStatusMessage`, which appends the call that would be inserted) and
///          the regression graph sheet's row (which must **not** append it — that sheet inserts
///          nothing). Writing it twice would drift, and what would drift is exactly the pair counts
///          the user needs in order to add the data that lights the cell up.
String _fitPairFloorsReading(List<String> values) {
  final floors = kFitMinimumPairs.entries
      .map((entry) => '${entry.key} 要 ${entry.value} 对')
      .join('、');
  if (values.isEmpty) return '拟合把数据集读成两行（前一半 X、后一半 Y）：$floors；数据集是空的';
  if (values.length.isOdd) {
    return '拟合把数据集读成两行（需要偶数个值）：$floors；当前有 ${values.length} 个';
  }
  return '拟合把数据集读成两行：$floors；当前有 ${values.length} 个值';
}

/// 中文：**回归图（HiPER 的「回归图」那条计算细节）在控制器这一侧的那一半**：图上那些点从哪儿
///       来、那条曲线怎么问引擎要。
///
///       ### 它对应来源里的什么
///
///       HiPER 的帮助文本（`help.statistics.contents`，取法见报告）在统计那一章里写着：
///       「**If you press the `<key:MORE>` button on the display, you will see a graph of regression
///       function and all points.**」；那一章的上文说「一组值」是**行矩阵**或**两行矩阵**；
///       而条目本身的上下文键是 `detailGroup.REGRESSION_GRAPH.title`（`= "Graph of regression"`），
///       批注写着 `"2D an 3D graphs" calculation details`——也就是说它在来源里是**一条计算细节**，
///       不是一整页统计编辑器。本机那张真机截图里 `更多…` 正是显示区右上角那颗按钮。
///
///       所以这一半要给的是**两样东西**：所有的数据点，和一条拟合曲线。
///
///       ### 点：只读**两行**那一种读法
///
///       [regressionGraphPoints] 用的是与 `pearson`/`covar`/`spearman`**同一次切分**
///       （`datasetPairCount`：前一半 X、后一半 Y），不是第二种切法。**一行那一种读法画不出图**——
///       一组值没有 y，要画就得给横轴发明一个下标，那是**数据之外的第二个真相源**。
///
///       ### 曲线：引擎算，一个点一发调用
///
///       这条曲线必须来自引擎，理由与那三个拟合格逐字相同（引擎是这个应用里唯一会做最小二乘的
///       东西）。**「从引擎拿到一串 y」只有两条路，两条都量过**（宿主 libqalculate 5.12.0，与
///       `android/app/build.gradle.kts` 里那个 AAR 同版本）：
///
///       1. **把引擎印出来的那条函数拿回来自己求值**——**否掉**。引擎印的是**显示文本**
///          （实测 `linearfit(matrix(1,5,1,2,3,4,5),matrix(1,5,1,4,9,16,25))` 印成 `6x − 7`，
///          而 `quadraticfit` 印成 `x²`——一个真的上标字符），而这个应用有一条standing 规矩：
///          显示文本永不喂给任何数值消费者。把 `x²` 拿旧解析器求值是在赌两套记号的每一个角落
///          都一致，而赌输的样子是一条**看起来完全合理的错曲线**。
///       2. **让引擎自己做代换**：`replace(<那条拟合调用>,x,<数>)`。实测（同上）：
///          ```
///          $ qalc -t 'replace(linearfit(matrix(1,3,1,2,3),matrix(1,3,100,200,300)),x,5)'      => 500
///          $ qalc -t 'replace(quadraticfit(matrix(1,5,1,2,3,4,5),matrix(1,5,1,4,9,16,25)),x,5)' => 25
///          $ qalc -t 'replace(cubicfit(matrix(1,5,1,2,3,4,5),matrix(1,5,1,8,27,64,125)),x,5)'   => 125
///          ```
///          答案是一个**普通十进制数**，于是它过的是全应用那一道数值判据
///          （[MathResult.decimalValueOf]）——**没有第二份判据，也没有一个字被解析**。**这一条是
///          选中的那一条。**
///
///       **为什么一个点一发调用，而不是一发调用拿回整条曲线**（那一版能跑，量过，仍然否掉）：
///       `matrix(1,N,replace(F,x,v1),…,replace(F,x,vN))` 实测给出 `[−500  −450  …]`——**一次往返
///       就拿到 24 个点**（1846 字符的表达式，40 ms）。否掉它的理由是**答案的形状**：一个向量
///       没有十进制形态，`MathResult.decimalValueOf` 对它返回 null（这个应用对「矩阵」那一支的
///       判据就是这样），要把它用起来就得**给一个向量写第二份数值判据**——而那是这个项目花了
///       十几轮在消灭的东西。所以取的是慢而干净的那一条。
///
///       **代换必须是标量，这一条也是量出来的、而且是个新的静默错值形状**：`replace` 做的是
///       **结构代换**，不是逐元素映射。把 x 换成一个**向量**时——
///       ```
///       $ qalc -t 'replace(x^2,x,[1 2 3])'    => [1  2  3]²     ← 矩阵的幂，不是逐元素平方
///       $ qalc -t 'replace(2x,x,[1 2 3])'     => [2  4  6]      ← 乘法碰巧逐元素
///       $ qalc -t 'replace(1/x,x,[1 2 4])'    => 1 / [1  2  4]  ← 不是逐元素倒数
///       ```
///       所以**逐点标量代换不是保守，是唯一正确的那一种**；一次拿整条曲线的那一版之所以仍然
///       要用标量逐点写进同一个 `matrix(...)`，正是因为这个。
///
///       ### 失败一律 fail closed
///
///       四类失败都**不画曲线**、只画点，并给出一句话（[RegressionCurveOutcome.refusal]）：
///       对数不够（[fitCall] 返回 null）、翻译不过去、某个取样点答不出来（超时、引擎缺席、答案
///       不是一个有限十进制）、以及**取样期间数据集被改过**（代际守卫）。**绝不插值、绝不猜、
///       绝不用一半的点画一条线。**
///
/// English: **the controller-side half of the regression graph (HiPER's "Graph of regression"
///          calculation detail)**: where the plot's points come from and how the curve is asked of the
///          engine.
///
///          ### What it corresponds to in the sources
///
///          HiPER's help text (`help.statistics.contents`; how it was fetched is in the report) says,
///          in the statistics chapter: "**If you press the `<key:MORE>` button on the display, you
///          will see a graph of regression function and all points.**" The paragraphs above it say a
///          "set of values" is a **row matrix** or a **two-row matrix**; the entry's own context key
///          is `detailGroup.REGRESSION_GRAPH.title` (`= "Graph of regression"`) annotated
///          `"2D an 3D graphs" calculation details` — so in the source it is a **calculation detail**,
///          not a whole statistics editor page. In the one real screenshot on this machine, `更多…`
///          is exactly the button at the display's top right.
///
///          So this half has to supply **two things**: all the data points, and one fitted curve.
///
///          ### The points: the **two-row** reading only
///
///          [regressionGraphPoints] uses the **same cut** as `pearson`/`covar`/`spearman`
///          (`datasetPairCount`: first half X, second half Y), not a second cut. **The one-row reading
///          cannot be plotted** — a set of values has no y, and drawing it would mean inventing an
///          index for the horizontal axis, which is a **second source of truth outside the data**.
///
///          ### The curve: the engine computes it, one point per call
///
///          The curve has to come from the engine, byte for byte the reason the three fit cells give
///          (the engine is the only thing in this app that does least squares). **There are two ways
///          to get a run of y values out of the engine and both were measured** (host libqalculate
///          5.12.0, the version the AAR in `android/app/build.gradle.kts` bundles):
///
///          1. **Take the printed function back and evaluate it here** — **rejected**. What the engine
///             prints is **display text** (measured: `linearfit(matrix(1,5,1,2,3,4,5),
///             matrix(1,5,1,4,9,16,25))` prints `6x − 7`, while `quadraticfit` prints `x²` — a real
///             superscript character), and this app has a standing rule that display text is never fed
///             to a numeric consumer. Evaluating `x²` with the legacy parser bets that every corner of
///             the two notations agrees, and losing that bet looks like **a perfectly reasonable wrong
///             curve**.
///          2. **Let the engine substitute**: `replace(<that fit call>,x,<number>)`. Measured (same
///             host): see the block above. The answer is an **ordinary decimal number**, so it goes
///             through the app's single numeric judgement ([MathResult.decimalValueOf]) — **no second
///             judgement and not one character parsed**. **This is the one chosen.**
///
///          **Why one call per point rather than one call for the whole curve** (that version works
///          and was measured, and is still rejected): `matrix(1,N,replace(F,x,v1),…,replace(F,x,vN))`
///          measured returns `[−500  −450  …]` — **the whole 24-point curve in one round trip** (a
///          1846-character expression, 40 ms). It is rejected because of the **shape of the answer**: a
///          vector has no decimal form, `MathResult.decimalValueOf` returns null for it (that is what
///          this app's judgement says about the matrix branch), and putting it to use would mean
///          **writing a second numeric judgement for a vector** — precisely what this project has
///          spent a dozen rounds deleting. So the slow, clean one is the one taken.
///
///          **The substitution has to be scalar, and that too was measured — it is a new
///          silently-wrong-value shape**: `replace` does a **structural** substitution, not an
///          element-wise map. Substituting a **vector** for x gives the block above: `replace(x^2,x,
///          [1 2 3])` is a matrix power rather than an element-wise square, and `replace(1/x,x,[1 2 4])`
///          is not an element-wise reciprocal. **So point-by-point scalar substitution is not
///          conservatism, it is the only correct form**; the version that fetched the whole curve at
///          once still had to write scalar substitutions into one `matrix(...)` for exactly this
///          reason.
///
///          ### Every failure fails closed
///
///          All four kinds of failure **draw no curve**, only the points, and give one sentence
///          ([RegressionCurveOutcome.refusal]): too few pairs ([fitCall] returns null), the call does
///          not translate, one sample does not come back (timeout, absent engine, an answer that is
///          not a finite decimal), and **the dataset changed during sampling** (the generation guard).
///          **No interpolation, no guessing, and never a line drawn from half the points.**
mixin _CalculatorFitCurve on _CalculatorState, _CalculatorDataset {
  /// 中文：**图上那些点**——数据集的**两行**读法（前一半 X、后一半 Y），每对是一个
  ///       `(x: double, y: double)`。
  ///
  ///       读不成两行（空、奇数个、只有一对）时是**空表**，判据就是那一条
  ///       （[canReadDatasetAsTwoRows]，与面板上那两行用的是同一个）。**空表的意思是「没有点可画」，
  ///       不是「点算不出来」**——图上于是什么都不画，并把 [regressionUnavailableMessage] 那句话
  ///       摆在旁边。
  ///
  ///       每一个值都**再过一次** [MathResult.decimalValueOf]：数据集里的值进来时已经过了同一道
  ///       判据（[storableDatasetValue]），这里是**读的那一侧**——与 `_readDataset` 对盘上那一份
  ///       做的是同一件事，理由也同一条（「存起来的时候对」不等于「用的时候还对」）。任何一条
  ///       过不去就整份当作没有：一条缺了一个点的散点图比没有更坏。
  ///
  ///       **它不是第二个真相源**：读的还是 `_dataset` 那一串文本，变的只是它被切成什么形状
  ///       （与 `regressionCall` 逐字同一条理由）。
  ///
  /// English: **the points on the plot** — the dataset's **two-row** reading (first half X, second
  ///          half Y), each pair a `(x: double, y: double)`.
  ///
  ///          When it cannot be read as two rows (empty, odd count, one pair only) this is an **empty
  ///          list**, and the judgement is that one ([canReadDatasetAsTwoRows], the same one the two
  ///          sheet rows use). **An empty list means "there are no points to draw", not "the points
  ///          could not be computed"** — the plot then draws nothing and
  ///          [regressionUnavailableMessage] sits beside it.
  ///
  ///          Every value goes through [MathResult.decimalValueOf] **once more**: values already went
  ///          through that judgement when they entered ([storableDatasetValue]), and this is the
  ///          **reading** side — byte for byte what `_readDataset` does to the copy on disk, for the
  ///          same reason ("it was right when it was stored" is not "it is still right when it is
  ///          used"). If any one fails the whole set counts as absent: a scatter plot missing one point
  ///          is worse than none.
  ///
  ///          **It is not a second source of truth**: what is read is still the run of text in
  ///          `_dataset`, and only the shape it is cut into changes (word for word `regressionCall`'s
  ///          reason).
  List<({double x, double y})> get regressionGraphPoints {
    final pairs = datasetPairCount;
    if (pairs < kMinRegressionPairs) return const <({double x, double y})>[];
    final points = <({double x, double y})>[];
    for (var i = 0; i < pairs; i++) {
      final x = MathResult.decimalValueOf(_dataset[i]);
      final y = MathResult.decimalValueOf(_dataset[pairs + i]);
      if (x == null || y == null) return const <({double x, double y})>[];
      points.add((x: x, y: y));
    }
    return List<({double x, double y})>.unmodifiable(points);
  }

  /// 中文：**回归图面板上那一行读数**——它比 `STAT` 面板那一行**少了尾巴上那条调用**，而且这是
  ///       有意的：那个面板**什么都不插**，把一条「按下去会插进去的调用」印在一张不插东西的面板上，
  ///       说的是一件不会发生的事。前半句两处共用（[_fitPairFloorsReading]），所以「几对值」这个
  ///       用户唯一能据以补数据的数字在两处**逐字相同**。
  ///
  /// English: **the reading on the regression graph sheet** — it is the `STAT` sheet's reading
  ///          **without the call at the end**, deliberately: that sheet **inserts nothing**, and
  ///          printing "the call this would insert" on a sheet that inserts nothing describes
  ///          something that will not happen. The first half is shared ([_fitPairFloorsReading]), so
  ///          the pair counts — the one number the user can act on — are byte-for-byte the same in
  ///          both places.
  String get regressionGraphFitReading => _fitPairFloorsReading(_dataset);

  /// 中文：**某一条拟合为什么画不出来**——对数不够时的那一句话。
  ///
  ///       它与 [fitStatusMessage] 那一行**措辞不同**，而且又是故意的：两句话可能同时出现在屏幕上
  ///       （面板一行、图面板一行），共用一串字符会让「这句话说的是哪一行」变成猜的。它说的是
  ///       **这一条**拟合要几对、现在有几对——用户据此知道再加几个值就能画出来。
  ///
  /// English: **why one fit cannot be drawn** — the sentence for "not enough pairs".
  ///
  ///          Its wording is **deliberately different** from [fitStatusMessage]'s, again: both may sit
  ///          on screen at once (one line on the sheet, one on the graph sheet) and sharing a run of
  ///          characters would make "which line is this sentence about" a guess. It says how many
  ///          pairs **this** fit needs and how many there are — which is what tells the user how much
  ///          more data would make it appear.
  String fitCurveUnavailableMessage(String function) {
    final minimum = kFitMinimumPairs[function];
    if (minimum == null) return '`$function` 不是这个应用里的拟合函数，没有曲线可画';
    final pairCount = datasetPairCount;
    return '$function 的曲线没画：它要 $minimum 对值，'
        '数据集现在有 $pairCount 对（${_dataset.length} 个值）';
  }

  /// 中文：**要一条拟合曲线**：在 `[xMin, xMax]` 上等距取
  ///       [kRegressionGraphCurveSamples] 个位置，**逐点问引擎**那一条拟合函数在那里的值。
  ///
  ///       返回的两种结果见 [RegressionCurveOutcome]。**四种失败都不画曲线**，每一种都有一句
  ///       自己的话：
  ///
  ///       1. **[fitCall] 是 null**（对数不够）→ [fitCurveUnavailableMessage]。**这一条正是那一轮
  ///          在翻译层加的形状判据要挡的东西**：喂成两行矩阵时 n=2 上引擎会给一条种类与正解完全
  ///          相同的**错函数**（`x + 1` 对 `x + 2`），所以那条判据必须问**输入**；这里问的是同一个
  ///          判断（[fitCall]），**没有再写一份**。
  ///       2. **翻译不过去**（`UntranslatableExpression`）→ 引擎根本不会被问。
  ///       3. **某一个取样点答不出来**——超时、没有原生侧、答案不是一个有限十进制
  ///          （[MathResult.decimalValueOf] 为 null）。**一个点答不出来就是整条曲线不画**：
  ///          用剩下的点连一条折线会得到一个**看起来完整、实际有洞**的图形，而那正是硬性边界 4
  ///          说的「一个错的图比没有图更坏」。
  ///       4. **取样期间数据集或别的状态被改过**（`_stateRevision` 变了）→ 不画。曲线是从**那一刻**
  ///          的数据集算出来的，而屏幕上的点读的是**此刻**的数据集；不挡的话，两条曲线与点会来自
  ///          两个时刻，而它们在屏幕上看起来是一张图。
  ///
  ///       **串行取样，第一处失败就收手。** 这不是为了简单——串行把「引擎卡死」的代价封在**一发**
  ///       超时里（并发发 24 发的话，原生队列里会攒 24 个被放弃的项，而那正是 `_askEngine` 的注释
  ///       里点名过的那种「不会自己报警的不变式」）。代价是健康引擎下也要走 24 次往返，量级是
  ///       几十毫秒，用户看得见的是这张面板打开到曲线出现之间的一次等待。
  ///
  ///       问引擎的那一串是**拼出来的**，而且与 `showBaseReadout` 同一条理由：它**不是应用自己的
  ///       表达式**（`replace` 不在应用词汇表里），所以不经过 `engineExpressionFor` 走全程——但
  ///       里面那个**拟合调用**是应用自己的文本，它**过**了翻译层（`engineExpressionFor`），
  ///       与那一格插进表达式之后走的是同一条路、同一份产物。跨过去的那一小段是「一个 `replace`
  ///       调用名 + 一个裸 `x` + 一个十进制字面量」，封闭性是构造出来的。
  ///
  /// English: **ask for one fitted curve**: take [kRegressionGraphCurveSamples] evenly spaced
  ///          positions across `[xMin, xMax]` and ask the engine **point by point** for that fitted
  ///          function's value there.
  ///
  ///          The two outcomes are on [RegressionCurveOutcome]. **All four kinds of failure draw no
  ///          curve**, each with a sentence of its own:
  ///
  ///          1. **[fitCall] is null** (too few pairs) → [fitCurveUnavailableMessage]. **This is
  ///             exactly what the input-side shape judgement added in the fits round exists to stop**:
  ///             fed the two-row shape, at n=2 the engine returns a **wrong function of the very same
  ///             kind** as the right answer (`x + 1` against `x + 2`), so that judgement has to ask
  ///             about the **input**; this asks the same judgement ([fitCall]) and **writes no second
  ///             copy of it**.
  ///          2. **It does not translate** (`UntranslatableExpression`) → the engine is never asked.
  ///          3. **One sample does not come back** — timeout, no native side, an answer that is not a
  ///             finite decimal ([MathResult.decimalValueOf] returns null). **One missing point means
  ///             no curve at all**: joining the remaining points would produce a figure that looks
  ///             complete and has a hole in it, which is precisely hard boundary 4's "a wrong picture
  ///             is worse than a missing one".
  ///          4. **The dataset or other state changed during sampling** (`_stateRevision` moved) → no
  ///             curve. The curve was computed from **that moment's** dataset while the points on
  ///             screen are read from the dataset **right now**; without this guard the curve and the
  ///             points would come from two different moments while looking like one figure.
  ///
  ///          **Sampling is serial and stops at the first failure.** Not for simplicity — serial keeps
  ///          the cost of a wedged engine to **one** timeout (firing 24 concurrently would leave 24
  ///          abandoned entries on the native queue, which is exactly the "invariant that does not
  ///          announce itself" `_askEngine`'s note names). The price is 24 round trips even against a
  ///          healthy engine — tens of milliseconds, visible to the user as a wait between opening
  ///          this sheet and the curve appearing.
  ///
  ///          The string written for the engine is **assembled**, for the same reason
  ///          `showBaseReadout`'s is: it is **not an expression of this app** (`replace` is not in the
  ///          app's vocabulary), so it does not go through `engineExpressionFor` end to end — but the
  ///          **fit call** inside it is this app's own text and it **does** go through the translation
  ///          layer, the same route and the same product as when that cell inserts it into the
  ///          expression. What crosses over is "one `replace` call name, one bare `x`, one decimal
  ///          literal", closed by construction.
  Future<RegressionCurveOutcome> regressionCurveFor(
    String function, {
    required double xMin,
    required double xMax,
  }) async {
    final call = fitCall(function);
    if (call == null) {
      return RegressionCurveOutcome.refused(fitCurveUnavailableMessage(function));
    }
    final translated = engineExpressionFor(call);
    if (translated is! TranslatedExpression) {
      return const RegressionCurveOutcome.refused(_kCurveNoEngineAnswer);
    }
    final xs = _curveSampleXs(xMin, xMax);
    final literals = <String>[];
    for (final x in xs) {
      final literal = _curveXLiteral(x);
      if (literal == null) return const RegressionCurveOutcome.refused(_kCurveNoEngineAnswer);
      literals.add(literal);
    }
    final generation = _stateRevision;
    final ys = <double>[];
    for (final literal in literals) {
      final reply = await _askEngine('replace(${translated.text},x,$literal)');
      if (_disposed || generation != _stateRevision) {
        return const RegressionCurveOutcome.refused(_kCurveStaleError);
      }
      final value = reply.ok
          ? MathResult.decimalValueOf(reply.result?.decimalText ?? '')
          : null;
      if (value == null) {
        return const RegressionCurveOutcome.refused(_kCurveNoEngineAnswer);
      }
      ys.add(value);
    }
    return RegressionCurveOutcome.drawn(
      RegressionCurve(function: function, xs: xs, ys: ys),
    );
  }

  /// 中文：**取样位置**——`[xMin, xMax]` 上等距的 [kRegressionGraphCurveSamples] 个。两端都取到，
  ///       所以曲线铺满整个 x 窗口，不会在边上短一截。
  ///
  ///       窗口不是一个合法区间时（非有限、或 `xMax <= xMin`）给空表——调用方按「没有曲线」处理。
  ///       **除零也在这里被挡掉**：`count - 1` 是常量 23，不是零，但 `xMax - xMin` 为零时整串会
  ///       退化成同一个 x，那种窗口画不出图。
  ///
  /// English: **the sample positions** — [kRegressionGraphCurveSamples] evenly spaced across
  ///          `[xMin, xMax]`, both ends included, so the curve spans the whole x window instead of
  ///          stopping short at the edges.
  ///
  ///          A window that is not a legal interval (non-finite, or `xMax <= xMin`) gives an empty
  ///          list — the caller reads that as "no curve". **Division by zero is caught here too**: the
  ///          `count - 1` is the constant 23 rather than zero, but a zero `xMax - xMin` collapses the
  ///          run to one x, and no plot comes out of that window.
  List<double> _curveSampleXs(double xMin, double xMax) {
    if (!xMin.isFinite || !xMax.isFinite || xMax <= xMin) return const <double>[];
    const count = kRegressionGraphCurveSamples;
    return <double>[
      for (var i = 0; i < count; i++) xMin + (xMax - xMin) * i / (count - 1),
    ];
  }

  /// 中文：**代换进去的那个 x 字面量**——必须是**普通十进制写法**，否则返回 null（调用方按
  ///       「没有曲线」处理）。
  ///
  ///       为什么要有这条：`replace` 的实参是我们拼进一条引擎查询里的文本，而引擎对实参的读法
  ///       与屏幕上的写法不是一回事。`toStringAsFixed(10)` 在 `|x| >= 1e21` 时**切换成指数写法**
  ///       （`1e+21`，实测），那时这个字面量就不再是我们能担保的那个形状了——所以**拒绝**，不猜。
  ///       一份 x 都在 1e21 量级的数据集本来也画不出一张有意义的图。
  ///
  ///       末尾的零要剥掉：`2.5` 而不是 `2.5000000000`。剥不剥不影响引擎读到的值，只影响那条
  ///       查询的长度——而它是**每一次调用**都要拼一遍的。
  ///
  /// English: **the x literal substituted in** — it has to be a **plain decimal**, or this returns
  ///          null and the caller reads that as "no curve".
  ///
  ///          Why this exists: `replace`'s argument is text we assemble into an engine query, and the
  ///          engine's reading of an argument is not the same thing as the way it is written on
  ///          screen. `toStringAsFixed(10)` **switches to exponent form at `|x| >= 1e21`** (`1e+21`,
  ///          measured), and at that point the literal is no longer a shape we can vouch for — so it
  ///          **refuses rather than guesses**. A dataset whose x values sit at 1e21 could not make a
  ///          meaningful plot anyway.
  ///
  ///          Trailing zeros are stripped: `2.5` rather than `2.5000000000`. Whether they are
  ///          stripped makes no difference to the value the engine reads, only to the length of that
  ///          query — and it is assembled again on **every** call.
  String? _curveXLiteral(double value) {
    if (!value.isFinite) return null;
    if (value == 0) return '0';
    var text = value.toStringAsFixed(10);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    if (text.contains('e') || text.contains('E')) return null;
    return text;
  }
}

/// 中文：**曲线画不出来时那两句话**（第三、四种失败）。它们是**说给用户听的**，所以说的是真正
///       的原因与后果，不是「错误」两个字——与数据集那两句同一种。
///
///       第四句**把动作说出来**（「再按一次」）：那不是装饰。取样中途数据集被改过时屏幕上的点已经
///       是新的了，用户唯一能得到曲线的办法就是重新选一次这条拟合——不说，他看到的只是一个没有
///       曲线的图，而没有任何线索。
///
/// English: **the two sentences for a curve that cannot be drawn** (the third and fourth failures).
///          They are **written for the user**, so they name the real cause and consequence rather than
///          saying "error" — the same kind as the dataset's two.
///
///          The fourth one **names the action** ("press it again"), and that is not decoration: when
///          the dataset was edited mid-sampling, the points on screen are already the new ones, and the
///          only way for the user to get a curve is to pick that fit again — unsaid, all they see is a
///          plot with no curve and no clue why.
const String _kCurveNoEngineAnswer = '曲线没画：引擎没有给出这条曲线上的全部点，只画了数据集里的点';

const String _kCurveStaleError = '曲线没画：取样期间数据集变过，再按一次这条拟合';
