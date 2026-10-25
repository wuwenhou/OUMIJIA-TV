import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'screens/home_screen.dart';
import 'services/config_service.dart';
import 'services/prefs_service.dart';
import 'ui.dart';

/// OUMIJIA TV — xem truyền hình, phim, YouTube không quảng cáo cho người già.
///
/// Luồng khởi động:
/// 1. Nạp cài đặt tại máy (kênh cuối, cỡ chữ...)
/// 2. Tải cấu hình nội dung (GitHub → cache → bundled)
/// 3. Vào màn hình chính, tự phát kênh xem lần cuối
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await PrefsService.init();
  final config = await ConfigService.load();

  runApp(OumijiaTvApp(config: config));
}

class OumijiaTvApp extends StatelessWidget {
  final AppConfig config;

  const OumijiaTvApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OUMIJIA TV',
      debugShowCheckedModeBanner: false,
      theme: Ui.theme(),
      home: HomeScreen(config: config),
    );
  }
}
