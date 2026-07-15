import 'dart:math' as math;

import 'contingency.dart';

/// spec.md 第I部 §4.3・第II部 §6.3: Fisherの正確確率検定（両側）。
///
/// 2×2分割表の行和・列和（周辺和）を固定した超幾何分布のもとで、観測表と
/// 同じか、それ以下の確率を持つすべての表の確率を合計する。対数階乗の
/// 逐次和により計算し、値が大きくなってもアンダーフローしないようにする。
double fisherExactTest(ContingencyTable table) {
  final rowA = table.a + table.b;
  final rowB = table.c + table.d;
  final colA = table.a + table.c;
  final n = table.n;

  if (n == 0) return 1.0;

  final observedLogP = _logHypergeometricP(table.a, rowA, rowB, colA, n);

  final lowerA = math.max(0, colA - rowB);
  final upperA = math.min(rowA, colA);

  // 観測値そのものの浮動小数点誤差で漏れないよう、わずかな許容誤差を設ける。
  const tolerance = 1e-7;

  var totalP = 0.0;
  for (var x = lowerA; x <= upperA; x++) {
    final logP = _logHypergeometricP(x, rowA, rowB, colA, n);
    if (logP <= observedLogP + tolerance) {
      totalP += math.exp(logP);
    }
  }
  return totalP.clamp(0.0, 1.0);
}

double _logHypergeometricP(int a, int rowA, int rowB, int colA, int n) {
  final b = rowA - a;
  final c = colA - a;
  final d = n - rowA - colA + a;
  if (a < 0 || b < 0 || c < 0 || d < 0) return double.negativeInfinity;

  return _logFactorial(rowA) +
      _logFactorial(rowB) +
      _logFactorial(colA) +
      _logFactorial(n - colA) -
      _logFactorial(a) -
      _logFactorial(b) -
      _logFactorial(c) -
      _logFactorial(d) -
      _logFactorial(n);
}

/// log(0!)=0, log(1!)=0 を初期値とする累積テーブル。必要になった分だけ
/// 伸ばしてキャッシュする。毎回O(n)のループで再計算すると、全ペア×全候補表
/// の検定でnが数百の場合に無視できないコストになるため。
final List<double> _logFactorialCache = <double>[0.0, 0.0];

double _logFactorial(int n) {
  while (_logFactorialCache.length <= n) {
    _logFactorialCache
        .add(_logFactorialCache.last + math.log(_logFactorialCache.length));
  }
  return _logFactorialCache[n];
}
