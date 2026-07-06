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
      // 横マージンはmockの16px × 1.37 dp換算。
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionChip(label: '今月の割合'),
          // mockの.ratioContentH{padding-top:10px} × 1.37 dp換算。
          const SizedBox(height: 14),
          // mock準拠の横並び: ドーナツ / 凡例(固定幅・ドーナツと同じ高さに等間隔配置)
          // / 前月比(残り幅の中央寄せ)。凡例をExpandedにすると中央に大きな
          // 空白ができてmockと乖離するため、幅は固定にする。
          // 各要素の寸法はmock/calendar.htmlのpx値 × 1.37 dp換算
          // （他画面のComposerCard等と同じ規約）。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                // mockの.ratioDonut(90px) × 1.37。
                width: 123,
                height: 123,
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
                                      // mockのring stroke-width(14) を
                                      // viewBoxスケール(0.9)と1.37で換算。
                                      radius: 17.5,
                                      showTitle: false,
                                    ),
                              ],
                              // mockのドーナツはセグメント間に隙間が無い。
                              sectionsSpace: 0,
                              // mockの内側半径(31svg単位) × 0.9 × 1.37。
                              centerSpaceRadius: 38,
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
                                  // mockのSVGテキスト(19px) × 1.37。
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const Text(
                                '今月平均',
                                style: TextStyle(
                                  // mockのSVGテキスト(9px) × 1.37。
                                  fontSize: 12,
                                  color: Color(0xFFAAB2C0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              // mockの.ratioContentH{gap:10px} × 1.37。
              const SizedBox(width: 14),
              // 凡例: mockの.legendColA（ドーナツと同じ高さに等間隔配置）。
              // mockは幅60px固定だが、実フォントでは2桁日数+2桁%だと
              // 収まらない。固定幅にすると前月比(momSlot)側の残り幅を
              // 狭めてmockより窮屈に見えるため、必要な分だけ幅を取る
              // IntrinsicWidthにして前月比側に余裕を残す。
              IntrinsicWidth(
                child: SizedBox(
                  height: 123,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final level in ConditionLevel.values)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: level.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            // mockの.legRowA{gap:4px} × 1.37。
                            const SizedBox(width: 5.5),
                            Text(
                              '${counts[level] ?? 0}日',
                              style: const TextStyle(
                                // mockの.legRowA b(10px) × 1.37。
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 5.5),
                            if (total > 0)
                              Text(
                                '${(((counts[level] ?? 0) / total) * 100).round()}%',
                                style: const TextStyle(
                                  // mockの.pct(8.5px) × 1.37。
                                  fontSize: 11.5,
                                  color: Color(0xFF9AA2B0),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 前月比: mockの.momSlot（残り幅を使い、縦横とも中央に配置）。
              Expanded(
                child: SizedBox(
                  // mockの.momSlot(90px) × 1.37。
                  height: 123,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '前月比',
                        style: TextStyle(
                          // mockの.momLabel(9px) × 1.37。
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF98A2B3),
                        ),
                      ),
                      // mockの.momLabel{margin-bottom:6px} × 1.37。
                      const SizedBox(height: 8),
                      if (diffPercent != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            // mockの.momBadge{padding:6px 13px} × 1.37。
                            horizontal: 18,
                            vertical: 8,
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
                              // mockの.momBadge(15px) × 1.37。
                              fontSize: 20.5,
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
                          style: TextStyle(fontSize: 20.5, color: Colors.grey),
                        ),
                      if (prevAverage != null)
                        Padding(
                          // mockの.momBadgeSub{margin-top:6px} × 1.37。
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '先月 ${(prevAverage! + 3).toStringAsFixed(1)}',
                            style: const TextStyle(
                              // mockの.momBadgeSub(8.5px) × 1.37。
                              fontSize: 11.5,
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
