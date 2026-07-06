import 'package:flutter/material.dart';

import '../../domain/daily_score.dart';
import '../theme.dart';

/// mock/calendar.html 案2「平均値を主役に・日付を脇役に」に準拠した月グリッド。
/// 記録の無い日は空白（数字のみ）、ある日は円の中に日次平均値を大きく表示し、
/// 日付はその下に小さく添える。
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.scores,
    required this.onDayTap,
  });

  final DateTime month;

  /// 日(1始まり) -> その日の日次平均スコア（記録が無ければnull）。
  final Map<int, double?> scores;

  final ValueChanged<DateTime> onDayTap;

  static const _weekHeaders = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Dart: Monday=1...Sunday=7。日曜始まりの列インデックス(0=日,...,6=土)に変換する。
    final firstWeekdayColumn = DateTime(month.year, month.month, 1).weekday % 7;
    final totalCells = firstWeekdayColumn + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Padding(
      // 横マージンはmockの16px × 1.37 dp換算。
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in _weekHeaders)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        // mockの.weekHead(10px) × 1.37。
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: label == '日'
                            ? const Color(0xFFEF4444)
                            : label == '土'
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 各週の行は与えられた高さを等分して埋める（mockのgrid-auto-rows:1fr）。
          // 最終行以外は下罫線で区切る（mockの.calGrid .cell）。
          for (var row = 0; row < rowCount; row++)
            Expanded(
              child: Container(
                decoration: row < rowCount - 1
                    ? const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x12111827)),
                        ),
                      )
                    : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < 7; col++)
                      _DayCell(
                        day: row * 7 + col - firstWeekdayColumn + 1,
                        daysInMonth: daysInMonth,
                        month: month,
                        scores: scores,
                        onDayTap: onDayTap,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.daysInMonth,
    required this.month,
    required this.scores,
    required this.onDayTap,
  });

  final int day;
  final int daysInMonth;
  final DateTime month;
  final Map<int, double?> scores;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    if (day < 1 || day > daysInMonth) {
      return const Expanded(child: SizedBox.shrink());
    }

    final score = scores[day];
    final date = DateTime(month.year, month.month, day);

    return Expanded(
      child: InkWell(
        onTap: () => onDayTap(date),
        // セルの実寸に合わせて円の直径を決める。mockでは円がセル幅の
        // 約8割を占めるため、固定サイズではなく画面幅に追従させる。
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 下の日付ラベルと間隔のぶんを差し引いた高さに円を収める。
            // ラベルをmock比例(13pt)に拡大した分、確保する余白も広げる。
            const dayLabelSpace = 28.0;
            final diameter = (constraints.maxWidth * 0.8)
                .clamp(16.0, 52.0)
                .clamp(
                  0.0,
                  (constraints.maxHeight - dayLabelSpace).clamp(16.0, 52.0),
                );
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (score == null)
                    // 記録の無い日も円と同じ高さを確保し、日付ラベルの
                    // 縦位置を記録のある日と揃える。
                    SizedBox(width: diameter, height: diameter)
                  else
                    Builder(
                      builder: (context) {
                        final level = ConditionLevel.fromDbValue(
                          roundDailyScore(score),
                        );
                        return CircleAvatar(
                          radius: diameter / 2,
                          backgroundColor: level.color,
                          child: Text(
                            // 表示はUI値スケール(1〜5)。DB値(-2〜2)から変換する。
                            (score + 3).toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              // 円の直径に比例させる(直径30pxで10pt相当)。
                              fontSize: diameter / 3,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '$day',
                    style: TextStyle(
                      // mockの.avgNum(9.5px) × 1.37。
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
