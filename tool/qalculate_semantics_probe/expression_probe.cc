#include <libqalculate/qalculate.h>
#include <chrono>
#include <cstdio>
#include <string>
#include <vector>

// 中文：**把一串表达式在宿主上跑一遍：每条计时，并同时印出两种 `approximation` 下的结果。**
//
//       用途两件，都指向 `docs/verification.md`：
//         · §5 那句「the controller's `engineTimeout` is 5 s and **a mid-weight symbolic sum exceeds
//           it**」——**没找到见证者**：`sum(...)` 的各种写法在两种模式下**都原样回显**（0.0–0.7 ms，
//           引擎根本没算它），唯一求值了的符号积分花了 4.7 ms。
//         · **§5e 那条实测**：`integrate(x^3, x)` 在**两种模式下都给** `-infinity`，而定积分
//           `integrate(x^3, 0, 1, x)` 给 `0.25` ✓ —— **不定积分是错的，定积分是对的**。
//
//       `probe.cc` 是硬编码的语义表、不接参数，所以另起这一个。
//
//       设置与 `probe.cc` 逐项一致（精度 16、打印选项、**角度单位钉成弧度**，理由见 `probe.cc` 里那段：
//       桥每次都设，探针不设就会量到桥上不存在的取值），入口也是同一个 `calc.calculate(...)`。
//
//       ⚠️ **宿主上的数只是下界。** 宿主是 x86-64、设备是 arm64：**这里超过 5 s ⇒ 设备必然也超过**；
//       这里远低于 5 s 则**不能**反推设备也低。要设备的真数只有走零接触通道（会改 `app_settings`，
//       得先备份再逐字节还原）。
//
//       每条算完**立刻 flush**：重的例子可能跑很久，被 `timeout` 杀掉时至少能看出是卡在哪一条。
//
// English: **runs a list of expressions on the host: times each, and prints the result under *both*
//          approximation modes.**
//
//          Two uses, both pointing at `docs/verification.md`:
//            · §5's "the controller's `engineTimeout` is 5 s and a mid-weight symbolic sum exceeds it" —
//              **no witness found**: every `sum(...)` shape came back **unevaluated** in both modes
//              (0.0–0.7 ms; the engine echoes the call instead of computing it), and the one symbolic
//              integral that did evaluate took 4.7 ms.
//            · **§5e's measurement**: `integrate(x^3, x)` returns `-infinity` in **both** modes while the
//              definite `integrate(x^3, 0, 1, x)` returns `0.25` ✓ — **the indefinite one is wrong, the
//              definite one is right**.
//
//          `probe.cc` is a hardcoded semantics table with no argument handling, hence this sibling.
//
//          The setup matches `probe.cc` item for item (precision 16, the print options, and the **angle
//          unit pinned to radians** for the reason given there: the bridge sets it on every call, so a
//          probe that does not would measure values the bridge never produces), and it enters through the
//          same `calc.calculate(...)`.
//
//          ⚠️ **A host number is a lower bound.** The host is x86-64 and the device is arm64: **exceeding
//          5 s here means the device certainly does**; being well under here proves nothing about the
//          device. The only real device number comes from the zero-touch channel (which rewrites
//          `app_settings`, so back the database up first and restore it byte for byte).
//
//          Each case **flushes immediately**: a heavy one can run for a long time, and if `timeout` kills
//          the process this at least shows which case it died on.
int main() {
	Calculator calc; calc.loadGlobalDefinitions(); calc.setPrecision(16); calc.useDecimalPoint(true);
	PrintOptions po; po.number_fraction_format = FRACTION_DECIMAL; po.use_unicode_signs = false;
	po.digit_grouping = DIGIT_GROUPING_NONE; po.interval_display = INTERVAL_DISPLAY_MIDPOINT;
	std::vector<std::string> cases = {
		// 对照组：应当毫秒级
		"2+2", "sin(1)",
		// 逐步加重的符号求和（`sum` 的那几种写法都放进来：写错参数顺序会**原样回显**，
		// 从输出就能看出它是"没算"而不是"算得快"）
		"sum(x^n/n, n, 1, 10)",
		"sum(x^n/n, n, 1, 30)",
		"sum(x^n/n!, n, 0, 30)",
		"sum(x^n/n!, n, 0, 60)",
		"sum(1/n^s, n, 1, 50)",
		"sum(1/n^s, n, 1, 200)",
		// 符号积分：另一类"中等体量"的候选
		"integrate(x^n, x)",
		"integrate(sin(x)^n, x)",
		// ⚠️ **上面那条 `integrate(x^n, x)` 求值了，而它印出来的分子两项看着一模一样**
		//    （`(x * x^n - x * x^n) / (n + 1)`）——那读起来是 0。下面这一组用**数值幂**判定：
		//    定积分有已知答案（∫₀¹x³ = 0.25、∫₀¹x² = 1/3），所以它能分开两种可能：
		//    **不定积分印错了** vs **积分本身算错了**。
		// English: `integrate(x^n, x)` above *did* evaluate, and its numerator prints two terms that
		//          look identical (`(x * x^n - x * x^n) / (n + 1)`) — which reads as 0. This group uses
		//          **numeric powers**: the definite ones have known answers (∫₀¹x³ = 0.25, ∫₀¹x² = 1/3),
		//          so they separate "the indefinite form prints wrong" from "integration is wrong".
		"integrate(x^3, x)",
		"integrate(x^3, 0, 1, x)",
		"integrate(x^2, x)",
		"integrate(x^2, 0, 1, x)",
	};
	// 中文：⚠️ **两种 approximation 都要跑。** 应用对同一个表达式走**两条路**：精确形态那一份用
	//       `APPROXIMATION_EXACT`、十进制那一份用 `APPROXIMATE`（见 `QalculateOptions.kt` 的
	//       `evaluationOptions`——`approximation` 是**调用方传进来的参数**，而 `printOptions` 的注释里
	//       写着「精确形态那一份照旧由 APPROXIMATION_EXACT 保留」）。只跑一种就会把其中一条路的结果
	//       当成"应用看到的东西"——2026-10-10 我就这么错过一次（只跑 APPROXIMATE，于是把
	//       `integrate(x^3, x)` 的 `-infinity` 当成了定论）。
	// English: ⚠️ **run both approximation modes.** The app takes **two paths** for one expression: the
	//          exact form uses `APPROXIMATION_EXACT` and the decimal one uses `APPROXIMATE` (see
	//          `evaluationOptions` in `QalculateOptions.kt`, where `approximation` is a **caller-supplied
	//          parameter**, and the note on `printOptions`: "the exact form is still preserved by
	//          APPROXIMATION_EXACT on its own path"). Running one mode means mistaking one path's output
	//          for "what the app sees" — which is what I did on 2026-10-10 (APPROXIMATE only, and took
	//          `-infinity` for `integrate(x^3, x)` as the verdict).
	const std::vector<std::pair<const char*, ApproximationMode>> modes = {
		{"APPROX", APPROXIMATION_APPROXIMATE},
		{"EXACT ", APPROXIMATION_EXACT},
	};
	for (auto e : cases) {
		for (auto mode : modes) {
			EvaluationOptions eo; eo.approximation = mode.second; eo.allow_complex = true;
			eo.parse_options.comma_as_separator = false;
			eo.parse_options.angle_unit = ANGLE_UNIT_RADIANS;
			auto t0 = std::chrono::steady_clock::now();
			std::string n = calc.unlocalizeExpression(e, eo.parse_options);
			MathStructure m = calc.calculate(n, eo);
			auto t1 = std::chrono::steady_clock::now();
			double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
			std::string out = calc.print(m, 2000, po, false, 0, TAG_TYPE_TERMINAL);
			bool echoed = out.find("sum(") != std::string::npos || out.find("integrate(") != std::string::npos;
			if (out.size() > 70) out = out.substr(0, 70) + "…";
			printf("%8.1f ms [%s] %-26s -> %s%s\n", ms, mode.first, e.c_str(), out.c_str(),
				echoed ? "   [未求值]" : "");
			fflush(stdout);
		}
	}
	return 0;
}
