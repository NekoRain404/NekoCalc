package com.nekorain.nekocalc.qalculate

import com.jherkenhoff.libqalculate.AngleUnit
import com.jherkenhoff.libqalculate.ApproximationMode
import com.jherkenhoff.libqalculate.DigitGrouping
import com.jherkenhoff.libqalculate.IntervalDisplay
import com.jherkenhoff.libqalculate.MixedUnitsConversion
import com.jherkenhoff.libqalculate.NumberFractionFormat
import com.jherkenhoff.libqalculate.libqalculateJNI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Before
import org.junit.Test

/**
 * 中文：`QalculateOptions.kt` 的映射表——**答案会因此改变的那一层**，而且错了不会崩，只会算错。
 *       本仓库此前一条直测都没有：`flutter test` 把引擎整条换成假实现，Kotlin 一行都不执行。
 *
 *       这里跑在宿主 JVM 上（`:app:testDebugUnitTest`），所以 AAR 里那些 native 构造器由
 *       `app/src/test/java/com/jherkenhoff/libqalculate/libqalculateJNI.java` 这份记录型替身接住：
 *       `evaluationOptions(...)` / `printOptions(...)` 照常构造真类、照常 set，每一次 set 都被记成
 *       一条 `"<字段>=<值>"`。下面每条断言里的**期望值都能回指源文件的行号**，没有一个是编的。
 *
 *       替身**不模拟 C++ 语义**：它证明的是「Kotlin 递了哪个值下去」，不是「引擎会印成什么」。
 *
 * English: the mapping tables of `QalculateOptions.kt` — the layer where a mistake changes the
 *          *answer* rather than crashing, and which had no direct test at all in this repository
 *          (`flutter test` swaps the whole engine for a fake, so not a line of Kotlin runs).
 *
 *          These run on the host JVM (`:app:testDebugUnitTest`), so the AAR's native constructors are
 *          caught by the recording double at
 *          `app/src/test/java/com/jherkenhoff/libqalculate/libqalculateJNI.java`:
 *          `evaluationOptions(...)` / `printOptions(...)` still construct the real classes and still
 *          call the setters, and every set is recorded as one `"<field>=<value>"` line. Every
 *          expected value below **points back at a line of the source**; none is invented.
 *
 *          The double does **not** emulate the C++ semantics: it proves which value the Kotlin handed
 *          down, not what the engine prints with it.
 */
class QalculateOptionsTest {

    @Before
    fun clearRecording() {
        libqalculateJNI.reset()
    }

    /**
     * 中文：`angleUnitFor` 是唯一不构造任何 AAR 对象的函数（`AngleUnit` 的常量是纯 Java 的
     *       静态实例），所以这一条连替身都不需要。判据是 `QalculateOptions.kt:33-38`：只有
     *       `angleMode.equals("DEG", ignoreCase = true)` 走角度，其余全落进 `else`（第 37 行）。
     *
     * English: `angleUnitFor` is the one function that constructs no AAR object (the `AngleUnit`
     *          constants are plain Java statics), so this case does not even need the double. The rule
     *          is `QalculateOptions.kt:33-38`: only `angleMode.equals("DEG", ignoreCase = true)` means
     *          degrees, everything else falls into the `else` at line 37.
     */
    @Test
    fun `only the literal DEG spells degrees, every other angleMode is radians`() {
        val cases = listOf(
            // 第 34 行：equals(ignoreCase = true)，所以三种大小写都是角度。
            "DEG" to AngleUnit.ANGLE_UNIT_DEGREES,
            "deg" to AngleUnit.ANGLE_UNIT_DEGREES,
            "Deg" to AngleUnit.ANGLE_UNIT_DEGREES,
            // 第 37 行：其余一律弧度（文件头 26-31 行说明的理由——Dart 只发 DEG/RAD）。
            "RAD" to AngleUnit.ANGLE_UNIT_RADIANS,
            "rad" to AngleUnit.ANGLE_UNIT_RADIANS,
            // 引擎自己的枚举名不是这个函数的输入：它比的是字面量 "DEG"，"DEGREES" 落进 else。
            // 第 34 行是一次普通的 equals，没有 trim，所以多一个空格也不算。
            "DEGREES" to AngleUnit.ANGLE_UNIT_RADIANS,
            "DEG " to AngleUnit.ANGLE_UNIT_RADIANS,
            "" to AngleUnit.ANGLE_UNIT_RADIANS,
            "gradians" to AngleUnit.ANGLE_UNIT_RADIANS,
        )

        for ((angleMode, expected) in cases) {
            assertSame("angleMode=<$angleMode>", expected, angleUnitFor(angleMode))
        }
    }

    /**
     * 中文：三个 `approximation` 取值就是 `QalculateEngine.kt` 的三处调用点（TRY_EXACT:180、
     *       EXACT:276、APPROXIMATE:508/514），它们必须原样到达 `setApproximation`（第 44 行）。
     *       另外四条也是逐行读出来的：`allow_complex(true)`（45）、混合单位关掉（75）、角度单位
     *       落在 `parse_options` 上（87）、逗号不是分隔符（122）。
     *
     * English: the three `approximation` values are the three call sites in `QalculateEngine.kt`
     *          (TRY_EXACT:180, EXACT:276, APPROXIMATE:195/508/514) and must arrive at
     *          `setApproximation` unchanged (line 44). The other four are read off the file the same
     *          way: `allow_complex(true)` (45), mixed units off (75), the angle unit lands on
     *          `parse_options` (87), and a comma is not a separator (122).
     */
    @Test
    fun `evaluationOptions hands down each call site's approximation and the angle unit`() {
        val cases = listOf(
            ApproximationMode.APPROXIMATION_TRY_EXACT to AngleUnit.ANGLE_UNIT_DEGREES,
            ApproximationMode.APPROXIMATION_EXACT to AngleUnit.ANGLE_UNIT_RADIANS,
            ApproximationMode.APPROXIMATION_APPROXIMATE to AngleUnit.ANGLE_UNIT_DEGREES,
        )

        for ((approximation, angleUnit) in cases) {
            libqalculateJNI.reset()
            evaluationOptions(approximation, angleUnit)

            assertEquals(
                "approximation=${approximation.swigValue()}, angleUnit=${angleUnit.swigValue()}",
                listOf(
                    "EvaluationOptions.approximation=${approximation.swigValue()}",
                    "EvaluationOptions.allow_complex=true",
                    "EvaluationOptions.mixed_units_conversion=" +
                        "${MixedUnitsConversion.MIXED_UNITS_CONVERSION_NONE.swigValue()}",
                    "ParseOptions.angle_unit=${angleUnit.swigValue()}",
                    "ParseOptions.comma_as_separator=false",
                ),
                libqalculateJNI.events(),
            )
        }
    }

    /**
     * 中文：`number_fraction_format` 的三个取值（`QalculateOptions.kt:185-191`）：`combined`
     *       走第一个分支（187 行的 `FRACTION_COMBINED`）、`fractional` 次之（188 行的
     *       `FRACTION_FRACTIONAL`）、默认是 `FRACTION_DECIMAL`（189 行）。`fractional`/`combined`
     *       同时为真时前者说了算不了——两个都传不是调用方会做的事（文件自己说了，那一段注释），
     *       这里也不替它立规矩。
     *
     * English: the three values of `number_fraction_format` (`QalculateOptions.kt:185-191`):
     *          `combined` takes the first branch (line 187, `FRACTION_COMBINED`), `fractional` the
     *          second (line 188, `FRACTION_FRACTIONAL`), and the default is `FRACTION_DECIMAL`
     *          (line 189). Passing both is not something callers do — the file says so in that same
     *          note — so no rule is invented for it here.
     */
    @Test
    fun `fractional and combined select the two non-decimal fraction spellings`() {
        val cases = listOf(
            Triple(false, false, NumberFractionFormat.FRACTION_DECIMAL),
            Triple(true, false, NumberFractionFormat.FRACTION_FRACTIONAL),
            Triple(false, true, NumberFractionFormat.FRACTION_COMBINED),
        )

        for ((fractional, combined, expected) in cases) {
            libqalculateJNI.reset()
            printOptions(latex = true, fractional = fractional, combined = combined)

            assertEquals(
                "fractional=$fractional combined=$combined",
                expected.swigValue(),
                libqalculateJNI.field("PrintOptions.number_fraction_format"),
            )
        }
    }

    /**
     * 中文：`latex = true` 那一份的**全部**取值，一条不多一条不少：分数写法定在
     *       `FRACTION_DECIMAL`（189 行的默认支）、Unicode 符号关（199 行，取值见 292 行的
     *       `UNICODE_SIGNS_OFF = 0`）、区间印中点（215 行）；而 `digit_grouping` 与 `base`
     *       **一次都没有被碰过**——事件表逐字相等就是在断言这一点。
     *
     * English: **every** value the `latex = true` render sets, no more and no less: the fraction
     *          spelling stays `FRACTION_DECIMAL` (the default branch at line 189), Unicode signs are
     *          off (line 199, value from `UNICODE_SIGNS_OFF = 0` at line 292), an interval prints as
     *          its midpoint (line 215); and `digit_grouping` and `base` are **never touched** — the
     *          literal equality of the event list is what asserts that.
     */
    @Test
    fun `the plain latex render sets exactly three fields`() {
        printOptions(latex = true)

        assertEquals(
            listOf(
                "PrintOptions.number_fraction_format=${NumberFractionFormat.FRACTION_DECIMAL.swigValue()}",
                "PrintOptions.use_unicode_signs=0",
                "PrintOptions.interval_display=${IntervalDisplay.INTERVAL_DISPLAY_MIDPOINT.swigValue()}",
            ),
            libqalculateJNI.events(),
        )
    }

    /**
     * 中文：机器可解析那一份（`decimal`）多出**一格**：千分位显式关掉（205 行的
     *       `DIGIT_GROUPING_NONE`），因为 `5,656.854` 到了 Dart 侧是静默的 null。Unicode 符号同样
     *       关着（199 行的 `latex || machineReadable`），负号才不会是 U+2212。
     *
     * English: the machine-readable render (`decimal`) sets **one field more**: digit grouping is
     *          explicitly off (205, `DIGIT_GROUPING_NONE`), because `5,656.854` is a silent null on
     *          the Dart side. Unicode signs are off too (line 199's `latex || machineReadable`), so a
     *          minus sign is never U+2212.
     */
    @Test
    fun `the machine-readable render adds digit grouping off and keeps unicode signs off`() {
        printOptions(latex = false, machineReadable = true)

        assertEquals(
            listOf(
                "PrintOptions.number_fraction_format=${NumberFractionFormat.FRACTION_DECIMAL.swigValue()}",
                "PrintOptions.use_unicode_signs=0",
                "PrintOptions.digit_grouping=${DigitGrouping.DIGIT_GROUPING_NONE.swigValue()}",
                "PrintOptions.interval_display=${IntervalDisplay.INTERVAL_DISPLAY_MIDPOINT.swigValue()}",
            ),
            libqalculateJNI.events(),
        )
    }

    /**
     * 中文：度分秒那一份（`QalculateEngine.kt:519` 的调用点）独有两格：`base` 设成
     *       `BASE_SEXAGESIMAL`（278 行；它的字面量 60 来自 294 行，`includes.h:314`）、千分位
     *       再显式关一次（279 行）。Unicode 符号在这里**开着**——199 行的条件里两个布尔都是
     *       false，所以取 293 行的 `UNICODE_SIGNS_ON = 1`，`°′″` 才是真字符。顺序也是源文件里的
     *       顺序：分数、Unicode、区间、base、千分位。
     *
     * English: the degrees-minutes-seconds render (called at `QalculateEngine.kt:519`) carries two
     *          fields of its own: `base` set to `BASE_SEXAGESIMAL` (line 278 — its literal 60 comes
     *          from line 294, `includes.h:314`) and digit grouping off again (line 279). Unicode signs
     *          are **on** here — both booleans in line 199's condition are false, so it takes
     *          `UNICODE_SIGNS_ON = 1` (line 293) and `°′″` are real characters. The order is the
     *          source's order too: fraction, Unicode, interval, base, digit grouping.
     */
    @Test
    fun `the DMS render sets base to the sexagesimal constant and unicode signs on`() {
        printOptions(latex = false, sexagesimal = true)

        assertEquals(
            listOf(
                "PrintOptions.number_fraction_format=${NumberFractionFormat.FRACTION_DECIMAL.swigValue()}",
                "PrintOptions.use_unicode_signs=1",
                "PrintOptions.interval_display=${IntervalDisplay.INTERVAL_DISPLAY_MIDPOINT.swigValue()}",
                // BASE_SEXAGESIMAL（QalculateOptions.kt:294）的字面量就是 60。
                "PrintOptions.base=60",
                "PrintOptions.digit_grouping=${DigitGrouping.DIGIT_GROUPING_NONE.swigValue()}",
            ),
            libqalculateJNI.events(),
        )
    }
}
