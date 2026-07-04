import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_providers.dart';
import '../../providers/database_providers.dart';
import 'event_locked_section.dart';
import 'recent_trend_chart.dart';
import 'tag_pair_list.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(allRecordsProvider);
    final tagsAsync = ref.watch(allTagsProvider);

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('読み込みエラー: $error')),
      data: (records) {
        if (records.isEmpty) {
          return const Center(child: Text('記録がまだありません。Trackで記録を作成してみましょう。'));
        }

        return tagsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('読み込みエラー: $error')),
          data: (_) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: const [
                RecentTrendChart(),
                Divider(height: 24, indent: 16, endIndent: 16),
                EventLockedSection(),
                Divider(height: 24, indent: 16, endIndent: 16),
                TagPairList(),
              ],
            );
          },
        );
      },
    );
  }
}
