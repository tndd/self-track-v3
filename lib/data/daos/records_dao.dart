import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../database.dart';
import '../tables.dart';

part 'records_dao.g.dart';

@DriftAccessor(tables: [Records, Tags, RecordTags])
class RecordsDao extends DatabaseAccessor<AppDatabase> with _$RecordsDaoMixin {
  RecordsDao(super.db);

  static const _uuid = Uuid();

  /// レコードとタグ紐付けを1トランザクションで作成する。タグは常に value=1.0（design.md §3.3）。
  Future<String> createRecord({
    required DateTime timestamp,
    String? comment,
    required int value,
    List<String> tagIds = const [],
  }) {
    final id = _uuid.v4();
    final now = DateTime.now();
    return transaction(() async {
      await into(records).insert(
        RecordsCompanion.insert(
          id: id,
          timestamp: timestamp,
          comment: Value(comment),
          value: Value(value),
          updatedAt: now,
        ),
      );
      for (final tagId in tagIds) {
        await into(recordTags).insert(
          RecordTagsCompanion.insert(recordId: id, tagId: tagId),
        );
      }
      return id;
    });
  }

  /// レコードを更新する。`tagIds` を渡した場合のみタグ紐付けを丸ごと入れ替える。
  Future<void> updateRecord({
    required String id,
    required DateTime timestamp,
    String? comment,
    required int value,
    List<String>? tagIds,
  }) {
    final now = DateTime.now();
    return transaction(() async {
      await (update(records)..where((r) => r.id.equals(id))).write(
        RecordsCompanion(
          timestamp: Value(timestamp),
          comment: Value(comment),
          value: Value(value),
          updatedAt: Value(now),
        ),
      );
      if (tagIds != null) {
        await (delete(recordTags)
              ..where((rt) => rt.recordId.equals(id)))
            .go();
        for (final tagId in tagIds) {
          await into(recordTags).insert(
            RecordTagsCompanion.insert(recordId: id, tagId: tagId),
          );
        }
      }
    });
  }

  /// レコードを削除する。record_tagsはON DELETE CASCADEで自動的に削除される。
  Future<void> deleteRecord(String id) {
    return (delete(records)..where((r) => r.id.equals(id))).go();
  }

  /// [from, to) の半開区間でレコードをタグ付きで新しい順に取得するストリーム。
  Stream<List<RecordWithTags>> watchByDateRange(DateTime from, DateTime to) {
    return _watchRecordsWithTags(
      whereSql: 'timestamp >= ? AND timestamp < ?',
      variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
      orderBySql: 'timestamp DESC',
    );
  }

  /// [from]以降の全レコードをタグ付きで新しい順に取得するストリーム。
  /// Trackタイムラインの過去方向無限スクロールで、遡り済みウィンドウの
  /// 開始日を渡して使う。上限を設けないことで、日付をまたいで作成された
  /// 新規レコードも即座に反映される。
  Stream<List<RecordWithTags>> watchSince(DateTime from) {
    return _watchRecordsWithTags(
      whereSql: 'timestamp >= ?',
      variables: [Variable.withDateTime(from)],
      orderBySql: 'timestamp DESC',
    );
  }

  /// 最古レコードのtimestamp（レコードが無ければnull）。
  /// 無限スクロールの「これ以上遡れない」判定に使う。
  Stream<DateTime?> watchOldestTimestamp() {
    final min = records.timestamp.min();
    final query = selectOnly(records)..addColumns([min]);
    return query.watchSingle().map((row) => row.read(min));
  }

  /// 統計計算などで使う、全レコードを時刻昇順で取得するストリーム。
  Stream<List<RecordWithTags>> watchAll() {
    return _watchRecordsWithTags(
      whereSql: '',
      variables: const [],
      orderBySql: 'timestamp ASC',
    );
  }

  /// records単体のクエリとしてSQLを組み立てつつ、`readsFrom`でrecord_tags・
  /// tagsも依存テーブルに含めて監視する。record_tags×tagsをjoinして1つの
  /// watchクエリにする方式も試したが、Track画面のように複数のwatchが同時に
  /// 走る状況（ウィジェットテストで再現）でストリームが初回値を配信しない
  /// まま固まる問題があったため採用していない。ここでは監視クエリ自体は
  /// records単体（既存のwatch系と同じ安全な形）のまま、依存テーブルだけを
  /// 広げることで、タグの改名・アーカイブにも反応しつつjoinのリスクを避ける。
  Stream<List<RecordWithTags>> _watchRecordsWithTags({
    required String whereSql,
    required List<Variable<Object>> variables,
    required String orderBySql,
  }) {
    final sql = StringBuffer('SELECT * FROM records');
    if (whereSql.isNotEmpty) sql.write(' WHERE $whereSql');
    sql.write(' ORDER BY $orderBySql');

    final query = customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: {records, recordTags, tags},
    );
    return query
        .watch()
        .map((rows) => [for (final row in rows) records.map(row.data)])
        .asyncMap(_attachTagsBatch);
  }

  /// Composerの「最近使ったタグ」算出に使う、直近レコードを新しい順で取得する
  /// ストリーム。最大[limit]件に絞ってから1本のバッチクエリでタグを付ける。
  Stream<List<RecordWithTags>> watchRecent({int limit = 30}) {
    final query = select(records)
      ..orderBy([(r) => OrderingTerm.desc(r.timestamp)])
      ..limit(limit);
    return query.watch().asyncMap(_attachTagsBatch);
  }

  Future<List<RecordWithTags>> _attachTagsBatch(List<RecordEntry> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList();
    final tagRows = await (select(recordTags).join([
      innerJoin(tags, tags.id.equalsExp(recordTags.tagId)),
    ])
          ..where(recordTags.recordId.isIn(ids)))
        .get();

    final tagsByRecordId = <String, List<TagRef>>{};
    for (final row in tagRows) {
      final link = row.readTable(recordTags);
      final tag = row.readTable(tags);
      (tagsByRecordId[link.recordId] ??= []).add(
        TagRef(id: tag.id, name: tag.name, group: tag.group, colorIndex: tag.colorIndex),
      );
    }

    return [
      for (final r in rows)
        RecordWithTags(
          id: r.id,
          timestamp: r.timestamp,
          comment: r.comment,
          value: r.value,
          tags: tagsByRecordId[r.id] ?? const [],
        ),
    ];
  }
}
