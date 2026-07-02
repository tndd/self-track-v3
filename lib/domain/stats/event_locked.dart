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

  /// 平均を構成したタグ発生回数（全発生回で共通のはず）。
  final int sampleCount;
}

/// design.md §4.3・plan.md M6: [tagId]の各発生時刻を0として、-12h〜+12hを
/// 1時間刻みでcondition曲線（12時間減衰の仮想ポイント込み）からサンプリングし、
/// 全発生回について平均する。
///
/// [records]は当該タグが付いていないものも含めた全レコード（timestamp昇順）
/// であること。体調曲線の構築には全レコードの文脈が必要なため。
List<EventLockedPoint> computeEventLockedAverage({
  required List<RecordWithTags> records,
  required String tagId,
  required DateTime now,
}) {
  final occurrences = [
    for (final r in records)
      if (r.tags.any((t) => t.id == tagId)) r.timestamp,
  ];
  if (occurrences.isEmpty) return const [];

  final series = buildConditionSeries(records, now: now);

  return [
    for (var offset = -12; offset <= 12; offset++)
      EventLockedPoint(
        offsetHours: offset,
        averageValue: _average([
          for (final occurrence in occurrences)
            valueAtTime(series, occurrence.add(Duration(hours: offset))),
        ]),
        sampleCount: occurrences.length,
      ),
  ];
}

double _average(List<double> values) {
  return values.reduce((a, b) => a + b) / values.length;
}
