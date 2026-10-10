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
- ⚠️ **the tool buttons — my first statement of this was wrong, and measuring the buttons themselves
  corrected it.** The `IconButton`s on the text-tool detail screen measure **48×48**, `BoxConstraints(unconstrained)`:

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

**The owner has since been found by reading the source**: `DetailMetric` wraps its copy `IconButton` in
`SizedBox(width: 28, height: 28)` (`tool_widgets.dart:443`) — a repeated small button, which is what the 60 and
70 counts are.

**And enlarging it to 48 dp was tried, and reverted** — it reddens **the same four layout guards** the
aspect-ratio change did, i.e. **it re-introduces the overflow this file just had fixed** (the label row grows
by 20 dp and the cell can no longer hold its content).

⚠️ **So the two gaps are coupled, and neither can be fixed alone**:

| Want | Cost |
|---|---|
| cell holds its content (no overflow) | needs a **shorter** cell or **taller** rows |
| copy button at 48 dp | makes the row **20 dp taller** ⇒ overflow returns |

**Fixing both means changing the cell's proportions *and* the button together, then re-deriving the four
guards' numbers.** That is one coherent piece of work, and it is written down as such rather than attempted
in halves — **which is exactly what happened here: the half was attempted and reverted.**

**Where the audit stands** (a dimension with **zero** coverage before this work):

| Screen | labels | tap targets |
|---|---|---|
| Calculator keypad | ✓ | **✗ 48.3 × 24.2** — HiPER-parity trade-off, owner's call |
| Tools home | ✓ (fixed) | not measured |
| Tool category | ✓ (fixed) | not measured |
| Text tool detail | ✓ | ✓ (after the `IconToolButton` fix) |
| Structured tool detail | ✓ | **✗ 34 × 34 ×N — owner unidentified** |
| Settings | ✓ | ✓ |

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
