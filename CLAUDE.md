# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Toolchain

Managed via Rokit (`aftman.toml`):

- `stylua` — formatter (config in `stylua.toml`: single quotes, no call parens, Unix EOL, Luau syntax, sort requires).
- `luau-lsp` — language server (config under `.vscode/settings.json`; old solver, vector ctor `vector.create`, relative string requires).
- `lute` — Luau runtime used to execute scripts/tests.

`.luaurc` enforces strict mode with `ImplicitReturn` lint disabled.

## Common commands

```sh
# format (PowerShell or shell)
stylua lib tests

# lint
luau-lsp analyze --base-luaurc .luaurc lib tests

# run the test suite
lute tests/runner.luau

# run benchmarks / visual story
lute tests/oklch.bench.luau
lute tests/oklch.story.luau
```

To add a new spec file, `require` it into the `suites` array in `tests/runner.luau`. Test functions must be exposed on the returned table with names prefixed `should_` — the runner discovers them by prefix and reports `ok - <name>` / `not ok - <name>`.

## Architecture

Library is a terminal drawing toolkit producing truecolor ANSI output. The entry point `lib/init.luau` re-exports the public surface (canvas, area, ansi, text, geometry, layout.table, chart.area, oklch, plus the `pixel`/`print`/`luau_code` helpers and `style`).

### Canvas as the core primitive (`lib/canvas.luau`)

A `canvas` is a flat row-major grid of `width * height` cells with parallel arrays:

- `mode: buffer` — per-cell tag: `0` empty, `1` char, `2` pixel.
- `z: buffer` — signed depth for z-test (i8).
- `chars`, `ansis` — char-mode glyph + its ANSI prefix.
- `top`, `bot: { vector? }` — pixel-mode upper/lower half RGB; rendered together as `▀` (top fg + bot bg), `▀` (top only), or `▄` (bot only). This is how a single text row carries two logical pixel rows.

Every write (`put`, `pixel`, segment chars, text) z-tests against the existing cell's `z` and skips if behind. The cell mode determines which fields are read at `emit`, so writing a pixel after a char must clear `chars`/`ansis` (and vice versa) — see the `prev_mode ~= 2` branch in `pixel`. Position vectors carry depth in `pos.z` (using `vector`'s third lane as z-index).

### Coordinate spaces

- Char/glyph coordinates: 1-indexed column/row of the canvas grid.
- Pixel coordinates: 1-indexed column, but row is the half-cell row (`cell_row = (pixel_row + 1) // 2`). Pixel y=1 and y=2 share the same canvas cell.
- `area` (`lib/area.luau`) is an immutable axis-aligned rect `{x1,x2,y1,y2}` built from one of three input shapes (`pos+size`, `x+y` ranges, `start+final`). Used as a layout zone, not a draw primitive.

### Segment-char merging (`lib/components/segment_char.luau`)

Box-drawing glyphs are picked from a bitmask of cardinal directions (`NORTH=1, EAST=2, SOUTH=4, WEST=8`). When two lines/boxes touch a cell **at the same z**, their bitmasks OR together so corners and intersections pick the correct glyph (`├ ┤ ┬ ┴ ┼`). The per-canvas `seg_state` (bits + z) lives in a weak-keyed map so segment merging state is GC'd with the canvas. Different z levels do **not** merge — the new write replaces. Styles: `SOLID`, `DASHED`, `HEAVY`, `DOUBLE`.

`geometry.line` only supports horizontal/vertical strokes; diagonals raise. `geometry.box` is four lines that auto-corner via merging.

### Text (`lib/components/text.luau`)

`text` is a callable namespace built from chained attribute lookups: `text.bold.italic(buf, def)` resolves to a memoized function whose `attrs` string is the concatenated ANSI codes. The leaf write goes through the same z-test as `canvas.put` but inlined for the row. `anchor` is normalized (e.g. `vector.create(0.5,0,0)` centers).

### Color (`lib/oklch.luau`)

Full sRGB ↔ linear ↔ LMS ↔ OkLab ↔ OkLCh chain with vector matrix-multiplies expressed as channel-wise `vector` ops (each "row" of a matrix is a vector dot via componentwise multiply + sum). `lerp(rgb, rgb, alpha)` interpolates in OkLCh with **shortest-arc hue** (`lerp_hue` wraps the diff into `(-π, π]`). `palette(n, L?, C?)` distributes `n` hues evenly at fixed L/C, returning rounded RGB bytes.

`ansi.foreground` / `ansi.background` cache truecolor escapes per RGB vector; `ansi.to_rgb` round-trips both 24-bit codes and the 16 named colors via `rgb_lookup`.

### Higher-level components

- `components/area_chart.luau` — multi-series filled chart. Pipeline: bounds → per-sequence column-height array → for each (col, level) decide edge vs fill, blend in OkLCh, paint via `canvas.pixel`. Edges use the series hue at full chroma; fills dim lightness via `dim_lch`. Axes and grid lines are segment-char dashed lines; tick labels via `text.dim`.
- `components/table.luau` — plain text table printer (no canvas). Computes per-column max width, formats with `%Ns`/`%-Ns`, applies cells' optional ANSI prefix + RESET.
- `components/luau_code.luau` — Luau syntax highlighter producing an ANSI string (returned, not drawn to a canvas). Hand-rolled scanner with state for nested rainbow braces, long strings/comments (`[[...]]` / `[=[...]=]`), and interpolated string `\`...{expr}...\``.

### Conventions

- `--!native` is set on hot files (canvas, ansi, geometry, segment_char, text, oklch, story/bench). Add it when introducing a perf-sensitive module.
- Requires use the relative string-require form (`require '@self/...'` from `lib/init.luau`, `require '../canvas'` from components). Match the existing style; `luau-lsp` is configured for relative requires only.
- Vectors are the workhorse type — positions, colors, ranges, and 2D extents all use `vector.create`. The third lane is repurposed (z-index for positions, blue for colors, etc.). Use `--!native` modules' componentwise ops rather than scalar loops where possible.
- Returned module tables are `table.freeze`d.
