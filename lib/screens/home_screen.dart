import 'package:flutter/material.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../ui.dart';
import '../widgets/update_dialog.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'youtube_screen.dart';
import 'settings_screen.dart';

/// Màn hình chính — 4 tab duy nhất, chữ to, không menu lồng sâu.
class HomeScreen extends StatefulWidget {
  final AppConfig config;

  const HomeScreen({super.key, required this.config});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    if (PrefsService.autoUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showUpdateFlow(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const NavigationDestination(
        icon: Icon(Icons.live_tv, size: 24),
        selectedIcon: Icon(Icons.live_tv, size: 24, color: Ui.accent),
        label: 'Truyền hình',
      ),
      const NavigationDestination(
        icon: Icon(Icons.movie, size: 24),
        selectedIcon: Icon(Icons.movie, size: 24, color: Ui.accent),
        label: 'Phim',
      ),
      const NavigationDestination(
        icon: Icon(Icons.music_note, size: 24),
        selectedIcon: Icon(Icons.music_note, size: 24, color: Ui.accent),
        label: 'YouTube',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings, size: 24),
        selectedIcon: Icon(Icons.settings, size: 24, color: Ui.accent),
        label: 'Cài đặt',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          LiveScreen(config: widget.config),
          MoviesScreen(config: widget.config),
          YouTubeScreen(config: widget.config),
          SettingsScreen(onChanged: () => setState(() {})),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: tabs,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
