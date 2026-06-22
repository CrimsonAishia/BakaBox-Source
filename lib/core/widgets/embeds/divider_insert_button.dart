import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'divider_embed_builder.dart';
import 'toolbar_icon_button.dart';

/// 工具栏「插入分割线」按钮
///
/// 在光标处插入水平分割线 BlockEmbed（占据独立行）。
class DividerInsertButton extends StatelessWidget {
  final QuillController controller;

  const DividerInsertButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ToolbarIconButton(
      icon: Icons.horizontal_rule_rounded,
      tooltip: '插入分割线',
      onTap: () => _insert(context),
    );
  }

  void _insert(BuildContext context) {
    final selection = controller.selection;
    if (!selection.isValid) return;

    final index = selection.baseOffset;
    final length = selection.extentOffset - index;
    final docLength = controller.document.length;
    final safeIndex = (index < 0 || index > docLength)
        ? (docLength > 0 ? docLength - 1 : 0)
        : index;

    const embed = DividerBlockEmbed();

    if (length > 0 && index >= 0) {
      controller.replaceText(safeIndex, length, embed, null);
    } else {
      controller.document.insert(safeIndex, embed);
    }
    // 分割线后插入一个换行，让光标落到下一行，方便继续编辑
    controller.document.insert(safeIndex + 1, '\n');
    controller.updateSelection(
      TextSelection.collapsed(offset: safeIndex + 2),
      ChangeSource.local,
    );
  }
}
