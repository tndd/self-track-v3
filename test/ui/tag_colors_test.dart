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

  test('resolveTagChipColorsは保存されたcolorIndexを優先し、null/範囲外はハッシュに戻る', () {
    // 明示indexが優先される。
    final explicit = resolveTagChipColors('頭痛', 1);
    expect(explicit.background, kTagChipPalettes[1].background);

    // nullはタグ名ハッシュと同じ。
    final auto = resolveTagChipColors('頭痛', null);
    expect(auto.background, tagChipColorsFor('頭痛').background);

    // 範囲外のindex（将来のパレット縮小など）もハッシュにフォールバック。
    final outOfRange = resolveTagChipColors('頭痛', 99);
    expect(outOfRange.background, tagChipColorsFor('頭痛').background);
  });

  test('異なるタグ名で異なる色になる組み合わせが存在する', () {
    final names = ['頭痛', '倦怠感', 'コーヒー', 'ロキソニン', 'ウォーキング', '低気圧', '飲酒'];
    final backgrounds = names.map((n) => tagChipColorsFor(n).background).toSet();
    expect(backgrounds.length, greaterThan(1));
  });
}
