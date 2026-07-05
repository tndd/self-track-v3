import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('タグ無しでレコードを作成できる（体調のみの記録）', () async {
    final now = DateTime(2026, 6, 29, 14, 20);
    final id = await db.recordsDao.createRecord(
      timestamp: now,
      value: 0,
    );

    final all = await db.recordsDao.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.value, 0);
    expect(all.single.comment, isNull);
    expect(all.single.tags, isEmpty);
  });

  test('タグとコメント付きでレコードを作成すると紐付けタグが取得できる', () async {
    final tagId = await db.tagsDao.createTag(name: '頭痛', group: '症状');
    final now = DateTime(2026, 6, 29, 14, 20);

    await db.recordsDao.createRecord(
      timestamp: now,
      comment: 'お昼すぎ、急激に強い倦怠感。',
      value: -2,
      tagIds: [tagId],
    );

    final all = await db.recordsDao.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.comment, 'お昼すぎ、急激に強い倦怠感。');
    expect(all.single.value, -2);
    expect(all.single.tags, hasLength(1));
    expect(all.single.tags.single.name, '頭痛');
  });

  test('watchByDateRangeは指定期間内のレコードのみ新しい順で返す', () async {
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 28, 10),
      value: 0,
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 7, 40),
      value: 1,
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 14, 20),
      value: -1,
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 30, 0, 0),
      value: 2,
    );

    final result = await db.recordsDao
        .watchByDateRange(DateTime(2026, 6, 29), DateTime(2026, 6, 30))
        .first;

    expect(result, hasLength(2));
    expect(result[0].timestamp, DateTime(2026, 6, 29, 14, 20));
    expect(result[1].timestamp, DateTime(2026, 6, 29, 7, 40));
  });

  test('watchSinceはfrom以降のレコードのみ新しい順で返す（from当時刻を含む）', () async {
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 28, 23, 59),
      value: 0,
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29),
      value: 1,
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 30, 14, 20),
      value: -1,
    );

    final result = await db.recordsDao.watchSince(DateTime(2026, 6, 29)).first;

    expect(result, hasLength(2));
    expect(result[0].timestamp, DateTime(2026, 6, 30, 14, 20));
    expect(result[1].timestamp, DateTime(2026, 6, 29));
  });

  test('watchOldestTimestampはレコードが無ければnull、あれば最古の時刻を返す', () async {
    expect(await db.recordsDao.watchOldestTimestamp().first, isNull);

    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 14, 20),
      value: 0,
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 1, 8, 0),
      value: 1,
    );

    expect(
      await db.recordsDao.watchOldestTimestamp().first,
      DateTime(2026, 6, 1, 8, 0),
    );
  });

  test('レコードを削除するとタグ紐付けもカスケード削除される', () async {
    final tagId = await db.tagsDao.createTag(name: '薬', group: '薬');
    final recordId = await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 12),
      value: 0,
      tagIds: [tagId],
    );

    await db.recordsDao.deleteRecord(recordId);

    final all = await db.recordsDao.watchAll().first;
    expect(all, isEmpty);

    final orphanTagLinks = await db.select(db.recordTags).get();
    expect(orphanTagLinks, isEmpty);
  });

  test('タグをアーカイブしても過去レコードのタグ紐付けは維持され、isArchivedが伝搬される', () async {
    final tagId = await db.tagsDao.createTag(name: 'ビタミンD', group: 'サプリ');
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 12),
      value: 1,
      tagIds: [tagId],
    );

    await db.tagsDao.archiveTag(tagId);

    final all = await db.recordsDao.watchAll().first;
    expect(all.single.tags.single.name, 'ビタミンD');
    expect(all.single.tags.single.isArchived, isTrue);
  });

  test('タグ名・色の変更が既存の監視ストリームに再発行される（joinクエリの変更監視）', () async {
    final tagId = await db.tagsDao.createTag(name: '頭痛', group: '症状');
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 12),
      value: -1,
      tagIds: [tagId],
    );

    final stream = db.recordsDao.watchAll();
    // タグ名の変更（tagsテーブルのみの更新）でもストリームが再発行され、
    // 新しいタグ名が届くこと。
    final futureRenamed = stream
        .firstWhere((records) => records.single.tags.single.name == '偏頭痛');

    await db.tagsDao.updateTag(id: tagId, name: '偏頭痛', group: '症状', colorIndex: 3);

    final renamed = await futureRenamed.timeout(const Duration(seconds: 5));
    expect(renamed.single.tags.single.name, '偏頭痛');
    expect(renamed.single.tags.single.colorIndex, 3);
  });

  test('updateRecordはisDirtyをtrueに戻す（同期用フラグの自動設定）', () async {
    final recordId = await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 12),
      value: 0,
    );
    // 同期済みを模してフラグを落とす。
    await (db.update(db.records)..where((r) => r.id.equals(recordId))).write(
      const RecordsCompanion(isDirty: Value(false)),
    );

    await db.recordsDao.updateRecord(
      id: recordId,
      timestamp: DateTime(2026, 6, 29, 12),
      value: 1,
    );

    final row = await (db.select(db.records)
          ..where((r) => r.id.equals(recordId)))
        .getSingle();
    expect(row.isDirty, isTrue);
  });

  test('updateRecordでtagIdsを渡すとタグ紐付けが丸ごと入れ替わる', () async {
    final headacheId = await db.tagsDao.createTag(name: '頭痛', group: '症状');
    final medId = await db.tagsDao.createTag(name: 'ロキソニン', group: '薬');
    final recordId = await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 12),
      value: -1,
      tagIds: [headacheId],
    );

    await db.recordsDao.updateRecord(
      id: recordId,
      timestamp: DateTime(2026, 6, 29, 12),
      value: -1,
      tagIds: [medId],
    );

    final all = await db.recordsDao.watchAll().first;
    expect(all.single.tags, hasLength(1));
    expect(all.single.tags.single.name, 'ロキソニン');
  });

  test('タグ名を変更すると既存の監視ストリームにも新しい名前が反映される', () async {
    final tagId = await db.tagsDao.createTag(name: '旧名', group: '症状');
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 12),
      value: 0,
      tagIds: [tagId],
    );

    final stream = db.recordsDao.watchAll().asBroadcastStream();
    expect((await stream.first).single.tags.single.name, '旧名');

    final renamed = stream.firstWhere(
      (records) => records.single.tags.single.name == '新名',
    );
    await db.tagsDao.updateTag(id: tagId, name: '新名', group: '症状');

    final result = await renamed.timeout(const Duration(seconds: 2));
    expect(result.single.tags.single.name, '新名');
  });

  test('updateRecordでtagIdsを渡さない場合はタグ紐付けを変更しない', () async {
    final tagId = await db.tagsDao.createTag(name: '運動', group: '行動');
    final recordId = await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 12),
      value: 1,
      tagIds: [tagId],
    );

    await db.recordsDao.updateRecord(
      id: recordId,
      timestamp: DateTime(2026, 6, 29, 12),
      comment: '更新後コメント',
      value: 2,
    );

    final all = await db.recordsDao.watchAll().first;
    expect(all.single.comment, '更新後コメント');
    expect(all.single.value, 2);
    expect(all.single.tags, hasLength(1));
    expect(all.single.tags.single.name, '運動');
  });
}
