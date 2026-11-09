import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oumijia_tv/models.dart';
import 'package:oumijia_tv/screens/channels_screen.dart';
import 'package:oumijia_tv/services/prefs_service.dart';
import 'package:oumijia_tv/theme/design_system.dart';
import 'package:oumijia_tv/widgets/channel_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'favorites': ['vtv3'],
    });
    await PrefsService.init();
  });

  testWidgets('kênh yêu thích được đưa lên đầu danh sách', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final config = AppConfig.fromJson({
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
        {
          'id': 'vtv2',
          'name': 'VTV2',
          'group': 'Quốc gia',
          'logo': '',
          'primary': 'http://example.com/vtv2.m3u8',
          'health': 'WORKING',
        },
      ],
      'youtubeCategories': [],
      'movieSources': [],
      'movies': [],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
        home: ChannelsScreen(config: config),
      ),
    );
    await tester.pump();

    final vtv3Top = tester.getTopLeft(find.text('VTV3').first).dy;
    final vtv1Top = tester.getTopLeft(find.text('VTV1').first).dy;
    final vtv2Top = tester.getTopLeft(find.text('VTV2').first).dy;

    expect(vtv3Top, lessThan(vtv1Top));
    expect(vtv3Top, lessThan(vtv2Top));
    expect(find.text('VTV3'), findsOneWidget);
    expect(find.text('VTV1'), findsOneWidget);
    expect(find.text('VTV2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('xoay ngang tự dùng lưới kênh thay vì danh sách dọc', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final config = AppConfig.fromJson({
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

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
        home: ChannelsScreen(config: config),
      ),
    );
    await tester.pump();

    expect(find.byType(ChannelGridTile), findsWidgets);
    expect(find.byType(ChannelCard), findsNothing);
    expect(find.text('Kênh'), findsWidgets);
    expect(find.text('3 kênh'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
