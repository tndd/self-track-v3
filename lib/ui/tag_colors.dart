import 'package:flutter/material.dart';

/// mock/track.html のタグチップ配色（.chip / .tag-*）。
/// 背景と文字色のペアで、タイムライン・Composer・全画面タグ選択で共用する。
class TagChipColors {
  const TagChipColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// モックの7パレット（デフォルトindigo + tag-red/green/orange/purple/gray/blue）。
const kTagChipPalettes = <TagChipColors>[
  TagChipColors(Color(0xFFEEF2FF), Color(0xFF3446A8)), // indigo（デフォルト）
  TagChipColors(Color(0xFFFFE4E6), Color(0xFFBE123C)), // red
  TagChipColors(Color(0xFFDCFCE7), Color(0xFF15803D)), // green
  TagChipColors(Color(0xFFFFEDD5), Color(0xFFC2410C)), // orange
  TagChipColors(Color(0xFFF3E8FF), Color(0xFF7E22CE)), // purple
  TagChipColors(Color(0xFFEEF2F7), Color(0xFF475569)), // gray
  TagChipColors(Color(0xFFDBEAFE), Color(0xFF1D4ED8)), // blue
];

/// タグ名から安定的に配色を選ぶ。タグに色属性を持たせる代わりに、
/// 名前のハッシュで決めることでDB変更なしに「タグごとに色が違う」
/// モックの見た目を再現する。String.hashCodeはDartバージョン間で
/// 安定しないため、自前の31乗算ハッシュを使う。
TagChipColors tagChipColorsFor(String name) {
  var h = 0;
  for (final rune in name.runes) {
    h = (h * 31 + rune) & 0x7fffffff;
  }
  return kTagChipPalettes[h % kTagChipPalettes.length];
}
