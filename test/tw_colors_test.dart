import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tw_colors/tw_colors.dart';

void main() {
  test('TwColorsV3 matches Tailwind v3 default palette', () {
    expect(TwColorsV3.red500, const Color(0xFFEF4444));
    expect(TwColorsV3.gray500, const Color(0xFF6B7280));
    expect(TwColorsV3.black, const Color(0xFF000000));
    expect(TwColorsV3.white, const Color(0xFFFFFFFF));
    expect(TwColorsV3.transparent, const Color(0x00000000));
  });

  test('TwColorsV2 preserves historical values distinct from v3', () {
    // v2's "gray" is what v3 later renamed to "zinc" -- a different value
    // from v3's own "gray".
    expect(TwColorsV2.gray500, const Color(0xFF71717A));
    expect(TwColorsV2.coolGray500, const Color(0xFF6B7280));
    expect(TwColorsV2.gray500, isNot(TwColorsV3.gray500));
  });

  test('TwColorsV4 converts oklch to the same sRGB Tailwind ships', () {
    expect(TwColorsV4.red500, const Color(0xFFFB2C36));
    expect(TwColorsV4.red500, isNot(TwColorsV3.red500));
  });

  test('TwColors aliases the latest version', () {
    expect(TwColors.red500, TwColorsV4.red500);
  });

  test('family swatches support arbitrary shade indexing', () {
    expect(TwColorsV3.red[500], TwColorsV3.red500);
    expect(TwColorsV3.red[900], TwColorsV3.red900);
    // The bare swatch is itself a Color, defaulting to the 500 shade.
    expect(TwColorsV3.red.toARGB32(), TwColorsV3.red500.toARGB32());
  });
}
