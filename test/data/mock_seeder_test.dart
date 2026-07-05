import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/data/dev/mock_seeder.dart';
import 'package:self_track_v3/domain/stats/contingency.dart';

void main() {
  late AppDatabase db;
  final anchor = DateTime(2026, 7, 1, 12, 0);

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('空のDBに投入するとtrue、既にデータがある場合はfalseを返す', () async {
    final seeder = MockSeeder(db, anchor: anchor);
    expect(await seeder.seedIfEmpty(), isTrue);
    expect(await MockSeeder(db, anchor: anchor).seedIfEmpty(), isFalse);
  });

  test('約180日・800件以上のレコードと18タグ（3つアーカイブ済み）を投入する', () async {
    await MockSeeder(db, anchor: anchor).seed();

    final records = await db.recordsDao.watchAll().first;
    expect(records.length, greaterThanOrEqualTo(800));

    // 期間はanchor当日から遡って180日以内に収まる。
    final today = DateTime(anchor.year, anchor.month, anchor.day);
    final oldest = records.first.timestamp; // watchAllは時刻昇順
    final newest = records.last.timestamp;
    expect(oldest.isAfter(today.subtract(const Duration(days: 180))), isTrue);
    expect(newest.isBefore(today.add(const Duration(days: 1))), isTrue);

    final tags = await db.tagsDao.watchAll().first;
    expect(tags, hasLength(18));
    expect(tags.where((t) => t.isArchived), hasLength(3));
    expect(tags.where((t) => t.group == '症状'), isNotEmpty);
    // 保存色（頭痛=赤index1）と自動配色（colorIndex=null）が混在する。
    expect(tags.firstWhere((t) => t.name == '頭痛').colorIndex, 1);
    expect(tags.where((t) => t.colorIndex == null), isNotEmpty);
  });

  test('体調値はDB値の範囲（-2〜2）に収まり、コメント付きレコードが存在する', () async {
    await MockSeeder(db, anchor: anchor).seed();

    final records = await db.recordsDao.watchAll().first;
    expect(records.every((r) => r.value >= -2 && r.value <= 2), isTrue);
    expect(records.where((r) => r.comment != null), isNotEmpty);
  });

  test('コーヒー×頭痛がStatsの「データ不足」閾値を超え、正の関連を示す', () async {
    await MockSeeder(db, anchor: anchor).seed();

    final records = await db.recordsDao.watchAll().first;
    final table = buildDayContingencyTable(
      records: records,
      actionTagId: MockSeeder.tagId('coffee'),
      symptomTagId: MockSeeder.tagId('headache'),
    );

    // tag_pair_list.dartの_minOccurrenceThreshold（3日）を十分に超えること。
    expect(table.actionDayCount, greaterThanOrEqualTo(3));
    expect(table.symptomDayCount, greaterThanOrEqualTo(3));
    // コーヒーの日に頭痛が出やすい設計なので、リフト値は明確に1を超える。
    expect(liftValue(table), greaterThan(1.2));
  });

  test('同じseedとanchorなら同一のデータが再現される', () async {
    final db2 = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db2.close);

    await MockSeeder(db, anchor: anchor).seed();
    await MockSeeder(db2, anchor: anchor).seed();

    final records1 = await db.recordsDao.watchAll().first;
    final records2 = await db2.recordsDao.watchAll().first;
    expect(records1.length, records2.length);
    expect(records1.first.id, records2.first.id);
    expect(records1.last.id, records2.last.id);
    expect(records1.last.timestamp, records2.last.timestamp);
    expect(records1.last.value, records2.last.value);
  });
}
