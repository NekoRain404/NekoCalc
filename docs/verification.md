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

## 2. Baselines (measured 2026-09-30; **all but one re-checked 2026-10-10**)

| Quantity | Value | Re-checked 2026-10-10 |
|---|---|---|
| Release APK, `--split-per-abi` arm64-v8a | 32.6 MB | **32.64 MB — unchanged** |
| Cold start `am start -W` | debug 1.75 s / **release 0.33 s** | **debug 1.75–1.76 s** (`1913 / 1761 / 1754` ms; the first is the run right after `force-stop`) and **release 0.32–0.34 s** (`336 / 338 / 319` ms) — both unchanged |
| Engine call, host, bridge's own sequence | first call 16 ms (lazy `loadGlobalDefinitions`), then 0.02–0.6 ms | not re-measured (a host-side sequence, not reachable from the device pass) |
| Memory, release, idle | TOTAL PSS 216 MB | **217,634 KB ≈ 212.5 MiB — unchanged** |

⚠️ **One measurement is deliberately left out of that table**: the **debug** build's idle memory, measured at
**391 MiB (`400259` KB)** during the same pass. It is a **different build type**, so it is **not comparable to
the release `212.5 MiB`** and is recorded here only so nobody compares the two.

⚠️ **I first wrote here that the two release rows "were declined deliberately", and then measured them.** The
reasoning for declining was itself wrong, and the measurement is what refuted it: I assumed the device carried
the **debug** build, so a release install would need an uninstall and would cost the app's data. **It carried a
release-signed build all along** — a debug APK re-signed with the release keystore, which is what the device
recipe in `HANDOVER.md` produces. Verified by pulling the installed APK and reading its certificate:

```
installed base.apk : CN=NekoCalc, OU=NekoRain, ... SHA-256 bbb28c50…2d1007
my app-arm64-v8a-release.apk : CN=NekoCalc, OU=NekoRain, ... SHA-256 bbb28c50…2d1007   ← identical
```

**Same certificate ⇒ `adb install -r` replaces in place and keeps the data** (it also went `2009 → 4009`, an
upgrade, so no downgrade guard fires). Both release rows above come from that install.

⚠️ **The reverse direction is worse than "needs `-d`" — measured, `-d` is not enough on this device.** ⚠️ **And
none of this is new.** `HANDOVER.md` **§十九** — whose heading is "read this before going onto the device" —
recorded the whole trap on **2026-09-30**: the `4009`/`2009` split, all three flags being refused, `run-as`
breaking, and the uninstall + byte-exact database restore it used to recover. **I re-derived it the hard way
because I went onto the device without reading that section**, which is precisely what its heading warns
against; the correction is recorded in §十九 too. Going back
to a debuggable build means installing `2009` over `4009`, and **both entry points refuse it**:

```
adb install -r -d …                  → INSTALL_FAILED_VERSION_DOWNGRADE: Downgrade detected: Update version code 2009 is older than current 4009
adb shell pm install -r -d --user 0 … → same
```

`-d` is documented as "debuggable packages only" and the APK **is** debuggable (verified: `CN=NekoCalc`,
`bbb28c50…`), so this is the ROM refusing the downgrade rather than the flag being omitted.

⚠️ **Consequence: `flutter run` / `flutter install` on this device is blocked while `4009` is installed.** It
builds the **debug** variant at `2009`, a downgrade from `4009`. **The channel itself was recovered, though —
without uninstalling and without touching data**, and the recipe is now a script: `tool/install_debug_over_release.sh`
(written *and run* on 2026-10-10). The move is to build the debug variant at the **installed** versionCode and
re-sign it with the release key, so it is an ordinary replace rather than a downgrade:

```
flutter build apk --debug --build-number=4009      # = the installed release's versionCode
zipalign -f -p 4 … && apksigner sign --ks android/nekocalc-release.jks --out … …
adb install -r …                                   # 4009 over 4009 — a normal replace
```

`--build-number` is what makes this work: it overrides the build number **without editing `pubspec.yaml`**.
Verified afterwards: `pkgFlags=[ DEBUGGABLE … ]`, `versionCode=4009`, and `run-as … ls databases` listing the
database again. **So §十九's "uninstall is the only way back" is true of the *flags* — `-r` / `-d` /
`pm install -r -d` really are all refused — but not of the *problem*.**

⚠️ **And the device's data was verified intact — by row content, not by eye.** Compared against the 2026-09-30
backup **with its `-wal` attached**:

| table | 2026-09-30 | 2026-10-10 |
|---|---|---|
| `calculation_history` | 16 rows, `d9b39a721cd9` | **same fingerprint** |
| `recent_tools` | 12 rows, `3d0427d30c87` | **same fingerprint** |
| `notes` / `favorite_tools` | 0 / 0 | same |
| `app_settings` | 24 rows | 24 rows, **every value identical** |

The only `app_settings` "difference" is a last-touched timestamp on rows whose values are unchanged
(`1790710793363 → 1791639353009` — a delta of exactly the 10.75 days that elapsed, written when the app was
launched for the cold-start runs). **The release install cost the user no data.**

⚠️ **Two comparisons were invalid before that one, and both are the trap this repo already documents.** (1)
Comparing the pulled copy **without its `-wal`** is the "少一个就不是同一份" rule. (2) Letting `sqlite3` **open**
the copy **checkpoints the WAL and deletes the `-wal`/`-shm`**, so the main file's bytes legitimately change (the
header's change counter moves) — which is why the comparison has to be **logical** (row content), not bytewise.

⚠️ **The `versionCode` split itself**: measured, the debug variant is `2009` and release is `4009`, while this
project's `build.gradle.kts` contains only `versionCode = flutter.versionCode` (grepped). So the `+2000` on
release comes from Flutter's own Gradle plugin — **not verified here**, and worth knowing before anyone changes
version numbers by hand.

⚠️ **And a trap that nearly produced a false regression.** The *same* arm64-v8a artifact reads **32.64 MB** from
`ls -l` (binary MiB — the unit this table uses) and **"34.2MB"** in Flutter's own build output (decimal MB,
34.2 × 10⁶ bytes). Comparing the build log against this table reports a **1.6 MB regression that does not
exist** — 34.2 × 10⁶ / 2²⁰ = 32.62. **Match the unit before matching the number.**

⚠️ **Baselines, not comparisons**: HiPER's own figures were not obtainable. (This line sat here **twice** —
a duplication left by a revision — and the tally below replaces both.) The tally, with the **failure mode** of
each, written down so nobody re-walks them:

| route | outcome |
|---|---|
| the Play Store page, direct | a **JS shell**; the figures are not in the served HTML |
| `WebSearch` | **session budget exhausted (200/200)** — re-confirmed by a live attempt on 2026-10-10, not a stale note |
| apkpure / apkcombo / apkmirror | 403 / 410 / 403 |
| the developer's site (`hipercalc.com`) | socket closed |
| a saved copy of the Play page | the same JS shell |
| **`web.archive.org`** (Wayback — the route that *would* have sidestepped the JS problem) | **"Claude Code is unable to fetch from web.archive.org"** — blocked by the fetch tool itself, so this is **not** a dead end that more effort fixes |

**What that leaves, and why it is enough.** The comparison that exists is by **capability**, not by vanity
metrics: `comparison-with-hiper.md` §1's item-by-item table against HiPER's **own v12 manual**, where
「HiPER 有、我们没有」 no longer appears. **Install count, rating and APK size are not reachable from this
environment** — and none of the three would change what gets built. If they are wanted, they have to come from
a source the user supplies.

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
| Structured tool detail — **two fixes, one measured refusal** (2026-10-10) | The **14 × `28×28`** copy buttons use the **whole card** as their target, and the input field's **`119×32`** editable area is fixed by **`isDense: false`** (its box was already 48 ⇒ no layout cost). The **12 × `34×34`** steppers **stay 34** — growing them to 48 was implemented, measured, and reverted: 24 of the 28dp came out of the app's single card-spacing standard, and the only standard-preserving route costs the field half its digit room (§5c) | `tool_detail_screen.dart`, `tool_widgets.dart` |
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
  ⚠️ **And the "decision-relevant part" this bullet used to assert — "the controller's `engineTimeout` is
  5 s and a mid-weight symbolic sum exceeds it" — still has no witness.** A host-side probe on 2026-10-10
  could not reproduce it: with the engine's own argument order (**the variable goes last**), every symbolic
  sum tried **evaluates**, in **0.2–7.9 ms** — the heaviest (`sum(1/n^s, 1, 200, n)`) is ~630× under the 5 s
  budget. The control `sum(x,1,10,x)` returns **`55`** in both approximation modes, which is the value this
  repository's own `calculator_key_dispatch.dart` records for the `Σ` key. So the claim is **not refuted** —
  it simply **never named its witness**, and nothing in the shape its wording suggests comes near it.
  §5e is that probe; §2 is the engine-latency baseline that *is* measured.

  ⚠️ **This bullet carried a false generalisation for one revision, and the cause was my instrument.** The
  first version ran `sum(expr, n, lower, upper)` — the variable in the **middle** — so every case came back
  **unevaluated**, and it was written up as "the engine does not compute it", i.e. as a property of the
  engine. **It was a property of my argument order.** Caught by the app's own comment
  (`calculator_key_dispatch.dart`: 「`sum(x,1,10,x)`=55」) and re-run with the variable last — and that `55`
  is the control that proves the corrected order is the right one.
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

⚠️ **And as of 2026-10-10 it is not a tap-target defect either.** That `119 × 32` node is the field's
**editable area** — a *child* of a render box that was **already 118.86 × 48.00** — so "make the field 48 tall"
was the wrong question (I asked it first, and the measurement said no). `isDense: false` lets the editable area
fill that existing 48, and it **costs no layout**: the box and the row height measure identical before and
after. The screen's sub-48 tappable count goes **1 → 0**, and `tool_detail_screen.dart` now carries a note at
that line saying why it must stay `false` — the next reader's instinct will be to tighten it back.

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

### ✅ 2026-10-10: the copy button is **fixed** — the structural option was taken

The paragraph above lists the structural options and says taking one is a design call. **One was taken**: the
`IconButton` was demoted to decoration (its own `onTap` dropped, the icon kept) and the **whole card** wrapped
in `Tooltip` + `InkWell`. Measured on the structured screen (`battery_life`, 360 × 2200 dp):

| quantity | before | after |
|---|---|---|
| the tappable node | **28 × 28** | **160 × 119** (the whole card) |
| the label box | **110.00 dp** | **110.00 dp — unchanged** |
| sub-48 tappable nodes on that screen | **27** | **13** (12 steppers + 1 input field) |
| `labeledTapTargetGuideline` | passes | **passes** (the name now comes from the wrapping `Tooltip`) |

**So this one did not trade — it resolved.** The target grew ~40× in area and the label gave up **nothing**,
because the icon stayed (as the affordance) and only its *role* changed. That is exactly why "over/around the
card" was listed: it is the only one of the options that costs no width.

⚠️ **It is the `110.00` being identical before and after that makes this a resolution rather than a lucky
escape** — that box is the denominator of the 715-string English criterion, so anything that moved it would
have been a trade in disguise. It was measured, not assumed: the icon's 28dp still occupies that row.

⚠️ **What the change costs**: interaction semantics — tapping anywhere on a card copies it. On this screen a
card has exactly one action, so nothing is displaced. Full suite after: **1807 green**.

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

### ❌ 2026-10-10: the steppers were grown to 48, then **reverted the same day** — consistency outranks them

Every route above spends *text* width. **A route that spends none was found and did work.** A row's **34dp per
side is measured** as page **16** + the `Card`'s margin **4** + the card's `padding` **14**, so reclaiming the
last two plus one gap (`margin: EdgeInsets.zero`, `padding: all(6)`, and the `SizedBox` between the label and
the first stepper **8 → 4**) returned exactly **28dp** — matching the steppers' growth (34 → 48) to the digit.
The flexible space stayed **208** and the text did not move (the steppers really did measure **48.0 × 48.0**, and
the label cell stayed **89.142857 dp**).

**It was reverted because of where those 28dp came from: 24 of them were the app's single card standard.**
`margin 4 → 0` and `padding 14 → 6` is the *only* card in the app that is not `padding: all(14)` + the default
margin (ten `Card` sites measured identical), and the other 4dp came out of a row gap — so the input card became
**the app's one exception to its own spacing rule**, on a screen whose whole job is to look like the rest of the
app. The user's priority is UI consistency, so the exception is not worth 14dp of hit area.

**The one other route that keeps the standard was measured too**: change the row's flex from **3 : 4** to
**1 : 1** — no card is touched, but the field's room for digits drops from about **41dp to 22dp**. That is a real
input defect for a numeric field, so it is out as well.

**Adopted instead: nothing on the steppers; the field's `isDense: false` stays.** That fix costs no layout at all
(its box was already 48 — only the *editable area* was 32), so it is not an exception to anything.

| quantity | value | note |
|---|---|---|
| the steppers | **34 × 34** | unchanged from the start; sub-48 by choice, with the three routes above measured |
| the input field's editable area | **48.0** ✓ | `isDense: false` — **kept**, zero layout cost |
| sub-48 tappable nodes on that screen | **12** | all twelve are the steppers; the field is no longer among them |

⚠️ **A variant that was reverted: reclaim only 20dp — and it costs exactly three English labels.** A row's **34dp per side is measured** as
page **16** + the `Card`'s margin **4** + the card's `padding` **14** (`CARD w=328 left=16`,
`PAD14 w=320 left=20`). Reclaiming the last two (`margin → 0`, `padding → 8`) returns **20dp**, so only the
remaining **8dp** comes out of the text (label : field = 3 : 4):

| what | as it stands | reclaimed + steppers at 48 |
|---|---|---|
| the steppers | 34 × 34 | **48.0 × 48.0** ✓ |
| sub-48 tap targets on that screen | **13** | **1** (the input field alone) ✓ |
| the input field | 118.86 | 114.29 (**−4.57**) |
| the label cell | 89.142857 | **85.714286** (**−3.43**) |

⚠️ **And the price is exactly three English labels.** With `labelBox = 85.714286` the line criterion reports
**exactly three** crossings — `wire_voltage_drop.parallel` "Parallel wires" (86.7dp), `npv.rate` "Discount
rate" (86.2dp), `work_power.distance` "Displacement" (88.4dp); each one's Chinese fits a single line, so its
English is allowed one. **So the reclaim is a trade as well** — unless the padding goes to 4 (visually
cramped), those three are allowed to wrap, or the tightening is generalised to every card on the screen.
**The route was tried in full and reverted** (byte-exact; suite green after).

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
| Structured tool detail | ✓ | **two fixes + one refusal** (2026-10-10): the 14 × **`28×28`** copy buttons (target = the whole card), and the input field's **`119×32`** editable area (**`isDense: false`** — its box was already 48 tall, so this cost no layout). The 12 × **`34×34`** steppers **were grown to 48 and reverted** — that route required 24dp from the app's single card-spacing rule (§5c). **`SUB48 = 12` on that screen now, all twelve being steppers** |
| Settings | ✓ | ✓ |

⚠️ **The same "reclaim the whitespace" question the steppers were fixed with (§5c), asked of the keypad, comes
back negative — and quantified.** The keypad's own padding is `_panelPadding = 6` (**12dp** of vertical
whitespace) plus `_cellInsets = all(1.5)` (**3dp** per row group), and its band/key split is a
`_bandFlex : _mainFlex = 2 : 5` flex inside each row group. Measured, a band is **15.0dp** at 360×800 and there
are **~6 band rows**; bringing each band to 48 needs **+33dp** ⇒ roughly **198dp** of extra height, against
roughly **30dp** of reclaimable padding — **short by a factor of about 6.6**. The keys are short as well
(29.0–46.3dp, each needing between +2 and +19dp).
*(The constants and the heights are measured; the shortfall is arithmetic on them — stated as arithmetic, since
a deduced limit is what hid the steppers' route for a while.)*
**So the keypad is a structural trade, not a whitespace question** — which is what "raising them shoves the whole
keypad around" meant, now with numbers.

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
provably that one. ⚠️ **A synthetic
reconstruction of the same shape is a false negative** — I built one and it *passed* the guideline, so this
class of question has to be measured on the real screen.

⚠️ **And "the text does not move a pixel" — which this section said when it was first written — is itself
wrong.** Caught the same day by re-reading my own commit rather than by any test. `minHeight` alone leaves the
row a `Row(crossAxisAlignment: center)`, so raising it 29 → 48 **centred the title** (down ≈ 9.5dp) while the
**action's text stayed pinned to the top of its stretched box** (up ≈ 3.5dp) — leaving the two texts ≈ 13dp
apart. Measured on the tools home:

| what | after the first attempt |
|---|---|
| the row | `265.0..313.0` (h **48.0**) |
| the title cell | `274.5..303.5` (h 29.0 — centred) |
| the action `Text` | `265.0..305.0` (h **40.0** — stretched by `minHeight`, text at the top) |

The repair: `Center` the action's text in that 48dp band (the same centring the title gets) and drop the 8dp of
bottom padding, which was written for the old 29dp geometry. Alignment then measures **Δcenters = 0.00** and
the guideline still passes (1807 green after).

⚠️ **The generalisable part**: raising one cell of a **centre-aligned** row does not only change that cell's
box — every other cell in the row re-centres. **"The extra height goes below it" is not true in a
centre-aligned row**, and that is exactly the sentence I wrote first.

### 5e. The engine's indefinite integral of a numeric power returns **±infinity** — measured

Probing host-side (`tool/qalculate_semantics_probe/`, libqalculate **5.12.0** — the same version this AAR
bundles) through the same `Calculator::calculate` the bridge enters, with the bridge's own options
(`QalculateOptions.kt`: `allow_complex`, `mixed_units_conversion = NONE`, `angle_unit = RADIANS`,
`comma_as_separator = false`), and **in both approximation modes**, because the app takes two paths
(`APPROXIMATION_EXACT` for the exact form, `APPROXIMATE` for the decimal one):

| input | `APPROXIMATE` | `EXACT` |
|---|---|---|
| `integrate(x^3, x)` | **`-infinity`** | **`-infinity`** |
| `integrate(x^2, x)` | **`+infinity`** | **`+infinity`** |
| `integrate(x^3, 0, 1, x)` | `0.25` ✓ | `0.25` ✓ |
| `integrate(x^2, 0, 1, x)` | `0.3333333333333333` ✓ | same ✓ |
| `integrate(x^n, x)` | `(x * x^n - x * x^n) / (n + 1)` | same |
| **control** `sin(1)` | `0.8414709848078965` | **`sin(1 rad)`** |

**The definite integral is right; the indefinite one is not.** `∫x³dx = x⁴/4`, and the engine answers
`-infinity`. And `integrate(x^n, x)` prints a numerator whose two terms are **textually identical**
(`x·x^n − x·x^n`), which **reads as 0**.

⚠️ **The control row is what makes this trustworthy**: `sin(1)` differs between the two modes exactly as the
app's two-path design requires, so "both modes agree on ±infinity" is a real agreement — not two modes that
were silently the same object.

⚠️ **How far this reaches into the app — carried as far as the repository allows, and no further.**

- **The keypad never produces the indefinite form.** `∫dx` inserts `integrate(x^2,0,1,x)`
  (`calculator_key_dispatch.dart:387`, `case 'ins:integrate'`) — **with bounds** — and that is the branch the
  engine answers **correctly** (`1/3`). So the **key-driven path is safe.**
- ⚠️ **Measured — and it refutes the inference that stood here.** Feeding a stubbed `MathEngine` a reply of
  exactly the shape the host probe says the engine produces (`displayText` / `displayTex` = `±infinity`,
  `decimalText` empty, two different non-quantity kinds) and submitting `integrate(x^3, x)`, a domain-level
  probe found:

  ```
  engineCalls=1   result="函数需要括号"   hasError=true   submitted=false     (×4: ±infinity × 2 kinds)
  ```

  - **`engineCalls=1`** — the engine **was** consulted.
  - **The screen does not carry `-infinity`**: what reaches the user is the legacy parser's message
    (`函数需要括号`, "the function needs brackets").

  So the sentence this replaces — "route 3 returns the engine's text as it stands ⇒ the screen would carry
  `-infinity`" — **is not how it goes. The app does not show it.**

- ⚠️ **And the previous revision's wording over-claimed in turn.** It said "the reply is **rejected before
  display**" — **that is an inference, not what was measured.** What was measured is the four-column line
  above. At least two readings fit it, and nothing measured yet separates them:
  (i) the reply was offered and refused somewhere between the engine and the screen; or
  (ii) the counter's single call came from the **live / as-you-type** path, while the **submit** path never
  used the engine at all (e.g. the translation refused this expression) — in which case the reply was never
  a candidate for display.

  Separating them means following the submit path (which call site the counter saw); getting the *real*
  reply's shape means reproducing the bridge's own print options on the host (`QalculateResultPrints.kt`)
  or reading the bridge off the device.

  **Left here deliberately**: the practically-live facts are established (the engine's behaviour is measured
  above; the key-driven path inserts the definite form and is safe; the app does not display `-infinity`),
  and what is left is a question about a **hand-typed** indefinite integral. The next layer of digging should
  be a deliberate choice, not a reflex — this thread has already had six of its own claims corrected today,
  and the errors were all in the *attributions*, never in the numbers.

- ⚠️ **What is still not established: whether a *real* bridge reply has this shape.** The reply above was
  **synthetic** (its `displayTex` is not valid LaTeX, and a real `resultKind` comes from the Kotlin
  classifier), so the *reason* for the rejection is unknown — a gate on the reply's shape, the `-infinity`
  spelling itself, or the stub being malformed. Settling that needs the real reply (the device's zero-touch
  channel, or a JVM test of the bridge).

**Reproducing the measurement**: `lib/core/math/math_engine.dart` is an interface, so a domain-level test can
carry its own `_FakeMathEngine implements MathEngine`, build the controller, call `setExpression(...)`,
`await controller.submit()`, and read `controller.result` / `hasError` — see `quantity_decimal_places_test.dart`
for the shape. **Add a call counter to the fake**: without it, "the screen says the function needs brackets"
has two very different readings (the engine answered and the display rewrote it, versus the expression never
reaching the engine).

### 5f. The portrait lock (禁止屏幕旋转) — **declared and merged ✓; the device-side rotation test could not be run**

The requirement is "no screen rotation". Two lines implement it, in `AndroidManifest.xml`:

```xml
<activity android:name=".MainActivity" android:screenOrientation="portrait" …>
    <property android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"
              android:value="true" />
```

**Why two and not one.** `targetSdk` is **36** (it follows `flutter.targetSdkVersion`, which Flutter 3.44
resolves to 36 — confirmed by reading `FlutterExtension.kt`, and by the installed package reporting
`targetSdk=36`). Android's behaviour-changes page for API 36 states that for apps targeting 36 the system
**ignores** `screenOrientation`, `resizeableActivity`, `minAspectRatio`/`maxAspectRatio` and
`setRequestedOrientation()` on displays with **smallest width ≥ 600dp** — with `portrait`, `reversePortrait`,
`sensorPortrait` and `userPortrait` named explicitly in the ignored list. The documented opt-out is the
`<property>` above, declared as a child of the **activity** (per-activity form; an `<application>`-level form
also exists). **Worth knowing for later: the opt-out itself expires** — the same page says it will not apply
when targeting **API 37**, so the day `flutter.targetSdkVersion` becomes 37 this lock silently stops working on
tablets and foldables. Phones are unaffected either way, because `sw < 600dp` is an explicit exception to the
whole change. That is also why the plain attribute alone is sufficient on a phone.

**What is verified — mechanically, from the build product rather than from the source**: the merge kept both.
`aapt2 dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-debug.apk` gives

```
E: activity (line=31)
  A: …android:screenOrientation(0x0101001e)=1        ← enum 1 = portrait
    E: property (line=69)
      A: …android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"
      A: …android:value=true
```

and the app launches and runs with it (window measured at `[0,0][1440,3200]`, i.e. the full portrait display).
Checking the **merged** manifest matters here: the property is an unusual element, and a source-level check
would not have shown whether the merge dropped it.

⚠️ **What is NOT verified: that the app actually refuses a rotation — because this device would not rotate.**
Five routes were tried, all of which left `mCurrentRotation=ROTATION_0`:

| route | result |
|---|---|
| `settings put system accelerometer_rotation 0` + `user_rotation 1` | writes confirmed by `settings get` (0, 1), display unmoved |
| `cmd window user-rotation lock 1` | no output, display unmoved |
| `wm user-rotation lock 1` (syntax confirmed via `wm help`) | display unmoved |
| screen power cycle (`input keyevent 26` ×2) to force a re-apply | display unmoved |
| relaunching the activity while the rotation was locked | window `[0,0][1440,3200]`, display still portrait |

So there was **no rotation to resist**, and this measurement cannot answer the question on this hardware/ROM
(rotation appears to be governed by MIUI, which also runs a cover-screen UI, `com.xiaomi.misubscreenui`). All
device settings were restored afterwards (`accelerometer_rotation=1`, `user_rotation=0`). The declaration is
correct per the platform documentation and is present in the installed APK; the on-device *behaviour* is
**untested**, and the untested part is precisely the tablet path, since this device reports **sw = 411dp**
(1440 × 3200 at 560 dpi) and is therefore outside the Android-16 change altogether.

### 5g. UI consistency: a role-based audit of every hard-coded inset and radius (2026-10-10)

**Method.** Rather than arguing about "there are too many different values", every `EdgeInsets.all(N)` and
`BorderRadius.circular(N)` in `lib/` was listed with its **role** — what widget it sits in, and whether that
widget is a top-level surface or nested inside another one. The question is not *how many values exist* but
*does the same role use the same value*.

**Two standards came out real**, both already majority-held:

| standard | uses | what it is |
|---|---|---|
| `EdgeInsets.all(14)` | 16 | the card-content inset — in two spellings that already agree: `Card > Padding(all(14))` and `Container(padding: all(14), decoration: softPanel(...))` |
| `BorderRadius.circular(8)` | 28 | the surface/control radius — `softPanel`'s decoration, `CardThemeData`, every `TextField`, and the ripples clipped to match it |

**The tier rule that emerged: top-level surface = 14, nested tonal block = 12.** Five genuine drifts were fixed
against it (the `fix(ui)` commit of 2026-10-10): `EmptyPanel` 16 → 14 (a *shared* widget — it occupies the
card slot, so one edit aligns every empty state), `graph_page_output.dart`'s marker panel 12 → 14, two
chart-frame radii 10 → 8 (`data_fit_cards.dart` — where the same role 50 lines below in the same file was
already 8 — and `regression_graph_sheet.dart`), and a nested dialog panel 10 → 12.

⚠️ **One edit was made and then reverted by a test, and that is the useful part.** `tool_widgets.dart`'s
category card was changed 12 → 14 under the rule above, and `tool_catalog_strings_test` went red at once: the
title row **no longer fits all eight English names**. That test reads the box width out of the render tree, so
those 4dp were guarded all along; the 12 is a **deliberate exception** (like `DetailMetric`'s 10). **A rule
yields to a measurement** — and a rule invented from a census is exactly the kind that has to.

**The other 11 outliers are genuinely different roles and are left alone**: 18 = the emphasis tier (all three
occurrences are the same highlighted primary-result panel), 12 = nested tinted blocks (4/4 consistent), 10 =
fixed-size tiles (the 78dp tool tile; `DetailMetric`, whose label cell is measured at 110.00 against a 109.1dp
longest string), 6 = the inset between a chart's border and its painted content.

**Removable weight found in the same pass** (evidence = reference counts, not opinion; *candidates* — nothing
here is deleted yet):

| candidate | evidence | what would be lost |
|---|---|---|
| `lib/features/calculator/presentation/widgets/math_expression_text.dart` (**702 lines**) + its own test | the only `lib/` file with **no importer anywhere in `lib/`**; `MathExpressionText` appears only in its own file and its own test. Superseded by `math_expression_view.dart` (230 lines), which 2 `lib/` files and ~28 tests do import | nothing user-visible |
| `NekoAppMark` (`app_chrome.dart`) | 2 hits in `lib/` — the class and its constructor; **zero call sites** | nothing user-visible |
| `NotesController.setNoteArchiveFilter` / `setNoteSort` / `setNoteTag` | zero references in `lib/`, `test/`, `android/`; superseded by `applyNoteFilters`, which the filter sheet does call — so no filter choice becomes unreachable | nothing |
| `MathResult.hasFractionTex` / `hasMixedTex` / `hasDmsText`, `ResultPresentation.hasFraction` | zero readers (the live siblings `hasTex`, `hasMixed` and `hasDms` are used) | a small dead API |

### 5h. One source of truth for colour: the app theme is now *derived* from the selected palette (2026-10-10)

**The mistake this fixes was made and corrected the same day.** Re-pointing the app's Material scheme at the
home page's palette (the `feat(ui)` commit) was first done by **copying the palette's literals** into
`app_theme.dart` — 94 lines duplicating values that already live in `calc_theme.dart`. That is the two-apps
problem again in a new form: the user can pick `lavenderMist` or `peachSugar`, and only the calculator would
have changed while every other screen stayed roseCream.

`AppTheme.light(CalcTheme base)` / `AppTheme.dark(CalcTheme base)` now hold **no colour literals at all**.
Every role reads a token (`primary` ← `display.indicatorFg`, `surface` ← `display.background`,
`scaffoldBackgroundColor` ← `keypadBackground`, `onSurface` ← `keys.functionFg`, `outlineVariant` ←
`keys.functionBg`, `secondaryContainer` ← `keys.variableBg`, …), roles outside the mapping come from
`ColorScheme.fromSeed(display.indicatorFg)`, and `dark()` reads `base.dark`. `lib/app.dart` resolves the theme
**once** — its existing `_calcTheme`, from `CalcTheme.resolve(settings.themeId)` — and feeds the *same* value
to both the Material theme and `CalcThemeScope`, so there is no second source of truth;
`calc_theme.dart` has no dependency back on `app_theme.dart`.

**The guard is a test, not a convention**: `test/shared/app_theme_follows_calc_theme_test.dart` walks
`CalcTheme.all`, asserts the Material scheme equals that theme's tokens, **and that the three primaries
differ** — so the day the derivation degrades back into a hard-coded palette it goes red. Measured:
`#AA5462` (roseCream) / `#6C5CB4` (lavenderMist) / `#98622F` (peachSugar).

⚠️ One call site had to change to compile: `tool_description_lines_test.dart` passed `AppTheme.light()` and now
passes `CalcTheme.fallback` — the palette it was already measuring against. **No assertion was touched**; that
test measures fonts and geometry, not colour.

**Verified on the device (2026-10-10).** Switching the theme to `lavenderMist` re-themed the **Settings page** —
a screen that never calls `CalcTheme` — its canvas, row icons and switches all went violet, and the picker's
own row then read 「薰衣草雾」. **That is precisely the case the old code could not produce**: the Material
scheme was pinned to roseCream literals, so only the calculator would have changed. Cycling the three themes
also **measurably** moved the calculator's display background (`#FFFBF6` peachSugar → `#FFFAF7` roseCream →
`#FBFAFF` lavenderMist), which is how the setting was restored to the original `roseCream` after the test —
with a **stop condition on the measured colour**, not on a count of taps (the first attempt had no `break` at
all and cycled straight past the target; the pixels are what caught it).

⚠️ **Not verified: how the DARK palette actually renders on the device.** Dark mode is supported, wired
(`lib/app.dart`'s `darkTheme: AppTheme.dark(…)`) and guarded at the token level — the test asserts
`AppTheme.dark(t).colorScheme.primary == t.dark.display.indicatorFg` for all three themes — but it has **never
been looked at on a screen**. Two routes were attempted on 2026-10-11 and **both were blocked by the device
rather than by the code**: (a) the system switch — this ROM does not honour `cmd uimode night yes` from adb (it
reports `Night mode: no` before and after, exactly as it ignores the adb rotation commands recorded in §5f);
and (b) the app's own 主题模式 row — the taps stopped landing and the captures stopped being produced at all,
with `mCurrentFocus=null` and the screen asleep, i.e. **adb input no longer reaches the UI**. The device was
left in its natural state and verified so (`Night mode: no`). **Route (b) is still the right one next time**,
because it is an app setting rather than a system one and it directly exercises `AppTheme.dark()`; it will need
the device awake and unlocked.

### 5i. Multi-language: structurally sound; three gaps and one layering defect (audited 2026-10-10)

**Two languages** (`zh`, the fallback, and `en`), **24 named `…Strings` classes**, each an exhaustive `switch`
over `AppLanguage` with **no defaulted fields** — so a key missing for a language is a **compile error**, not a
runtime gap. Nine further files are Zh→En maps (Chinese key → English value, `?? key` fallback) where the
compiler cannot enforce completeness; tests do instead
(`tool_result_label_lengths_test.dart` asserts `en.labels.length == 720`). Switching rebuilds the tree from
`MaterialApp.builder` above the Navigator, and both `State` caches re-read in `didChangeDependencies` — **no
stale-language path was found**.

**Gaps, worst first** (measured, still open):

| site | what | note |
|---|---|---|
| `inline_expression_editor.dart:174` | `message: '粘贴计算详情'` on a paste `Tooltip` | **Chinese text in an English UI** — the only chrome string with no strings-table entry |
| `unit_picker_sheet.dart:165` | `const Text('to')` | an English connector inside the Chinese UI |
| `result_format_sheet.dart:135-141` | six English-only result-format labels | documented as deliberate HiPER vendor strings |
| unit-conversion names — ~290 CJK lines in `core/units/tool_unit_conversion_units_{core,engineering}.dart` | Chinese and English spellings sit in the **same map as the parser's input aliases** | there is no separate display-name table, so translating display names means separating those two concerns first |

⚠️ **The layering defect worth naming: domain-layer result objects carry user-facing prose.** A dozen-plus sites
(`calculator_submit_result.dart`, `tool_save_result.dart`, `calculator_save_result.dart`,
`recent_tool_action_result.dart`, `notes_clipboard_import.dart`, `notes_controller.dart`,
`backup_snapshot_validator.dart`, `data_backup_repository.dart`, `github_release_checker.dart`) build Chinese
sentences that reach the screen via `SnackBar(content: Text(result.message))`
(`calculator_key_dispatch.dart:236`) and `Text(result.message)` (`calculator_page_sheets.dart:345`). A domain
object that outlives the UI cannot be localised by a widget-level strings table; the fix is a **token or enum
on the result, translated at the presentation edge** — the shape the tool-result path already uses. Both cited
call sites have since been converted; converted vs remaining families are tracked below.

**First path done (2026-10-10).** The calculator submit path now has that shape: the domain result carries only
its `CalculatorSubmitStatus` token plus payloads — its unnamed constructor is **private**, so a variant whose
payload is missing cannot be constructed and the edge never renders half a sentence — the eight sentences live
in `calculator_strings.dart` (Chinese byte-identical, English added), and one new presentation function
`calculatorSubmitMessage(result, strings)` renders them where the `SnackBar` is built. The guard mirrors the
tool path's: a legacy-sentence table in both directions, an en-rendering check that forbids CJK, and a source
scan that fails if a wide literal reappears in the domain file.

**Second slice done (2026-10-11): the two save-receipt families.** `CalculatorSaveNoteResult` and
`ToolSaveResult` shed their `message` fields under the same shape. The tokens are the pre-existing
`CalculatorSaveNoteStatus` (calculator) and `ToolSaveStatus` × `ToolSaveTarget` (tools) — no new token type was
invented. The prose lives in `calculator_strings.dart` and `tools_strings.dart` (Chinese byte-identical,
English added), rendered at the edge by `calculatorSaveNoteMessage` / `toolSaveMessage` where the `SnackBar`s
are built (`calculator_page_sheets.dart` and the tool / text-tool / fit screens' save paths). One rule moved
to the edge because it is wording rather than outcome: an `inputInvalid` summary that is empty after trimming
drops the colon; `notWritten`/`superseded` deliberately share one cell. Each family carries the same guard
(legacy-sentence table both directions, en-rendering forbids CJK, source scan of the domain file). **Converted since this audit (third and
fourth slices, 2026-10-11):** the notes family (`notes_clipboard_import.dart`, `notes_delete_result.dart`),
`recent_tool_action_result.dart`, `github_release_checker.dart`, the backup-warning family in
`backup_snapshot_validator.dart` and the import-impact family in `data_backup_repository.dart` — **eight
families converted in all, not the sweep.** **What is still open:** `notes_controller.dart` (search-summary
labels and the fallback note titles it saves are still Chinese composed in the application layer), plus the
**residual prose inside the two partly converted files** — `backup_snapshot_validator.dart`'s
`FormatException` sentences, `emptyBackupReplaceErrorMessage`, `backupTableLabels` and `BackupPreview.summary`
/ `totalLabel`; and `data_backup_repository.dart`'s `BackupImportPlan.modeLabel` / `totalLabel` / `summary`,
`BackupImportReport.modeLabel` / `resultLabel` / `summary` and `BackupExportResult.successMessage` / `detail`.

### 5j. The same defect twice over: English cells copied from the Chinese ones, punctuation and all (2026-10-11)

While recovering the fifth layering slice, its own new guard caught **two** defects of one kind — an English
table cell transcribed from the Chinese one with the words changed but the **punctuation** left behind. Both
were found by measurement, not by reading, and **in both cases the test was right and the code was wrong**:

1. `summaryPartsSeparator` (en) was `' · '` — the Chinese separator verbatim. The guard asserts flatly that an
   English summary keeps no `·`, so it went red. Fixed to `', '`, which is the repo's own English convention
   (`calculator_controller_strings.dart:490`'s `listSeparator` and `settings_backup_strings.dart:300`'s
   `backupTableListSeparator` are both `', '` against a Chinese `'、'`).
2. `summarySearching` (en) was `'Searching “$query”'` — Chinese curly quotes. The ruler
   `containsWideOrFullwidth` (`test/shared/source_scan.dart:101`) flags `0x201C`/`0x201D` explicitly, so it
   went red too. Fixed to ASCII `"`.

**The same class is present elsewhere, and the counts are known.** Measured by running the ruler's own
character set over every `*_strings.dart` English value:

| rune | where the ruler stands | English cells |
|---|---|---|
| `“ ”` curly quotes | explicitly banned (`_typographicPunctuation`) | **3** — `notes_strings.dart:474` (`Delete “$title”? …`), `tools_strings.dart:622`, `:651` |
| `…` ellipsis | **also in that banned set** (`0x2026`) | **8** — `calculator_strings.dart:589/615/628/630`, `notes_strings.dart:435/518/522`, `tools_strings.dart:618` |

⚠️ **Those 11 are left as they are, deliberately.** Adding a guard that bans the whole set would force a
**style sweep across several tables**, and every one of those cells is pinned byte-for-byte by its own strings
test — a change of copy, not a bug fix. The curly quotes are the same defect as (2) and are the better
candidates if a sweep is ever wanted; the ellipsis is a **pervasive pre-existing convention** in this repo's
English copy and reversing it is a decision for the owner. Recorded rather than done, so that the finding is
not lost and nobody re-derives it.

## 6. Four mechanical checks that exist because of repeated mistakes

All four guard the **same shape**: an action that did nothing looks exactly like one that ran
and had no effect.

| Check | Guards against |
|---|---|
| `test/features/math_reachability_test.dart` | a file under `lib/core/math/` that **nothing references** |
| `test/features/new_text_tools_screen_test.dart` | a tool **registered but unreachable on screen** |
| `tool/pull_device_db.sh` | pulling the SQLite database **without its `-wal`** (reads a stale value) |
| `tool/install_debug_over_release.sh` | losing the device's debuggable build — it **sidesteps** the versionCode (build the debug variant at the installed one) instead of fighting the downgrade guard (§2) |

⚠️ **Measuring trap, learned the hard way**: `meetsGuideline` reports failures **asynchronously** —
`expect(...)` does not throw. try/catch cannot be used to see whether it passes.
