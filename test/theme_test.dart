import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oumijia_tv/theme/design_system.dart';

/// Chống tái phát lỗi "grey screen": ThemeExtension phải được đăng ký
/// trong ThemeData, nếu không mọi `context.c` sẽ ném null.
void main() {
  test('buildTheme đăng ký OumijiaColors cho cả light và dark', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = buildTheme(
        mode: brightness,
        accentKey: 'gold',
        fontScale: 1.0,
      );
      expect(theme.extension<OumijiaColors>(), isNotNull);
      expect(theme.extension<OumijiaColors>()!.accent, isNotNull);
      expect(theme.scaffoldBackgroundColor, theme.extension<OumijiaColors>()!.bg);
    }
  });

  testWidgets('context.c đọc được token trong widget thật', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(mode: Brightness.dark, accentKey: 'ocean'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Container(
              key: const Key('token'),
              color: context.c.bg,
              child: Text('ok', style: TextStyle(color: context.c.textHi)),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ok'), findsOneWidget);
    final box = tester.widget<Container>(find.byKey(const Key('token')));
    expect((box.color), isNotNull);
  });
}
