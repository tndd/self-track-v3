import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/condition_series.dart';
import '../domain/daily_score.dart';
import '../domain/dates.dart';
import 'calendar_providers.dart';

/// 派生計算が参照する「現在時刻」。1分ごとに自らを無効化して進む。
///
/// 体調系列や日次スコアは12時間減衰・当日の部分積分のためにnowに依存する。
/// 各計算がDateTime.now()を直接呼ぶとメモ化により「次のレコード書き込みまで
/// 時刻が止まる」ため、時刻の進行をproviderの依存として明示する。
/// ウィジェットテストでは固定時刻でoverrideすること（実タイマーを残さない）。
final nowProvider = Provider.autoDispose<DateTime>((ref) {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime.now();
});

/// 全レコードから構築した体調系列（12時間減衰の仮想ポイント込み）。
/// レコードの変化とnowの進行にのみ反応してメモ化される。Calendar・Statsの
/// 全日次スコア・イベントロック平均がこの1本を共有し、ビルドのたびに
/// 系列を作り直すことを避ける。
final conditionSeriesProvider = Provider.autoDispose<List<ConditionPoint>>((ref) {
  final records = ref.watch(allRecordsProvider).value ?? const [];
  final now = ref.watch(nowProvider);
  return buildConditionSeries(records, now: now);
});

/// レコードが1件以上存在する日の集合。日次スコアの「記録なし日」判定を
/// 全レコード走査ではなく集合参照で行うための前計算。
final recordedDaysProvider = Provider.autoDispose<Set<DateTime>>((ref) {
  final records = ref.watch(allRecordsProvider).value ?? const [];
  return {for (final record in records) startOfDay(record.timestamp)};
});

/// 指定日の日次平均スコア（記録の無い日はnull）。
/// 家族(family)引数は日の開始時刻（startOfDay済み）で渡すこと。
final dailyAverageProvider =
    Provider.autoDispose.family<double?, DateTime>((ref, day) {
  final records = ref.watch(allRecordsProvider).value ?? const [];
  if (records.isEmpty) return null;
  return computeDailyAverage(
    allRecordsAscending: records,
    day: day,
    now: ref.watch(nowProvider),
    series: ref.watch(conditionSeriesProvider),
    recordedDays: ref.watch(recordedDaysProvider),
  );
});
