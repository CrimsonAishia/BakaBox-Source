import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../utils/log_service.dart';
import 'hover_info_block_embed.dart';
import 'hover_info_picker_panel.dart';
import 'toolbar_icon_button.dart';

/// 工具栏「插入引用」按钮
///
/// 点击弹出 5-tab 选择面板，选中后在光标处插入 hoverInfo 内联徽章。
class HoverInfoInsertButton extends StatelessWidget {
  final QuillController controller;

  const HoverInfoInsertButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ToolbarIconButton(
      icon: Icons.alternate_email_rounded,
      tooltip: '插入引用（地图/角色/枪模/刀模/符卡）',
      onTap: () => _handleInsert(context),
    );
  }

  Future<void> _handleInsert(BuildContext context) async {
    final data = await HoverInfoPickerPanel.show(context);
    if (data == null) return;

    try {
      final embed = HoverInfoBlockEmbed.create(
        type: data.type,
        id: data.id,
        label: data.label,
        iconUrl: data.iconUrl,
      );

      final index = controller.selection.baseOffset;
      final length = controller.selection.extentOffset - index;
      final docLength = controller.document.length;
      final safeIndex =
          (index < 0 || index > docLength) ? (docLength > 0 ? docLength - 1 : 0) : index;

      if (length > 0 && index >= 0) {
        controller.replaceText(safeIndex, length, embed, null);
      } else {
        controller.document.insert(safeIndex, embed);
      }
      controller.updateSelection(
        TextSelection.collapsed(offset: safeIndex + 1),
        ChangeSource.local,
      );
    } catch (e) {
      LogService.e('插入引用失败', e);
    }
  }
}
