import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/calendar_providers.dart';
import 'package:self_track_v3/providers/database_providers.dart';
import 'package:self_track_v3/providers/track_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('recentTagsはアーカイブ済みタグを除外し、新しい順・重複除去で返す', () async {
    final coffeeId = await db.tagsDao.createTag(name: 'コーヒー', group: '行動');
    final oldMedId = await db.tagsDao.createTag(name: '旧薬', group: '薬');

    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 28, 9),
      value: 0,
      tagIds: [oldMedId],
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime(2026, 6, 29, 9),
      value: 0,
      tagIds: [coffeeId, oldMedId],
    );
    await db.tagsDao.archiveTag(oldMedId);

    // recentTagsProviderの依存元ストリームの初回発行を待つ。
    final sub = container.listen(recentTagsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(allRecordsProvider.future);

    final recent = container.read(recentTagsProvider);
    expect(recent.map((t) => t.name), ['コーヒー']);
  });
}
