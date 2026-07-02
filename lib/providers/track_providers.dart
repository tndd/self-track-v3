import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import 'database_providers.dart';

DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Track画面で現在表示中の日付（時刻情報は持たず、日の開始時刻で正規化する）。
/// design.md §4.2の通り、レコードはtimestampが属する日にそのまま帰属させる
/// （特例なし）ため、範囲クエリも単純な半開区間で表現できる。
final selectedDateProvider = StateProvider<DateTime>((ref) => _startOfDay(DateTime.now()));

/// 選択中の日付のタイムライン（新しい順）。
final timelineProvider = StreamProvider.autoDispose<List<RecordWithTags>>((ref) {
  final date = ref.watch(selectedDateProvider);
  final dao = ref.watch(recordsDaoProvider);
  return dao.watchByDateRange(date, date.add(const Duration(days: 1)));
});

/// Composerの「最近使ったタグ」候補。直近レコードのタグを新しい順・重複除去で最大8件。
final recentTagsProvider = StreamProvider.autoDispose<List<TagRef>>((ref) {
  final dao = ref.watch(recordsDaoProvider);
  return dao.watchRecent().map((records) {
    final seen = <String>{};
    final result = <TagRef>[];
    for (final record in records) {
      for (final tag in record.tags) {
        if (seen.add(tag.id)) {
          result.add(tag);
          if (result.length >= 8) return result;
        }
      }
    }
    return result;
  });
});
