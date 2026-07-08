# tw-colors-flutter

Tailwind CSS's default color palette as `dart:ui` `Color` constants for Flutter.

## Features

- Every shade of every color family from Tailwind's default palette, as `static const Color` values (so they work in `const` widgets) — e.g. `TwColorsV3.red500`.
- Each family is also available as a `ColorSwatch<int>` (the same type behind Flutter's own `Colors.red`), so `TwColorsV3.red` is itself a `Color` (the 500 shade) that can also be indexed by a shade chosen at runtime: `TwColorsV3.red[shade]`. The index can be any of Tailwind's real stops (`50, 100, 200, ..., 900`, plus `950` for v3/v4) — indexing with a number that isn't one of those stops (e.g. `red[550]`) returns `null`, same as Flutter's own `ColorSwatch`. It's runtime-selectable, not a continuous/interpolated scale.
- Three versions of the palette, since Tailwind's default colors actually changed values (not just names) across major releases:
  - `TwColorsV2` — Tailwind v2's palette (includes v2-only families like `coolGray`, `blueGray`, `warmGray`, `trueGray`).
  - `TwColorsV3` — Tailwind v3's palette (sRGB hex), the palette most projects still use.
  - `TwColorsV4` — Tailwind v4's palette, converted from its native `oklch()` values to sRGB.
  - `TwColors` — an alias for the latest supported version (currently `TwColorsV4`).
  - The palettes aren't perfectly symmetric: `transparent` is only defined on `TwColorsV3`. Tailwind's own v2 `colors.js` and v4 `theme.css` never define a transparent color entry (only v3's `colors.js` does), so `TwColorsV2.transparent` and `TwColorsV4.transparent` don't exist. `black` and `white` are defined on all three.

## Usage

```dart
import 'package:flutter/widgets.dart';
import 'package:tw_colors/tw_colors.dart';

const box = DecoratedBox(
  decoration: BoxDecoration(color: TwColorsV3.red500),
);

// Or pin to a specific version explicitly:
const chip = ColoredBox(color: TwColorsV4.emerald600);

// Index a family swatch with a shade computed at runtime:
int shade = isDark ? 800 : 200;
final background = TwColorsV3.slate[shade];
```

## Where the data comes from

The color constants aren't hand-written — `tool/generate_colors.dart` fetches Tailwind's own published color data directly from unpkg (pinned to specific Tailwind versions for reproducibility) and generates the `lib/src/tw_colors_v*.g.dart` files. Tailwind v4's colors are defined in `oklch()`; the generator converts them to sRGB hex using the same Oklab math Tailwind's own tooling uses.

To regenerate (e.g. after bumping a pinned version in the script to pick up a newer Tailwind release):

```sh
dart run tool/generate_colors.dart
```
