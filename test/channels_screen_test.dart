import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oumijia_tv/models.dart';
import 'package:oumijia_tv/screens/channels_screen.dart';
import 'package:oumijia_tv/services/prefs_service.dart';
import 'package:oumijia_tv/theme/design_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'favorites': ['vtv3'],
    });
    await PrefsService.init();
  });

  testWidgets('kênh yêu thích được đưa lên đầu danh sách', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
}
