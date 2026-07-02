import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daos/records_dao.dart';
import '../data/daos/tags_dao.dart';
import '../data/database.dart';
import '../data/dev/mock_seeder.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  if (kDebugMode) {
    // デバッグビルドでは開発用DB（self_track_v3_dev）が開かれるため、
    // 空ならモックデータを自動投入する。各画面はDriftのストリームを
    // watchしているので、投入完了時にUIへ反映される。
    // テストはこのプロバイダをoverrideWithValueで差し替えるため実行されない。
    unawaited(
      MockSeeder(db).seedIfEmpty().catchError((Object e, StackTrace s) {
        debugPrint('MockSeeder failed: $e\n$s');
        return false;
      }),
    );
  }
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
