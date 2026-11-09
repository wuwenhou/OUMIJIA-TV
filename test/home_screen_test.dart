import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oumijia_tv/models.dart';
import 'package:oumijia_tv/screens/home_screen.dart';
import 'package:oumijia_tv/services/prefs_service.dart';
import 'package:oumijia_tv/theme/design_system.dart';

/// Hồi quy lỗi màn xám + điều hướng 4 tab (đã bỏ tab Trang chủ).
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
    'movieSources': [],
    'movies': [],
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
      home: HomeScreen(config: config),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('mở app vào thẳng tab Kênh, không có Trang chủ', (tester) async {
    await pumpHome(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Kênh truyền hình'), findsOneWidget);
    expect(find.text('VTV1'), findsWidgets);
    expect(find.text('Trang chủ'), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);

    // Đúng 4 tab điều hướng.
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.destinations.length, 4);
    expect(nav.selectedIndex, 0);
  });

  testWidgets('xoay ngang dùng NavigationRail thay vì thanh dưới', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
      home: HomeScreen(config: config),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('VTV1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chuyển tab Kênh / Phim / YouTube / Cài đặt không lỗi',
      (tester) async {
    await pumpHome(tester);

    // Phim/YouTube/Cài đặt dùng surface 390px như thiết bị thật.
    for (final label in ['Kênh', 'Phim', 'YouTube', 'Cài đặt']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: 'tab $label');
      expect(find.byType(ErrorWidget), findsNothing, reason: 'tab $label');
    }
  });
}
