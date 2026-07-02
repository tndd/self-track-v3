import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/domain/models.dart';
import 'package:self_track_v3/domain/stats/contingency.dart';

RecordWithTags _record(DateTime day, List<String> tagIds) {
  return RecordWithTags(
    id: 'r-${day.microsecondsSinceEpoch}-${tagIds.join(',')}',
    timestamp: day,
    comment: null,
    value: 0,
    tags: [for (final id in tagIds) TagRef(id: id, name: id, group: 'test')],
  );
}

void main() {
  group('buildDayContingencyTable', () {
    test('日単位でaction/symptomの共起を集計する', () {
      final records = [
        // 6/1: action(コーヒー)のみ
        _record(DateTime(2026, 6, 1, 9), ['coffee']),
        // 6/2: action + symptom 同日共起
        _record(DateTime(2026, 6, 2, 9), ['coffee']),
        _record(DateTime(2026, 6, 2, 14), ['headache']),
        // 6/3: symptomのみ
        _record(DateTime(2026, 6, 3, 9), ['headache']),
        // 6/4: どちらも無し（観測日にはカウントする）
        _record(DateTime(2026, 6, 4, 9), ['unrelated']),
      ];

      final table = buildDayContingencyTable(
        records: records,
        actionTagId: 'coffee',
        symptomTagId: 'headache',
      );

      expect(table.a, 1); // 6/2: action かつ symptom
      expect(table.b, 1); // 6/1: action のみ
      expect(table.c, 1); // 6/3: symptom のみ
      expect(table.d, 1); // 6/4: どちらも無し
      expect(table.n, 4);
      expect(table.actionDayCount, 2);
      expect(table.symptomDayCount, 2);
    });

    test('同じ日に複数レコードがあってもタグ発生日として1日にまとめる', () {
      final records = [
        _record(DateTime(2026, 6, 1, 8), ['coffee']),
        _record(DateTime(2026, 6, 1, 20), ['coffee']),
        _record(DateTime(2026, 6, 1, 22), ['headache']),
      ];

      final table = buildDayContingencyTable(
        records: records,
        actionTagId: 'coffee',
        symptomTagId: 'headache',
      );

      expect(table.n, 1);
      expect(table.a, 1);
      expect(table.b, 0);
      expect(table.c, 0);
      expect(table.d, 0);
    });

    test('レコードが無ければ全セルが0になる', () {
      final table = buildDayContingencyTable(
        records: const [],
        actionTagId: 'coffee',
        symptomTagId: 'headache',
      );

      expect(table.n, 0);
      expect(table.a, 0);
      expect(table.b, 0);
      expect(table.c, 0);
      expect(table.d, 0);
    });
  });
}
