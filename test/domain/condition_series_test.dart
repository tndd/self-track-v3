import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/domain/condition_series.dart';
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
  group('buildConditionSeries', () {
    test('レコードが1件も無い場合は空の時系列を返す', () {
      final series = buildConditionSeries(const [], now: DateTime(2026, 6, 29));
      expect(series, isEmpty);
    });

    test('間隔がちょうど12時間の場合は仮想ポイントを挿入しない', () {
      final a = _record(DateTime(2026, 6, 29, 0), 1);
      final b = _record(DateTime(2026, 6, 29, 12), -1);

      final series = buildConditionSeries([a, b], now: b.timestamp);

      expect(series, hasLength(2));
      expect(series.every((p) => !p.isVirtual), isTrue);
    });

    test('間隔が12時間を1分でも超えると間にvalue=0の仮想ポイントを挿入する', () {
      final a = _record(DateTime(2026, 6, 29, 0), 2);
      final b = _record(DateTime(2026, 6, 29, 12, 1), -2);

      final series = buildConditionSeries([a, b], now: b.timestamp);

      expect(series, hasLength(3));
      expect(series[0].timestamp, a.timestamp);
      expect(series[0].value, 2);
      expect(series[1].timestamp, a.timestamp.add(const Duration(hours: 12)));
      expect(series[1].value, 0);
      expect(series[1].isVirtual, isTrue);
      expect(series[2].timestamp, b.timestamp);
      expect(series[2].value, -2);
    });

    test('最終ログからnowまでがちょうど12時間の場合は末尾に仮想ポイントを追加しない', () {
      final a = _record(DateTime(2026, 6, 29, 0), 1);
      final now = DateTime(2026, 6, 29, 12);

      final series = buildConditionSeries([a], now: now);

      expect(series, hasLength(1));
    });

    test('最終ログからnowまで12時間を超える場合、+12時間地点とnow自身に仮想ポイントを追加する', () {
      final a = _record(DateTime(2026, 6, 29, 0), 1);
      final now = DateTime(2026, 6, 29, 15);

      final series = buildConditionSeries([a], now: now);

      expect(series, hasLength(3));
      expect(series[1].timestamp, DateTime(2026, 6, 29, 12));
      expect(series[1].value, 0);
      expect(series[1].isVirtual, isTrue);
      expect(series[2].timestamp, now);
      expect(series[2].value, 0);
      expect(series[2].isVirtual, isTrue);
    });

    test('単一レコードでnowが近い場合は減衰せずそのまま1点のみ', () {
      final a = _record(DateTime(2026, 6, 29, 10), -1);
      final now = DateTime(2026, 6, 29, 11);

      final series = buildConditionSeries([a], now: now);

      expect(series, hasLength(1));
      expect(series.single.value, -1);
      expect(series.single.isVirtual, isFalse);
    });
  });
}
