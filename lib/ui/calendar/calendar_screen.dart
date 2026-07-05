import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/daily_score.dart';
import '../../domain/dates.dart';
import '../../providers/calendar_providers.dart';
import '../../providers/navigation_providers.dart';
import '../../providers/score_providers.dart';
import '../../providers/track_providers.dart';
import 'month_grid.dart';
import 'ratio_section.dart';
import 'trend_section.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(currentMonthProvider);
    final recordsAsync = ref.watch(allRecordsProvider);

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('読み込みエラー: $error')),
      data: (records) {
        // 日次スコアはメモ化済みのproviderから取得する。レコードやnowが
        // 変わらない限り再計算されず、月移動やComposer操作等による
        // リビルドで全履歴の系列を作り直すことがない。
        double? scoreFor(DateTime day) => ref.watch(dailyAverageProvider(day));

        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final monthScores = <int, double?>{
          for (var d = 1; d <= daysInMonth; d++)
            d: scoreFor(DateTime(month.year, month.month, d)),
        };

        final prevMonth = DateTime(month.year, month.month - 1, 1);
        final prevDaysInMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
        final prevDefinedScores = [
          for (var d = 1; d <= prevDaysInMonth; d++)
            scoreFor(DateTime(prevMonth.year, prevMonth.month, d)),
        ].whereType<double>().toList();

        final definedScores = monthScores.values.whereType<double>().toList();
        final monthAverage = averageScore(definedScores);
        final prevAverage = averageScore(prevDefinedScores);

        final todayStart = startOfDay(ref.watch(nowProvider));
        final last7Days = [
          for (var i = 6; i >= 0; i--) todayStart.subtract(Duration(days: i)),
        ];
        final last7Scores = [for (final d in last7Days) scoreFor(d)];
        // plan.md M5「7日平均と前週比」: 前週（7〜13日前）の平均。
        final prevWeekAverage = averageScore([
          for (var i = 13; i >= 7; i--)
            scoreFor(todayStart.subtract(Duration(days: i))),
        ].whereType<double>());

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _MonthNavRow(month: month),
            MonthGrid(
              month: month,
              scores: monthScores,
              onDayTap: (day) {
                requestDateJump(ref, day);
                ref.read(currentDestinationProvider.notifier).state = AppDestination.track;
              },
            ),
            const SizedBox(height: 16),
            RatioSection(
              scores: definedScores,
              monthAverage: monthAverage,
              prevAverage: prevAverage,
            ),
            const SizedBox(height: 16),
            TrendSection(
              days: last7Days,
              scores: last7Scores,
              prevWeekAverage: prevWeekAverage,
            ),
          ],
        );
      },
    );
  }
}

class _MonthNavRow extends ConsumerWidget {
  const _MonthNavRow({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(currentMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1, 1),
          ),
          Text(
            '${month.year}年${month.month}月',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(currentMonthProvider.notifier).state =
                DateTime(month.year, month.month + 1, 1),
          ),
        ],
      ),
    );
  }
}
