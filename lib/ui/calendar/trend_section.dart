import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/daily_score.dart';
import '../section_chip.dart';
import '../theme.dart';

/// mockのpivotGradLine/pivotGradFillに対応する縦グラデーションの色と位置。
/// チャートのY値域(-2〜2)の下端=最悪(赤)〜上端=最高(青)で、基準線(0=普通)の
/// 50%を境に暖色と寒色が切り替わる。
const _pivotLineColors = [
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFF97316),
  Color(0xFF22C55E),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
];

/// Y軸レンジ内での基準線(0=普通)の相対位置pivot(0=下端,1=上端)に応じた
/// グラデーションの色と位置を返す。レンジが動的に変わっても、暖色と寒色の
/// 切り替わりが常に基準線の高さに一致するようにする。
(List<Color>, List<double>) _pivotGradient(double pivot) {
  // レンジ全体が基準線より上(全て普通以上)なら寒色のみ、下なら暖色のみ。
  if (pivot <= 0) {
    return (
      const [Color(0xFF22C55E), Color(0xFF22C55E), Color(0xFF3B82F6)],
      const [0.0, 0.4, 1.0],
    );
  }
  if (pivot >= 1) {
    return (
      const [Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFF97316)],
      const [0.0, 0.6, 1.0],
    );
  }
  return (
    _pivotLineColors,
    [0.0, pivot * 0.6, pivot, pivot, pivot + (1 - pivot) * 0.4, 1.0],
  );
}

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

    // Y軸レンジをデータの実際の振れ幅に合わせて動的に決める。全レンジ
    // (-2〜2)固定だと数値の小さな変動が潰れて見えるため、データの
    // 最小〜最大に余白を付けた範囲へズームする。ただし極端に拡大して
    // ノイズを誇張しないよう、最低でも1レベル分(1.0)の幅は確保する。
    var minY = -2.0;
    var maxY = 2.0;
    if (spots.isNotEmpty) {
      var lo = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      var hi = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      const minSpan = 1.0;
      if (hi - lo < minSpan) {
        final mid = (hi + lo) / 2;
        lo = mid - minSpan / 2;
        hi = mid + minSpan / 2;
      }
      // 上下に15%の余白を付け、スコアの定義域を少し超える所までで打ち切る。
      final pad = (hi - lo) * 0.15;
      minY = (lo - pad).clamp(-2.2, 2.2);
      maxY = (hi + pad).clamp(-2.2, 2.2);
    }
    // 基準線(0=普通)のレンジ内での相対位置。グラデーションの境界に使う。
    final pivot = (0 - minY) / (maxY - minY);
    final (pivotColors, pivotStops) = _pivotGradient(pivot);
    // 基準線がレンジ外に出た場合は破線自体を描かない。
    final showBaseline = minY <= 0 && 0 <= maxY;

    return Padding(
      // 横マージンはmockの16px × 1.37 dp換算。
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionChip(label: '7日間の傾向'),
          // タイトルバーは全幅のまま。数値・グラフ・日付ラベルは左右に
          // 内側マージンを付け、グレーのタイトルバーより明確に狭くする
          // （バーの縁とツライチにならないようにする）。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                // mockの.trendNumRow相当。ヘッダー行がタイトルの横幅を超えて
                // はみ出さないよう、余った分は数値・バッジ側を縮めて詰める
                // (前週比ラベルは固定表示を優先する)。
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        // 表示はUI値スケール(1〜5)。DB値(-2〜2)から変換する。
                        average != null
                            ? (average + 3).toStringAsFixed(1)
                            : '-',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          // mockの.trendNumRow b(20px) × 1.37。
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    // mockの.trendNumRow{gap:8px} × 1.37。
                    const SizedBox(width: 11),
                    const Text(
                      '前週比',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    if (diff != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            // mockの.trendTag{padding:2px 7px} × 1.37。
                            horizontal: 9.5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: diff >= 0
                                ? const Color(0xFFE7F8EE)
                                : const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${diff >= 0 ? '↗ +' : '↘ '}${diff.toStringAsFixed(1)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              // mockの.trendTag(10px) × 1.37。
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: diff >= 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      )
                    else
                      const Text(
                        '-',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: spots.length < 2
                      ? const Center(
                          child: Text(
                            'データが不足しています',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            // 描画をチャート枠内にクリップする。未設定だと
                            // 両端の点や曲線が枠の外へわずかにはみ出し、
                            // 上のタイトルバーの幅を超えて見えてしまう。
                            clipData: const FlClipData.all(),
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                if (showBaseline)
                                  HorizontalLine(
                                    y: 0,
                                    color: Colors.grey.shade400,
                                    strokeWidth: 1,
                                    dashArray: const [3, 3],
                                    label: HorizontalLineLabel(
                                      show: true,
                                      alignment: Alignment.topLeft,
                                      padding: const EdgeInsets.only(
                                        left: 2,
                                        bottom: 2,
                                      ),
                                      style: const TextStyle(
                                        // mockの基準線ラベル(7px) × 1.37。
                                        fontSize: 10,
                                        color: Color(0xFF9AA2B0),
                                      ),
                                      labelResolver: (_) => '普通',
                                    ),
                                  ),
                              ],
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                // 曲線補間が両端点の外側へオーバーシュートして
                                // 枠をはみ出さないようにする。
                                preventCurveOverShooting: true,
                                // mockのpivotGradLine準拠: 基準線(普通=0)を境に
                                // 下は赤→橙、上は緑→青の縦グラデーションで塗る。
                                // 境界位置は動的レンジ内の基準線の高さに追従する。
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: pivotColors,
                                  stops: pivotStops,
                                ),
                                barWidth: 2.5,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) =>
                                      FlDotCirclePainter(
                                        radius: 3,
                                        // 各点はその日の体調レベルの色で塗る（mock準拠）。
                                        color: ConditionLevel.fromDbValue(
                                          roundDailyScore(spot.y),
                                        ).color,
                                        strokeWidth: 0,
                                      ),
                                ),
                                // mockのpivotGradFill準拠: 線と基準線の間を
                                // 同系色・低不透明度のグラデーションで塗る。
                                belowBarData: BarAreaData(
                                  show: true,
                                  applyCutOffY: true,
                                  cutOffY: 0,
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      for (final c in pivotColors)
                                        c.withValues(alpha: 0.24),
                                    ],
                                    stops: pivotStops,
                                  ),
                                ),
                                aboveBarData: BarAreaData(
                                  show: true,
                                  applyCutOffY: true,
                                  cutOffY: 0,
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      for (final c in pivotColors)
                                        c.withValues(alpha: 0.24),
                                    ],
                                    stops: pivotStops,
                                  ),
                                ),
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
                        style: const TextStyle(
                          // mockの.dayLabels(9px) × 1.37。
                          fontSize: 12,
                          color: Color(0xFFB0B7C3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
