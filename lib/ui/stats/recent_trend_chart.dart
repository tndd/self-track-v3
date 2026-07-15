import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../providers/score_providers.dart';

/// spec.md M6「直近30日の体調スコア推移グラフ」。
/// 日次スコアはメモ化済みのdailyAverageProviderから取得する。
class RecentTrendChart extends ConsumerWidget {
  const RecentTrendChart({super.key, this.days = 30});

  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = startOfDay(ref.watch(nowProvider));
    final dayList = [for (var i = days - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    final scores = [for (final d in dayList) ref.watch(dailyAverageProvider(d))];

    final spots = <FlSpot>[
      for (var i = 0; i < scores.length; i++)
        if (scores[i] != null) FlSpot(i.toDouble(), scores[i]!),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '直近30日の体調スコア推移',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF344054)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: spots.length < 2
                ? const Center(
                    child: Text('データが不足しています', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  )
                : LineChart(
                    LineChartData(
                      // 記録の無い日が端にあってもX軸が全期間に固定されるよう
                      // 明示する。自動スケールに任せると下の日付ラベル
                      // （30日前/今日）と折れ線の範囲がズレる。
                      minX: 0,
                      maxX: (days - 1).toDouble(),
                      minY: -2,
                      maxY: 2,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 0,
                            color: Colors.grey.shade400,
                            strokeWidth: 1,
                            dashArray: const [3, 3],
                          ),
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF3B82F6),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: const Color(0x333B82F6)),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${dayList.first.month}/${dayList.first.day}',
                style: const TextStyle(fontSize: 9, color: Color(0xFFB0B7C3)),
              ),
              Text(
                '${dayList.last.month}/${dayList.last.day}',
                style: const TextStyle(fontSize: 9, color: Color(0xFFB0B7C3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
