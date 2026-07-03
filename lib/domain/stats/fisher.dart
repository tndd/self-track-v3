import 'dart:math' as math;

import 'contingency.dart';

/// design.md §4.3・plan.md §6.3: Fisherの正確確率検定（両側）。
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

/// log(n!)の累積キャッシュ（`_logFactorialCache[n]` == log(n!)）。単調増加で
/// 値も変わらないため、プロセス内で使い回してよい。TagPairListは1回の描画で
/// action×symptomの全ペアに対しFisher検定を行い、それぞれが `_logHypergeometricP`
/// を候補表の数だけ呼ぶため、都度O(n)で計算し直すと総和が大きくなる。
final List<double> _logFactorialCache = [0.0];

double _logFactorial(int n) {
  for (var i = _logFactorialCache.length; i <= n; i++) {
    _logFactorialCache.add(_logFactorialCache[i - 1] + math.log(i));
  }
  return _logFactorialCache[n];
}
