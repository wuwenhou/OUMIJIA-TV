import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oumijia_tv/models.dart';
import 'package:oumijia_tv/services/prefs_service.dart';
import 'package:oumijia_tv/theme/design_system.dart';
import 'package:oumijia_tv/widgets/channel_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.init();
  });

  Future<void> pumpCard(WidgetTester tester, Channel channel) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
        home: Scaffold(
          body: ListView(
            children: [
              ChannelCard(
                channel: channel,
                onTap: () {},
              ),
              ChannelGridTile(
                channel: channel,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hiển thị tên kênh mà không có logo bên trái', (tester) async {
    final channel = Channel.fromJson({
      'id': 'vtv1',
      'name': 'VTV1',
      'group': 'Quốc gia',
      'logo': '',
      'primary': 'http://example.com/vtv1.m3u8',
      'health': 'WORKING',
    });

    await pumpCard(tester, channel);

    expect(find.text('VTV1'), findsWidgets);
    expect(find.byType(ChannelLogo), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cỡ chữ lớn không làm tên và trạng thái tràn layout',
      (tester) async {
    final channel = Channel.fromJson({
      'id': 'thvl1',
      'name': 'Truyền hình Vĩnh Long 1',
      'group': 'Địa phương',
      'logo': '',
      'primary': 'http://example.com/thvl1.m3u8',
      'health': 'WORKING',
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(mode: Brightness.dark, accentKey: 'gold'),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: ChannelCard(
              channel: channel,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Truyền hình Vĩnh Long 1'), findsOneWidget);
    expect(find.text('Đang phát'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
