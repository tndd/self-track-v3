import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/domain/condition_series.dart';
import 'package:self_track_v3/domain/daily_score.dart';
import 'package:self_track_v3/domain/models.dart';

RecordWithTags _record(DateTime timestamp, int value) {
  return RecordWithTags(
    id: 'r-${timestamp.microsecondsSinceEpoch}',
    timestamp: timestamp,
    comment: null,
    value: value,
    tags: const [],
  );
}

void main() {
  group('computeDailyAverage', () {
    test('レコードが1件も無い日はnullを返す（Calendarでは空白表示にする）', () {
      final result = computeDailyAverage(
        allRecordsAscending: const [],
        day: DateTime(2026, 6, 29),
        now: DateTime(2026, 6, 29, 20),
      );

      expect(result, isNull);
    });

    test('対象日以外にしかレコードが無い場合もnullを返す', () {
      final other = _record(DateTime(2026, 6, 28, 12), 1);

      final result = computeDailyAverage(
        allRecordsAscending: [other],
        day: DateTime(2026, 6, 29),
        now: DateTime(2026, 6, 29, 20),
      );

      expect(result, isNull);
    });

    test('当日（nowが対象日の途中）は00:00〜nowの部分積分を経過時間で正規化する', () {
      final record = _record(DateTime(2026, 6, 29, 12), 2);

      final result = computeDailyAverage(
        allRecordsAscending: [record],
        day: DateTime(2026, 6, 29),
        now: DateTime(2026, 6, 29, 12),
      );

      // 00:00→12:00: (0+2)/2*12=12 を経過12時間で正規化して1.0。
      // （未来の12:00→24:00を最終値2のまま積分してしまうと1.5に過大評価される）
      expect(result, closeTo(1.0, 1e-9));
    });

    test('過去日は00:00〜24:00の全区間を積分する（12時間減衰込み）', () {
      final record = _record(DateTime(2026, 6, 29, 12), 2);

      final result = computeDailyAverage(
        allRecordsAscending: [record],
        day: DateTime(2026, 6, 29),
        now: DateTime(2026, 6, 30, 12),
      );

      // 00:00→12:00: (0+2)/2*12=12, 12:00→24:00(減衰で6/30 0:00に0へ): (2+0)/2*12=12
      // 合計24 / 24h = 1.0
      expect(result, closeTo(1.0, 1e-9));
    });

    test('前日・翌日のレコードから当日の境界値を線形補間する（日跨ぎ）', () {
      final prevDay = _record(DateTime(2026, 6, 28, 18), 0);
      final morning = _record(DateTime(2026, 6, 29, 6), 2);
      // 06-29 06:00 から 06-30 06:00 まで24時間離れているため、
      // 06-29 18:00 に仮想ポイント(value=0)が挿入される。
      final nextDay = _record(DateTime(2026, 6, 30, 6), -2);

      final result = computeDailyAverage(
        allRecordsAscending: [prevDay, morning, nextDay],
        day: DateTime(2026, 6, 29),
        now: DateTime(2026, 6, 30, 6),
      );

      // dayStart(00:00)はprevDay(18:00,0)とmorning(06:00,2)の中間点(6h/12h)で1.0
      // dayEnd(24:00)は仮想点(18:00,0)とnextDay(06:00,-2)の中間点(6h/12h)で-1.0
      // 面積: 00-06(1.0→2):9.0, 06-18(2→0):12.0, 18-24(0→-1.0):-3.0 合計18.0/24h=0.75
      expect(result, closeTo(0.75, 1e-9));
    });

    test('最終レコードからnowまで12時間を超えて減衰すると平均が押し下げられる', () {
      final record = _record(DateTime(2026, 7, 2, 6), 2);
      final now = DateTime(2026, 7, 2, 21);

      final result = computeDailyAverage(
        allRecordsAscending: [record],
        day: DateTime(2026, 7, 2),
        now: now,
      );

      // 当日のため00:00〜21:00の部分積分。
      // 00-06(0→2):6.0, 06-18(2→0):12.0, 18-21(0→0):0 合計18.0/21h=6/7
      // （減衰が無ければ06:00以降ずっと2のままで平均が大きく上振れする）
      expect(result, closeTo(18.0 / 21, 1e-9));
    });

    test('構築済みのseriesを渡した場合も同じ結果になる（再構築の省略）', () {
      final records = [
        _record(DateTime(2026, 6, 28, 18), 0),
        _record(DateTime(2026, 6, 29, 6), 2),
        _record(DateTime(2026, 6, 30, 6), -2),
      ];
      final now = DateTime(2026, 6, 30, 6);
      final series = buildConditionSeries(records, now: now);

      final withSeries = computeDailyAverage(
        allRecordsAscending: records,
        day: DateTime(2026, 6, 29),
        now: now,
        series: series,
      );
      final withoutSeries = computeDailyAverage(
        allRecordsAscending: records,
        day: DateTime(2026, 6, 29),
        now: now,
      );

      expect(withSeries, withoutSeries);
    });
  });

  group('roundDailyScore', () {
    test('四捨五入して-2〜2にクランプする（spec.md §6.2）', () {
      expect(roundDailyScore(0.4), 0);
      expect(roundDailyScore(0.5), 1);
      expect(roundDailyScore(-0.5), -1);
      expect(roundDailyScore(1.6), 2);
      expect(roundDailyScore(2.4), 2);
      expect(roundDailyScore(-2.4), -2);
    });
  });

  group('averageScore', () {
    test('空ならnull、それ以外は算術平均を返す', () {
      expect(averageScore(const []), isNull);
      expect(averageScore(const [1.0, 2.0, 3.0]), closeTo(2.0, 1e-9));
      expect(averageScore(const [-2.0, 2.0]), closeTo(0.0, 1e-9));
    });
  });
}
