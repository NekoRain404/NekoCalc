#include <libqalculate/qalculate.h>
#include <cstdio>
#include <string>
#include <vector>
int main() {
	Calculator calc; calc.loadGlobalDefinitions(); calc.setPrecision(16); calc.useDecimalPoint(true);
	PrintOptions po; po.number_fraction_format = FRACTION_DECIMAL; po.use_unicode_signs = false;
	po.digit_grouping = DIGIT_GROUPING_NONE; po.interval_display = INTERVAL_DISPLAY_MIDPOINT;
	std::vector<std::string> cases = {
		"sin(1)","sin(-1)","cos(0)","tan(0.5)","asin(0.5)","acos(0.5)","atan(1)",
		"sinh(1)","cosh(1)","tanh(1)","cot(1)","sec(1)","csc(1)",
		"log(100)","log2(8)","ln(2)","exp(1)","abs(-3)","sqrt(2)","cbrt(-8)",
		"floor(1.7)","floor(-1.7)","ceil(1.2)","ceil(-1.2)","round(1.5)","round(-1.5)","round(2.5)",
		"min(3,1)","max(3,1)","mod(7,3)","mod(7,-3)","mod(-7,3)","mod(-7,-3)",
		"gcd(24,18)","lcm(4,6)","root(27,3)","root(3,27)","atan2(1,1)","sqrt(9)","exp(0)"
	};
	for (auto e : cases) {
		EvaluationOptions eo; eo.approximation = APPROXIMATION_APPROXIMATE; eo.allow_complex = true;
		eo.parse_options.comma_as_separator = false;
		std::string n = calc.unlocalizeExpression(e, eo.parse_options);
		MathStructure m = calc.calculate(n, eo);
		printf("    ('%s', '%s'),\n", e.c_str(),
			calc.print(m, 2000, po, false, 0, TAG_TYPE_TERMINAL).c_str());
	}
	return 0;
}
