import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  static const _uuid = Uuid();

  /// タグを新規作成する。`name`はUNIQUE制約により重複登録時は例外を投げる。
  /// [colorIndex]はチップ配色パレットのindex（null=タグ名ハッシュで自動）。
  Future<String> createTag({
    required String name,
    required String group,
    int? colorIndex,
  }) {
    final id = _uuid.v4();
    return into(tags)
        .insert(TagsCompanion.insert(
          id: id,
          name: name,
          group: group,
          colorIndex: Value(colorIndex),
        ))
        .then((_) => id);
  }

  /// [colorIndex]は常に上書きする（nullを渡すと自動配色に戻る）。
  Future<void> updateTag({
    required String id,
    required String name,
    required String group,
    int? colorIndex,
  }) {
    return (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        name: Value(name),
        group: Value(group),
        colorIndex: Value(colorIndex),
      ),
    );
  }

  /// タグの削除はアーカイブで行う（spec.md §3.2）。過去のrecord_tagsは保持される。
  Future<void> archiveTag(String id) => _setArchived(id, true);

  Future<void> unarchiveTag(String id) => _setArchived(id, false);

  Future<void> _setArchived(String id, bool archived) {
    return (update(tags)..where((t) => t.id.equals(id)))
        .write(TagsCompanion(isArchived: Value(archived)));
  }

  /// Track画面のタグ選択候補として使う、未アーカイブのタグ一覧。
  Stream<List<Tag>> watchActive() {
    final query = select(tags)
      ..where((t) => t.isArchived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.group), (t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  /// Tags画面用の全タグ一覧（アーカイブ済み含む）。
  Stream<List<Tag>> watchAll() {
    final query = select(tags)
      ..orderBy([
        (t) => OrderingTerm.asc(t.isArchived),
        (t) => OrderingTerm.asc(t.group),
        (t) => OrderingTerm.asc(t.name),
      ]);
    return query.watch();
  }
}
