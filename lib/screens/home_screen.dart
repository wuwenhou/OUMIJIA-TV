import 'package:flutter/material.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../ui.dart';
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
  Widget build(BuildContext context) {
    final scale = PrefsService.fontScale;

    final tabs = [
      const NavigationDestination(
        icon: Icon(Icons.live_tv, size: 32),
        selectedIcon: Icon(Icons.live_tv, size: 32, color: Ui.accent),
        label: 'Truyền hình',
      ),
      const NavigationDestination(
        icon: Icon(Icons.movie, size: 32),
        selectedIcon: Icon(Icons.movie, size: 32, color: Ui.accent),
        label: 'Phim',
      ),
      const NavigationDestination(
        icon: Icon(Icons.music_note, size: 32),
        selectedIcon: Icon(Icons.music_note, size: 32, color: Ui.accent),
        label: 'YouTube',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings, size: 32),
        selectedIcon: Icon(Icons.settings, size: 32, color: Ui.accent),
        label: 'Cài đặt',
      ),
    ];

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 2.0,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: _scaledTextTheme(Theme.of(context).textTheme, scale),
        ),
        child: Scaffold(
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
            height: 84,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: tabs,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
        ),
      ),
    );
  }

  TextTheme _scaledTextTheme(TextTheme t, double s) => TextTheme(
        displaySmall: t.displaySmall?.copyWith(fontSize: (t.displaySmall?.fontSize ?? 36) * s),
        titleLarge: t.titleLarge?.copyWith(fontSize: (t.titleLarge?.fontSize ?? 26) * s),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: (t.bodyLarge?.fontSize ?? 20) * s),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: (t.bodyMedium?.fontSize ?? 18) * s),
        labelLarge: t.labelLarge?.copyWith(fontSize: (t.labelLarge?.fontSize ?? 18) * s),
      );
}
