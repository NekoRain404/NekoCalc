package com.jherkenhoff.libqalculate;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 中文：**测试替身，不是产品代码。** 它只存在于 `app/src/test/java` 之下，永远不会进 APK。
 *
 *       它为什么存在：那三个映射文件（`QalculateOptions.kt` 等）里除了 `angleUnitFor` 之外，
 *       每一个函数都会构造或读取 AAR 里的 SWIG 包装类（`EvaluationOptions` / `PrintOptions` /
 *       `Calculator`），而那些类的**每一个构造器与方法体都是 native**——宿主 JVM 上没有
 *       arm64 的 `.so`，一行都跑不起来。可 Kotlin 这一侧要交给 C++ 的**取值**恰恰是会静默算错
 *       答案的那一层（角度单位、分数写法、Unicode 符号、千分位）。所以这里把**最下面那一层
 *       JNI 胶水**换成一份纯 Java 的记录器：`EvaluationOptions()` 之类照样被构造（构造器只是
 *       调用本类的静态方法），只是每一次 set 都被记下来，测试再断 Kotlin 到底递了什么过去。
 *
 *       类的全名与包名**必须**与 AAR 里那份一模一样（`libqalculateJNI` 是 SWIG 生成的名字，
 *       小写开头不是笔误）：单元测试的运行时 classpath 上，测试自己的 class 目录排在依赖 jar
 *       之前，于是 JVM 解析到的就是这个替身。这一点由测试自己证明——真的那份被解析到时，
 *       第一次 `PrintOptions()` 就会抛 `UnsatisfiedLinkError`。
 *
 *       它**不模拟 C++ 语义**：只说得出「Kotlin 递了哪个值下去」，说不出「引擎会拿它印成什么」。
 *
 * English: **A test double, not production code.** It lives only under `app/src/test/java` and never
 *          enters the APK.
 *
 *          Why it exists: apart from `angleUnitFor`, every function in the three mapping files
 *          constructs or reads SWIG wrapper classes from the AAR (`EvaluationOptions` /
 *          `PrintOptions` / `Calculator`), and every one of those constructors and method bodies is
 *          **native** — there is no arm64 `.so` on a host JVM, so not a line of them can run. Yet
 *          the *values* the Kotlin side hands to C++ are exactly the layer where a mistake is a
 *          silently wrong answer (angle unit, fraction spelling, Unicode signs, digit grouping). So
 *          the **bottom layer, the JNI glue**, is replaced by a pure-Java recorder: `EvaluationOptions()`
 *          and friends are still constructed (their constructors merely call this class's static
 *          methods), but every set is recorded, and the tests assert what the Kotlin actually handed
 *          over.
 *
 *          The class name and package **must** be identical to the AAR's (`libqalculateJNI` is the
 *          SWIG-generated name; the lower-case first letter is not a typo): on the unit test's
 *          runtime classpath the test's own class directory precedes the dependency jars, so the JVM
 *          resolves this double. The tests prove that themselves — if the real one were resolved
 *          instead, the first `PrintOptions()` would throw `UnsatisfiedLinkError`.
 *
 *          It does **not** emulate the C++ semantics: it can say "the Kotlin handed down this value",
 *          never "the engine prints that with it".
 */
public final class libqalculateJNI {

    private static final List<String> EVENTS = new ArrayList<>();
    private static final Map<String, Object> LAST = new LinkedHashMap<>();
    private static final Set<String> FUNCTIONS = new LinkedHashSet<>();
    private static final Set<String> VARIABLES = new LinkedHashSet<>();
    private static final Set<String> UNITS = new LinkedHashSet<>();
    private static long nextPointer = 1L;

    private libqalculateJNI() {
    }

    // ------------------------------------------------------------------
    // 中文：给测试读的一面。English: the surface the tests read.
    // ------------------------------------------------------------------

    /** 中文：清空记录（不碰那张假符号表）。English: clear the recording (the stub symbol table stays). */
    public static void reset() {
        EVENTS.clear();
        LAST.clear();
    }

    /** 中文：按发生顺序记下的每一次 set。English: every set, in the order it happened. */
    public static List<String> events() {
        return new ArrayList<>(EVENTS);
    }

    /** 中文：某个字段最后一次被设成的值；从没设过就是 null。 */
    public static Object field(String name) {
        return LAST.get(name);
    }

    /**
     * 中文：假符号表——`Calculator.getFunction/getVariable/getUnit` 会照着这三张表回答。名字是
     *       测试摆进去的，**不是**对真引擎的断言（真引擎那张表是在设备上量出来的，见
     *       `QalculateResultKind.kt` 的注释）。三张表都可以反复清空重摆。
     * English: the stub symbol table — what `Calculator.getFunction/getVariable/getUnit` answer from.
     *          The names are put there by the tests and are **not** a claim about the real engine
     *          (its table was measured on a device; see the notes in `QalculateResultKind.kt`).
     */
    public static void knowFunction(String... names) {
        for (String name : names) {
            FUNCTIONS.add(name);
        }
    }

    public static void knowVariable(String... names) {
        for (String name : names) {
            VARIABLES.add(name);
        }
    }

    public static void knowUnit(String... names) {
        for (String name : names) {
            UNITS.add(name);
        }
    }

    public static void clearSymbolTable() {
        FUNCTIONS.clear();
        VARIABLES.clear();
        UNITS.clear();
    }

    private static void record(String field, Object value) {
        EVENTS.add(field + "=" + value);
        LAST.put(field, value);
    }

    private static long allocate() {
        return nextPointer++;
    }

    // ------------------------------------------------------------------
    // EvaluationOptions
    // ------------------------------------------------------------------

    public static long new_EvaluationOptions() {
        return allocate();
    }

    public static void delete_EvaluationOptions(long pointer) {
    }

    public static void EvaluationOptions_approximation_set(
            long pointer, EvaluationOptions self, int value) {
        record("EvaluationOptions.approximation", value);
    }

    public static void EvaluationOptions_allow_complex_set(
            long pointer, EvaluationOptions self, boolean value) {
        record("EvaluationOptions.allow_complex", value);
    }

    public static void EvaluationOptions_mixed_units_conversion_set(
            long pointer, EvaluationOptions self, int value) {
        record("EvaluationOptions.mixed_units_conversion", value);
    }

    public static void EvaluationOptions_auto_post_conversion_set(
            long pointer, EvaluationOptions self, int value) {
        record("EvaluationOptions.auto_post_conversion", value);
    }

    /** 中文：返回的是一枚新指针，SWIG 包装类会把它包成**非拥有**的 `ParseOptions`。 */
    public static long EvaluationOptions_parse_options_get(
            long pointer, EvaluationOptions self) {
        return allocate();
    }

    // ------------------------------------------------------------------
    // ParseOptions
    // ------------------------------------------------------------------

    public static void ParseOptions_angle_unit_set(
            long pointer, ParseOptions self, int value) {
        record("ParseOptions.angle_unit", value);
    }

    public static void ParseOptions_comma_as_separator_set(
            long pointer, ParseOptions self, boolean value) {
        record("ParseOptions.comma_as_separator", value);
    }

    // ------------------------------------------------------------------
    // PrintOptions
    // ------------------------------------------------------------------

    public static long new_PrintOptions() {
        return allocate();
    }

    public static void delete_PrintOptions(long pointer) {
    }

    public static void PrintOptions_number_fraction_format_set(
            long pointer, PrintOptions self, int value) {
        record("PrintOptions.number_fraction_format", value);
    }

    public static void PrintOptions_use_unicode_signs_set(
            long pointer, PrintOptions self, int value) {
        record("PrintOptions.use_unicode_signs", value);
    }

    public static void PrintOptions_digit_grouping_set(
            long pointer, PrintOptions self, int value) {
        record("PrintOptions.digit_grouping", value);
    }

    public static void PrintOptions_interval_display_set(
            long pointer, PrintOptions self, int value) {
        record("PrintOptions.interval_display", value);
    }

    public static void PrintOptions_base_set(
            long pointer, PrintOptions self, int value) {
        record("PrintOptions.base", value);
    }

    // ------------------------------------------------------------------
    // Calculator —— 三张符号表 + 求值路径走到「调用名守卫」为止所需的那几个方法。
    //                别的 native 方法没有实现（也没被这几个测试碰到）。
    //                The three symbol tables, plus the handful of methods the evaluation path
    //                needs to reach the call-name guard. The other native methods are not
    //                implemented (and are not reached by these tests).
    // ------------------------------------------------------------------

    /**
     * 中文：`loadGlobalDefinitions()` 的返回值，**由测试摆**：真机上它是一次真实的加载
     *       （400 多个单位与所有常数），这里只是一个可以被设成 `false` 的开关——那正是
     *       `QalculateEngine` 必须记下来、又必须过 channel 的那条事实。默认 `true`（健康引擎）。
     * English: what `loadGlobalDefinitions()` returns, **staged by the tests**: on a device it is a
     *          real load (400-odd units and every constant); here it is a switch that can be set to
     *          `false` — which is exactly the fact `QalculateEngine` has to record and has to send
     *          across the channel. Defaults to `true` (a healthy engine).
     */
    private static boolean globalDefinitionsLoadable = true;

    public static void setGlobalDefinitionsLoadable(boolean value) {
        globalDefinitionsLoadable = value;
    }

    public static long new_Calculator__SWIG_0() {
        return allocate();
    }

    public static void delete_Calculator(long pointer) {
    }

    public static boolean Calculator_loadGlobalDefinitions__SWIG_0(
            long pointer, Calculator self) {
        record("Calculator.loadGlobalDefinitions", globalDefinitionsLoadable);
        return globalDefinitionsLoadable;
    }

    public static void Calculator_setPrecision__SWIG_0(
            long pointer, Calculator self, int value) {
        record("Calculator.precision", value);
    }

    public static void Calculator_useDecimalPoint__SWIG_0(
            long pointer, Calculator self, boolean value) {
        record("Calculator.use_decimal_point", value);
    }

    public static void Calculator_clearMessages(long pointer, Calculator self) {
    }

    /**
     * 中文：原样返回输入串。真引擎会把本地化的函数名与符号换成内部写法，替身**不模拟**这一步
     *       （那正是「只说得出递了什么、说不出引擎会怎么读」那条边界）；调用名守卫看到的因此
     *       就是测试自己摆的那串字。
     * English: returns its input unchanged. The real engine rewrites localised names and symbols into
     *          its internal spelling; the double does **not** emulate that (that is exactly the
     *          boundary "it can say what was handed over, never how the engine reads it"), so the
     *          call-name guard sees the very string the test staged.
     */
    public static String Calculator_unlocalizeExpression__SWIG_0(
            long pointer, Calculator self, String expression, long parseOptions,
            ParseOptions parseOptionsSelf) {
        return expression;
    }

    public static long Calculator_getFunction__SWIG_0(
            long pointer, Calculator self, String name) {
        return FUNCTIONS.contains(name) ? allocate() : 0L;
    }

    public static long Calculator_getVariable__SWIG_0(
            long pointer, Calculator self, String name) {
        return VARIABLES.contains(name) ? allocate() : 0L;
    }

    public static long Calculator_getUnit__SWIG_0(
            long pointer, Calculator self, String name) {
        return UNITS.contains(name) ? allocate() : 0L;
    }

    // ------------------------------------------------------------------
    // SWIG 的向上转型胶水：`Variable(long, boolean)` 之类的构造器第一步就调用它，把派生类的
    // 指针转成基类指针。这里的指针只是个编号，原样返回即可（测试只判 null / 非 null）。
    // SWIG's upcast glue: constructors such as `Variable(long, boolean)` call it as their first
    // step to turn a derived pointer into a base one. Here the pointer is just a number, so it is
    // returned unchanged (the tests only tell null from non-null).
    // ------------------------------------------------------------------

    public static long Variable_SWIGUpcast(long pointer) {
        return pointer;
    }

    public static long MathFunction_SWIGUpcast(long pointer) {
        return pointer;
    }

    public static long Unit_SWIGUpcast(long pointer) {
        return pointer;
    }

    public static void delete_ExpressionItem(long pointer) {
    }

    public static void delete_Variable(long pointer) {
    }

    public static void delete_MathFunction(long pointer) {
    }

    public static void delete_Unit(long pointer) {
    }
}
