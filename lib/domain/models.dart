/// タグの表示に必要な最小限の情報。
class TagRef {
  const TagRef({
    required this.id,
    required this.name,
    required this.group,
    this.colorIndex,
  });

  final String id;
  final String name;
  final String group;

  /// チップ配色パレットのindex。nullならタグ名ハッシュで自動決定する。
  final int? colorIndex;
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
