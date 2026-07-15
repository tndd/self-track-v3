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

  /// レコードとタグ紐付けを1トランザクションで作成する。タグは常に value=1.0（spec.md §3.3）。
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
      // spec.md M1: isDirtyは書き込み時にDAO内で自動設定する。更新も
      // 未同期扱いに戻さないと、将来のクラウド同期で更新漏れが発生する。
      await (update(records)..where((r) => r.id.equals(id))).write(
        RecordsCompanion(
          timestamp: Value(timestamp),
          comment: Value(comment),
          value: Value(value),
          updatedAt: Value(now),
          isDirty: const Value(true),
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
    return _watchWithTags(
      where: records.timestamp.isBiggerOrEqualValue(from) &
          records.timestamp.isSmallerThanValue(to),
      ascending: false,
    );
  }

  /// [from]以降の全レコードをタグ付きで新しい順に取得するストリーム。
  /// Trackタイムラインの過去方向無限スクロールで、遡り済みウィンドウの
  /// 開始日を渡して使う。上限を設けないことで、日付をまたいで作成された
  /// 新規レコードも即座に反映される。
  Stream<List<RecordWithTags>> watchSince(DateTime from) {
    return _watchWithTags(
      where: records.timestamp.isBiggerOrEqualValue(from),
      ascending: false,
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
    return _watchWithTags(ascending: true);
  }

  /// records×record_tags×tagsを1本のjoin監視クエリで発行し、行をレコード
  /// 単位にグループ化して返す。
  ///
  /// 単一のjoinクエリにすることで、(1) レコード1件ごとにタグを問い合わせる
  /// N+1クエリを避け、(2) クエリにtagsテーブルが含まれるためタグ名・色の
  /// 変更やアーカイブ切り替えもDriftの変更監視対象となり、タイムライン等へ
  /// 即座に反映される。
  Stream<List<RecordWithTags>> _watchWithTags({
    Expression<bool>? where,
    required bool ascending,
  }) {
    final query = select(records).join([
      leftOuterJoin(recordTags, recordTags.recordId.equalsExp(records.id)),
      leftOuterJoin(tags, tags.id.equalsExp(recordTags.tagId)),
    ]);
    if (where != null) {
      query.where(where);
    }
    query.orderBy([
      ascending
          ? OrderingTerm.asc(records.timestamp)
          : OrderingTerm.desc(records.timestamp),
      // 同時刻レコードでも同一レコードの行が連続するよう安定化する。
      OrderingTerm.asc(records.id),
      OrderingTerm.asc(tags.name),
    ]);
    return query.watch().map(_groupJoinedRows);
  }

  List<RecordWithTags> _groupJoinedRows(List<TypedResult> rows) {
    final result = <RecordWithTags>[];
    final indexById = <String, int>{};
    for (final row in rows) {
      final record = row.readTable(records);
      var index = indexById[record.id];
      if (index == null) {
        index = result.length;
        indexById[record.id] = index;
        result.add(
          RecordWithTags(
            id: record.id,
            timestamp: record.timestamp,
            comment: record.comment,
            value: record.value,
            tags: [],
          ),
        );
      }
      final tag = row.readTableOrNull(tags);
      if (tag != null) {
        result[index].tags.add(
              TagRef(
                id: tag.id,
                name: tag.name,
                group: tag.group,
                colorIndex: tag.colorIndex,
                isArchived: tag.isArchived,
              ),
            );
      }
    }
    return result;
  }
}
