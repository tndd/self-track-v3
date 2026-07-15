import 'condition_series.dart';
import 'dates.dart';
import 'models.dart';

/// spec.md §4.2: 指定日(00:00〜24:00)の体調スコアを台形公式で積分し、
/// 経過時間で正規化した平均値（-2〜2の連続値）として返す。
///
/// [allRecordsAscending] はアプリ全体のレコードをtimestamp昇順に並べたもの
/// （境界値の補間には対象日の前後のレコードも必要なため、対象日分だけでなく
/// 全件を渡す）。[now] は12時間減衰の判定に使う現在時刻。
///
/// [series] に構築済みの体調系列（buildConditionSeriesの結果）を渡すと
/// 再構築を省略できる。複数日をまとめて計算する呼び出し側は、系列を
/// 1回だけ構築して全日で共有すること。
///
/// 対象日が当日（[now]が対象日の途中）の場合は 00:00〜now の部分積分とし、
/// 経過時間で正規化する。未来の時間帯を最終ログ値のまま積分して
/// スコアが過大・過小評価されることを防ぐため。
///
/// [recordedDays]（各レコードのtimestampをstartOfDayで丸めた日の集合）を
/// 渡すと「対象日にレコードがあるか」の判定に全レコード走査の代わりに
/// 集合参照を使う。複数日をまとめて計算する呼び出し側向けの前計算。
///
/// 対象日に実レコードが1件も無い場合はnullを返す（spec.md §4.2および
/// Calendar画面では「記録の無い日」として空白表示にするため）。
double? computeDailyAverage({
  required List<RecordWithTags> allRecordsAscending,
  required DateTime day,
  required DateTime now,
  List<ConditionPoint>? series,
  Set<DateTime>? recordedDays,
}) {
  final dayStart = startOfDay(day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final effectiveEnd = dayEnd.isAfter(now) ? now : dayEnd;
  if (!effectiveEnd.isAfter(dayStart)) return null;

  final hasRecordThatDay = recordedDays != null
      ? recordedDays.contains(dayStart)
      : allRecordsAscending.any(
          (r) => !r.timestamp.isBefore(dayStart) && r.timestamp.isBefore(dayEnd),
        );
  if (!hasRecordThatDay) return null;

  final resolvedSeries =
      series ?? buildConditionSeries(allRecordsAscending, now: now);

  final interior = resolvedSeries.where(
    (p) => p.timestamp.isAfter(dayStart) && p.timestamp.isBefore(effectiveEnd),
  );

  final points = <ConditionPoint>[
    ConditionPoint(timestamp: dayStart, value: valueAtTime(resolvedSeries, dayStart)),
    ...interior,
    ConditionPoint(timestamp: effectiveEnd, value: valueAtTime(resolvedSeries, effectiveEnd)),
  ];

  var area = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final hours = b.timestamp.difference(a.timestamp).inMicroseconds / Duration.microsecondsPerHour;
    area += (a.value + b.value) / 2 * hours;
  }

  final totalHours =
      effectiveEnd.difference(dayStart).inMicroseconds / Duration.microsecondsPerHour;
  return area / totalHours;
}

/// spec.md §6.2: 日次平均（連続値）をカレンダー等の5段階表示に丸める規則。
/// 四捨五入した上でDB値域(-2〜2)にクランプする。
int roundDailyScore(double score) => score.round().clamp(-2, 2);

/// 定義済みスコアの平均。1件も無ければnull。
/// 月平均・7日平均などの集計で共通に使う。
double? averageScore(Iterable<double> scores) {
  var sum = 0.0;
  var count = 0;
  for (final score in scores) {
    sum += score;
    count++;
  }
  return count == 0 ? null : sum / count;
}
