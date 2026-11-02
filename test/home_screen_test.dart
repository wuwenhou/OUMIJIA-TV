import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oumijia_tv/models.dart';
import 'package:oumijia_tv/screens/home_screen.dart';
import 'package:oumijia_tv/services/prefs_service.dart';
import 'package:oumijia_tv/theme/design_system.dart';

/// Hồi quy lỗi màn xám: các tab phải render được với design system.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_update': false});
    await PrefsService.init();
  });

  final config = AppConfig.fromJson({
    'headers': {
      'User-Agent': 'Mozilla/5.0 test',
    },
    'channels': [
      {
        'id': 'vtv1',
        'name': 'VTV1',
        'group': 'Quốc gia',
        'logo': '',
        'primary': 'http://example.com/vtv1.m3u8',
        'health': 'WORKING',
      },
      {
        'id': 'vtv3',
        'name': 'VTV3',
        'group': 'Giải trí',
        'logo': '',
        'primary': 'http://example.com/vtv3.m3u8',
        'health': 'WORKING',
      },
    ],
    'youtubeCategories': [],
    'movies': [],
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
      home: HomeScreen(config: config),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('Home render nội dung, không có ErrorWidget', (tester) async {
    await pumpHome(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('OUMIJIA TV'), findsOneWidget);
    expect(find.text('VTV1'), findsWidgets);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('chuyển tab Kênh / Phim / YouTube không lỗi', (tester) async {
    await pumpHome(tester);

    for (final label in ['Kênh', 'Phim', 'YouTube', 'Trang chủ']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: 'tab $label');
      expect(find.byType(ErrorWidget), findsNothing, reason: 'tab $label');
    }
  });
}
