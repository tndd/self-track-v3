import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/daily_score.dart';
import '../../providers/calendar_providers.dart';
import '../../providers/navigation_providers.dart';
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
        final now = DateTime.now();
        double? scoreFor(DateTime day) =>
            computeDailyAverage(allRecordsAscending: records, day: day, now: now);

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
        final monthAverage = definedScores.isEmpty
            ? null
            : definedScores.reduce((a, b) => a + b) / definedScores.length;
        final prevAverage = prevDefinedScores.isEmpty
            ? null
            : prevDefinedScores.reduce((a, b) => a + b) / prevDefinedScores.length;

        final todayStart = DateTime(now.year, now.month, now.day);
        final last7Days = [
          for (var i = 6; i >= 0; i--) todayStart.subtract(Duration(days: i)),
        ];
        final last7Scores = [for (final d in last7Days) scoreFor(d)];

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _MonthNavRow(month: month),
            MonthGrid(
              month: month,
              scores: monthScores,
              onDayTap: (day) {
                ref.read(selectedDateProvider.notifier).state = day;
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
            TrendSection(days: last7Days, scores: last7Scores),
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
