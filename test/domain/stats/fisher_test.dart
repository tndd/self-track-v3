import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/domain/stats/contingency.dart';
import 'package:self_track_v3/domain/stats/fisher.dart';

void main() {
  group('fisherExactTest', () {
    test('教科書的な既知の例 (3,1,1,3) でp≈0.4857になる', () {
      const table = ContingencyTable(a: 3, b: 1, c: 1, d: 3);

      final p = fisherExactTest(table);

      expect(p, closeTo(0.4857, 1e-3));
    });

    test('完全に偏った分割表 (4,0,0,4) は有意に小さいp値になる', () {
      const table = ContingencyTable(a: 4, b: 0, c: 0, d: 4);

      final p = fisherExactTest(table);

      // R: fisher.test(matrix(c(4,0,0,4),2,2)) -> p-value = 0.02857
      expect(p, closeTo(0.02857, 1e-4));
    });

    test('全く偏りが無い一様な分割表はp値が1に近い', () {
      const table = ContingencyTable(a: 2, b: 2, c: 2, d: 2);

      final p = fisherExactTest(table);

      expect(p, closeTo(1.0, 1e-6));
    });

    test('データが1件も無い場合はp値1.0を返す', () {
      const table = ContingencyTable(a: 0, b: 0, c: 0, d: 0);

      expect(fisherExactTest(table), 1.0);
    });
  });

  group('oddsRatio', () {
    test('ゼロセルが無ければ単純な交差比を返す', () {
      const table = ContingencyTable(a: 4, b: 2, c: 1, d: 3);

      expect(oddsRatio(table), closeTo((4 * 3) / (2 * 1), 1e-9));
    });

    test('ゼロセルがある場合はHaldane補正(各+0.5)を適用する', () {
      const table = ContingencyTable(a: 4, b: 0, c: 0, d: 4);

      final expected = (4.5 * 4.5) / (0.5 * 0.5);
      expect(oddsRatio(table), closeTo(expected, 1e-9));
    });
  });

  group('liftValue', () {
    test('P(症状|行動)がP(症状)と等しければリフト値は1.0', () {
      // 観測日8日、行動日4日中症状2日、非行動日4日中症状2日 -> 全体症状率と一致
      const table = ContingencyTable(a: 2, b: 2, c: 2, d: 2);

      expect(liftValue(table), closeTo(1.0, 1e-9));
    });

    test('行動時に症状が起きやすいほどリフト値は1より大きい', () {
      const table = ContingencyTable(a: 4, b: 0, c: 0, d: 4);

      // P(症状|行動)=4/4=1.0, P(症状)=4/8=0.5 -> リフト=2.0
      expect(liftValue(table), closeTo(2.0, 1e-9));
    });

    test('行動日・症状日のいずれかが0日の場合はnullを返す', () {
      const table = ContingencyTable(a: 0, b: 0, c: 3, d: 5);

      expect(liftValue(table), isNull);
    });
  });
}
