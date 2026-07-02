import 'package:drift/drift.dart';

/// 体調・コメントの親レコード（design.md §3.1）。
/// `value` は -2〜2 のDB値。UI表示（1〜5）への変換は ui/theme.dart で行う。
/// Dartの言語機能「レコード（タプル）」との混同を避けるため、
/// 生成される行データクラス名は明示的に `RecordEntry` にする。
@DataClassName('RecordEntry')
class Records extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get comment => text().nullable()();
  IntColumn get value => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// タグマスタ（design.md §3.2）。
/// `group` はSQLite予約語のため、DB上の列名は `tag_group` にリネームする。
@DataClassName('Tag')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get group => text().named('tag_group')();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// チップ配色パレット（ui/tag_colors.dart の kTagChipPalettes）のindex。
  /// nullの場合はタグ名のハッシュで自動決定する。schema v2で追加。
  IntColumn get colorIndex => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// レコードとタグの中間テーブル（design.md §3.3）。
/// v1.0では `value` の入力UIを設けず、常に1.0で作成する。
@DataClassName('RecordTagEntry')
class RecordTags extends Table {
  TextColumn get recordId =>
      text().references(Records, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id)();
  RealColumn get value => real().withDefault(const Constant(1.0))();

  @override
  Set<Column> get primaryKey => {recordId, tagId};
}
