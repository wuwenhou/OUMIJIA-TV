import 'package:flutter/material.dart';

/// OUMIJIA DESIGN SYSTEM
///
/// Một bộ token duy nhất dùng chung mọi màn hình:
/// - OumijiaColors: token màu theo Light/Dark (ThemeExtension)
/// - Accent palette : 5 bảng màu chọn được, dùng được cả sáng lẫn tối
/// - buildTheme()   : ThemeData đầy đủ cho MaterialApp
///
/// Nguyên tắc: dark = "stage" (nền sân khấu nội dung nổi), light = "daylight".
/// Border hairline thay shadow nặng; shadow chỉ cho phần tử nổi rõ (player, dialog).

/// các bảng màu chủ đạo người dùng có thể chọn
const kAccentKeys = ['gold', 'ocean', 'violet', 'emerald', 'rose'];

class OumijiaColors extends ThemeExtension<OumijiaColors> {
  final Color bg;
  final Color surface; // card
  final Color surfaceAlt; // nền nâng cao (chip, banner)
  final Color border;
  final Color textHi;
  final Color textMed;
  final Color textLo;
  final Color accent;
  final Color danger;

  const OumijiaColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textHi,
    required this.textMed,
    required this.textLo,
    required this.accent,
    required this.danger,
  });

  @override
  OumijiaColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textHi,
    Color? textMed,
    Color? textLo,
    Color? accent,
    Color? danger,
  }) =>
      OumijiaColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        border: border ?? this.border,
        textHi: textHi ?? this.textHi,
        textMed: textMed ?? this.textMed,
        textLo: textLo ?? this.textLo,
        accent: accent ?? this.accent,
        danger: danger ?? this.danger,
      );

  @override
  OumijiaColors lerp(OumijiaColors? other, double t) {
    if (other == null) return this;
    return OumijiaColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textHi: Color.lerp(textHi, other.textHi, t)!,
      textMed: Color.lerp(textMed, other.textMed, t)!,
      textLo: Color.lerp(textLo, other.textLo, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// bảng màu dark — "premium stage"
const _darkBase = OumijiaColors(
  bg: Color(0xFF0B0F14),
  surface: Color(0xFF141B23),
  surfaceAlt: Color(0xFF1C2630),
  border: Color(0xFF25303C),
  textHi: Color(0xFFF4F7FA),
  textMed: Color(0xFF9AA8B5),
  textLo: Color(0xFF66737F),
  accent: Color(0xFFFFC93C),
  danger: Color(0xFFFF6B6B),
);

/// bảng màu light — sạch, không chói
const _lightBase = OumijiaColors(
  bg: Color(0xFFF6F8FB),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFEDF1F7),
  border: Color(0xFFDFE6EE),
  textHi: Color(0xFF111820),
  textMed: Color(0xFF55626F),
  textLo: Color(0xFF8D99A6),
  accent: Color(0xFFE0A800),
  danger: Color(0xFFE5484D),
);

/// accent theo key — dùng được cả dark & light (dark sáng hơn, light đậm hơn)
const Map<String, Color> _accentDark = {
  'gold': Color(0xFFFFC93C),
  'ocean': Color(0xFF53C6F7),
  'violet': Color(0xFFA78BFA),
  'emerald': Color(0xFF39D98A),
  'rose': Color(0xFFFB7185),
};

const Map<String, Color> _accentLight = {
  'gold': Color(0xFFB98A00),
  'ocean': Color(0xFF0284C7),
  'violet': Color(0xFF6D5BD0),
  'emerald': Color(0xFF0E9F6E),
  'rose': Color(0xFFD5476A),
};

Color accentColor(String key, bool dark) => dark ? _accentDark[key] ?? _accentDark['gold']! : _accentLight[key] ?? _accentLight['gold']!;

/// tên hiển thị cho selector
const Map<String, String> kAccentNames = {
  'gold': 'Vàng OUMIJIA',
  'ocean': 'Biển',
  'violet': 'Tím',
  'emerald': 'Xanh lá',
  'rose': 'Hồng',
};

/// radius uniform
class Radii {
  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 22;
  static const double xl = 28;
}

/// spacing scale 4pt
class Sp {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

buildTheme({
  required Brightness mode,
  required String accentKey,
  double fontScale = 1.0,
}) {
  final dark = mode == Brightness.dark;
  final base = dark
      ? ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: null)
      : ThemeData(brightness: Brightness.light, useMaterial3: true);

  final colors = (dark ? _darkBase : _lightBase).copyWith(accent: accentColor(accentKey, dark));

  final scheme = base.colorScheme.copyWith(
    brightness: mode,
    primary: colors.accent,
    onPrimary: Colors.black,
    secondary: colors.accent,
    surface: colors.surface,
    onSurface: colors.textHi,
    error: colors.danger,
    outline: colors.border,
    surfaceContainerHighest: colors.surfaceAlt,
  );

  double f(double size) => size * fontScale;

  final textTheme = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
        color: colors.textHi, fontSize: f(28), fontWeight: FontWeight.w800, letterSpacing: -0.5),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: colors.textHi, fontSize: f(24), fontWeight: FontWeight.w700),
    titleLarge: base.textTheme.titleLarge?.copyWith(
        color: colors.textHi, fontSize: f(19), fontWeight: FontWeight.w700),
    titleMedium: base.textTheme.titleMedium?.copyWith(
        color: colors.textHi, fontSize: f(16), fontWeight: FontWeight.w600),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(color: colors.textHi, fontSize: f(15.5)),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(color: colors.textMed, fontSize: f(14)),
    bodySmall: base.textTheme.bodySmall?.copyWith(color: colors.textLo, fontSize: f(12.5)),
    labelLarge: base.textTheme.labelLarge?.copyWith(
        color: colors.textHi, fontSize: f(14), fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    scaffoldBackgroundColor: colors.bg,
    colorScheme: scheme,
    extensions: [colors],
    splashFactory: InkSparkle.splashFactory,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: colors.textHi),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        side: BorderSide(color: colors.border, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: f(11.5),
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? colors.accent : colors.textMed,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? colors.accent : colors.textMed,
            size: 24,
          )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.m)),
        textStyle: TextStyle(fontSize: f(14.5), fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textHi,
        side: BorderSide(color: colors.border),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.m)),
        textStyle: TextStyle(fontSize: f(14.5), fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        textStyle: TextStyle(fontSize: f(14.5), fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceAlt,
      hintStyle: TextStyle(color: colors.textLo),
      prefixIconColor: colors.textLo,
      suffixIconColor: colors.textLo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.black : colors.textMed),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? colors.accent : colors.border),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.surfaceAlt,
      thumbColor: colors.accent,
      overlayColor: colors.accent.withValues(alpha: 0.15),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colors.surfaceAlt,
      side: BorderSide(color: colors.border),
      labelStyle: TextStyle(color: colors.textMed, fontSize: f(13)),
      selectedColor: colors.accent.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xs)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.s))),
        side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? colors.accent.withValues(alpha: 0.2) : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? colors.accent : colors.textMed,
        ),
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: f(13.5), fontWeight: FontWeight.w600)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.l)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surfaceAlt,
      contentTextStyle: TextStyle(color: colors.textHi, fontSize: f(13.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.s)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent, linearTrackColor: colors.surfaceAlt),
    focusColor: colors.accent,
  );
}

/// tiện truy cập token từ context
extension OumijiaCtx on BuildContext {
  OumijiaColors get c => Theme.of(this).extension<OumijiaColors>()!;
}
