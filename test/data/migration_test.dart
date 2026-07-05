import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// schema v1（colorIndex列なし）のDBファイルを最新のAppDatabaseで開き、
/// onUpgradeマイグレーションで既存データを保持したままcolorIndex列（v2）と
/// records.timestampインデックス（v3）が追加されることを検証する。
/// 実機の本番DB・開発用DBのアップグレード経路に相当。
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('self_track_migration');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('v1のDBを開くとcolorIndex列とtimestampインデックスが追加され既存タグ・レコードが保持される', () async {
    final path = '${tempDir.path}/v1.sqlite';

    // schema v1相当のDDL（lib/data/tables.dartのv1定義から生成される構造）。
    final raw = sqlite.sqlite3.open(path);
    raw.execute('''
      CREATE TABLE records (
        id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        comment TEXT NULL,
        value INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        is_dirty INTEGER NOT NULL DEFAULT 1 CHECK (is_dirty IN (0, 1)),
        PRIMARY KEY (id)
      );
      CREATE TABLE tags (
        id TEXT NOT NULL,
        name TEXT NOT NULL UNIQUE,
        tag_group TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
        PRIMARY KEY (id)
      );
      CREATE TABLE record_tags (
        record_id TEXT NOT NULL REFERENCES records (id) ON DELETE CASCADE,
        tag_id TEXT NOT NULL REFERENCES tags (id),
        value REAL NOT NULL DEFAULT 1.0,
        PRIMARY KEY (record_id, tag_id)
      );
      PRAGMA user_version = 1;
    ''');
    raw.execute(
        "INSERT INTO tags (id, name, tag_group) VALUES ('t1', '頭痛', '症状')");
    raw.execute(
        "INSERT INTO records (id, timestamp, value, updated_at) VALUES ('r1', 1000, -1, 1000)");
    raw.execute(
        "INSERT INTO record_tags (record_id, tag_id) VALUES ('r1', 't1')");
    raw.dispose();

    // 最新のAppDatabaseで開く → onUpgradeが走る。
    final db = AppDatabase.withExecutor(NativeDatabase(File(path)));
    addTearDown(db.close);

    final tags = await db.tagsDao.watchAll().first;
    expect(tags.single.name, '頭痛');
    expect(tags.single.colorIndex, isNull); // 追加列はnullで初期化される

    // v3: records.timestampのインデックスが作成されている。
    final indexRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_records_timestamp'",
        )
        .get();
    expect(indexRows, hasLength(1));

    // 追加された列に書き込めること。
    await db.tagsDao
        .updateTag(id: 't1', name: '頭痛', group: '症状', colorIndex: 2);
    final updated = await db.tagsDao.watchAll().first;
    expect(updated.single.colorIndex, 2);

    // 既存レコードとタグ紐付けも保持されている。
    final records = await db.recordsDao.watchAll().first;
    expect(records.single.id, 'r1');
    expect(records.single.tags.single.name, '頭痛');
    expect(records.single.tags.single.colorIndex, 2);
  });
}
