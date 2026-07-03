import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/database_providers.dart';
import '../tag_colors.dart';
import 'tag_form_dialog.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  Future<void> _addTag(BuildContext context, WidgetRef ref, List<Tag> allTags) async {
    final groups = allTags.map((t) => t.group).toSet().toList()..sort();
    final result = await showTagFormDialog(context, existingGroups: groups);
    if (result == null) return;
    if (!context.mounted) return;
    await _saveTag(
      context,
      () => ref.read(tagsDaoProvider).createTag(
            name: result.name,
            group: result.group,
            colorIndex: result.colorIndex,
          ),
    );
  }

  Future<void> _editTag(BuildContext context, WidgetRef ref, Tag tag, List<Tag> allTags) async {
    final groups = allTags.map((t) => t.group).toSet().toList()..sort();
    final result = await showTagFormDialog(
      context,
      existingGroups: groups,
      initialName: tag.name,
      initialGroup: tag.group,
      initialColorIndex: tag.colorIndex,
    );
    if (result == null) return;
    if (!context.mounted) return;
    await _saveTag(
      context,
      () => ref.read(tagsDaoProvider).updateTag(
            id: tag.id,
            name: result.name,
            group: result.group,
            colorIndex: result.colorIndex,
          ),
    );
  }

  /// `name`はtables.dartでUNIQUE制約が付いており（アーカイブ済みタグとの重複も
  /// 含む）、フォームの空チェックだけでは弾けない。未処理のままだとダイアログは
  /// 既に閉じているため、例外が飛んでも「保存されたように見えて何も起きない」
  /// 状態になっていた。
  Future<void> _saveTag(BuildContext context, Future<void> Function() save) async {
    try {
      await save();
    } catch (e) {
      if (!context.mounted) return;
      final message = e.toString().contains('UNIQUE')
          ? 'その名前のタグは既に存在します。'
          : 'タグの保存に失敗しました。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          final active = allTags.where((t) => !t.isArchived).toList();
          final archived = allTags.where((t) => t.isArchived).toList();

          if (allTags.isEmpty) {
            return const Center(child: Text('タグがまだありません。右下の + から追加できます。'));
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final tag in active)
                _TagTile(
                  tag: tag,
                  onEdit: () => _editTag(context, ref, tag, allTags),
                  onToggleArchive: () => ref.read(tagsDaoProvider).archiveTag(tag.id),
                  archiveActionLabel: 'アーカイブ',
                ),
              if (archived.isNotEmpty)
                ExpansionTile(
                  title: Text('アーカイブ済み（${archived.length}）'),
                  children: [
                    for (final tag in archived)
                      _TagTile(
                        tag: tag,
                        onEdit: () => _editTag(context, ref, tag, allTags),
                        onToggleArchive: () =>
                            ref.read(tagsDaoProvider).unarchiveTag(tag.id),
                        archiveActionLabel: 'アーカイブ解除',
                      ),
                  ],
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

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.tag,
    required this.onEdit,
    required this.onToggleArchive,
    required this.archiveActionLabel,
  });

  final Tag tag;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;
  final String archiveActionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = resolveTagChipColors(tag.name, tag.colorIndex);
    return ListTile(
      // 実効配色（保存色 or タグ名ハッシュ）のプレビュー。
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colors.background,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Icon(Icons.sell_outlined, size: 16, color: colors.foreground),
        ),
      ),
      title: Text(
        tag.name,
        style: TextStyle(
          color: tag.isArchived ? Theme.of(context).disabledColor : null,
        ),
      ),
      subtitle: Text(tag.group),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '編集',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: archiveActionLabel,
            icon: Icon(tag.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
            onPressed: onToggleArchive,
          ),
        ],
      ),
    );
  }
}
