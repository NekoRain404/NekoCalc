#include <libqalculate/qalculate.h>
#include <cstdio>
#include <string>
#include <vector>
int main() {
	Calculator calc; calc.loadGlobalDefinitions(); calc.setPrecision(16); calc.useDecimalPoint(true);
	PrintOptions po; po.number_fraction_format = FRACTION_DECIMAL; po.use_unicode_signs = false;
	po.digit_grouping = DIGIT_GROUPING_NONE; po.interval_display = INTERVAL_DISPLAY_MIDPOINT;
	std::vector<std::string> cases = {
		"sin(1)","sin(-1)","cos(0)","tan(0.5)","asin(0.5)","acos(0.5)","atan(1)","atan2(7,100)",
		"sinh(1)","cosh(1)","tanh(1)","cot(1)","sec(1)","csc(1)",
		"log(100)","log2(8)","ln(2)","exp(1)","abs(-3)","sqrt(2)","cbrt(-8)",
		"floor(1.7)","floor(-1.7)","ceil(1.2)","ceil(-1.2)","round(1.5)","round(-1.5)","round(2.5)",
		"min(3,1)","max(3,1)","mod(7,3)","mod(7,-3)","mod(-7,3)","mod(-7,-3)",
		"gcd(24,18)","lcm(4,6)","root(27,3)","root(3,27)","atan2(1,1)","sqrt(9)","exp(0)",
		// 常量被当成调用——`phi` 是这里面唯一一个引擎有同名**函数**的（欧拉 φ）。
		// Constants written as calls — `phi` is the one the engine has a same-named **function** for.
		"phi(2)","pi(2)","e(2)","tau(2)"
	};
	for (auto e : cases) {
		EvaluationOptions eo; eo.approximation = APPROXIMATION_APPROXIMATE; eo.allow_complex = true;
		eo.parse_options.comma_as_separator = false;
		// 中文：**角度单位必须和桥接层一致。** 桥接层每次都设 `parse_options.set_angle_unit(...)`
		//       （`QalculateEngine.evaluationOptions`，取应用设置的 DEG/RAD，默认 RAD）；探针不设的话
		//       引擎会把反三角函数的结果印成带 ` rad` 的角度量，而桥上永远不会出现那个后缀——
		//       那样量出来的表就不是桥上的取值。这里跟桥一样钉成弧度。
		// English: **the angle unit has to match the bridge.** The bridge sets
		//          `parse_options.set_angle_unit(...)` on every call (`QalculateEngine.evaluationOptions`,
		//          from the app's DEG/RAD setting, RAD by default); without it the engine prints the
		//          inverse trigonometric results as angle quantities carrying ` rad`, a suffix the bridge
		//          never produces — so the table would not be the bridge's values. Pinned to radians
		//          here, exactly as the bridge does.
		eo.parse_options.angle_unit = ANGLE_UNIT_RADIANS;
		std::string n = calc.unlocalizeExpression(e, eo.parse_options);
		MathStructure m = calc.calculate(n, eo);
		printf("    ('%s', '%s'),\n", e.c_str(),
			calc.print(m, 2000, po, false, 0, TAG_TYPE_TERMINAL).c_str());
	}
	return 0;
}
