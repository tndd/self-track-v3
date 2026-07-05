import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/database_providers.dart';
import '../section_chip.dart';
import '../tag_colors.dart';
import 'tag_form_dialog.dart';

/// タグ管理画面。
///
/// タグを一直線のリストではなく「グループごとのセクション」にまとめ、
/// 各タグは実効配色のチップ（ピル）として Wrap で並べる。
/// 区切りにはTrack/Calendarと共通のSectionChip（全幅の灰色タイトルバー）
/// を使い、画面間の世界観を統一する。
/// チップをタップするとボトムシートが開き、編集・アーカイブ操作を行う。
/// アーカイブ済みタグは最下部の折りたたみセクションに退避する。
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
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            children: [
              for (final group in groupNames)
                _GroupSection(
                  group: group,
                  tags: grouped[group]!,
                  onTagTap: (tag) => _showTagActions(context, ref, tag, allTags),
                ),
              if (archived.isNotEmpty)
                _ArchivedSection(
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

/// 1グループ分のセクション。Track/Calendarと共通のSectionChip
/// （全幅の灰色タイトルバー）で区切り、右端に件数を添える。
/// バーの下はタグチップのWrapのみを置き、チップの色が主役になるよう
/// 余計な装飾を足さない。
class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.tags,
    required this.onTagTap,
  });

  final String group;
  final List<Tag> tags;
  final void Function(Tag) onTagTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionChip(
            label: group,
            trailing: Text(
              '${tags.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // チップはバーと形が似るため、バーより一段内側に寄せて
          // 「バーの中身」として読めるようにする。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags) _TagChip(tag: tag, onTap: () => onTagTap(tag)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// アーカイブ済みタグの折りたたみセクション。SectionChipをそのまま
/// タップ可能にし（Trackの日付バーと同じ操作感）、シェブロンで開閉を示す。
class _ArchivedSection extends StatefulWidget {
  const _ArchivedSection({required this.tags, required this.onTagTap});

  final List<Tag> tags;
  final void Function(Tag) onTagTap;

  @override
  State<_ArchivedSection> createState() => _ArchivedSectionState();
}

class _ArchivedSectionState extends State<_ArchivedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _expanded = !_expanded),
            child: SectionChip(
              label: 'アーカイブ済み（${widget.tags.length}）',
              trailing: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
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
        ],
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
    // アーカイブ済みはフラット背景上でも判別できる濃さのグレーに落とす。
    final background = tag.isArchived ? const Color(0xFFE2E6ED) : colors.background;
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
