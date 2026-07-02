import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// 現在表示中の画面。Calendarの日付タップからTrackへ遷移するなど、
/// 画面をまたいだナビゲーションを可能にするためRiverpodで公開する。
final currentDestinationProvider = StateProvider<AppDestination>(
  (ref) => AppDestination.track,
);
