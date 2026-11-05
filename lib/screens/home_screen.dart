import 'package:flutter/material.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../widgets/update_dialog.dart';
import 'channels_screen.dart';
import 'movies_screen.dart';
import 'settings_screen.dart';
import 'youtube_screen.dart';

/// Khung điều hướng chính — 4 tab: Kênh · Phim · YouTube · Cài đặt.
/// Không còn tab Trang chủ; mở app vào thẳng danh sách kênh.
class HomeScreen extends StatefulWidget {
  final AppConfig config;

  const HomeScreen({super.key, required this.config});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late AppConfig _config = widget.config;

  /// Chỉ dựng tab khi người dùng mở lần đầu — tránh gọi mạng YouTube,
  /// đọc PackageInfo... ngay lúc khởi động.
  final Set<int> _visited = {0};

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      _visited.add(index);
    });
  }

  @override
  void initState() {
    super.initState();
    if (PrefsService.autoUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await checkAndShowUpdate(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(
          icon: Icon(Icons.tv_outlined),
          selectedIcon: Icon(Icons.tv),
          label: 'Kênh'),
      NavigationDestination(
          icon: Icon(Icons.movie_outlined),
          selectedIcon: Icon(Icons.movie),
          label: 'Phim'),
      NavigationDestination(
          icon: Icon(Icons.smart_display_outlined),
          selectedIcon: Icon(Icons.smart_display),
          label: 'YouTube'),
      NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Cài đặt'),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _visited.contains(0)
              ? ChannelsScreen(
                  config: _config,
                  onConfigChanged: (cfg) => setState(() => _config = cfg),
                )
              : const SizedBox.shrink(),
          _visited.contains(1)
              ? MoviesScreen(config: _config)
              : const SizedBox.shrink(),
          _visited.contains(2)
              ? YouTubeScreen(config: _config)
              : const SizedBox.shrink(),
          _visited.contains(3)
              ? SettingsScreen(config: _config)
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: destinations,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
