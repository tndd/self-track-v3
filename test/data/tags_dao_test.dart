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

  test('タグを作成すると未アーカイブ一覧に現れる', () async {
    final id = await db.tagsDao.createTag(name: '頭痛', group: '症状');

    final active = await db.tagsDao.watchActive().first;

    expect(active, hasLength(1));
    expect(active.single.id, id);
    expect(active.single.name, '頭痛');
    expect(active.single.group, '症状');
    expect(active.single.isArchived, isFalse);
  });

  test('同名タグの重複作成はUNIQUE制約違反になる', () async {
    await db.tagsDao.createTag(name: 'ロキソニン', group: '薬');

    expect(
      () => db.tagsDao.createTag(name: 'ロキソニン', group: '薬'),
      throwsA(anything),
    );
  });

  test('アーカイブすると未アーカイブ一覧から消えるが全件一覧には残る', () async {
    final id = await db.tagsDao.createTag(name: '倦怠感', group: '症状');

    await db.tagsDao.archiveTag(id);

    final active = await db.tagsDao.watchActive().first;
    final all = await db.tagsDao.watchAll().first;

    expect(active, isEmpty);
    expect(all, hasLength(1));
    expect(all.single.isArchived, isTrue);
  });

  test('アーカイブ解除で再び未アーカイブ一覧に現れる', () async {
    final id = await db.tagsDao.createTag(name: '散歩', group: '行動');
    await db.tagsDao.archiveTag(id);

    await db.tagsDao.unarchiveTag(id);

    final active = await db.tagsDao.watchActive().first;
    expect(active, hasLength(1));
    expect(active.single.isArchived, isFalse);
  });

  test('タグを編集すると名前とグループが更新される', () async {
    final id = await db.tagsDao.createTag(name: 'コーヒー', group: '行動');

    await db.tagsDao.updateTag(id: id, name: 'カフェイン', group: '嗜好品');

    final all = await db.tagsDao.watchAll().first;
    expect(all.single.name, 'カフェイン');
    expect(all.single.group, '嗜好品');
  });
}
