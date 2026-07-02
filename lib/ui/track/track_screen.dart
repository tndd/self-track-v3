import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../domain/models.dart';
import '../../providers/composer_provider.dart';
import '../../providers/database_providers.dart';
import '../../providers/track_providers.dart';
import '../theme.dart';
import 'composer_card.dart';
import 'timeline_entries.dart';
import 'timeline_item.dart';

/// Trackタイムライン。mock/track.htmlを基に、チャット式（最新が最下部、
/// 上方向スクロールで過去日を自動読み込み）に変更している。
class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  final _commentController = TextEditingController();
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();

  /// 直近のビルドで表示したエントリ列。位置リスナーからの参照用。
  List<TimelineEntry> _entries = const [];
  DateTime? _pendingJumpDay;
  bool _positionsSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _commentController.dispose();
    super.dispose();
  }

  /// 位置リスナーはレイアウト中にも発火するため、provider更新や
  /// 追加読み込みはフレーム完了後にまとめて行う。
  void _onPositionsChanged() {
    if (_positionsSyncScheduled) return;
    _positionsSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionsSyncScheduled = false;
      if (mounted) _syncFromPositions();
    });
  }

  void _syncFromPositions() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || _entries.isEmpty) return;

    // reverse:true のためleading edgeは画面下端。画面内で最も上に
    // 見えているのはindexが最大のアイテム。
    var topIndex = -1;
    for (final pos in positions) {
      if (pos.itemTrailingEdge > 0 && pos.index > topIndex) {
        topIndex = pos.index;
      }
    }
    if (topIndex < 0) return;
    topIndex = topIndex.clamp(0, _entries.length - 1);

    // 日付サブ行の追従: 最上部エントリの属する日を通知する。
    DateTime? day;
    for (var i = topIndex; i >= 0 && day == null; i--) {
      day = switch (_entries[i]) {
        TimelineRecordEntry(:final record) => DateTime(
            record.timestamp.year, record.timestamp.month, record.timestamp.day),
        TimelineDateHeaderEntry(:final day) => day,
        TimelineLoadingEntry() => null,
      };
    }
    if (day != null && ref.read(visibleTimelineDayProvider) != day) {
      ref.read(visibleTimelineDayProvider.notifier).state = day;
    }

    // 最上部付近に到達したら過去方向へウィンドウを広げる。
    if (topIndex >= _entries.length - 2) {
      _extendWindow();
    }
  }

  void _extendWindow() {
    if (!ref.read(hasMoreTimelineProvider)) return;
    // ウィンドウ拡張による再購読中の多重発火を防ぐ。
    if (ref.read(timelineProvider).isLoading) return;

    final notifier = ref.read(timelineWindowStartProvider.notifier);
    var next = notifier.state.subtract(const Duration(days: 14));
    final oldest = ref.read(oldestRecordTimestampProvider).value;
    if (oldest != null) {
      final oldestDay = DateTime(oldest.year, oldest.month, oldest.day);
      if (next.isBefore(oldestDay)) next = oldestDay;
      // ウィンドウ内に1件も無い場合は最古日まで一気に広げる。
      if ((ref.read(timelineProvider).value ?? const []).isEmpty) {
        next = oldestDay;
      }
    }
    notifier.state = next;
  }

  /// ジャンプ先の日のヘッダに最も近いエントリ位置。配列は新しい順なので、
  /// 先頭から走査して最初に見つかる「日付がtarget以前のヘッダ」が
  /// target当日（無記録日の場合は直近の過去日）のヘッダになる。
  int _indexForDay(List<TimelineEntry> entries, DateTime target) {
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry is TimelineDateHeaderEntry && !entry.day.isAfter(target)) {
        return i;
      }
    }
    return entries.length - 1;
  }

  Future<void> _submit() async {
    final composer = ref.read(composerProvider);
    final dao = ref.read(recordsDaoProvider);
    final comment = _commentController.text.trim();
    final dbValue = conditionUiToDb(composer.conditionUiValue);
    final tagIds = composer.selectedTagIds.toList();

    if (composer.isEditing) {
      await dao.updateRecord(
        id: composer.editingRecordId!,
        timestamp: composer.editingTimestamp!,
        comment: comment.isEmpty ? null : comment,
        value: dbValue,
        tagIds: tagIds,
      );
    } else {
      await dao.createRecord(
        timestamp: DateTime.now(),
        comment: comment.isEmpty ? null : comment,
        value: dbValue,
        tagIds: tagIds,
      );
    }

    ref.read(composerProvider.notifier).reset();
    _commentController.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  void _startEdit(RecordWithTags record) {
    ref.read(composerProvider.notifier).startEditing(
          recordId: record.id,
          timestamp: record.timestamp,
          conditionUiValue: conditionDbToUi(record.value),
          tagIds: record.tags.map((t) => t.id).toSet(),
        );
    _commentController.text = record.comment ?? '';
  }

  Future<void> _confirmDelete(RecordWithTags record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('記録を削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(recordsDaoProvider).deleteRecord(record.id);
    }
  }

  Future<void> _showLongPressMenu(RecordWithTags record) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('編集'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('削除'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      _startEdit(record);
    } else if (action == 'delete') {
      await _confirmDelete(record);
    }
  }

  void _collapseComposer() {
    ref.read(composerProvider.notifier).collapse();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // DatePicker / Calendarからの日付ジャンプ要求。ウィンドウを対象日まで
    // 広げてから、データ描画後にその日のヘッダ位置へジャンプする。
    ref.listen<int>(dateJumpSeqProvider, (prev, next) {
      final day = ref.read(selectedDateProvider);
      final windowNotifier = ref.read(timelineWindowStartProvider.notifier);
      if (day.isBefore(windowNotifier.state)) {
        windowNotifier.state = day;
      }
      setState(() => _pendingJumpDay = day);
    });

    final timelineAsync = ref.watch(timelineProvider);
    final hasMore = ref.watch(hasMoreTimelineProvider);
    final isComposerExpanded =
        ref.watch(composerProvider.select((s) => s.isExpanded));

    final entries = buildTimelineEntries(
      timelineAsync.value ?? const [],
      hasMore: hasMore,
    );
    _entries = entries;

    if (_pendingJumpDay != null && entries.isNotEmpty && !timelineAsync.isLoading) {
      final index = _indexForDay(entries, _pendingJumpDay!);
      _pendingJumpDay = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _itemScrollController.isAttached) {
          // reverse:true ではalignment=0が画面下端。ヘッダを画面上部寄せにする。
          _itemScrollController.jumpTo(index: index, alignment: 0.85);
        }
      });
    }

    final Widget timeline;
    if (entries.isEmpty) {
      timeline = timelineAsync.isLoading && !timelineAsync.hasValue
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: timelineAsync.hasError
                  ? Text('読み込みエラー: ${timelineAsync.error}')
                  : const Text('まだ記録がありません。'),
            );
    } else {
      timeline = ScrollablePositionedList.builder(
        reverse: true,
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 170),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          if (index < 0 || index >= entries.length) {
            return const SizedBox.shrink();
          }
          return switch (entries[index]) {
            TimelineRecordEntry(:final record) => TimelineItem(
                key: ValueKey(record.id),
                record: record,
                // reverse:trueではindex-1が視覚的にすぐ下のエントリ。
                // 同じ日のレコード同士は配列上で連続する（日付ヘッダが日を
                // 区切る）ため、下がレコードなら同日＝レールを接続する。
                connectBottom:
                    index > 0 && entries[index - 1] is TimelineRecordEntry,
                onLongPress: () => _showLongPressMenu(record),
              ),
            TimelineDateHeaderEntry(:final label, :final day) =>
              _DateHeader(key: ValueKey('header-$day'), label: label),
            TimelineLoadingEntry() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          };
        },
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: timeline),
        // Composer展開中は画面外タップでパネルを閉じる（mockのscrim相当）。
        if (isComposerExpanded)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('composer-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: _collapseComposer,
              child: const ColoredBox(color: Color(0x0F0F172A)),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ComposerCard(commentController: _commentController, onSubmit: _submit),
        ),
      ],
    );
  }
}

/// ヘッダ（AppShell）のタイトル直下に表示する日付サブ行。
/// スクロールで最上部に見えている日を常に表示し、タップでDatePickerを開く。
class TrackDateSubtitle extends ConsumerWidget {
  const TrackDateSubtitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(visibleTimelineDayProvider) ?? _today();
    final label =
        '${day.month}月${day.day}日 ${kWeekdayLabels[day.weekday - 1]}曜';

    return InkWell(
      onTap: () => _pickDate(context, ref, day),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              // 時刻ラベルなどの補助テキスト（#667085）より一段濃く・太くし、
              // 「いま表示している日」として目立たせる。
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      requestDateJump(ref, picked);
    }
  }
}

/// チャットアプリ風の日付見出し（各日のレコード群の直上に表示）。
class _DateHeader extends StatelessWidget {
  const _DateHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // 補助テキストと同じ薄灰色だと区切りとして埋もれるため、
    // チャットアプリ風の淡いピル＋濃い文字で「日の区切り」を強調する。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}
