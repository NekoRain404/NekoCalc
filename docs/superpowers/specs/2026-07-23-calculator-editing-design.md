# Calculator Editing Design

## Goal

Make long calculator expressions practical to revise on mobile without giving
up the existing calculator keypad or mathematical display. The editor must
support precise cursor placement, selection, copy, cut, paste, and external
keyboard input.

## Scope

This work is limited to the calculator expression display and its editing
behavior. Calculation semantics, history, memory, and the function catalog do
not change except where they consume the edited expression.

## Interaction Model

The expression has one canonical, parser-compatible string. When not being
edited, it is rendered with `MathExpressionText` using the existing math
symbols and rich layout.

Tapping the expression enters an inline native editing layer in the same
display area. The initial tap resolves to the nearest canonical expression
position. Long press exposes native selection handles and the platform
copy/cut/paste menu. Leaving the editor restores the mathematical rendering
without changing the canonical text or current cursor selection.

The calculator keypad stays visible while the inline editor has focus. The
soft keyboard is only requested through the existing edit action or by a
physical keyboard, so mobile users keep the calculator-first layout.

## Selection and Keypad Rules

The controller owns an inclusive selection start and exclusive selection end.
A collapsed selection is the cursor position used today.

- Text entry, operators, constants, and functions replace a non-empty
  selection.
- Backspace deletes a non-empty selection; otherwise it deletes the preceding
  canonical character.
- Cursor controls support previous/next character, start/end, press-and-hold
  repeat, and previous/next editing block.
- An editing block is a balanced function or parenthesized group, a contiguous
  number, or a plain operator. Block navigation falls back to one character
  for incomplete expressions.
- Native copy, cut, and paste use the selected canonical expression. Existing
  report-aware paste parsing remains the path for multi-line NekoCalc exports.

## Architecture

`CalculatorController` receives a small selection value type and atomic
operations for selection replacement, deletion, movement, and select-all.
All calculator keypad actions use these operations. The controller remains
free of widget-specific `TextEditingController` state.

An inline expression editor owns Flutter's `TextEditingController`, `FocusNode`,
and platform selection behavior. It synchronizes user edits and selection
changes to the controller, while controller-initiated keypad edits update the
native value only when its text or selection differs. A revision guard prevents
feedback loops.

`MathExpressionText` gains a layout-position helper that maps a display tap to
the nearest canonical offset. Its conversion of parser tokens such as `pi` to
the `π` glyph and its function/exponent spans must retain canonical offset
metadata. If a visual span has no exact character position, it resolves to its
nearest legal boundary.

## Error Handling

Incomplete expressions continue to show the current non-blocking waiting
status. Editing never discards invalid or incomplete text. Explicit submission
continues to surface the existing friendly parser errors. Clipboard failures
leave the expression and selection unchanged and show the existing feedback
path.

## Verification

Controller tests cover selection replacement, deletion, character and block
movement, undo/redo, persistence/restore, and parser-safe keypad edits.
Widget tests cover initial tap placement, long-press selection actions,
copy/cut/paste, keypad replacement of a selected range, display-mode handoff,
and narrow mobile layout. Manual Android verification covers native selection
handles and physical keyboard input.

## Non-Goals

The work does not add a computer algebra system, change parser syntax, or
replace the calculator with a general-purpose document editor.
