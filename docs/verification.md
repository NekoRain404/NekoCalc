# Verification — what is proven, how, and what is not

The long-form measurements, engine probe logs and hand-over narrative live in
`.superpowers/backup/` (gitignored). This file is the **committed** summary.

## 1. How each layer is proven

| Layer | Proven by | Where |
|---|---|---|
| Pure maths (base conversion, Roman numerals, prime factorisation, polynomial factoring, differentiation, arithmetic steps) | unit tests; expected values from an **independent implementation** (sympy / Python `hex` / the engine itself) | `test/core/math/*_test.dart` |
| Engine selection (which answer is taken, which is refused) | controller tests with stub engines returning **measured** engine strings | `test/domain/calculator_engine_*_test.dart` |
| On-screen behaviour of engine-backed features | **a real device** — `flutter test` cannot prove engine behaviour | `.superpowers/backup/engine-capability-probe.md` §6, §8 |
| Tool registration | guards: catalogue tables, name/description/field tables, two source whitelists | `test/features/tool_*_test.dart` |
| Tools reachable **on screen** | widget tests that open the tool and assert its output | `test/features/new_text_tools_screen_test.dart` |
| Accessibility labels | Flutter's `labeledTapTargetGuideline`, at device size | `test/features/calculator_accessibility_test.dart` |

## 2. Baselines (measured 2026-09-30; numbers, not impressions)

| Quantity | Value |
|---|---|
| Release APK, `--split-per-abi` arm64-v8a | 32.6 MB |
| Cold start `am start -W` | debug 1.75 s / **release 0.33 s** |
| Engine call, host, bridge's own sequence | first call 16 ms (lazy `loadGlobalDefinitions`), then 0.02–0.6 ms |
| Memory, release, idle | TOTAL PSS 216 MB |

⚠️ **Baselines, not comparisons**: HiPER's own figures were not obtainable (seven sources tried).

## 3. Where this project is *more correct than the engine*

- `factor(x^2+2x+1)` — the engine hands the input back; this app returns `(x+1)²`.
- `roman(10000)` / `roman(-1)` / `roman(0)` — the engine returns `"10000"` / `"-I"` / the number `0`;
  this app refuses, because none has a canonical spelling.
- Step-by-step differentiation — the engine gives no derivation at all.

## 4. Where it is **below** the platform's own standard

`androidTapTargetGuideline` (every tappable ≥ 48 dp) fails in **two** places, both measured:

| Where | Measured | Code |
|---|---|---|
| Calculator keypad — every row | **48.3 × 24.2 dp** | `hiper_keypad_function_rows.dart` |
| Tool detail screen — the paste / clear / copy buttons | **36 × 36 dp** | `text_tool_detail_screen.dart:405, 410, 471, 503` |

Both are deliberately **not** fixed:

- the keypad's rows are **laid out to match HiPER** and raising them shoves the whole keypad around;
- the tool buttons are stock `IconButton`s whose size comes from the **theme's density**, so changing
  them is a theme-level decision, not a local edit.

⚠️ **They are not the same defect**: the keypad one is a HiPER-parity trade-off, the tool one is a
theme-density consequence. Both are the owner's call; the numbers are here so the call has evidence.

`labeledTapTargetGuideline` passes on the screens measured so far — **four unnamed buttons were found
and fixed**: the keypad's figure-faced `[matrix]` key (no text for `InkWell` to derive from; see
`calculator_keypad.dart`'s `_variantFace`), the tools home's search button, and the category screen's
back + search buttons (`IconButton` with no `tooltip`). A repo-wide scan for "`IconButton` with no
`tooltip`" now comes back clean.

⚠️ **Not yet measured**: the structured **tool detail screen** and the settings screen. Adding the former
to `calculator_accessibility_test.dart` hit a **layout assertion** (the screen overflows at the test's
360×800 surface), which is a harness problem, not a finding — **it is unwired here, not unmeasured**, and
that distinction is the point of this file.

Numbers in `.superpowers/backup/comparison-with-hiper.md` §11.

## 5. What is **not** verified

- HiPER's own figures (size, version, memory) — seven sources tried, all blocked.
- Appearance / interaction versus HiPER — nothing measured.
- Device-side **pure** evaluation latency — the end-to-end path is measured, the evaluation alone is not.
  The decision-relevant part *is*: the controller's `engineTimeout` is 5 s and a mid-weight symbolic sum
  exceeds it.
- Camera / natural-language input — not implemented (engineering scale, not a defect).

## 5b. A layout defect found by measuring (open)

The structured **tool detail screen** overflows on **every phone size tested**
(360×640 / 360×800 / 411×731 / 412×915): `A RenderFlex overflowed by 12 pixels on the bottom`, the
offending tree being

```
Column ← Padding ← DecoratedBox ← Container ← DetailMetric
```

i.e. **a result-card cell** (`tool_widgets.dart:420`) whose content (label + value + unit) is taller than
its grid cell. The cells are sized by **`childAspectRatio: 1.55`** (`tool_detail_screen.dart:313`), which
is wider than tall.

**Why this was invisible until now**: in a release build an overflow does not paint the yellow/black
stripes — it **clips silently**, so the content is quietly cut rather than loudly wrong.

**Not fixed, and the cost of fixing it is now measured.** I tried `1.55 → 1.35` (which does remove the
overflow — verified at all four sizes) and **four guards went red**:

```
tool_result_label_lengths_test.dart   「那一格的三个数从渲染树里读出来：盒宽 110.0dp…」
tool_field_strings_test.dart  (×2)    「标签那一格的三个数从渲染树里读出来：盒宽 89.1dp…」
tool_result_label_strings_test.dart   「详情页：结果卡…两种语言各是各的」
```

They measure the **result-cell geometry from the render tree** — that is exactly what they exist for, and
they did their job: **the change is not a one-liner, it is a coordinated update of four guards.**

**So the entries are two separate things, and both are recorded**: the overflow is real, and the price of
fixing it is four guard updates plus a proportions decision. **Anyone doing it knows both up front.**

⚠️ **One level deeper**: `tool_result_label_lengths_test.dart` does not merely disagree about a number — it
reports **`boxes` is empty**, i.e. it found **zero** label cells, and its own message says the assertion
would then be **vacuous**.

⚠️⚠️ **And my first explanation of that was wrong — corrected here rather than deleted.** I wrote "so the
guards need to measure at a device-sized surface first". **They already do**: measured,
`grep -c physicalSize` returns **1 / 1 / 2** across
`tool_result_label_lengths_test.dart` / `tool_result_label_strings_test.dart` / `tool_field_strings_test.dart`.
So the cause of the empty `boxes` is **not** the viewport, **and I do not know what it is.**

**The observation stands; the explanation is withdrawn.** Anyone picking this up starts from: the overflow is
real (measured at four sizes), `1.55 → 1.35` removes it (measured), and the four guards then redden with
`boxes` empty for a reason that is **still open**.

**What has been ruled out, and what has not** (so the next attempt does not repeat it):

| Checked | Result |
|---|---|
| Is the surface too short? | **No** — that guard uses `Size(360*3, 2200*3)`, so cards cannot be pushed off |
| Do the guards set a device surface? | **Yes** — `physicalSize` is set in all three |
| Does the screen throw before layout (which would leave no `Text` widgets at all)? | **No** — tested: with `1.35` applied the guard reports a **`TestFailure`** (its own assertion), not an exception during layout. That candidate is ruled out. |

**Four candidates examined, and the cause is still unexplained — the evidence now contradicts itself:**

| Checked | Result |
|---|---|
| Is the assertion running at the default 800×600 surface? | **No** — the `boxes` assertion (`:105`) is inside the same `testWidgets` that sets `physicalSize = Size(360*3, 2200*3)` (`:63`) |
| Does `DetailMetric`'s label have `maxLines: 1` / `fontSize: 12` only under some condition? | **No** — read the source: `tool_widgets.dart:436` renders that `Text` **unconditionally**, with `maxLines: 1` and `fontSize: 12` |
| Does the screen render anything at all at `1.35`? | **Yes** — a probe at `1.35` found **73** non-empty `Text` widgets |

**So the source says "that label always exists", the probe says "73 texts are there", and the guard says
"zero match". Three facts that cannot all be true of one run.** The most likely remaining difference is that
**the guard and my probe are not looking at the same screen state** (different fixture / different tool /
different point in the pump), and that is the first thing to check next — not the ratio.

**Narrowed once more**: the guard and the probe use the **same tool** (`toolById('battery_life')`), so the
difference is not which screen. The two remaining deltas are:

1. the guard uses **`const _EmptyDatabase()`**, the probe used a stub whose `noSuchMethod` returns
   `Future<void>.value()`;
2. the guard **pre-pumps `const MaterialApp(home: SizedBox.shrink())`** and `pump()`s before mounting the
   screen — the probe went straight to the screen.

**And that pair has now been tested — the answer is "neither".** A probe that mimics the guard's fixture
exactly (`const _EmptyDb()`, the `SizedBox.shrink()` pre-pump, `toolById('battery_life')`, the 360×2200
surface) reports, **at `1.35`**:

```
MIMIC maxLines1+size12 = 14
```

**Fourteen matching cells at the new ratio.** So the taller cells do **not** make the labels disappear, and
**the ratio is not why that guard's `boxes` is empty** — which also means my earlier reading ("the change
reddens four guards *because* the cells vanish") was **wrong about the mechanism**.

**What is still true**: the four guards do redden when the ratio changes, and one of them reports `boxes`
empty. **What is no longer believed**: that the ratio makes the cells vanish. **The next attempt should read
that guard's own body line by line** — the difference is inside it, not in the fixture and not in the ratio.

⚠️ **This is written down because a contradiction is more useful than a tidy guess.** Everything else about
this defect is measured; only this last step is open.

## 6. Three mechanical checks that exist because of repeated mistakes

All three guard the **same shape**: an action that did nothing looks exactly like one that ran
and had no effect.

| Check | Guards against |
|---|---|
| `test/features/math_reachability_test.dart` | a file under `lib/core/math/` that **nothing references** |
| `test/features/new_text_tools_screen_test.dart` | a tool **registered but unreachable on screen** |
| `tool/pull_device_db.sh` | pulling the SQLite database **without its `-wal`** (reads a stale value) |

⚠️ **Measuring trap, learned the hard way**: `meetsGuideline` reports failures **asynchronously** —
`expect(...)` does not throw. try/catch cannot be used to see whether it passes.
