import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndDeleteAll(BuildContext context, WidgetRef ref) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データを全て削除しますか？'),
        content: const Text('体調記録・タグを含む全てのデータが削除されます。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('次へ'),
          ),
        ],
      ),
    );
    if (firstConfirm != true) return;
    if (!context.mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本当によろしいですか？'),
        content: const Text('もう一度確認します。全データの削除を実行すると元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('全て削除する'),
          ),
        ],
      ),
    );
    if (secondConfirm != true) return;

    await ref.read(appDatabaseProvider).deleteAllData();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('全てのデータを削除しました。')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
          title: const Text('データを全て削除'),
          subtitle: const Text('体調記録・タグを含む全てのデータを端末から削除します。'),
          onTap: () => _confirmAndDeleteAll(context, ref),
        ),
      ],
    );
  }
}
