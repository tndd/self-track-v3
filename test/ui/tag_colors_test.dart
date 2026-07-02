import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/ui/tag_colors.dart';

void main() {
  test('同じタグ名には常に同じ配色が割り当てられる', () {
    final a = tagChipColorsFor('頭痛');
    final b = tagChipColorsFor('頭痛');
    expect(a.background, b.background);
    expect(a.foreground, b.foreground);
  });

  test('返される配色はパレット7種のいずれかである', () {
    for (final name in ['頭痛', 'コーヒー', 'ウォーキング', 'ビタミンD', '低気圧']) {
      final colors = tagChipColorsFor(name);
      expect(
        kTagChipPalettes.any(
          (p) => p.background == colors.background && p.foreground == colors.foreground,
        ),
        isTrue,
        reason: '$name の配色がパレット外',
      );
    }
  });

  test('異なるタグ名で異なる色になる組み合わせが存在する', () {
    final names = ['頭痛', '倦怠感', 'コーヒー', 'ロキソニン', 'ウォーキング', '低気圧', '飲酒'];
    final backgrounds = names.map((n) => tagChipColorsFor(n).background).toSet();
    expect(backgrounds.length, greaterThan(1));
  });
}
