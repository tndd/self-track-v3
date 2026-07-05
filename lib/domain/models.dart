/// タグの表示に必要な最小限の情報。
class TagRef {
  const TagRef({
    required this.id,
    required this.name,
    required this.group,
    this.colorIndex,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String group;

  /// チップ配色パレットのindex。nullならタグ名ハッシュで自動決定する。
  final int? colorIndex;

  /// アーカイブ済みかどうか。「最近使ったタグ」の候補除外や、編集時の
  /// 選択チップ表示など、下流のUIがアーカイブ判定できるよう伝搬する。
  final bool isArchived;
}

/// タイムライン表示や統計計算で使う、タグ付きレコード。
/// `value` はDB値（-2〜2）のまま保持する。
class RecordWithTags {
  const RecordWithTags({
    required this.id,
    required this.timestamp,
    required this.comment,
    required this.value,
    required this.tags,
  });

  final String id;
  final DateTime timestamp;
  final String? comment;
  final int value;
  final List<TagRef> tags;
}
