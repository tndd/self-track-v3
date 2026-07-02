import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// mock/calendar.html の「今月の割合」セクション：5段階の日数・割合のドーナツと前月比。
class RatioSection extends StatelessWidget {
  const RatioSection({
    super.key,
    required this.scores,
    required this.monthAverage,
    required this.prevAverage,
  });

  /// 当月のうち記録が存在した日の日次平均スコアの一覧。
  final List<double> scores;
  final double? monthAverage;
  final double? prevAverage;

  @override
  Widget build(BuildContext context) {
    final counts = {for (final level in ConditionLevel.values) level: 0};
    for (final score in scores) {
      final level = ConditionLevel.fromDbValue(score.round().clamp(-2, 2));
      counts[level] = (counts[level] ?? 0) + 1;
    }
    final total = scores.length;

    final hasComparison = monthAverage != null && prevAverage != null;
    final diff = hasComparison ? monthAverage! - prevAverage! : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionChip(label: '今月の割合'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: total == 0
                    ? const Center(
                        child: Text('データ無し', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sections: [
                                for (final level in ConditionLevel.values)
                                  if ((counts[level] ?? 0) > 0)
                                    PieChartSectionData(
                                      value: (counts[level] ?? 0).toDouble(),
                                      color: level.color,
                                      radius: 14,
                                      showTitle: false,
                                    ),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: 24,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                monthAverage?.toStringAsFixed(1) ?? '-',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const Text(
                                '今月平均',
                                style: TextStyle(fontSize: 9, color: Color(0xFFAAB2C0)),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final level in ConditionLevel.values)
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${counts[level] ?? 0}日',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 4),
                          if (total > 0)
                            Text(
                              '${(((counts[level] ?? 0) / total) * 100).round()}%',
                              style: const TextStyle(fontSize: 8.5, color: Color(0xFF9AA2B0)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 74,
                child: Column(
                  children: [
                    const Text('前月比', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    const SizedBox(height: 6),
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
                    if (prevAverage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '先月 ${prevAverage!.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 8.5, color: Color(0xFFAAB2C0)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF667085)),
      ),
    );
  }
}
