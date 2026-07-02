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
    final query = select(records)
      ..where(
        (r) =>
            r.timestamp.isBiggerOrEqualValue(from) &
            r.timestamp.isSmallerThanValue(to),
      )
      ..orderBy([(r) => OrderingTerm.desc(r.timestamp)]);
    return query.watch().asyncMap(_attachTags);
  }

  /// [from]以降の全レコードをタグ付きで新しい順に取得するストリーム。
  /// Trackタイムラインの過去方向無限スクロールで、遡り済みウィンドウの
  /// 開始日を渡して使う。上限を設けないことで、日付をまたいで作成された
  /// 新規レコードも即座に反映される。
  Stream<List<RecordWithTags>> watchSince(DateTime from) {
    final query = select(records)
      ..where((r) => r.timestamp.isBiggerOrEqualValue(from))
      ..orderBy([(r) => OrderingTerm.desc(r.timestamp)]);
    return query.watch().asyncMap(_attachTags);
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
    final query = select(records)
      ..orderBy([(r) => OrderingTerm.asc(r.timestamp)]);
    return query.watch().asyncMap(_attachTags);
  }

  /// Composerの「最近使ったタグ」算出に使う、直近レコードを新しい順で取得するストリーム。
  Stream<List<RecordWithTags>> watchRecent({int limit = 30}) {
    final query = select(records)
      ..orderBy([(r) => OrderingTerm.desc(r.timestamp)])
      ..limit(limit);
    return query.watch().asyncMap(_attachTags);
  }

  Future<List<RecordWithTags>> _attachTags(List<RecordEntry> rows) async {
    if (rows.isEmpty) return const [];

    final recordIds = rows.map((r) => r.id).toList();
    final tagQuery = select(recordTags).join([
      innerJoin(tags, tags.id.equalsExp(recordTags.tagId)),
    ])..where(recordTags.recordId.isIn(recordIds));

    final tagRows = await tagQuery.get();

    final tagsByRecordId = <String, List<TagRef>>{};
    for (final row in tagRows) {
      final entry = row.readTable(recordTags);
      final tag = row.readTable(tags);
      final ref = TagRef(
        id: tag.id,
        name: tag.name,
        group: tag.group,
        colorIndex: tag.colorIndex,
      );
      tagsByRecordId.putIfAbsent(entry.recordId, () => []).add(ref);
    }

    return rows.map((row) {
      return RecordWithTags(
        id: row.id,
        timestamp: row.timestamp,
        comment: row.comment,
        value: row.value,
        tags: tagsByRecordId[row.id] ?? const [],
      );
    }).toList();
  }
}
