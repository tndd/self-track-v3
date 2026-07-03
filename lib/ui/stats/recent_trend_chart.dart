import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/condition_series.dart';
import '../../domain/daily_score.dart';
import '../../domain/models.dart';

/// plan.md M6「直近30日の体調スコア推移グラフ」。
class RecentTrendChart extends StatelessWidget {
  const RecentTrendChart({super.key, required this.records, this.days = 30});

  final List<RecordWithTags> records;
  final int days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayList = [for (var i = days - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    // 30日分をスコアリングするたびに全レコードから系列を再構築しないよう、
    // 系列と記録日集合はここで1回だけ作る。
    final series = buildConditionSeries(records, now: now);
    final recordedDays = {
      for (final r in records)
        DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day),
    };
    final scores = [
      for (final d in dayList)
        computeDailyAverageFromSeries(series: series, recordedDays: recordedDays, day: d),
    ];

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
