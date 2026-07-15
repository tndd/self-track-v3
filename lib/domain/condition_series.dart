import 'models.dart';

/// spec.md §4.1の「12時間以上ログがない場合は平常（0）に戻る」を
/// 表現する閾値。
const decayThreshold = Duration(hours: 12);

/// 体調推移上の1点。実レコードによる点か、12時間減衰による仮想点かを区別する。
class ConditionPoint {
  const ConditionPoint({
    required this.timestamp,
    required this.value,
    this.isVirtual = false,
  });

  final DateTime timestamp;

  /// DB値域(-2〜2)の連続値。線形補間の結果として小数になり得る。
  final double value;

  final bool isVirtual;
}

/// レコード列（[records]はtimestamp昇順であること）から、12時間以上の
/// 空白を挟む箇所に value=0 の仮想ポイントを補完した時系列を構築する。
///
/// - 隣り合うログA・Bの間隔が12時間を超える場合、A+12時間の位置に仮想ポイントを挿入する。
/// - 最後のログから[now]までの間隔が12時間を超える場合、最後のログ+12時間の位置と
///   [now]自身の2点に value=0 の仮想ポイントを挿入する。
/// - 間隔が12時間以内の場合も、[now]時点の減衰途中の値（最後のログ値から
///   +12時間で0になる直線上の値）を仮想ポイントとして追加し、系列が常に
///   [now]で終端するようにする。これにより「未来の時間帯」が最終ログ値の
///   まま延長されて日次スコア等が過大評価されることを防ぐ。
///
/// 仮想ポイントはメモリ上の計算・描画のためだけに存在し、DBには保存しない。
List<ConditionPoint> buildConditionSeries(
  List<RecordWithTags> records, {
  required DateTime now,
}) {
  if (records.isEmpty) return const [];

  final points = <ConditionPoint>[
    ConditionPoint(timestamp: records.first.timestamp, value: records.first.value.toDouble()),
  ];

  for (var i = 0; i < records.length - 1; i++) {
    final a = records[i];
    final b = records[i + 1];
    if (b.timestamp.difference(a.timestamp) > decayThreshold) {
      points.add(
        ConditionPoint(timestamp: a.timestamp.add(decayThreshold), value: 0, isVirtual: true),
      );
    }
    points.add(ConditionPoint(timestamp: b.timestamp, value: b.value.toDouble()));
  }

  final last = records.last;
  final gap = now.difference(last.timestamp);
  if (gap > decayThreshold) {
    points.add(
      ConditionPoint(timestamp: last.timestamp.add(decayThreshold), value: 0, isVirtual: true),
    );
    points.add(ConditionPoint(timestamp: now, value: 0, isVirtual: true));
  } else if (gap > Duration.zero) {
    final remaining = 1 - gap.inMicroseconds / decayThreshold.inMicroseconds;
    points.add(
      ConditionPoint(timestamp: now, value: last.value * remaining, isVirtual: true),
    );
  }

  return points;
}

/// [series]（timestamp昇順であること）を使い、任意時刻[t]の体調値を線形補間で求める。
/// daily_score.dart・stats/event_locked.dartの双方が使う共通ロジック。
///
/// - 系列の最初の点より前の時刻: データが無いため既定値0とする（spec.md §2.2）。
/// - 系列の最後の点より後の時刻: 最後の値がそのまま続くとみなす。
///   （buildConditionSeriesは系列をnowで終端させるため、通常この分岐は
///   now以降＝未来の時刻を問い合わせた場合にのみ通る。未来のサンプリングを
///   避けたい呼び出し側は事前に系列終端と比較すること。）
///
/// 系列は昇順ソート済みのため二分探索でO(log N)。
double valueAtTime(List<ConditionPoint> series, DateTime t) {
  if (series.isEmpty) return 0;
  if (t.isBefore(series.first.timestamp)) return 0;

  // timestamp <= t を満たす最後のindexを二分探索で求める。
  var lo = 0;
  var hi = series.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (series[mid].timestamp.isAfter(t)) {
      hi = mid - 1;
    } else {
      lo = mid;
    }
  }

  final before = series[lo];
  if (lo == series.length - 1) return before.value;
  final after = series[lo + 1];
  if (!after.timestamp.isAfter(before.timestamp)) return before.value;

  final spanMicros = after.timestamp.difference(before.timestamp).inMicroseconds;
  final elapsedMicros = t.difference(before.timestamp).inMicroseconds;
  return before.value + (after.value - before.value) * (elapsedMicros / spanMicros);
}
