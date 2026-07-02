import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import 'database_providers.dart';

/// 日次スコア計算（境界補間）にはアプリ全体のレコードが必要なため、
/// 期間を絞らず全件を監視する。
final allRecordsProvider = StreamProvider.autoDispose<List<RecordWithTags>>((ref) {
  return ref.watch(recordsDaoProvider).watchAll();
});

/// Calendar画面で表示中の月（月初の日付で表す）。
final currentMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});
