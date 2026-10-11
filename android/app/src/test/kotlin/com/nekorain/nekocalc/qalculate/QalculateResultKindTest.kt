package com.nekorain.nekocalc.qalculate

import com.jherkenhoff.libqalculate.Calculator
import com.jherkenhoff.libqalculate.libqalculateJNI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

/**
 * 中文：`QalculateResultKind.kt` 里唯一能在宿主 JVM 上摆出输入的是
 *       [firstCallNameUnknownToEngine]——它要的那个 `Calculator` 由测试替身供应（见
 *       `app/src/test/java/com/jherkenhoff/libqalculate/libqalculateJNI.java`）。
 *
 *       **符号表的内容是测试自己摆的，不是对真引擎的断言。** 真引擎那张表（哪些名字是函数/变量/
 *       单位）是在设备上逐条量出来的，出处写在 [firstCallNameUnknownToEngine] 自己的注释里；
 *       这里摆出来的只有守卫逻辑需要的那几个名字。所以这一组测的是**守卫自己的判据**：
 *       - `to` 这个换算词不是调用名，要跳过（第 116 行的 `continue`；那一段的理由在 88-116 行，
 *         是真机上抓到的误判）；
 *       - 函数、变量、单位，**认一个就算认识**（54 行的放宽）；
 *       - 只问「调用」（标识符紧跟左括号），裸标识符不问（36-43 行）；
 *       - 返回**第一个**不认识的名字（120 行）。
 *
 *       另外两个判据（`isPlainQuantity`、`conversionLanded`）**没有**被搬上来：它们的输入是引擎
 *       自己算出来的 `MathStructure` 树与量纲关系，用替身摆出来的树只能证明替身的行为，证明不了
 *       真实分类——那是自欺，所以宁可留白。
 *
 * English: the only predicate in `QalculateResultKind.kt` whose input can be staged on the host JVM
 *          is [firstCallNameUnknownToEngine] — the `Calculator` it wants comes from the test double at
 *          `app/src/test/java/com/jherkenhoff/libqalculate/libqalculateJNI.java`.
 *
 *          **The symbol table's contents are put there by the tests, not a claim about the real
 *          engine.** The real engine's table (which names are functions/variables/units) was measured
 *          one by one on a device, with its sources in the notes on [firstCallNameUnknownToEngine]
 *          itself; only the names the guard logic needs are staged here. So this group tests **the
 *          guard's own judgements**:
 *          - the conversion word `to` is not a call name and must be skipped (the `continue` at line
 *            116; the reasoning in that block, 88-116, is a misjudgement caught on a real device);
 *          - function, variable or unit — **any one of the three counts as recognised** (the
 *            relaxation at line 54);
 *          - only *calls* are asked about (an identifier immediately followed by a bracket); bare
 *            identifiers are not (36-43);
 *          - the **first** unrecognised name is the one returned (line 120).
 *
 *          The other two predicates (`isPlainQuantity`, `conversionLanded`) are deliberately **not**
 *          staged here: their inputs are `MathStructure` trees and dimensional relations the engine
 *          computed itself, and a tree built by a double could only prove the double's behaviour, not
 *          the real classification — that would be self-deception, so the gap is left open and named.
 */
class QalculateResultKindTest {

    @Before
    fun clearSymbolTable() {
        libqalculateJNI.clearSymbolTable()
        libqalculateJNI.reset()
    }

    /** 中文：替身接住 `Calculator()` 的 native 构造器，符号表见上面那一段。 */
    private fun engine(): Calculator = Calculator()

    /**
     * 中文：**这一条就是真机上那个 bug 的形状。** 翻译器把换算写成
     *       `((((5)*(km))) to (mi))`（`engine_expression.dart` 的 `_wordOperator`），而
     *       `CALL_NAME` 允许名字与 `(` 之间有空白，于是 `to (mi)` 看起来像一次叫 `to` 的调用——
     *       引擎的符号表里三者皆无，判据于是拒绝，屏幕上出现「存在无法识别的内容」。
     *       第 116 行的 `continue` 要求：`to` 跳过。
     *
     * English: **this is the shape of the bug caught on a real device.** The translation writes a
     *          conversion as `((((5)*(km))) to (mi))` (`_wordOperator` in `engine_expression.dart`),
     *          and `CALL_NAME` allows whitespace between a name and `(`, so `to (mi)` looks like a
     *          call to `to` — the engine's symbol table has none of the three under that name, so the
     *          judgement refuses it and the screen says "unrecognised content". The `continue` at
     *          line 116 requires `to` to be skipped.
     */
    @Test
    fun `the translation's own to-keyword is skipped, not reported as an unknown call`() {
        libqalculateJNI.knowUnit("km", "mi")

        assertNull(firstCallNameUnknownToEngine(engine(), "((((5)*(km))) to (mi))"))
        // 同样的跳过也发生在没加括号的写法上（用户可能真的这么敲）。
        assertNull(firstCallNameUnknownToEngine(engine(), "5 km to mi"))
    }

    /**
     * 中文：认不认识是「函数 / 变量 / 单位」三选一（54 行）。`i(2)` 是那一段点名的情形：
     *       `i` 在引擎里是变量，`i(2)` 是隐式乘法，不是调用。
     *
     * English: recognition is "function, variable or unit" (line 54). `i(2)` is the case that block
     *          names: `i` is one of the engine's variables and `i(2)` is an implicit product, not a
     *          call.
     */
    @Test
    fun `a name the engine has only as a variable or a unit still counts as recognised`() {
        libqalculateJNI.knowVariable("i", "e", "pi")
        libqalculateJNI.knowUnit("deg", "rad")
        libqalculateJNI.knowFunction("sqrt")

        assertNull(firstCallNameUnknownToEngine(engine(), "i(2)"))
        assertNull(firstCallNameUnknownToEngine(engine(), "e(2)"))
        assertNull(firstCallNameUnknownToEngine(engine(), "pi(2)"))
        assertNull(firstCallNameUnknownToEngine(engine(), "deg(2)"))
        assertNull(firstCallNameUnknownToEngine(engine(), "sqrt(2)"))
    }

    /**
     * 中文：不认识的调用名照旧报出来，而且报的是**第一个**——守卫的返回值就是它
     *       （120 行的 `return name`）。
     *
     * English: an unrecognised call name is still reported, and it is the **first** one — that is
     *          what the guard returns (line 120's `return name`).
     */
    @Test
    fun `the first call name the symbol table does not know is the one reported`() {
        libqalculateJNI.knowFunction("sqrt")

        assertEquals("npr", firstCallNameUnknownToEngine(engine(), "sqrt(2) + npr(3,2)"))
        assertEquals("foo", firstCallNameUnknownToEngine(engine(), "foo(1) + bar(2)"))
    }

    /**
     * 中文：只问调用（36-43 行）。裸标识符由引擎的变量/单位表管，不是同一个问题，所以
     *       `2x`、`5 km` 这种输入在这里一个字都不该被报出来。
     *
     * English: only calls are asked about (36-43). Bare identifiers belong to the engine's
     *          variable/unit tables and are a different question, so inputs like `2x` or `5 km`
     *          report nothing here.
     */
    @Test
    fun `bare identifiers are not calls and are never reported`() {
        assertNull(firstCallNameUnknownToEngine(engine(), "2x"))
        assertNull(firstCallNameUnknownToEngine(engine(), "5 km"))
        assertNull(firstCallNameUnknownToEngine(engine(), ""))
        assertNull(firstCallNameUnknownToEngine(engine(), "1 + 2"))
    }

    /**
     * 中文：那一行跳过是**字面比较**（116 行的 `name == QalculateEngine.WORD_OPERATOR_TO`），
     *       所以大写 `TO` 不会被跳过、会被当成不认识的调用名报出来。这一条是在给边界留档：翻译器
     *       今天只写小写 `to`（`_binaryOperators` 里唯一的字母运算符），所以实际到不了这里。
     *
     * English: that skip is a **literal comparison** (line 116's
     *          `name == QalculateEngine.WORD_OPERATOR_TO`), so an upper-case `TO` is not skipped and
     *          is reported as an unknown call name. This one records the boundary: the translation
     *          writes lower-case `to` only (the single alphabetic operator in `_binaryOperators`), so
     *          it cannot reach here in practice.
     */
    @Test
    fun `the to-skip is an exact lower-case match`() {
        libqalculateJNI.knowUnit("km", "mi")

        // 形状与翻译器写出的一样（名字与括号相邻、前面有空格），只是 `to` 换成了大写。
        assertEquals("TO", firstCallNameUnknownToEngine(engine(), "5 km TO (mi)"))
    }
}
