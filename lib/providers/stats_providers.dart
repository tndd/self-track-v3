import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/stats/contingency.dart';
import '../domain/stats/event_locked.dart';
import '../domain/stats/fisher.dart';
import 'calendar_providers.dart';
import 'database_providers.dart';
import 'score_providers.dart';

/// イベントロック平均グラフで現在選択中のタグID。未選択ならnull。
final selectedEventTagIdProvider = StateProvider<String?>((ref) => null);

/// spec.mdの想定閾値: 双方の観測日数がこれ未満なら「データ不足」とする。
const kMinPairObservationDays = 3;

/// 行動タグ×症状タグ1ペア分の統計結果。
class TagPairStat {
  TagPairStat({
    required this.actionTag,
    required this.symptomTag,
    required this.table,
    required this.hasEnoughData,
  })  : lift = hasEnoughData ? liftValue(table) : null,
        pValue = hasEnoughData ? fisherExactTest(table) : null,
        odds = hasEnoughData ? oddsRatio(table) : null;

  final Tag actionTag;
  final Tag symptomTag;
  final ContingencyTable table;
  final bool hasEnoughData;
  final double? lift;
  final double? pValue;
  final double? odds;
}

/// spec.md M6「行動タグ×症状タグの関連リスト（リフト値降順、p値・発生回数併記）」。
///
/// - spec.md §5.4「過去の記録は保持され、統計にも引き続き利用できる」に
///   従い、アーカイブ済みタグも対象に含める（activeTagsではなくallTags）。
/// - タグ→発生日の集合を1パスで前計算し、ペアごとの全レコード再走査を避ける。
/// - providerとしてメモ化することで、レコード・タグが変化した時のみ
///   再計算され、ビルドのたびのFisher検定同期実行を避ける。
final tagPairStatsProvider = Provider.autoDispose<List<TagPairStat>>((ref) {
  final records = ref.watch(allRecordsProvider).value ?? const [];
  final tags = ref.watch(allTagsProvider).value ?? const <Tag>[];

  final symptomTags =
      tags.where((t) => t.group == kSymptomGroupName).toList();
  final actionTags =
      tags.where((t) => t.group != kSymptomGroupName).toList();
  if (symptomTags.isEmpty || actionTags.isEmpty) return const [];

  final sets = buildDayTagSets(records);

  final results = <TagPairStat>[
    for (final action in actionTags)
      for (final symptom in symptomTags)
        _buildPairStat(sets, action, symptom),
  ];

  results.sort((a, b) {
    if (a.hasEnoughData != b.hasEnoughData) return a.hasEnoughData ? -1 : 1;
    if (!a.hasEnoughData) return 0;
    return (b.lift ?? 0).compareTo(a.lift ?? 0);
  });
  return results;
});

TagPairStat _buildPairStat(DayTagSets sets, Tag action, Tag symptom) {
  final table = buildContingencyFromSets(
    sets: sets,
    actionTagId: action.id,
    symptomTagId: symptom.id,
  );
  final hasEnoughData = table.actionDayCount >= kMinPairObservationDays &&
      table.symptomDayCount >= kMinPairObservationDays;
  return TagPairStat(
    actionTag: action,
    symptomTag: symptom,
    table: table,
    hasEnoughData: hasEnoughData,
  );
}

/// 指定タグのイベントロック平均（-12h〜+12h、未来分は除外）。
/// 共有の体調系列を使い、レコード・nowの変化時のみ再計算される。
final eventLockedPointsProvider =
    Provider.autoDispose.family<List<EventLockedPoint>, String>((ref, tagId) {
  final records = ref.watch(allRecordsProvider).value ?? const [];
  return computeEventLockedAverage(
    records: records,
    tagId: tagId,
    now: ref.watch(nowProvider),
    series: ref.watch(conditionSeriesProvider),
  );
});
