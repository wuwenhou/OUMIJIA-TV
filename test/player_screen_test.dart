import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oumijia_tv/models.dart';
import 'package:oumijia_tv/screens/player_screen.dart';
import 'package:oumijia_tv/services/prefs_service.dart';
import 'package:oumijia_tv/theme/design_system.dart';
import 'package:oumijia_tv/widgets/channel_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.init();
  });

  AppConfig buildConfig() {
    return AppConfig.fromJson({
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
          'id': 'vtv2',
          'name': 'VTV2',
          'group': 'Quốc gia',
          'logo': '',
          'primary': 'http://example.com/vtv2.m3u8',
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
  }

  void useScreenSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpPlayer(
    WidgetTester tester, {
    double textScale = 1.0,
  }) async {
    final config = buildConfig();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: PlayerScreen(config: config, channel: config.channels.first),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('chạm vùng đen giữa màn hình sẽ ẩn thanh điều khiển',
      (tester) async {
    useScreenSize(tester, const Size(390, 844));
    await pumpPlayer(tester);

    expect(find.text('VTV1'), findsWidgets);
    expect(find.byType(ChannelLogo), findsNothing);
    expect(find.text('Kênh trước'), findsOneWidget);

    await tester.tapAt(const Offset(195, 250));
    await tester.pump();
    final overlayAfter = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(overlayAfter.opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nút thoát X là 56×56, icon 28 ở cả dọc và ngang',
      (tester) async {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      useScreenSize(tester, size);
      await pumpPlayer(tester);

      final exit = find.byTooltip('Thoát');
      expect(exit, findsOneWidget);
      final boxes = find.descendant(of: exit, matching: find.byType(SizedBox));
      expect(tester.getSize(boxes.first), const Size(56, 56));
      final icon = tester.widget<Icon>(
        find.descendant(of: exit, matching: find.byType(Icon)),
      );
      expect(icon.size, 28);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('vuốt lên sang kênh sau, vuốt xuống về kênh trước',
      (tester) async {
    useScreenSize(tester, const Size(390, 844));
    await pumpPlayer(tester);

    await tester.timedDragFrom(
      const Offset(195, 300),
      const Offset(0, -100),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(find.text('VTV2'), findsOneWidget);

    await tester.timedDragFrom(
      const Offset(195, 300),
      const Offset(0, 100),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(find.text('VTV1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vuốt xuống ở kênh đầu vòng về kênh cuối', (tester) async {
    useScreenSize(tester, const Size(390, 844));
    await pumpPlayer(tester);

    await tester.timedDragFrom(
      const Offset(195, 300),
      const Offset(0, 100),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(find.text('VTV3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vuốt quá ngắn không đổi kênh', (tester) async {
    useScreenSize(tester, const Size(390, 844));
    await pumpPlayer(tester);

    await tester.timedDragFrom(
      const Offset(195, 300),
      const Offset(0, -30),
      const Duration(milliseconds: 600),
    );
    await tester.pump();
    expect(find.text('VTV1'), findsOneWidget);
    expect(find.text('VTV2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn ngang 844×390 với chữ 130% không tràn layout',
      (tester) async {
    useScreenSize(tester, const Size(844, 390));
    await pumpPlayer(tester, textScale: 1.3);

    expect(find.text('VTV1'), findsWidgets);
    expect(find.text('Vuốt lên/xuống đổi kênh · Chạm để hiện/ẩn'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
