---
title: "A const typed Dictionary hands back a plain Array where it promised a packed one"
date: 2026-07-27
category: logic-errors
module: presentation/stage
problem_type: logic_error
component: service_object
symptoms:
  - "LayoutBook.FORMS[form].has(field) answered false while find(field) on the same value answered 0 — same array, same string"
  - "28 test failures whose assertions all named fields that were plainly present in the const"
  - "for field in FORMS[form] iterated zero times, so an assertion inside the loop had never run and the suite still reported PASS"
  - "size() and count() report 0 and subscripting [0] raises `Out of bounds get index '0' (on base: 'Array')` on a value whose str() prints the real contents"
root_cause: wrong_api
resolution_type: code_fix
severity: high
related_components:
  - testing_framework
  - documentation
tags: [godot, gdscript, godot-4-7, const, typed-dictionary, packed-array, silent-failure, engine-trap, test-hole]
---

# A const typed Dictionary hands back a plain Array where it promised a packed one

## Problem

`presentation/stage/layout_book.gd:275` (`FORMS`) declares the schema's field order as
`const FORMS: Dictionary[StringName, PackedStringArray]`. Reading it with
`FORMS[form]`, where `form` is a variable, returns a value that reports itself
**empty** to `size()`, `has()`, `count()`, `[i]` and `for`-in, while `find()` and
`str()` see the real contents. Nothing errors. The wrong answers are silent, and
one of them turned a test assertion into a no-op that still counted as passing.

## Symptoms

- `FORMS[form].has("groundY")` is `false`; `FORMS[form].find("groundY")` is `0`.
- `FORMS[form].size()` is `0` for an array that holds two strings.
- `FORMS[form][0]` raises `Out of bounds get index '0' (on base: 'Array')` —
  note the base is reported as `Array`, not `PackedStringArray`.
- `for f: String in FORMS[form]:` runs its body **zero** times.
- `str(FORMS[form])` prints `["x", "y"]` — the true contents.
- Assigning to a typed local first (`var a: PackedStringArray = FORMS[form]`)
  does not repair any of it.

## What Didn't Work

- **Blaming string identity.** The first theory was that a runtime-built
  `StringName` key compared unequal to the interned literal. It does not:
  `StringName("he" + "ro") == &"hero"` is `true`, and the lookup plainly finds
  the entry, since `find()` searches the real contents.
- **Blaming `has()`.** The session's first diagnosis — and the code comment it
  left behind in the docstring of `presentation/stage/layout_book.gd:865`
  (`fields`) — was "`has()` lies
  on 4.7.1". That is the visible half of a bigger fault. It stopped the
  investigation one step short, and the step it skipped is the one that matters:
  `size()` is `0` too, so anything that walks the array silently does nothing.
- **Binding to a typed local.** The natural "launder it through a variable" fix
  does not work, which is what makes the trap survive a careful reading.

## Solution

Read the const through `.get()` rather than `[]`, and never inline the
subscript at a statically-typed call site:

```gdscript
# presentation/stage/layout_book.gd
static func fields(form: StringName) -> PackedStringArray:
    return FORMS.get(form, PackedStringArray())

static func _declares(form: StringName, field: String) -> bool:
    return fields(form).find(field) >= 0
```

Every internal reader goes through `fields()`. The two call sites that used to
inline `FORMS[form]` are at `presentation/stage/layout_book.gd:422` (in `place`)
and `presentation/stage/layout_book.gd:800` (in `_defaults`).

Three other escapes were measured and all work: a **constant** key
(`FORMS[&"hero"]`), declaring the dictionary `static var` instead of `const`, and
passing the value through a `Variant` before calling anything on it.

## Why This Works

Printing `typeof()` through a `Variant` parameter is what separates the cases:

| Declaration | key | `typeof(d[key])` |
|---|---|---|
| `const Dictionary[StringName, PackedStringArray]` | variable | `28` (`TYPE_ARRAY`) |
| `const Dictionary[StringName, PackedStringArray]` | `&"hero"` | `28` (`TYPE_ARRAY`) |
| `static var Dictionary[StringName, PackedStringArray]` | variable | `34` (`TYPE_PACKED_STRING_ARRAY`) |
| local `Dictionary[StringName, PackedStringArray]` | variable | `34` (`TYPE_PACKED_STRING_ARRAY`) |

**A `const` typed Dictionary does not apply its declared value type to the
constant-folded initialiser** — it stores plain `Array` values. The parser still
types the subscript expression as `PackedStringArray`, so a directly-inlined call
is compiled as a statically-bound `PackedStringArray` builtin and reads an
`Array` through the wrong container layout. That is why `size()` is `0` and `[0]`
reports its base as `Array`.

A **constant** key escapes because the whole subscript is folded at parse time
into a real constant of the right type. `.get()` and a `Variant` round-trip
escape because both dispatch dynamically on the value's actual type. `find()`
takes that same dynamic path, so its answers are genuinely correct rather than
lucky — a present item returns its index, an absent one `-1`. That is precisely
why the fault first read as an `has()` bug: the one method still telling the
truth was sitting next to the one lying about the same array.

The scope, measured on `4.7.1.stable.official`:

- **Element type matters.** `Dictionary[StringName, PackedInt32Array]` is
  affected the same way. `Dictionary[StringName, Array]` is **not** —
  `has()` answers correctly. Only packed arrays were observed to break.
- **Key type does not.** `Dictionary[String, PackedStringArray]` read with a
  variable `String` key fails identically. The original "runtime-built
  `StringName`" framing was wrong; the axis is constant vs non-constant key.
- **`const` is the trigger.** The identical literal assigned to a `static var`
  or a local is correct throughout.

## Prevention

- **Do not declare a `const` Dictionary with a packed-array value type.** Use
  `static var`, or hold plain `Array` values. A sweep of this tree found exactly
  one such declaration, `presentation/stage/layout_book.gd:275` (`FORMS`); every other
  `const Dictionary[...]` here has `Dictionary`, `Array`, `Color`, `Vector2i` or
  `float` values and is unaffected.
- **A test that iterates the suspect expression proves nothing.** This is the
  sharp edge, and this tree had a live example. `tests/test_layout_book.gd`'s
  schema pass used to read

  ```gdscript
  for field: String in LayoutBook.FORMS[form]:
      _check(fails, LayoutBook.FIELDS.has(StringName("%s/%s" % [form, field])),
          "%s/%s is declared" % [form, field])
  ```

  The loop iterated zero times, so that assertion had never executed and the
  suite reported `PASS (12 tests)` regardless. Any guard test for this class of
  fault must assert the **count** first, so an empty container fails loudly
  before anything walks it — which is what
  `tests/test_layout_book.gd:179` (in `_schema`) now does:

  ```gdscript
  var order: PackedStringArray = LayoutBook.fields(form)
  _check(fails, order.size() > 0, "form %s has a non-empty field order" % form)
  for field: String in order:
  ```

  Fixed 2026-07-28. The `size() == 0` half of the hazard is pinned separately in
  the same function, so a future engine release that stops dropping the packed
  type fails the pin rather than passing silently.
- **A new test that passes proves nothing either.** The same trap catches the
  guard you just wrote. Break one authored value on purpose and watch the suite
  report `FAIL` with your assertion's own message before believing it runs.

- **When a container answers two questions inconsistently, ask it its size
  before theorising.** `has()` false with `find()` correct reads as a comparison
  bug; `size()` zero with `str()` correct names the real fault immediately. The
  first framing cost this session a diagnosis that was half right and a comment
  that recorded the half.

## Related Issues

- The docstring of `presentation/stage/layout_book.gd:865` (`fields`) — the
  in-code comment written from the first, incomplete diagnosis. Superseded by
  this document.
- [Matching constants prove nothing](../design-patterns/derive-authored-compensations-when-porting.md)
  — the same failure shape in a different register: a call site that exists in
  the source but never runs.
