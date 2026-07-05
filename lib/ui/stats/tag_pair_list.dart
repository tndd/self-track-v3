import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/stats/contingency.dart';
import '../../providers/database_providers.dart';
import '../../providers/stats_providers.dart';

/// plan.md M6「行動タグ×症状タグの関連リスト（リフト値降順、p値・発生回数併記）」。
/// 計算はtagPairStatsProviderにメモ化されており、レコード・タグの変化時のみ
/// 再実行される。アーカイブ済みタグも統計対象に含まれる（design.md §5.4）。
class TagPairList extends ConsumerWidget {
  const TagPairList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final hasSymptom = tags.any((t) => t.group == kSymptomGroupName);
    final hasAction = tags.any((t) => t.group != kSymptomGroupName);

    if (!hasSymptom || !hasAction) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '行動×症状の関連',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF344054)),
            ),
            SizedBox(height: 8),
            Text(
              '「症状」グループのタグと、それ以外のグループのタグが両方登録されると表示されます。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final results = ref.watch(tagPairStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '行動×症状の関連',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF344054)),
          ),
          const SizedBox(height: 4),
          const Text(
            'リフト値が高いほど、その行動をした日に症状が出やすい傾向を示します。',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          for (final result in results) _PairTile(result: result),
        ],
      ),
    );
  }
}

class _PairTile extends StatelessWidget {
  const _PairTile({required this.result});

  final TagPairStat result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${result.actionTag.name} → ${result.symptomTag.name}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (!result.hasEnoughData)
            const Text('データ不足', style: TextStyle(fontSize: 11, color: Colors.grey))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'リフト ${result.lift!.toStringAsFixed(2)}倍',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: result.lift! >= 1 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
                Text(
                  'p=${result.pValue!.toStringAsFixed(3)} / OR=${result.odds!.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
