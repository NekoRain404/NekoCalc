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

## 2. Baselines (measured 2026-09-30; **two of them re-checked 2026-10-10**)

| Quantity | Value | Re-checked 2026-10-10 |
|---|---|---|
| Release APK, `--split-per-abi` arm64-v8a | 32.6 MB | **32.64 MB — unchanged** |
| Cold start `am start -W` | debug 1.75 s / **release 0.33 s** | **debug 1.75–1.76 s** (`1913 / 1761 / 1754` ms; the first is the run right after `force-stop`). **Release not re-measured** — see below |
| Engine call, host, bridge's own sequence | first call 16 ms (lazy `loadGlobalDefinitions`), then 0.02–0.6 ms | not re-measured |
| Memory, release, idle | TOTAL PSS 216 MB | **not re-measured.** (Debug idle measured at **391 MiB / 400,259 KB** — a *different build type*, **not comparable to 216 MB**) |

⚠️ **Why the two release numbers were not re-measured.** Both need a **release APK installed**, and the device
carries the **debug** build (`versionCode=2009`). Installing release (`4009`) upgrades past it and then **blocks
the debug build** (`INSTALL_FAILED_VERSION_DOWNGRADE`), whose only recovery is **uninstall + reinstall + restore
the database** — that is, the app's own data. **The measurement was declined deliberately, not missed**; the
numbers above are still the 2026-09-30 ones and are marked as such. The debug rows were refreshed because
launching an already-installed build mutates nothing.

⚠️ **And a trap that nearly produced a false regression.** The *same* arm64-v8a artifact reads **32.64 MB** from
`ls -l` (binary MiB — the unit this table uses) and **"34.2MB"** in Flutter's own build output (decimal MB,
34.2 × 10⁶ bytes). Comparing the build log against this table reports a **1.6 MB regression that does not
exist** — 34.2 × 10⁶ / 2²⁰ = 32.62. **Match the unit before matching the number.**

⚠️ **Baselines, not comparisons**: HiPER's own figures were not obtainable (seven sources tried).

## 3. Where this project is *more correct than the engine*

- `factor(x^2+2x+1)` — the engine hands the input back; this app returns `(x+1)²`.
- `roman(10000)` / `roman(-1)` / `roman(0)` — the engine returns `"10000"` / `"-I"` / the number `0`;
  this app refuses, because none has a canonical spelling.
- Step-by-step differentiation — the engine gives no derivation at all.

## 4. Where it is **below** the platform's own standard

`androidTapTargetGuideline` (every tappable ≥ 48 dp) fails in the places below. ⚠️ **This table was
re-measured on 2026-10-10** — the first row carried a number that reproduces at **no** screen size and a code
pointer to the wrong file, and the second row's owner is identified and fixed in the prose directly below it.

| Where | Measured (2026-10-10) | Code |
|---|---|---|
| Calculator keypad — the **label bands**, *not* "every row" | bands **9.8–18.8 dp** at the six sizes measured; keys **29.0–46.3 dp**, and **clearing 48 at 412×915** | geometry: `calculator_keypad.dart` (`_row`'s two `Expanded`, `_bandCell`, `_keyButton`). `hiper_keypad_function_rows.dart` is the row/label **table**, not the geometry |
| Structured tool detail — **three** classes | **12 × `34×34`** steppers (增大/减小), **14 × `28×28`** copy buttons (复制此项), **1 × `119×32`** input field | `tool_detail_screen.dart:512`, `tool_widgets.dart` |
| Calculator display (status row) — **fixed 2026-10-10** | ☰ was **`40 × 40`**, `More...` **`111.7 × 34.0`** → both 48; display floor 176 → 182 dp | `display_status_row.dart` |

⚠️ **Only one of these is deliberately left unfixed:**

- **The keypad's label bands** — the keypad is **laid out to match HiPER** and raising either strip shoves the
  whole keypad around. (Corrected 2026-10-10: this used to say "the keypad's *rows*", and the rows are not what
  fails — the *bands* are, and the keys clear 48 at 412×915.)
- ⚠️ **The `36 × 36` — my first statement of this was wrong, and measuring the buttons themselves corrected
  it.** (Resolved: it was this project's own `IconToolButton`, 36 → 48, further down.) The `IconButton`s on the
  text-tool detail screen measure **48×48**, `BoxConstraints(unconstrained)`:

  ```
  BTN size=Size(48.0, 48.0) constraints=BoxConstraints(unconstrained)   (×3)
  ```

  So **the buttons are not 36 dp.** What `androidTapTargetGuideline` flagged as a `36×36` *semantics node*
  is therefore something else on that screen, and "the paste / clear / copy buttons are 36 dp" —
  which this file said one revision ago — **is withdrawn**.

  **And the "prime candidate" is dead too**: every `IconButton` on that screen was measured, not just the
  first three —

  ```
  BTN total=4        (nothing printed for "size != 48")
  ```

  **All four are 48×48**, including the `IconButton.filledTonal(iconSize: 18)` one. So **the `36×36` semantics
  node is not an `IconButton` at all**, and which widget owns it is **still unidentified**.

  **Two guesses had to be withdrawn** ("the buttons are 36 dp", then "it is the `iconSize: 18` one") before
  the tree itself named the owner — walking `find.byType(Semantics)` and printing the **ancestor chain** of
  every node under 48 dp gave it in one run:

  ```
  NODE size=Size(36.0, 36.0)
    chain = _OverlayPortal < OverlayPortal < RawTooltip < Tooltip < **IconToolButton** < Row < …
  ```

  **`IconToolButton` is this project's own widget**, not a Flutter one — which is exactly why grepping for
  `IconButton` kept coming up empty. And its cause is one hard-coded number
  (`lib/shared/presentation/app_chrome.dart:64`):

  ```dart
  width: 36,
  ```

  **So the root cause was a shared chrome widget pinning its box to 36 dp — and it is now fixed.** The
  `InkWell` is wrapped in a `SizedBox(48, 48)` + `Center`, giving **a 48 dp tap target around the unchanged
  36 dp visual**. Verified two ways:

  - `androidTapTargetGuideline` on that screen: **passes** (it was `36 × 36` before);
  - the full suite: **1806 pass** — so the footprint change (36 → 48) broke **no** layout guard.

  **This fixes every `IconToolButton` in the app at once**, which is why it was worth measuring rather than
  guessing: two guesses about which *Flutter* widget was at fault cost budget, and the run that printed the
  ancestor chain named the project's own widget in one probe.

  **The transferable part**: two guesses were wrong and cost budget; the run that printed the ancestor chain
  cost one probe and was right. **When a measurement can name the owner, take that instead of guessing the
  class.**

`labeledTapTargetGuideline` passes on the screens measured so far — **four unnamed buttons were found
and fixed**: the keypad's figure-faced `[matrix]` key (no text for `InkWell` to derive from; see
`calculator_keypad.dart`'s `_variantFace`), the tools home's search button, and the category screen's
back + search buttons (`IconButton` with no `tooltip`). A repo-wide scan for "`IconButton` with no
`tooltip`" now comes back clean.

⚠️ **"Not yet measured" — now measured, and the harness problem was solved without touching the screen.**
This paragraph used to say the structured **tool detail screen** and the settings screen were unmeasured;
adding the former to `calculator_accessibility_test.dart` hit a **layout assertion** (the screen overflows at
that test's 360×800 surface), which is a harness problem, not a finding. **2026-10-10: measured by pumping the
screen at 360 × 2200 dp instead** — which is a harness change, not a screen change, and is exactly what the
distinction in the sentence above is for. What that walk found is in the table above and in §5c (the three
sub-48 classes, named by tooltip). Also re-measured the same day:

- **Text-tool detail: zero sub-48 tappables** (its tappables are `48×48` ×6, `76×48` ×4, `328×172` ×1) —
  **independent corroboration of the `IconToolButton` fix** recorded further up.
- **`labeledTapTargetGuideline` passes on the structured screen** — so the ✓ that the audit table gives it
  under *labels* is correct, and the `119 × 32` field's three empty semantics strings (label, value, tooltip)
  are **not** a labelling defect. **I nearly recorded them as one**; the guideline check is what stopped it.

Numbers in `.superpowers/backup/comparison-with-hiper.md` §11.

## 5. What is **not** verified

- HiPER's own figures (size, version, memory) — seven sources tried, all blocked.
- Appearance / interaction versus HiPER — nothing measured.
- Device-side **pure** evaluation latency — the end-to-end path is measured, the evaluation alone is not.
  The decision-relevant part *is*: the controller's `engineTimeout` is 5 s and a mid-weight symbolic sum
  exceeds it.
- Camera / natural-language input — not implemented (engineering scale, not a defect).

## 5b. The tool detail screen's overflow — **found, explained, and fixed**

`DetailMetric`'s content (label + value + unit) was **12 px taller than its grid cell**, at **every** phone
size tested (360×640 / 360×800 / 411×731 / 412×915):

```
A RenderFlex overflowed by 12 pixels on the bottom.
Column ← Padding ← DecoratedBox ← Container ← DetailMetric
```

⚠️ **Why it survived so long**: a **release** build does not paint the yellow/black stripes — it **clips
silently**, so the content was quietly cut rather than loudly wrong.

**Fixed** by `childAspectRatio: 1.55 → 1.35` (`tool_detail_screen.dart`), measured at all four sizes: 360 dp
gives a 160 dp-wide cell, 1.55 gives 103 dp (12 px short) and 1.35 gives 118 dp.

### The four guards that "blocked" it were tolerating it on purpose

Each of the four layout guards carried

```dart
expect(knownOverflows, greaterThan(0),
    reason: '那条已知溢出一条都没出现——溢出没了要么是好事（那就把这段拆掉），要么是这屏根本没渲染出来');
```

— i.e. they **required the overflow to be present**. Fixing it made all four red **by design**, and their own
sentence said what to do. All four now read `greaterThanOrEqualTo(0)`, with `others` (the "no *new* exception"
half) left in place.

### ⚠️ And I spent a long detour misreading one of them

I attributed the failures to the **`boxes`** assertion (`一格的单行结果标签都没找到`) and hunted that — six
hypotheses, all ruled out by probes that kept finding the cells. **The actual failing assertion was the
`knownOverflows` one, in the same test.** `boxes` came from a *different, earlier* run whose message I carried
forward without re-reading.

**The lesson is cheap and general**: when a test file has several assertions, **read the one that failed** —
not the first one in the file. Six probes' worth of budget went into a sentence I had mis-attributed.

## 5c. A second tap-target gap, on the **structured** tool detail screen (open)

With the `IconToolButton` fix in (§4), the **text**-tool detail screen passes `androidTapTargetGuideline`.
The **structured** tool screen (`ToolDetailScreen`, e.g. `battery_life`) **does not** — it reports many nodes
of **`34 × 34`**.

Walking the `Semantics` nodes (the method that named `IconToolButton`) finds owners of **40 × 40** and
**24 × 24**, but **not** the `34 × 34` ones:

```
N34 40.0x40.0: _OverlayPortal < OverlayPortal < RawTooltip < Tooltip < DefaultTextStyle
N34 40.0x40.0: Listener < _ExclusiveMouseRegion < Semantics < _OverlayPortal < …
N34 24.0x24.0: Align < Padding < Listener < RawGestureDetector < GestureDetector
N34 24.0x24.0: Icon < Semantics < Align < Padding < Listener < …
```

**⚠️ And that sentence was itself wrong — the `34 × 34` nodes do exist, 60 of them.** A census of **every**
semantics node's size on that screen:

```
34x34:60   28x28:70   48x48:37   18x18:36   16x16:28   40x40:24   24x24:11   …
```

`34 × 34: 60` — **sixty nodes**. My ancestor-chain probe *had* been printing them; **my `head -6` cut the output
off before it got there.** So "the owner is unidentified" was **my instrument's fault, not the tree's** — the
same family as the two earlier wrong guesses on this item, and worth recording for that reason:

> **When a probe says "not found", check that the probe printed everything before believing it.**

⚠️ **"The owner has been found" — and that sentence named ONE owner for TWO different populations. Corrected
2026-10-10 by measuring, not by reading.** The semantics walk on `battery_life` (360 × 2200 dp) gives the whole
sub-48 tappable population on that screen, **named by tooltip**:

| size | count | owner (measured — tooltip + ancestor chain from the render tree) |
|---|---|---|
| `28 × 28` | 14 | `DetailMetric`'s copy button — tooltip **`复制此项`** (`tool_widgets.dart`'s `SizedBox(28, 28)` ✓) |
| `34 × 34` | 12 | **`_stepButton`** — tooltips **`增大` / `减小`** (`tool_detail_screen.dart:512`, `SizedBox(34, 34)`) |
| `119 × 32` | 1 | the numeric **`TextField`** — label, value **and** tooltip all empty (see the ⚠️ below) |

**So the `34 × 34` nodes were never the copy button.** They are the **stepper buttons on the input rows**
(`[label][−][field][+]`), a **third** sub-48 class this section had not recorded at all; the copy button is the
`28 × 28` one. The earlier census's 60/70 counts came from a **different viewport** — the *sizes* are what name
the owners, and both were read off the render tree this time.

⚠️ **And the `119 × 32` field is emphatically *not* a labelling defect** — which I checked because the obvious
inference from "label empty, value empty, tooltip empty" is "a screen reader announces nothing". **Measured:
`labeledTapTargetGuideline` PASSES on this screen.** So the ✓ this table gives that screen under *labels* is
correct, and the three empties are recorded here **only** so the next reader does not re-derive the defect I
nearly recorded. (An empty `value` is also just what an empty input looks like.)

**And enlarging the copy button to 48 dp was tried, and reverted** — it reddens **the same four layout guards**
the aspect-ratio change did, i.e. **it re-introduces the overflow this file just had fixed** (the label row grows
by 20 dp and the cell can no longer hold its content). The width half of that coupling is measured further down:
the label box is **exactly 110.00 dp** and the longest English label needs **109.1 dp**.

⚠️ **So the two gaps are coupled, and neither can be fixed alone**:

| Want | Cost |
|---|---|
| cell holds its content (no overflow) | needs a **shorter** cell or **taller** rows |
| copy button at 48 dp | makes the row **20 dp taller** ⇒ overflow returns |

**Fixing both means changing the cell's proportions *and* the button together, then re-deriving the four
guards' numbers.** That is one coherent piece of work, and it is written down as such rather than attempted
in halves — **which is exactly what happened here: the half was attempted and reverted.**

**And the number the coupled fix has to absorb is now measured**: with the copy button at 48 dp the cell
overflows **by 16 pixels** (not 12):

```
详情页上出现了这条已知溢出之外的异常：A RenderFlex overflowed by 16 pixels on the bottom.
```

⚠️ **Why that reddens those four guards while a 12 px overflow did not**: `_DetailErrors._collect` tolerates
one **exact** string — `'A RenderFlex overflowed by 12 pixels on the bottom'` **and** `DetailMetric` in the
information. A **16 px** overflow matches neither, so it lands in `others`, and `expect(others, isEmpty)`
goes red. **The tolerance is a literal, not a rule** — which is worth knowing before "fixing" it.

**So the coupled change was attempted in full** (button 48 dp **and** `childAspectRatio` 1.35 → 1.15) — and
**it works for the overflow**: the failure becomes a single sentence from a guard,

```
标签那一格实测 90.0dp，与记下的 110.0 dp 不同——布局动过，下面按这个宽度算的判据就都不成立了
```

**110.0 − 90.0 = exactly 20.0** — the 20 dp the copy button grew. So the mechanism is confirmed to the dp:
**the button takes its width out of the label's cell.**

**And that is the third consequence, the one that makes this more than a parameter change.** Those label
guards exist to guarantee that **English labels are not truncated**; a 90 dp cell is 20 dp narrower than the
one that guarantee was measured against (the widest label, `Speed for tgt speed`, is **109.1 dp** — wider than
90). So shrinking the cell to buy the button its tap target **buys it with truncated English labels**.

⚠️ **Which means the naive coupled fix is not available**: it trades one accessibility gap (a 28 dp button) for
another (truncated labels), and the second would need many labels re-abbreviated. **The real options are
structural** — put the copy button *below* or *over* the value instead of beside the label, or accept the
28 dp button. **Both are design calls, and this file now carries the numbers for either.**

### ⚠️ The steppers are the **second** instance of the same coupling — and I predicted it wrong

The other 12 sub-48 nodes on that screen are the **input-row steppers** (`增大` / `减小`, 6 rows × 2). They were
tried at 48 dp on 2026-10-10 and **reverted**, because:

| what | 34dp | 48dp | delta |
|---|---|---|---|
| the row height | 48.0 | 48.0 | **0** |
| the input field | 118.9dp | 102.9dp | **−16.0** |
| the label cell | **89.142857dp** | 77.142857dp | **−12.0** |

**The height is free** — that row's height comes from the `TextField` (already 48), so 34 → 48 costs nothing
vertically. The 28dp of width is split by the two `Expanded`s (`flex: 3` label / `flex: 4` field) as
3/7 × 28 = 12.0 and 4/7 × 28 = 16.0 — matching the table to the digit.

⚠️ **And the 12dp is the whole argument.** The label cell's width is the **denominator** of the English
line criterion in `tool_field_strings_test.dart`
(`_lines = (advance / labelBox).ceil()`, cap **2 lines**). Re-run it with the measured 77.14 and **a screenful
of English labels cross it** — `op_amp_gain.vin` "Input voltage" 84.0dp, `ldo_power.current` "Load current"
81.7dp, `capacitor_charge.c` "Capacitance" 80.3dp, `complex.b` "z1 imag part" 80.7dp, `circle.circumference`
"Circumference" 161.1dp (3 lines), `op_amp_gain.fullPowerFrequency` "Full-power BW" 158.9dp (3 lines) — **a
dozen or more.**

⚠️ **My hypothesis was that this one would be *softer* than the copy button** — this cell's label **wraps**
(no `maxLines: 1`), and wrapping beats truncation. **Measured, it is not softer at all**: the cell width *is*
the criterion's denominator, so narrowing it 12dp tightens the criterion by 12dp. **Same class of coupling,
different symptom** — truncation there, an exceeded line count here. That is worth writing down precisely
because the *prediction* was the error, not the arithmetic.

**And the `IconToolButton` pattern does not buy its way out here**: splitting it into a "34dp visual + 48dp hit
area" saves the *visual*, not the *layout width* — the box is still 48 and the 28dp is still paid. The only
change that actually keeps the width is giving the steppers **their own row**, which is a design change rather
than a parameter. The numbers are in `_stepButton`'s comment in `tool_detail_screen.dart`.

**Where the audit stands** (a dimension with **zero** coverage before this work). ⚠️ **Two rows of this table
were re-measured and rewritten on 2026-10-10** — the keypad row carried a number that reproduces at no
screen size, and the structured row attributed its nodes to the wrong widget. Both corrections are in §5c.

| Screen | labels | tap targets |
|---|---|---|
| Calculator keypad | ✓ | **✗ label bands only**: bands are 9.8–18.8 dp at the six sizes measured and always fail; the **keys** are 29.0–46.3 dp and **clear 48 at 412×915**. HiPER-parity mechanism (§5c) |
| Calculator display (status row) | ✓ | **fixed 2026-10-10**: ☰ was **40 × 40** and `More...` **111.7 × 34.0** → both 48 (display floor 176 → 182 dp) |
| Tools home | ✓ (fixed) | **fixed 2026-10-10**: the one tappable section header (`收藏工具`) was **29 dp** (§5d) |
| Tool category | ✓ (fixed) | same fix — shared `SectionHeader` |
| Text tool detail | ✓ | ✓ (after the `IconToolButton` fix) |
| Structured tool detail | ✓ | **✗ three measured classes** (§5c): 12 × **`34×34`** steppers, 14 × **`28×28`** copy buttons, 1 × **`119×32` unnamed** input |
| Settings | ✓ | ✓ |

### 5d. The two list screens: a **section header** is 29 dp — ⚠️ **and my first reading of this was wrong**

`androidTapTargetGuideline` on both the tools home and the category screen reports the same shape:

```
expected tap target size of at least Size(48.0, 48.0), but found Size(328.0, 29.0)
```

**I first wrote that `328 × 29` was "the tool list item, the app's main navigation target". That was an
inference, and it is wrong.** Walking the **semantics tree** (not the widget tree — that was the previous
probe's mistake) names the nodes directly:

```
SEM 328x29 actions=0       label=推荐工具
SEM 328x29 actions=4194305 label=收藏工具
SEM 328x29 actions=0       label=分类
SEMTOTAL 6
```

**They are section headers**, and only **`收藏工具`** carries a tap action — the other two have `actions=0`.
So the finding is **one tappable section header at 29 dp**, not "every row in the app's main list".

**And the tool rows themselves are not implicated at all**: `ToolListTile` is a `ListTile`, and its own file
comment records a **minimum of 88 dp** in search mode. Nothing here is 29 dp except the headers.

⚠️ **Three corrections of this kind in one day** (`knownOverflows` misread as `boxes`; "the buttons are 36 dp";
now "the rows are 29 dp"). The common shape is the same each time: **an inference about what a measurement was
of, where the measurement was available and I did not take it.** The semantics-tree walk — the instrument the
previous entry said to use — cost one probe and was right.

**Recorded, then fixed (2026-10-10)**: one tappable section header was 29 dp, and it was indeed the small, local
fix the next sentence predicted — **not** a proportions decision about the list, which is what I wrongly told
the reader one revision ago. The fix is a `ConstrainedBox(minHeight: 48)` around the `InkWell`'s child in
`SectionHeader` (`app_chrome.dart`), and it was verified **single-variable**: toggling that one `minHeight`
between **0 and 48** — same screen, same probe, nothing else touched — took the guideline from
`expected tap target size of at least Size(48.0, 48.0), but found Size(328.0, 29.0)` to **pass**. So the node is
provably that one. The text does not move a pixel; the extra height goes below it. ⚠️ **A synthetic
reconstruction of the same shape is a false negative** — I built one and it *passed* the guideline, so this
class of question has to be measured on the real screen.

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
