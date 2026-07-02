import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/domain/models.dart';
import 'package:self_track_v3/domain/stats/event_locked.dart';

RecordWithTags _record(DateTime timestamp, int value, {List<String> tagIds = const []}) {
  return RecordWithTags(
    id: 'r-${timestamp.microsecondsSinceEpoch}',
    timestamp: timestamp,
    comment: null,
    value: value,
    tags: [for (final id in tagIds) TagRef(id: id, name: id, group: 'test')],
  );
}

void main() {
  group('computeEventLockedAverage', () {
    test('対象タグの発生が無ければ空リストを返す', () {
      final records = [_record(DateTime(2026, 6, 29, 10), 1)];

      final result = computeEventLockedAverage(
        records: records,
        tagId: 'coffee',
        now: DateTime(2026, 6, 29, 10),
      );

      expect(result, isEmpty);
    });

    test('-12h〜+12hの25点を1時間刻みで返す', () {
      final records = [
        _record(DateTime(2026, 6, 29, 10), 0, tagIds: ['coffee']),
      ];

      final result = computeEventLockedAverage(
        records: records,
        tagId: 'coffee',
        now: DateTime(2026, 6, 29, 10),
      );

      expect(result, hasLength(25));
      expect(result.first.offsetHours, -12);
      expect(result.last.offsetHours, 12);
      expect(result.every((p) => p.sampleCount == 1), isTrue);
    });

    test('発生時刻(offset=0)では発生時のvalueがそのまま平均になる', () {
      final records = [
        _record(DateTime(2026, 6, 29, 10), 2, tagIds: ['coffee']),
      ];

      final result = computeEventLockedAverage(
        records: records,
        tagId: 'coffee',
        now: DateTime(2026, 6, 29, 10),
      );

      final atZero = result.firstWhere((p) => p.offsetHours == 0);
      expect(atZero.averageValue, closeTo(2, 1e-9));
    });

    test('複数回の発生を平均する', () {
      final records = [
        _record(DateTime(2026, 6, 28, 10), 2, tagIds: ['coffee']),
        _record(DateTime(2026, 6, 29, 10), -2, tagIds: ['coffee']),
      ];

      final result = computeEventLockedAverage(
        records: records,
        tagId: 'coffee',
        now: DateTime(2026, 6, 29, 10),
      );

      final atZero = result.firstWhere((p) => p.offsetHours == 0);
      // 2つの発生ともoffset=0ではその発生自体のvalue: (2 + -2) / 2 = 0
      expect(atZero.averageValue, closeTo(0, 1e-9));
      expect(atZero.sampleCount, 2);
    });
  });
}
