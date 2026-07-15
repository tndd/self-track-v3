import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import 'daos/records_dao.dart';
import 'daos/tags_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Records, Tags, RecordTags],
  daos: [RecordsDao, TagsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// テストや検証用に任意のQueryExecutor（例: インメモリDB）を注入するコンストラクタ。
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: タグにチップ配色のパレットindex（null=自動）を追加。
            await m.addColumn(tags, tags.colorIndex);
          }
          if (from < 3) {
            // v3: records.timestampのインデックス（spec.md M1）。
            await m.createIndex(idxRecordsTimestamp);
          }
        },
        beforeOpen: (details) async {
          // record_tagsのON DELETE CASCADEを機能させるため、SQLiteの
          // 外部キー制約は接続ごとに明示的に有効化する必要がある。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Settings画面の「データの全削除」から呼び出す。recordsを削除すれば
  /// record_tagsはON DELETE CASCADEで自動的に空になるため、tagsも
  /// あわせて削除すれば全データが消える。
  Future<void> deleteAllData() {
    return transaction(() async {
      await delete(records).go();
      await delete(tags).go();
    });
  }
}

QueryExecutor _openConnection() {
  // デバッグビルドでは本番DB（self_track_v3）を汚さないよう別ファイルを開く。
  // kDebugModeはコンパイル時定数のため、releaseビルドでは常に本番DBになる。
  // テストは AppDatabase.withExecutor 経由のためこの分岐を通らない。
  final name = kDebugMode ? 'self_track_v3_dev' : 'self_track_v3';
  return driftDatabase(name: name);
}
