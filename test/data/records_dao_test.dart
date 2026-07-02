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

  test('タグをアーカイブしても過去レコードのタグ紐付けは維持される', () async {
    final tagId = await db.tagsDao.createTag(name: 'ビタミンD', group: 'サプリ');
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 12),
      value: 1,
      tagIds: [tagId],
    );

    await db.tagsDao.archiveTag(tagId);

    final all = await db.recordsDao.watchAll().first;
    expect(all.single.tags.single.name, 'ビタミンD');
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
