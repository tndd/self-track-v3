import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/database_providers.dart';
import '../../providers/stats_providers.dart';

/// spec.md M6「タグを1つ選ぶ → イベントロック平均グラフ」。
/// アーカイブ済みタグも選択候補に含める（spec.md §5.4: 過去の記録は
/// 統計にも引き続き利用できる）。計算はproviderにメモ化されている。
class EventLockedSection extends ConsumerWidget {
  const EventLockedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final selectedId = ref.watch(selectedEventTagIdProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'イベントロック平均',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF344054)),
          ),
          const SizedBox(height: 4),
          const Text(
            'タグの発生時刻を0として、前後12時間の体調推移を平均します。',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (tags.isEmpty)
            const Text('タグがまだありません。', style: TextStyle(fontSize: 12, color: Colors.grey))
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in tags)
                  ChoiceChip(
                    label: Text(tag.name),
                    selected: tag.id == selectedId,
                    // 選択中チップの再タップで選択解除できるようにする。
                    onSelected: (selected) => ref
                        .read(selectedEventTagIdProvider.notifier)
                        .state = selected ? tag.id : null,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedId != null) _EventLockedChart(tagId: selectedId),
          ],
        ],
      ),
    );
  }
}

class _EventLockedChart extends ConsumerWidget {
  const _EventLockedChart({required this.tagId});

  final String tagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(eventLockedPointsProvider(tagId));
    if (points.isEmpty) {
      return const Text('このタグの記録がまだありません。', style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    final spots = [for (final p in points) FlSpot(p.offsetHours.toDouble(), p.averageValue)];
    final occurrenceCount =
        points.map((p) => p.sampleCount).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '発生回数: $occurrenceCount回',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minX: -12,
              maxX: 12,
              minY: -2,
              maxY: 2,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: Colors.grey.shade400,
                    strokeWidth: 1,
                    dashArray: const [3, 3],
                  ),
                ],
                verticalLines: [
                  VerticalLine(
                    x: 0,
                    color: Colors.grey.shade400,
                    strokeWidth: 1,
                    dashArray: const [3, 3],
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFF7E22CE),
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
