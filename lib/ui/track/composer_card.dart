import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/models.dart';
import '../../providers/composer_provider.dart';
import '../../providers/database_providers.dart';
import '../../providers/track_providers.dart';
import '../theme.dart';

/// Track画面下部の記録入力パネル（mock/track.htmlの「上伸びパネル」に相当）。
/// モックでは別カードのポップオーバーとStatusバーが分離しているが、
/// v1.0では単一の伸縮カードに統合して簡略化している。
class ComposerCard extends ConsumerWidget {
  const ComposerCard({
    super.key,
    required this.commentController,
    required this.onSubmit,
  });

  final TextEditingController commentController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composer = ref.watch(composerProvider);
    final notifier = ref.read(composerProvider.notifier);
    final activeTags = ref.watch(activeTagsProvider).value ?? const <Tag>[];
    final recentTags = ref.watch(recentTagsProvider).value ?? const <TagRef>[];
    final level = ConditionLevel.fromUiValue(composer.conditionUiValue);

    final selectedTags = [
      for (final id in composer.selectedTagIds)
        ...activeTags.where((t) => t.id == id),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDFE4EE)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A101828), blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedTags.isNotEmpty)
            _SelectedTagChips(tags: selectedTags, onRemove: notifier.toggleTag),
          if (composer.isExpanded) ...[
            if (composer.editingRecordId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Text('記録を編集中', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        notifier.reset();
                        commentController.clear();
                      },
                      child: const Text('編集をやめる'),
                    ),
                  ],
                ),
              ),
            if (composer.isTagZoneOpen)
              _TagZone(
                activeTags: activeTags,
                recentTags: recentTags,
                selectedIds: composer.selectedTagIds,
                onToggle: notifier.toggleTag,
              ),
            Row(
              children: [
                const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey)),
                const Spacer(),
                if (activeTags.isNotEmpty)
                  TextButton(
                    onPressed: notifier.toggleTagZone,
                    child: Text(composer.isTagZoneOpen ? 'タグ表示中' : 'タグを追加'),
                  ),
              ],
            ),
            _StatusStrip(
              selected: composer.conditionUiValue,
              onSelect: notifier.selectCondition,
            ),
            const Divider(height: 16),
          ],
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: notifier.expand,
              ),
              Expanded(
                child: TextField(
                  controller: commentController,
                  onTap: notifier.expand,
                  decoration: const InputDecoration(
                    hintText: 'コメントを書く...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: level.color),
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                onPressed: onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedTagChips extends StatelessWidget {
  const _SelectedTagChips({required this.tags, required this.onRemove});

  final List<Tag> tags;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final tag in tags)
            InputChip(
              label: Text(tag.name),
              onDeleted: () => onRemove(tag.id),
            ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final level in ConditionLevel.values)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(level.uiValue),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: level.uiValue == selected
                        ? const Color(0xFF111827)
                        : const Color(0xFFE5E7EB),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: level.color,
                      child: Text(
                        '${level.uiValue}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(level.label, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TagZone extends StatelessWidget {
  const _TagZone({
    required this.activeTags,
    required this.recentTags,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Tag> activeTags;
  final List<TagRef> recentTags;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final byGroup = <String, List<Tag>>{};
    for (final tag in activeTags) {
      byGroup.putIfAbsent(tag.group, () => []).add(tag);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recentTags.isNotEmpty)
              _TagGroupSection(
                title: '最近使ったタグ',
                children: [
                  for (final tag in recentTags) _buildChip(tag.id, tag.name),
                ],
              ),
            for (final entry in byGroup.entries)
              _TagGroupSection(
                title: entry.key,
                children: [
                  for (final tag in entry.value) _buildChip(tag.id, tag.name),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String id, String name) {
    return FilterChip(
      label: Text(name),
      selected: selectedIds.contains(id),
      onSelected: (_) => onToggle(id),
    );
  }
}

class _TagGroupSection extends StatelessWidget {
  const _TagGroupSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 4, runSpacing: 4, children: children),
        ],
      ),
    );
  }
}
