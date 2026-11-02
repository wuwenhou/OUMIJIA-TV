import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'screens/home_screen.dart';
import 'services/brightness_service.dart';
import 'services/config_service.dart';
import 'services/prefs_service.dart';
import 'theme/design_system.dart';
import 'theme/theme_controller.dart';

/// OUMIJIA TV — xem truyền hình, phim, YouTube không quảng cáo.
///
/// Khởi động: nạp cài đặt → controller giao diện → cấu hình nội dung
/// (GitHub → cache → bundled) → vào Home.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemOrientations.init();
  await PrefsService.init();
  await BrightnessService.init();
  await ThemeController.instance.load();
  final config = await ConfigService.load();

  runApp(OumijiaTvApp(config: config));
}

/// Ví linh hoạt: cho phép ngang (phát) và dọc (trang điều hướng).
abstract class SystemOrientations {
  static Future<void> init() => SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
}

class OumijiaTvApp extends StatefulWidget {
  final AppConfig config;

  const OumijiaTvApp({super.key, required this.config});

  @override
  State<OumijiaTvApp> createState() => _OumijiaTvAppState();
}

class _OumijiaTvAppState extends State<OumijiaTvApp> {
  // Nghe thay đổi theme ngay lập tức, không cần khởi động lại.
  final ThemeController _theme = ThemeController.instance;

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _theme.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = _theme.value;
    return MaterialApp(
      title: 'OUMIJIA TV',
      debugShowCheckedModeBanner: false,
      themeMode: s.mode,
      theme: buildTheme(mode: Brightness.light, accentKey: s.accentKey, fontScale: s.fontScale),
      darkTheme: buildTheme(mode: Brightness.dark, accentKey: s.accentKey, fontScale: s.fontScale),
      home: HomeScreen(config: widget.config),
    );
  }
}
