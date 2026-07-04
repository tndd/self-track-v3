import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/models.dart';
import '../../providers/composer_provider.dart';
import '../../providers/database_providers.dart';
import '../../providers/track_providers.dart';
import '../tag_colors.dart';
import '../theme.dart';

/// Track画面下部の記録入力パネル（mock/track.htmlの「上伸びパネル」に相当）。
/// モックでは別カードのポップオーバーとStatusバーが分離しているが、
/// v1.0では単一の伸縮カードに統合して簡略化している。
/// 寸法はmock/track.html（幅300pxフレーム）のpx値 × 1.37 を dp に丸めた値。
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
    final recentTags = ref.watch(recentTagsProvider);
    final level = ConditionLevel.fromUiValue(composer.conditionUiValue);

    // 選択済みチップは全タグ（アーカイブ済み含む）から解決する。編集対象の
    // レコードにアーカイブ済みタグが付いている場合でも、チップとして表示され
    // ユーザーが取り外せるようにするため（選択候補一覧には出さない）。
    final allTags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final selectedTags = [
      for (final id in composer.selectedTagIds) ...allTags.where((t) => t.id == id),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
                    const Text('記録を編集中',
                        style: TextStyle(fontSize: 15, color: Colors.grey)),
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
            if (composer.isTagZoneOpen) ...[
              // mockのpanelTop: 「Tags」見出し + 右端の全画面ボタン（⛶）。
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text('Tags', style: _panelTitleStyle),
                    const Spacer(),
                    _ExpandButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const FullTagSelectorDialog(),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: TagGroupList(
                    activeTags: activeTags,
                    recentTags: recentTags,
                    selectedIds: composer.selectedTagIds,
                    onToggle: notifier.toggleTag,
                  ),
                ),
              ),
              const Divider(height: 20, color: Color(0xFFEEF2F7)),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Text('Status', style: _panelTitleStyle),
                  const Spacer(),
                  if (activeTags.isNotEmpty)
                    _TagToggleButton(
                      label: composer.isTagZoneOpen ? 'タグ表示中' : 'タグを追加',
                      ghost: composer.isTagZoneOpen,
                      onPressed: notifier.toggleTagZone,
                    ),
                ],
              ),
            ),
            _StatusStrip(
              selected: composer.conditionUiValue,
              onSelect: notifier.selectCondition,
            ),
            const Divider(height: 20),
          ],
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                iconSize: 32,
                color: const Color(0xFF111827),
                onPressed: notifier.expand,
              ),
              Expanded(
                child: TextField(
                  controller: commentController,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'コメントを書く...',
                    hintStyle: TextStyle(fontSize: 18, color: Color(0xFF8A94A6)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: level.color,
                  fixedSize: const Size(44, 44),
                ),
                icon: Icon(
                  Icons.arrow_upward,
                  size: 22,
                  // mockでは普通（グレー）のみ濃色アイコン、他は白。
                  color: level == ConditionLevel.normal
                      ? const Color(0xFF111827)
                      : Colors.white,
                ),
                onPressed: onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _panelTitleStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: Color(0xFF667085),
);

/// mockの.tagToggle: 黒い丸みピル型ボタン。ghost=trueで淡色（タグ表示中）。
class _TagToggleButton extends StatelessWidget {
  const _TagToggleButton({
    required this.label,
    required this.ghost,
    required this.onPressed,
  });

  final String label;
  final bool ghost;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ghost ? const Color(0xFFF1F5F9) : const Color(0xFF111827),
      shape: StadiumBorder(
        side: ghost
            ? const BorderSide(color: Color(0xFFE5E7EB))
            : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ghost ? const Color(0xFF475569) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// mockの.expandBtn: タグ選択を全画面表示にする丸ボタン（⛶）。
class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: Color(0xFFE5E7EB))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.open_in_full, size: 18, color: Color(0xFF475569)),
        ),
      ),
    );
  }
}

/// mock case 04の全画面タグ選択。右上の「完了」で閉じる。
/// 選択状態はcomposerProviderを直接読むため、閉じるだけで反映済み。
class FullTagSelectorDialog extends ConsumerWidget {
  const FullTagSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composer = ref.watch(composerProvider);
    final notifier = ref.read(composerProvider.notifier);
    final activeTags = ref.watch(activeTagsProvider).value ?? const <Tag>[];
    final recentTags = ref.watch(recentTagsProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Color(0xFFDFE4EE)),
      ),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height,
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Tags',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  _TagToggleButton(
                    label: '完了',
                    ghost: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFEEF2F7)),
                      bottom: BorderSide(color: Color(0xFFEEF2F7)),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: TagGroupList(
                      activeTags: activeTags,
                      recentTags: recentTags,
                      selectedIds: composer.selectedTagIds,
                      onToggle: notifier.toggleTag,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Status', style: _panelTitleStyle),
              const SizedBox(height: 8),
              _StatusStrip(
                selected: composer.conditionUiValue,
                onSelect: notifier.selectCondition,
              ),
            ],
          ),
        ),
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
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in tags)
            InputChip(
              label: Text(tag.name),
              labelStyle: TextStyle(
                fontSize: 15,
                color: resolveTagChipColors(tag.name, tag.colorIndex).foreground,
              ),
              backgroundColor:
                  resolveTagChipColors(tag.name, tag.colorIndex).background,
              deleteIconColor:
                  resolveTagChipColors(tag.name, tag.colorIndex).foreground,
              shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
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
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: level.uiValue == selected
                      ? const Color(0xFFF8FAFC)
                      : Colors.white,
                  border: Border.all(
                    color: level.uiValue == selected
                        ? const Color(0xFF111827)
                        : const Color(0xFFE5E7EB),
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: level.color,
                      child: Text(
                        '${level.uiValue}',
                        style: TextStyle(
                          color: level == ConditionLevel.normal
                              ? const Color(0xFF111827)
                              : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(level.label, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 「最近使ったタグ」+ グループ別のタグチップ一覧。
/// Composerのアコーディオンと全画面タグ選択の両方で使う。
class TagGroupList extends StatelessWidget {
  const TagGroupList({
    super.key,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentTags.isNotEmpty)
          _TagGroupSection(
            title: '最近使ったタグ',
            children: [
              for (final tag in recentTags)
                _buildChip(tag.id, tag.name, tag.colorIndex),
            ],
          ),
        for (final entry in byGroup.entries)
          _TagGroupSection(
            title: entry.key,
            children: [
              for (final tag in entry.value)
                _buildChip(tag.id, tag.name, tag.colorIndex),
            ],
          ),
      ],
    );
  }

  Widget _buildChip(String id, String name, int? colorIndex) {
    final colors = resolveTagChipColors(name, colorIndex);
    final selected = selectedIds.contains(id);
    return FilterChip(
      label: Text(name),
      labelStyle: TextStyle(fontSize: 15, color: colors.foreground),
      backgroundColor: colors.background,
      selectedColor: colors.background,
      showCheckmark: false,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? const Color(0xFF111827) : Colors.transparent,
        ),
      ),
      selected: selected,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: children),
        ],
      ),
    );
  }
}
