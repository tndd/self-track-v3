import 'package:flutter/material.dart';

/// タグの新規作成・編集フォーム。呼び出し側が確定した (name, group) を受け取る。
class TagFormResult {
  const TagFormResult({required this.name, required this.group});

  final String name;
  final String group;
}

Future<TagFormResult?> showTagFormDialog(
  BuildContext context, {
  required List<String> existingGroups,
  String? initialName,
  String? initialGroup,
}) {
  return showDialog<TagFormResult>(
    context: context,
    builder: (context) => _TagFormDialog(
      existingGroups: existingGroups,
      initialName: initialName,
      initialGroup: initialGroup,
    ),
  );
}

class _TagFormDialog extends StatefulWidget {
  const _TagFormDialog({
    required this.existingGroups,
    this.initialName,
    this.initialGroup,
  });

  final List<String> existingGroups;
  final String? initialName;
  final String? initialGroup;

  @override
  State<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends State<_TagFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _groupController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _groupController = TextEditingController(text: widget.initialGroup ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      TagFormResult(
        name: _nameController.text.trim(),
        group: _groupController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialName != null;
    return AlertDialog(
      title: Text(isEditing ? 'タグを編集' : 'タグを追加'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名前'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '名前を入力してください' : null,
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.initialGroup ?? ''),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return widget.existingGroups;
                }
                return widget.existingGroups.where(
                  (group) => group.contains(textEditingValue.text),
                );
              },
              onSelected: (selection) => _groupController.text = selection,
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                // Autocomplete内部のcontrollerと同期させ、送信時に最新値を読めるようにする。
                controller.addListener(() => _groupController.text = controller.text);
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'グループ（例: 薬, サプリ, 症状）'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'グループを入力してください' : null,
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
