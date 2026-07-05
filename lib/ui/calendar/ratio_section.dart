import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/daily_score.dart';
import '../section_chip.dart';
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
      final level = ConditionLevel.fromDbValue(roundDailyScore(score));
      counts[level] = (counts[level] ?? 0) + 1;
    }
    final total = scores.length;

    // 前月比はUI値スケール(1〜5)同士の変化率(%)で表示する（mockの「↗ +11%」）。
    final hasComparison = monthAverage != null && prevAverage != null;
    final diffPercent = hasComparison
        ? ((monthAverage! + 3) - (prevAverage! + 3)) / (prevAverage! + 3) * 100
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionChip(label: '今月の割合'),
          const SizedBox(height: 10),
          // mock準拠の横並び: ドーナツ(110px固定) / 凡例(固定幅・ドーナツと同じ高さに等間隔配置)
          // / 前月比(残り幅の中央寄せ)。凡例をExpandedにすると中央に大きな
          // 空白ができてmockと乖離するため、幅は固定にする。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: total == 0
                    ? const Center(
                        child: Text(
                          'データ無し',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
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
                                      radius: 15,
                                      showTitle: false,
                                    ),
                              ],
                              // mockのドーナツはセグメント間に隙間が無い。
                              sectionsSpace: 0,
                              centerSpaceRadius: 34,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                // 表示はUI値スケール(1〜5)。DB値(-2〜2)から変換する。
                                monthAverage != null
                                    ? (monthAverage! + 3).toStringAsFixed(1)
                                    : '-',
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const Text(
                                '今月平均',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFFAAB2C0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 10),
              // 凡例: mockの.legendColA（幅固定・ドーナツと同じ高さに等間隔配置）。
              SizedBox(
                width: 92,
                height: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final level in ConditionLevel.values)
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: level.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${counts[level] ?? 0}日',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (total > 0)
                            Text(
                              '${(((counts[level] ?? 0) / total) * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF9AA2B0),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              // 前月比: mockの.momSlot（残り幅を使い、縦横とも中央に配置）。
              Expanded(
                child: SizedBox(
                  height: 110,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '前月比',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF98A2B3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (diffPercent != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: diffPercent >= 0
                                ? const Color(0xFFE7F8EE)
                                : const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${diffPercent >= 0 ? '↗ +' : '↘ '}${diffPercent.round()}%',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: diffPercent >= 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        )
                      else
                        const Text(
                          '-',
                          style: TextStyle(fontSize: 17, color: Colors.grey),
                        ),
                      if (prevAverage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '先月 ${(prevAverage! + 3).toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFAAB2C0),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
