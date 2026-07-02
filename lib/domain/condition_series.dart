import 'models.dart';

/// design.md §4.1の「12時間以上ログがない場合は平常（0）に戻る」を
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
  if (now.difference(last.timestamp) > decayThreshold) {
    points.add(
      ConditionPoint(timestamp: last.timestamp.add(decayThreshold), value: 0, isVirtual: true),
    );
    points.add(ConditionPoint(timestamp: now, value: 0, isVirtual: true));
  }

  return points;
}
