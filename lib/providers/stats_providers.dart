import 'package:flutter_riverpod/flutter_riverpod.dart';

/// イベントロック平均グラフで現在選択中のタグID。未選択ならnull。
final selectedEventTagIdProvider = StateProvider<String?>((ref) => null);
