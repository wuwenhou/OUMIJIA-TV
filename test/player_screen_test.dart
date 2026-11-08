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

  testWidgets('chạm vùng đen giữa màn hình sẽ ẩn thanh điều khiển',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final channel = Channel.fromJson({
      'id': 'offline',
      'name': 'Kênh tạm lỗi',
      'group': 'Kiểm tra',
      'logo': '',
      'primary': '',
      'health': 'OFFLINE',
    });
    final config = AppConfig.fromJson({
      'channels': [
        {
          'id': 'offline',
          'name': 'Kênh tạm lỗi',
          'group': 'Kiểm tra',
          'logo': '',
          'primary': '',
          'health': 'OFFLINE',
        },
      ],
      'youtubeCategories': [],
      'movieSources': [],
      'movies': [],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
        home: PlayerScreen(config: config, channel: channel),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Kênh tạm lỗi'), findsWidgets);
    expect(find.byType(ChannelLogo), findsNothing);
    expect(find.text('Kênh trước'), findsOneWidget);

    await tester.tapAt(const Offset(195, 250));
    await tester.pump();
    final overlayAfter = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(overlayAfter.opacity, 0);

    final overlay = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(overlay.opacity, 0);
    expect(tester.takeException(), isNull);
  });
}
