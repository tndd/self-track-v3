import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/database_providers.dart';
import '../tag_colors.dart';
import 'tag_form_dialog.dart';

/// タグ管理画面。
///
/// タグを一直線のリストではなく「グループごとのカード」にまとめ、
/// 各タグは実効配色のチップ（ピル）として Wrap で並べる。
/// チップをタップするとボトムシートが開き、編集・アーカイブ操作を行う。
/// アーカイブ済みタグは最下部の折りたたみカードに退避する。
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  Future<void> _addTag(BuildContext context, WidgetRef ref, List<Tag> allTags) async {
    final groups = allTags.map((t) => t.group).toSet().toList()..sort();
    final result = await showTagFormDialog(
      context,
      existingGroups: groups,
      existingNames: allTags.map((t) => t.name).toSet(),
    );
    if (result == null) return;
    try {
      await ref.read(tagsDaoProvider).createTag(
            name: result.name,
            group: result.group,
            colorIndex: result.colorIndex,
          );
    } catch (_) {
      // フォームで重複チェック済みだが、ダイアログ表示中の並行変更等で
      // UNIQUE制約違反になった場合の保険。無言で失敗させない。
      if (context.mounted) _showSaveFailed(context);
    }
  }

  Future<void> _editTag(BuildContext context, WidgetRef ref, Tag tag, List<Tag> allTags) async {
    final groups = allTags.map((t) => t.group).toSet().toList()..sort();
    final result = await showTagFormDialog(
      context,
      existingGroups: groups,
      // 自分自身の名前は変更なし保存を許すため除外する。
      existingNames: allTags
          .where((t) => t.id != tag.id)
          .map((t) => t.name)
          .toSet(),
      initialName: tag.name,
      initialGroup: tag.group,
      initialColorIndex: tag.colorIndex,
    );
    if (result == null) return;
    try {
      await ref.read(tagsDaoProvider).updateTag(
            id: tag.id,
            name: result.name,
            group: result.group,
            colorIndex: result.colorIndex,
          );
    } catch (_) {
      if (context.mounted) _showSaveFailed(context);
    }
  }

  void _showSaveFailed(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('タグを保存できませんでした。同じ名前のタグが既に存在する可能性があります。')),
    );
  }

  /// チップタップ時のアクションシート。編集 / アーカイブ切替を選ばせる。
  Future<void> _showTagActions(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
    List<Tag> allTags,
  ) async {
    final colors = resolveTagChipColors(tag.name, tag.colorIndex);
    final action = await showModalBottomSheet<_TagAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // シートの掴みハンドル。
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // タグのプレビュー（チップ + グループ名）。
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(
                        color: colors.foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tag.group,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, indent: 24, endIndent: 24),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('編集'),
              onTap: () => Navigator.of(sheetContext).pop(_TagAction.edit),
            ),
            ListTile(
              leading: Icon(
                tag.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              title: Text(tag.isArchived ? 'アーカイブ解除' : 'アーカイブ'),
              onTap: () => Navigator.of(sheetContext).pop(_TagAction.toggleArchive),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TagAction.edit:
        await _editTag(context, ref, tag, allTags);
      case _TagAction.toggleArchive:
        final dao = ref.read(tagsDaoProvider);
        if (tag.isArchived) {
          await dao.unarchiveTag(tag.id);
        } else {
          await dao.archiveTag(tag.id);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      body: allTagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('読み込みエラー: $error')),
        data: (allTags) {
          if (allTags.isEmpty) {
            return const _EmptyState();
          }

          final active = allTags.where((t) => !t.isArchived).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          final archived = allTags.where((t) => t.isArchived).toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          // アクティブなタグをグループ名でまとめる（グループ名昇順）。
          final grouped = <String, List<Tag>>{};
          for (final tag in active) {
            grouped.putIfAbsent(tag.group, () => []).add(tag);
          }
          final groupNames = grouped.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              for (final group in groupNames)
                _GroupCard(
                  group: group,
                  tags: grouped[group]!,
                  onTagTap: (tag) => _showTagActions(context, ref, tag, allTags),
                ),
              if (archived.isNotEmpty)
                _ArchivedCard(
                  tags: archived,
                  onTagTap: (tag) => _showTagActions(context, ref, tag, allTags),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTag(context, ref, allTagsAsync.value ?? const []),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ボトムシートで選択されるタグ操作の種類。
enum _TagAction { edit, toggleArchive }

/// タグが1件もないときの空状態表示。
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.sell_outlined, size: 34, color: Color(0xFF3446A8)),
          ),
          const SizedBox(height: 16),
          const Text(
            'タグがまだありません。右下の + から追加できます。',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

/// 1グループ分のカード。ヘッダ（グループ名 + 件数バッジ）と
/// タグチップの Wrap を白カードにまとめる。
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.tags,
    required this.onTagTap,
  });

  final String group;
  final List<Tag> tags;
  final void Function(Tag) onTagTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EDF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _CountBadge(count: tags.length),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in tags) _TagChip(tag: tag, onTap: () => onTagTap(tag))],
          ),
        ],
      ),
    );
  }
}

/// アーカイブ済みタグの折りたたみカード。既定では閉じており、
/// ヘッダタップで灰色チップの一覧を開閉する。
class _ArchivedCard extends StatefulWidget {
  const _ArchivedCard({required this.tags, required this.onTagTap});

  final List<Tag> tags;
  final void Function(Tag) onTagTap;

  @override
  State<_ArchivedCard> createState() => _ArchivedCardState();
}

class _ArchivedCardState extends State<_ArchivedCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'アーカイブ済み（${widget.tags.length}）',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in widget.tags)
                    _TagChip(tag: tag, onTap: () => widget.onTagTap(tag)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// グループ内のタグ件数を示す小さなバッジ。
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

/// タグ1件を表すチップ（ピル）。実効配色（保存色 or タグ名ハッシュ）で
/// 塗り、アーカイブ済みは灰色トーンに落とす。タップで操作シートを開く。
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.onTap});

  final Tag tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = resolveTagChipColors(tag.name, tag.colorIndex);
    final background = tag.isArchived ? const Color(0xFFE7EAF0) : colors.background;
    final foreground = tag.isArchived ? const Color(0xFF94A3B8) : colors.foreground;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: foreground),
              const SizedBox(width: 7),
              Text(
                tag.name,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
