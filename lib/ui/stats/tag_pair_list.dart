import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../domain/models.dart';
import '../../domain/stats/contingency.dart';
import '../../domain/stats/fisher.dart';

/// design.md draft.mdの「基本的には'症状'がyになる想定」に基づき、
/// group名が「症状」のタグをsymptom、それ以外の有効タグをactionとして扱う。
const _symptomGroupName = '症状';

/// plan.mdの想定閾値: 双方の観測日数がこれ未満なら「データ不足」とする。
const _minOccurrenceThreshold = 3;

class _PairResult {
  const _PairResult({
    required this.actionTag,
    required this.symptomTag,
    required this.table,
    required this.hasEnoughData,
  });

  final Tag actionTag;
  final Tag symptomTag;
  final ContingencyTable table;
  final bool hasEnoughData;

  double? get lift => hasEnoughData ? liftValue(table) : null;
  double? get pValue => hasEnoughData ? fisherExactTest(table) : null;
  double? get odds => hasEnoughData ? oddsRatio(table) : null;
}

/// plan.md M6「行動タグ×症状タグの関連リスト（リフト値降順、p値・発生回数併記）」。
class TagPairList extends StatelessWidget {
  const TagPairList({super.key, required this.records, required this.tags});

  final List<RecordWithTags> records;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final symptomTags = tags.where((t) => t.group == _symptomGroupName).toList();
    final actionTags = tags.where((t) => t.group != _symptomGroupName).toList();

    if (symptomTags.isEmpty || actionTags.isEmpty) {
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

    final results = <_PairResult>[
      for (final action in actionTags)
        for (final symptom in symptomTags)
          _buildPairResult(action, symptom),
    ];

    results.sort((a, b) {
      if (a.hasEnoughData != b.hasEnoughData) return a.hasEnoughData ? -1 : 1;
      if (!a.hasEnoughData) return 0;
      return (b.lift ?? 0).compareTo(a.lift ?? 0);
    });

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

  _PairResult _buildPairResult(Tag action, Tag symptom) {
    final table = buildDayContingencyTable(
      records: records,
      actionTagId: action.id,
      symptomTagId: symptom.id,
    );
    final hasEnoughData = table.actionDayCount >= _minOccurrenceThreshold &&
        table.symptomDayCount >= _minOccurrenceThreshold;
    return _PairResult(
      actionTag: action,
      symptomTag: symptom,
      table: table,
      hasEnoughData: hasEnoughData,
    );
  }
}

class _PairTile extends StatelessWidget {
  const _PairTile({required this.result});

  final _PairResult result;

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
