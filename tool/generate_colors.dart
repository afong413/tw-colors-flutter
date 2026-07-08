// Fetches Tailwind CSS's default color palette for several major versions
// directly from unpkg and generates the `TwColorsV*` classes under lib/src/.
//
// Run with: dart run tool/generate_colors.dart
//
// The Tailwind versions below are pinned on purpose so a rerun is
// reproducible. To pick up new/changed colors from a newer Tailwind release
// (for example, v4 gained the mauve/olive/mist/taupe families after 4.0),
// bump the relevant version constant and rerun this script.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const tailwindV2 = '2.2.19';
const tailwindV3 = '3.4.1';
const tailwindV4 = '4.3.2';

final v2Url = Uri.parse('https://unpkg.com/tailwindcss@$tailwindV2/colors.js');
final v3Url = Uri.parse(
  'https://unpkg.com/tailwindcss@$tailwindV3/lib/public/colors.js',
);
final v4Url = Uri.parse('https://unpkg.com/tailwindcss@$tailwindV4/theme.css');

Future<void> main() async {
  final [v2, v3, v4] = await Future.wait([
    _fetch(v2Url),
    _fetch(v3Url),
    _fetch(v4Url),
  ]);

  final v2Palette = _parseJsPalette(v2);
  final v3Palette = _parseJsPalette(v3);
  final v4Palette = _parseV4Palette(v4);

  await _writeVersion(
    className: 'TwColorsV2',
    outputPath: 'lib/src/tw_colors_v2.g.dart',
    sourceUrl: v2Url,
    palette: v2Palette,
  );
  await _writeVersion(
    className: 'TwColorsV3',
    outputPath: 'lib/src/tw_colors_v3.g.dart',
    sourceUrl: v3Url,
    palette: v3Palette,
  );
  await _writeVersion(
    className: 'TwColorsV4',
    outputPath: 'lib/src/tw_colors_v4.g.dart',
    sourceUrl: v4Url,
    palette: v4Palette,
  );

  for (final entry in {'v2': v2Palette, 'v3': v3Palette, 'v4': v4Palette}
      .entries) {
    final families = entry.value.families;
    final total = families.values.fold<int>(0, (n, s) => n + s.length);
    print(
      '${entry.key}: ${families.length} families, '
      '$total shades, special: ${entry.value.special.keys.join(', ')}',
    );
  }
}

Future<String> _fetch(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('GET $url failed with ${response.statusCode}');
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

class _Palette {
  _Palette(this.families, this.special);

  /// family name -> { shade -> hex }
  final Map<String, Map<String, String>> families;

  /// e.g. black/white/transparent -> hex (or a sentinel for `transparent`)
  final Map<String, String> special;
}

/// Parses the object-literal shape shared by Tailwind v2 and v3's
/// `colors.js`, e.g.:
///
/// ```js
/// {
///   black: "#000",
///   transparent: "transparent",
///   red: {
///     50: "#fef2f2",
///     ...
///   },
///   get lightBlue() { ... return this.sky },
/// }
/// ```
///
/// `get name() { ... }` blocks are deprecated aliases that just redirect to
/// another family's values (no distinct data of their own), so they're
/// skipped rather than treated as a family.
_Palette _parseJsPalette(String source) {
  final families = <String, Map<String, String>>{};
  final special = <String, String>{};

  final familyHeader = RegExp(r'^\s*([A-Za-z][A-Za-z0-9]*)\s*:\s*\{\s*$');
  final getterHeader = RegExp(r'^\s*get\s+[A-Za-z0-9]+\s*\(\)\s*\{\s*$');
  final shadeLine = RegExp(
    r'''^\s*(\d+)\s*:\s*['"]?(#[0-9a-fA-F]{3,8})['"]?,?\s*$''',
  );
  final specialLine = RegExp(
    r'''^\s*(black|white|transparent)\s*:\s*['"]([^'"]+)['"],?\s*$''',
  );

  final lines = source.split('\n');
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];

    if (getterHeader.hasMatch(line)) {
      var depth = 1;
      i++;
      while (i < lines.length && depth > 0) {
        depth += '{'.allMatches(lines[i]).length;
        depth -= '}'.allMatches(lines[i]).length;
        i++;
      }
      continue;
    }

    final special_ = specialLine.firstMatch(line);
    if (special_ != null) {
      special[special_.group(1)!] = special_.group(2)!;
      i++;
      continue;
    }

    final familyMatch = familyHeader.firstMatch(line);
    if (familyMatch != null) {
      final family = familyMatch.group(1)!;
      final shades = <String, String>{};
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('}')) {
        final shadeMatch = shadeLine.firstMatch(lines[i]);
        if (shadeMatch != null) {
          shades[shadeMatch.group(1)!] = shadeMatch.group(2)!;
        }
        i++;
      }
      i++; // consume the closing '},'
      if (shades.isNotEmpty) families[family] = shades;
      continue;
    }

    i++;
  }

  return _Palette(families, special);
}

/// Parses Tailwind v4's `theme.css`, where colors are CSS custom properties
/// like `--color-red-500: oklch(63.7% 0.237 25.331);`, converting each oklch
/// triple to an sRGB hex string.
_Palette _parseV4Palette(String css) {
  final families = <String, Map<String, String>>{};
  final special = <String, String>{};

  final shadePattern = RegExp(
    r'--color-([a-z]+)-(\d+):\s*oklch\(([\d.]+)%\s+([\d.]+)\s+([\d.]+)\);',
  );
  for (final m in shadePattern.allMatches(css)) {
    final family = m.group(1)!;
    final shade = m.group(2)!;
    final l = double.parse(m.group(3)!) / 100;
    final c = double.parse(m.group(4)!);
    final h = double.parse(m.group(5)!);
    (families[family] ??= {})[shade] = _oklchToHex(l, c, h);
  }

  final specialPattern = RegExp(r'--color-(black|white):\s*(#[0-9a-fA-F]{3,8});');
  for (final m in specialPattern.allMatches(css)) {
    special[m.group(1)!] = m.group(2)!;
  }

  return _Palette(families, special);
}

/// Converts an oklch(L C H) color to an sRGB hex string using Björn
/// Ottosson's Oklab conversion matrices (the same math Tailwind's own
/// tooling uses under the hood), so the generated constants match what
/// browsers render for Tailwind v4's default theme.
String _oklchToHex(double l, double c, double hDegrees) {
  final hRad = hDegrees * math.pi / 180;
  final a = c * math.cos(hRad);
  final b = c * math.sin(hRad);

  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

  final lc = l_ * l_ * l_;
  final mc = m_ * m_ * m_;
  final sc = s_ * s_ * s_;

  final r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc;
  final g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc;
  final bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc;

  int toByte(double channel) {
    final clamped = channel.clamp(0.0, 1.0);
    final gamma = clamped <= 0.0031308
        ? clamped * 12.92
        : 1.055 * math.pow(clamped, 1 / 2.4) - 0.055;
    return (gamma.clamp(0.0, 1.0) * 255).round();
  }

  final hex = StringBuffer('#');
  for (final channel in [r, g, bl]) {
    hex.write(toByte(channel).toRadixString(16).padLeft(2, '0'));
  }
  return hex.toString();
}

int _hexToArgb(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length != 6) {
    // Only 3- and 6-digit hex (the two forms Tailwind's data actually uses)
    // are handled above; anything else (e.g. a CSS 4/8-digit alpha hex)
    // would misalign the RGB bytes if parsed directly, so fail loudly
    // instead of silently generating a wrong color.
    throw FormatException('Unsupported hex color length: $hex');
  }
  return 0xFF000000 | int.parse(h, radix: 16);
}

String _colorLiteral(String hex) =>
    'Color(0x${_hexToArgb(hex).toRadixString(16).padLeft(8, '0').toUpperCase()})';

Future<void> _writeVersion({
  required String className,
  required String outputPath,
  required Uri sourceUrl,
  required _Palette palette,
}) async {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Generated by tool/generate_colors.dart from:')
    ..writeln('//   $sourceUrl')
    ..writeln('//')
    ..writeln('// Regenerate with: dart run tool/generate_colors.dart')
    ..writeln()
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln()
    ..writeln('/// Tailwind CSS default color palette ($className).')
    ..writeln('abstract final class $className {');

  for (final key in ['black', 'white', 'transparent']) {
    final hex = palette.special[key];
    if (hex == null) continue;
    final literal = key == 'transparent'
        ? 'Color(0x00000000)'
        : _colorLiteral(hex);
    buffer.writeln('  static const Color $key = $literal;');
  }

  final familyNames = palette.families.keys.toList()..sort();
  for (final family in familyNames) {
    final shades = palette.families[family]!;
    final shadeNumbers = shades.keys.map(int.parse).toList()..sort();
    for (final shade in shadeNumbers) {
      final hex = shades[shade.toString()]!;
      buffer.writeln(
        '  static const Color $family$shade = ${_colorLiteral(hex)};',
      );
    }
  }

  // A `ColorSwatch<int>` per family, so `TwColorsVN.red` is itself a Color
  // (the 500 shade, Tailwind's de facto base shade) that can also be
  // indexed by an arbitrary/runtime shade: `TwColorsVN.red[700]`.
  for (final family in familyNames) {
    final shades = palette.families[family]!;
    final shadeNumbers = shades.keys.map(int.parse).toList()..sort();
    if (!shadeNumbers.contains(500)) {
      throw StateError('Family "$family" has no 500 shade: $shadeNumbers');
    }
    final primaryArgb = _hexToArgb(shades['500']!);
    final swatchEntries = shadeNumbers
        .map((s) => '$s: ${_colorLiteral(shades[s.toString()]!)}')
        .join(', ');
    buffer.writeln(
      '  static const ColorSwatch<int> $family = '
      'ColorSwatch<int>(0x${primaryArgb.toRadixString(16).padLeft(8, '0').toUpperCase()}, '
      '<int, Color>{$swatchEntries});',
    );
  }

  buffer.writeln('}');

  final file = File(outputPath);
  await file.create(recursive: true);
  await file.writeAsString(buffer.toString());
}