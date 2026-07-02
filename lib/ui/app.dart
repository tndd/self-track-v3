import 'package:flutter/material.dart';

import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import 'stats/stats_screen.dart';
import 'tags/tags_screen.dart';
import 'theme.dart';
import 'track/track_screen.dart';

/// アプリの5つの遷移先。mock/menu.png のドロップダウンメニューに準拠し、
/// Drawer（横スライド）ではなくハンバーガーアイコン直下に浮かぶカード型メニューで切り替える。
enum AppDestination {
  track('Today', Icons.today_outlined),
  calendar('Calendar', Icons.calendar_month_outlined),
  stats('Analysis', Icons.insights_outlined),
  tags('Tags', Icons.sell_outlined),
  settings('Settings', Icons.settings_outlined);

  const AppDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class SelfTrackApp extends StatelessWidget {
  const SelfTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'self-track',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _current = AppDestination.track;
  final OverlayPortalController _menuController = OverlayPortalController();
  final LayerLink _menuLink = LayerLink();

  void _select(AppDestination destination) {
    setState(() => _current = destination);
    _menuController.hide();
  }

  Widget _buildScreen(AppDestination destination) {
    switch (destination) {
      case AppDestination.track:
        return const TrackScreen();
      case AppDestination.calendar:
        return const CalendarScreen();
      case AppDestination.stats:
        return const StatsScreen();
      case AppDestination.tags:
        return const TagsScreen();
      case AppDestination.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompositedTransformTarget(
                    link: _menuLink,
                    child: OverlayPortal(
                      controller: _menuController,
                      overlayChildBuilder: (context) => _MenuOverlay(
                        link: _menuLink,
                        current: _current,
                        onSelect: _select,
                        onDismiss: _menuController.hide,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: _menuController.toggle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _current.label,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: AppDestination.values.indexOf(_current),
                children: AppDestination.values.map(_buildScreen).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.link,
    required this.current,
    required this.onSelect,
    required this.onDismiss,
  });

  final LayerLink link;
  final AppDestination current;
  final void Function(AppDestination) onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            child: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final destination in AppDestination.values)
                    _MenuItem(
                      destination: destination,
                      selected: destination == current,
                      onTap: () => onSelect(destination),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F3F7))),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(destination.icon, size: 18, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                destination.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check, size: 18),
          ],
        ),
      ),
    );
  }
}
