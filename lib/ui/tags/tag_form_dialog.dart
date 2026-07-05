import 'package:flutter/material.dart';

import '../tag_colors.dart';

/// タグの新規作成・編集フォーム。呼び出し側が確定した (name, group, colorIndex) を受け取る。
class TagFormResult {
  const TagFormResult({
    required this.name,
    required this.group,
    required this.colorIndex,
  });

  final String name;
  final String group;

  /// チップ配色パレットのindex。null=タグ名ハッシュによる自動配色。
  final int? colorIndex;
}

Future<TagFormResult?> showTagFormDialog(
  BuildContext context, {
  required List<String> existingGroups,
  Set<String> existingNames = const {},
  String? initialName,
  String? initialGroup,
  int? initialColorIndex,
}) {
  return showDialog<TagFormResult>(
    context: context,
    builder: (context) => _TagFormDialog(
      existingGroups: existingGroups,
      existingNames: existingNames,
      initialName: initialName,
      initialGroup: initialGroup,
      initialColorIndex: initialColorIndex,
    ),
  );
}

class _TagFormDialog extends StatefulWidget {
  const _TagFormDialog({
    required this.existingGroups,
    required this.existingNames,
    this.initialName,
    this.initialGroup,
    this.initialColorIndex,
  });

  final List<String> existingGroups;

  /// 既存タグ名（編集時は自分自身を除く）。tags.nameのUNIQUE制約違反を
  /// 保存前に検出するために使う。アーカイブ済みタグは一覧上で折り畳まれて
  /// 見えないことがあるため、ここで弾かないと「保存したのに何も起きない」
  /// ように見える無言の失敗になる。
  final Set<String> existingNames;

  final String? initialName;
  final String? initialGroup;
  final int? initialColorIndex;

  @override
  State<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends State<_TagFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _groupController;
  int? _colorIndex;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _groupController = TextEditingController(text: widget.initialGroup ?? '');
    _colorIndex = widget.initialColorIndex;
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
        colorIndex: _colorIndex,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名前'),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return '名前を入力してください';
                if (widget.existingNames.contains(name)) {
                  return '同じ名前のタグが既に存在します（アーカイブ済みを含む）';
                }
                return null;
              },
              // 自動配色プレビューを名前の変化に追従させる。
              onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 20),
            const Text('色', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            _ColorSelector(
              selected: _colorIndex,
              previewName: _nameController.text.trim(),
              onSelect: (index) => setState(() => _colorIndex = index),
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

/// パレット7色 + 「自動」（タグ名ハッシュ）のスウォッチ列。
class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.selected,
    required this.previewName,
    required this.onSelect,
  });

  final int? selected;
  final String previewName;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final autoColors = tagChipColorsFor(previewName);

    Widget swatch({
      required int? index,
      required TagChipColors colors,
      String? label,
    }) {
      final isSelected = selected == index;
      return InkWell(
        key: ValueKey('color-swatch-${index ?? 'auto'}'),
        customBorder: const CircleBorder(),
        onTap: () => onSelect(index),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Center(
            child: label != null
                ? Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                    ))
                : Icon(Icons.circle, size: 14, color: colors.foreground),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 自動（タグ名ハッシュ）。プレビューとして現在の名前の自動配色を映す。
        swatch(index: null, colors: autoColors, label: '自動'),
        for (var i = 0; i < kTagChipPalettes.length; i++)
          swatch(index: i, colors: kTagChipPalettes[i]),
      ],
    );
  }
}
