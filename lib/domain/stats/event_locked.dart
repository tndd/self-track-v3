import '../condition_series.dart';
import '../models.dart';

/// イベントロック平均のうち、発生時刻からの相対時刻(時間)1点分。
class EventLockedPoint {
  const EventLockedPoint({
    required this.offsetHours,
    required this.averageValue,
    required this.sampleCount,
  });

  /// タグ発生時刻を0とした相対時間（-12〜12）。
  final int offsetHours;

  final double averageValue;

  /// この点の平均を構成したサンプル数。直近の発生では「発生時刻+オフセット」が
  /// 現在時刻より未来になり得るため、未来分を除外した結果、点ごとに
  /// サンプル数が異なる（プラス側ほど少なくなる）ことがある。
  final int sampleCount;
}

/// spec.md 第I部 §4.3・第II部 M6: [tagId]の各発生時刻を0として、-12h〜+12hを
/// 1時間刻みでcondition曲線（12時間減衰の仮想ポイント込み）からサンプリングし、
/// 全発生回について平均する。
///
/// [records]は当該タグが付いていないものも含めた全レコード（timestamp昇順）
/// であること。体調曲線の構築には全レコードの文脈が必要なため。
///
/// [series]に構築済みの体調系列を渡すと再構築を省略できる。
///
/// 「発生時刻+オフセット」が[now]より未来になるサンプルは、まだ観測されて
/// いないデータのため平均に含めない。全発生回で未来となるオフセットの点は
/// 出力に含まれない。
List<EventLockedPoint> computeEventLockedAverage({
  required List<RecordWithTags> records,
  required String tagId,
  required DateTime now,
  List<ConditionPoint>? series,
}) {
  final occurrences = [
    for (final r in records)
      if (r.tags.any((t) => t.id == tagId)) r.timestamp,
  ];
  if (occurrences.isEmpty) return const [];

  final resolvedSeries = series ?? buildConditionSeries(records, now: now);

  final points = <EventLockedPoint>[];
  for (var offset = -12; offset <= 12; offset++) {
    final duration = Duration(hours: offset);
    final samples = <double>[
      for (final occurrence in occurrences)
        if (!occurrence.add(duration).isAfter(now))
          valueAtTime(resolvedSeries, occurrence.add(duration)),
    ];
    if (samples.isEmpty) continue;
    points.add(
      EventLockedPoint(
        offsetHours: offset,
        averageValue: _average(samples),
        sampleCount: samples.length,
      ),
    );
  }
  return points;
}

double _average(List<double> values) {
  return values.reduce((a, b) => a + b) / values.length;
}
