import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daos/records_dao.dart';
import '../data/daos/tags_dao.dart';
import '../data/database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tagsDaoProvider = Provider<TagsDao>((ref) {
  return ref.watch(appDatabaseProvider).tagsDao;
});

final recordsDaoProvider = Provider<RecordsDao>((ref) {
  return ref.watch(appDatabaseProvider).recordsDao;
});

/// Track画面のタグ選択候補（アーカイブ済みを除く）。
final activeTagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(tagsDaoProvider).watchActive();
});

/// Tags画面用の全タグ（アーカイブ済み含む）。
final allTagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(tagsDaoProvider).watchAll();
});
