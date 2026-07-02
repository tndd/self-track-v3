import 'package:flutter/material.dart';

import '../theme.dart';

/// mock/calendar.html 案1「そのまま」に準拠した月グリッド。
/// 記録の無い日は空白（数字のみ）、ある日は日次平均を5段階に丸めた色のドットで表示する。
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        fontSize: 10,
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
          const SizedBox(height: 4),
          for (var row = 0; row < rowCount; row++)
            Row(
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
      return const Expanded(child: SizedBox(height: 40));
    }

    final score = scores[day];
    final date = DateTime(month.year, month.month, day);

    return Expanded(
      child: InkWell(
        onTap: () => onDayTap(date),
        child: SizedBox(
          height: 40,
          child: Center(
            child: score == null
                ? Text('$day', style: const TextStyle(fontSize: 12, color: Colors.grey))
                : CircleAvatar(
                    radius: 15,
                    backgroundColor:
                        ConditionLevel.fromDbValue(score.round().clamp(-2, 2)).color,
                    child: Text(
                      '$day',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
