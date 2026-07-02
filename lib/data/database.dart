import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // record_tagsのON DELETE CASCADEを機能させるため、SQLiteの
          // 外部キー制約は接続ごとに明示的に有効化する必要がある。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'self_track_v3');
}
