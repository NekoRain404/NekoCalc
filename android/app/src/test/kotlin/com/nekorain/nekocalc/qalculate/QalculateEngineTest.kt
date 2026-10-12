package com.nekorain.nekocalc.qalculate

import com.jherkenhoff.libqalculate.libqalculateJNI
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * 中文：`QalculateEngine` 的**回执**里那条事实：`loadGlobalDefinitions()` 到底成没成。
 *
 *       这条事实存在的理由是 §5o 记下的那个缺陷：求值里唯一一次全局定义加载（单位、常数、函数）
 *       的返回值此前**只写进 logcat**，于是 Dart 分不出「引擎没有单位」与「引擎给了一个答案」——
 *       同一个错值看起来与真值一模一样。现在它跟着回执过 channel（`definitionsLoaded`），
 *       这一组钉的就是它**真的在回执里**、而且跟着真假走。
 *
 *       它是怎么在宿主 JVM 上跑起来的：`QalculateEngine(loadNativeLibrary = {})` 把
 *       `System.loadLibrary` 那一步换成空操作（宿主上没有 `libqalculate_swig.so`，不换就必然
 *       抛 `UnsatisfiedLinkError`）；AAR 自己的 SWIG 胶水照旧由
 *       `app/src/test/java/com/jherkenhoff/libqalculate/libqalculateJNI.java` 那份替身接住。
 *
 *       ⚠️ **走得到的是「调用名守卫」那一条出口。** 表达式里带一个引擎不认识的调用名
 *       （这里符号表是空的，所以任何一个函数名都算不认识）时，求值在守卫那一行就返回，
 *       回执里带着 `definitionsLoaded`——**这就是本组覆盖的那一份回执**。
 *       另一份（求值成功那份 map）在宿主上走不到：它要一个活的 `MathStructure`（`calculate`、
 *       `print` 全是 native），用替身摆出来的树只能证明替身的行为——那是自欺，所以那一份
 *       **不在这里**，两边共用同一个局部值（`evaluateOnEngine` 里的 `definitionsLoadedEntry`），
 *       由阅读与编译保证；本文件只声明它没有测试这一个事实。
 *
 *       替身**不模拟 C++ 语义**：`setGlobalDefinitionsLoadable` 摆的是「真机会返回什么」，
 *       不是「真机怎么得出这个值」。
 *
 * English: **one fact in `QalculateEngine`'s receipt**: whether `loadGlobalDefinitions()` succeeded.
 *
 *          Why that fact has to exist is the defect §5o recorded: the return value of the single
 *          global-definitions load (units, constants, functions) used to **go to logcat only**, so
 *          Dart could not tell "the engine has no units" from "the engine gave an answer" — a wrong
 *          value looked exactly like a right one. It now travels with the receipt
 *          (`definitionsLoaded`), and this group pins that it **really is in the receipt** and
 *          follows the load's truth value.
 *
 *          How it runs on a host JVM: `QalculateEngine(loadNativeLibrary = {})` turns the
 *          `System.loadLibrary` step into a no-op (there is no `libqalculate_swig.so` on the host, so
 *          without it the call throws `UnsatisfiedLinkError`), while the AAR's own SWIG glue is still
 *          caught by the double at
 *          `app/src/test/java/com/jherkenhoff/libqalculate/libqalculateJNI.java`.
 *
 *          ⚠️ **The exit this group reaches is the call-name guard.** When the expression holds a call
 *          name the engine does not know (the symbol table is empty here, so every function name
 *          counts as unknown) the evaluation returns at that guard and its receipt carries
 *          `definitionsLoaded` — **that is the receipt this group covers**. The other one (the
 *          successful evaluation's map) is unreachable on a host: it wants a live `MathStructure`
 *          (`calculate` and `print` are native through and through), and a tree staged by a double
 *          could only prove the double's behaviour — self-deception — so it is **not here**. Both
 *          maps share one local value (`definitionsLoadedEntry` in `evaluateOnEngine`), which reading
 *          and compilation keep in step; this file only states the fact that it has no test.
 *
 *          The double does **not** emulate the C++ semantics: `setGlobalDefinitionsLoadable` stages
 *          *what a device would return*, not *how a device arrives at it*.
 */
class QalculateEngineTest {

    @Before
    fun clearRecording() {
        libqalculateJNI.reset()
        libqalculateJNI.clearSymbolTable()
        libqalculateJNI.setGlobalDefinitionsLoadable(true)
    }

    /** 中文：库加载那一步换成空操作——宿主上没有那个 `.so`。 */
    private fun engine(): QalculateEngine = QalculateEngine(loadNativeLibrary = {})

    /**
     * 中文：**这就是那个静默缺陷的形状。** `loadGlobalDefinitions()` 回 false 时算术照常工作，
     *       但 400 多个单位与所有常数消失；回执必须把这条事实带出去（`false`），否则 Dart 只能
     *       把这台引擎的答案当成真的。符号表是空的，于是 `sqrt(2)` 在调用名守卫那里就被拒绝——
     *       那条出口与求值成功那条出口共用同一个回执字段。
     *
     * English: **this is the shape of the silent defect.** When `loadGlobalDefinitions()` returns
     *          false, arithmetic still works but 400-odd units and every constant are gone; the
     *          receipt has to carry that fact out (`false`) or Dart can only take this engine's
     *          answers for real. The symbol table is empty, so `sqrt(2)` is refused at the call-name
     *          guard — and that exit shares the receipt field with the successful one.
     */
    @Test
    fun `a receipt from an engine whose global definitions failed says so`() {
        libqalculateJNI.setGlobalDefinitionsLoadable(false)

        val receipt = engine().evaluate("sqrt(2)", "RAD")

        // 中文：先钉住走的是守卫那一条出口（符号表空 ⇒ `sqrt` 不认识），否则下面那条断言
        //       可能是在另一条路上偶然成立的。
        // English: first pin the exit (an empty symbol table means `sqrt` is unknown), or the
        //          assertion below could be holding by accident on some other road.
        assertEquals("false", receipt["ok"])
        assertEquals("engine_unrecognised_identifier: sqrt", receipt["error"])
        assertEquals("false", receipt["definitionsLoaded"])
    }

    /**
     * 中文：反面。同一条出口、同一个表达式，只有加载结果不同——回执里那个字段跟着它走
     *       （`true`）。两条一起才说明它是**读出来的**，不是写死的。
     *
     * English: the reverse. Same exit, same expression, only the load's result differs — and the
     *          field follows it (`true`). Only the pair shows the field is **read**, not hardcoded.
     */
    @Test
    fun `a receipt from an engine whose global definitions loaded says so`() {
        libqalculateJNI.setGlobalDefinitionsLoadable(true)

        val receipt = engine().evaluate("sqrt(2)", "RAD")

        assertEquals("false", receipt["ok"])
        assertEquals("true", receipt["definitionsLoaded"])
    }
}
