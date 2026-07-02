import 'condition_series.dart';
import 'models.dart';

/// design.md §4.2: 指定日(00:00〜24:00)の体調スコアを台形公式で積分し、
/// 24時間で正規化した平均値（-2〜2の連続値）として返す。
///
/// [allRecordsAscending] はアプリ全体のレコードをtimestamp昇順に並べたもの
/// （境界値の補間には対象日の前後のレコードも必要なため、対象日分だけでなく
/// 全件を渡す）。[now] は12時間減衰の判定に使う現在時刻。
///
/// 対象日に実レコードが1件も無い場合はnullを返す（design.md §4.2および
/// Calendar画面では「記録の無い日」として空白表示にするため）。
double? computeDailyAverage({
  required List<RecordWithTags> allRecordsAscending,
  required DateTime day,
  required DateTime now,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final hasRecordThatDay = allRecordsAscending.any(
    (r) => !r.timestamp.isBefore(dayStart) && r.timestamp.isBefore(dayEnd),
  );
  if (!hasRecordThatDay) return null;

  final series = buildConditionSeries(allRecordsAscending, now: now);

  final interior = series.where(
    (p) => p.timestamp.isAfter(dayStart) && p.timestamp.isBefore(dayEnd),
  );

  final points = <ConditionPoint>[
    ConditionPoint(timestamp: dayStart, value: valueAtTime(series, dayStart)),
    ...interior,
    ConditionPoint(timestamp: dayEnd, value: valueAtTime(series, dayEnd)),
  ];

  var area = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final hours = b.timestamp.difference(a.timestamp).inMicroseconds / Duration.microsecondsPerHour;
    area += (a.value + b.value) / 2 * hours;
  }

  return area / 24;
}
