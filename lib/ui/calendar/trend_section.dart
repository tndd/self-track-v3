import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/daily_score.dart';
import '../section_chip.dart';

/// mock/calendar.html の「7日間の傾向」セクション：直近7日の日次平均の
/// スパークラインと、前週（7〜13日前）平均との比較（plan.md M5）。
class TrendSection extends StatelessWidget {
  const TrendSection({
    super.key,
    required this.days,
    required this.scores,
    this.prevWeekAverage,
  });

  final List<DateTime> days;
  final List<double?> scores;

  /// 前週（7〜13日前）の日次平均の平均。記録が無ければnull。
  final double? prevWeekAverage;

  @override
  Widget build(BuildContext context) {
    final average = averageScore(scores.whereType<double>());
    final diff = (average != null && prevWeekAverage != null)
        ? average - prevWeekAverage!
        : null;

    final spots = <FlSpot>[
      for (var i = 0; i < scores.length; i++)
        if (scores[i] != null) FlSpot(i.toDouble(), scores[i]!),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionChip(label: '7日間の傾向'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                // 表示はUI値スケール(1〜5)。DB値(-2〜2)から変換する。
                average != null ? (average + 3).toStringAsFixed(1) : '-',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 10),
              const Text('前週比', style: TextStyle(fontSize: 9, color: Colors.grey)),
              const SizedBox(width: 4),
              if (diff != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: diff >= 0 ? const Color(0xFFE7F8EE) : const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${diff >= 0 ? '↗ +' : '↘ '}${diff.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: diff >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                )
              else
                const Text('-', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: spots.length < 2
                ? const Center(
                    child: Text('データが不足しています', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  )
                : LineChart(
                    LineChartData(
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
                          barWidth: 2.5,
                          dotData: const FlDotData(show: true),
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
              for (final day in days)
                Text(
                  '${day.month}/${day.day}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFFB0B7C3)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
