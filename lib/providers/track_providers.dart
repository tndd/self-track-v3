import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dates.dart';
import '../domain/models.dart';
import 'calendar_providers.dart';
import 'database_providers.dart';

/// Track画面の「日付ジャンプ先」。DatePickerやCalendarの日セルタップで
/// セットされ、TrackScreenがタイムラインを該当日までスクロールする。
/// （時刻情報は持たず、日の開始時刻で正規化する。）
final selectedDateProvider = StateProvider<DateTime>((ref) => startOfDay(DateTime.now()));

/// タイムラインが遡って読み込み済みのウィンドウ開始日（この日以降を表示）。
/// 上方向へのスクロールで14日ずつ過去に広がる。初期値は直近14日。
final timelineWindowStartProvider = StateProvider<DateTime>(
  (ref) => startOfDay(DateTime.now()).subtract(const Duration(days: 13)),
);

/// ウィンドウ内の全レコード（新しい順）。チャット式の無限スクロールでは
/// 日単位ではなくウィンドウ開始日以降を丸ごと購読する。
final timelineProvider = StreamProvider.autoDispose<List<RecordWithTags>>((ref) {
  final start = ref.watch(timelineWindowStartProvider);
  return ref.watch(recordsDaoProvider).watchSince(start);
});

/// 最古レコードのtimestamp（nullなら記録なし）。遡り終端の判定に使う。
final oldestRecordTimestampProvider = StreamProvider.autoDispose<DateTime?>(
  (ref) => ref.watch(recordsDaoProvider).watchOldestTimestamp(),
);

/// ウィンドウよりさらに過去に記録が残っているか。
final hasMoreTimelineProvider = Provider.autoDispose<bool>((ref) {
  final oldest = ref.watch(oldestRecordTimestampProvider).value;
  if (oldest == null) return false;
  return oldest.isBefore(ref.watch(timelineWindowStartProvider));
});

/// スクロール位置の最上部に見えている日。ヘッダの日付サブ行が追従する。
/// nullは未確定（起動直後など）で、表示側は今日にフォールバックする。
final visibleTimelineDayProvider = StateProvider<DateTime?>((ref) => null);

/// 日付ジャンプ要求の連番。StateProviderは同値のセットでは通知しないため、
/// 同じ日を選び直した場合でも再ジャンプできるよう連番の変化で通知する。
final dateJumpSeqProvider = StateProvider<int>((ref) => 0);

/// DatePicker・Calendarの日セルタップから呼ぶ日付ジャンプの入口。
void requestDateJump(WidgetRef ref, DateTime day) {
  ref.read(selectedDateProvider.notifier).state = startOfDay(day);
  ref.read(dateJumpSeqProvider.notifier).state++;
}

/// Composerの「最近使ったタグ」候補。レコードのタグを新しい順・重複除去で
/// 最大8件。アーカイブ済みタグは選択候補に出さない（design.md §5.1）。
/// 常駐して監視済みのallRecordsProviderから導出することで、専用の
/// 直近Nレコード監視クエリを追加せずに済む。
final recentTagsProvider = Provider.autoDispose<List<TagRef>>((ref) {
  final records = ref.watch(allRecordsProvider).value ?? const [];
  final seen = <String>{};
  final result = <TagRef>[];
  for (final record in records.reversed) {
    for (final tag in record.tags) {
      if (tag.isArchived) continue;
      if (seen.add(tag.id)) {
        result.add(tag);
        if (result.length >= 8) return result;
      }
    }
  }
  return result;
});
