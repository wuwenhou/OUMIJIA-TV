import 'package:flutter/material.dart';

/// Ngôn ngữ thiết kế cho người già:
/// - Chữ to, nút to, tương phản cao
/// - Focus (điều khiển TV) viền sáng rõ ràng
class Ui {
  // Kích thước cơ bản (nhân với fontScale từ Cài đặt)
  static const double baseFont = 20;
  static const double minTouchTarget = 64;
  static const double channelTileHeight = 110;

  // Màu sắc
  static const bg = Color(0xFF101418);
  static const surface = Color(0xFF1C232B);
  static const accent = Color(0xFFFFC93C);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB9C4CE);
  static const focusBorder = Color(0xFF4FC3F7);

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: surface,
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(color: textPrimary),
        titleLarge:
            base.textTheme.titleLarge?.copyWith(color: textPrimary, fontSize: 26),
        bodyLarge: base.textTheme.bodyLarge
            ?.copyWith(color: textPrimary, fontSize: baseFont),
        bodyMedium: base.textTheme.bodyMedium
            ?.copyWith(color: textSecondary, fontSize: baseFont - 2),
      ),
    );
  }

  /// Viền focus sáng to khi điều khiển bằng remote TV.
  static BorderSide focusBorderSide({bool focused = false}) => BorderSide(
        color: focused ? focusBorder : Colors.transparent,
        width: focused ? 4 : 0,
      );
}
