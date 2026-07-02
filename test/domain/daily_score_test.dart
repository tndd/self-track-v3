import 'package:flutter_test/flutter_test.dart';
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

    test('前後に何もデータが無い単一レコード日は、0を起点・終点として積分する', () {
      final record = _record(DateTime(2026, 6, 29, 12), 2);

      final result = computeDailyAverage(
        allRecordsAscending: [record],
        day: DateTime(2026, 6, 29),
        now: DateTime(2026, 6, 29, 12),
      );

      // 00:00→12:00: (0+2)/2*12=12, 12:00→24:00: (2+2)/2*12=24, 合計36 / 24h = 1.5
      expect(result, closeTo(1.5, 1e-9));
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

      // 00-06(0→2):6.0, 06-18(2→0):12.0, 18-21(0→0):0, 21-24(0→0):0 合計18.0/24h=0.75
      // （減衰が無ければ 06:00以降ずっと2のままで平均1.75になるはずが、
      //   12時間減衰により18:00以降0に落ちるため平均が下がる）
      expect(result, closeTo(0.75, 1e-9));
    });
  });
}
