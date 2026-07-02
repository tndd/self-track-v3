import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../providers/composer_provider.dart';
import '../../providers/database_providers.dart';
import '../../providers/track_providers.dart';
import '../theme.dart';
import 'composer_card.dart';
import 'timeline_item.dart';

class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

  Future<void> _pickDate() async {
    final current = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state =
          DateTime(picked.year, picked.month, picked.day);
    }
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

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(timelineProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final dateLabel =
        '${selectedDate.month}月${selectedDate.day}日 ${_weekdayLabels[selectedDate.weekday - 1]}曜';

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text(dateLabel, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            Expanded(
              child: timelineAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('読み込みエラー: $error')),
                data: (records) {
                  if (records.isEmpty) {
                    return const Center(child: Text('この日の記録はまだありません。'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return TimelineItem(
                        record: record,
                        onLongPress: () => _showLongPressMenu(record),
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
