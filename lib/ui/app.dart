import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_providers.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import 'stats/stats_screen.dart';
import 'tags/tags_screen.dart';
import 'theme.dart';
import 'track/track_screen.dart';

export '../providers/navigation_providers.dart' show AppDestination;

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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final OverlayPortalController _menuController = OverlayPortalController();
  final LayerLink _menuLink = LayerLink();

  void _select(AppDestination destination) {
    ref.read(currentDestinationProvider.notifier).state = destination;
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
    final current = ref.watch(currentDestinationProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompositedTransformTarget(
                    link: _menuLink,
                    child: OverlayPortal(
                      controller: _menuController,
                      overlayChildBuilder: (context) => _MenuOverlay(
                        link: _menuLink,
                        current: current,
                        onSelect: _select,
                        onDismiss: _menuController.hide,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu),
                        iconSize: 30,
                        onPressed: _menuController.toggle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.label,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                          ),
                          // Trackのみ、mock同様タイトル直下にスクロール位置へ
                          // 追従する日付サブ行を表示する。
                          if (current == AppDestination.track)
                            const TrackDateSubtitle(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: AppDestination.values.indexOf(current),
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
