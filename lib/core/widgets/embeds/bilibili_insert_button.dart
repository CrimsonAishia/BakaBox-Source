import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../services/bilibili_service.dart';
import '../../utils/toast_utils.dart';
import '../guide/guide_tokens.dart';
import 'bilibili_embed_builder.dart';
import 'toolbar_icon_button.dart';

/// B 站视频插入工具栏按钮
///
/// 点击弹出 URL 输入对话框 → 解析 BV 号 → 调 `BilibiliService.fetchMeta`
/// → 在 Quill 文档当前光标位置插入 `BilibiliBlockEmbed`。
/// 解析失败时保留链接为可点击文本 + Toast 提示。
class BilibiliInsertButton extends StatelessWidget {
  /// Quill 编辑器 Controller，用于在文档中插入 embed
  final QuillController controller;

  const BilibiliInsertButton({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ToolbarIconButton(
      icon: Icons.play_circle_outline,
      tooltip: '插入 B 站视频',
      onTap: () => _showInsertDialog(context),
    );
  }

  void _showInsertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _BilibiliUrlInputDialog(
        onConfirm: (url) => _handleInsert(context, url),
      ),
    );
  }

  Future<void> _handleInsert(BuildContext context, String url) async {
    if (url.trim().isEmpty) return;

    // 先检查 BV 号是否可提取
    final bvid = BilibiliService.extractBvid(url);
    if (bvid == null) {
      if (context.mounted) {
        ToastUtils.showError(context, '无法识别 B 站视频链接');
        _insertFallbackLink(url);
      }
      return;
    }

    // 调用 fetchMeta 获取视频元数据
    final meta = await BilibiliService.fetchMeta(url);

    if (meta == null) {
      // 解析失败：保留链接为可点击文本 + Toast
      if (context.mounted) {
        ToastUtils.showWarning(context, '获取视频信息失败，已插入链接');
      }
      _insertFallbackLink(url);
      return;
    }

    // 成功：插入 BilibiliBlockEmbed
    final embed = BilibiliBlockEmbed.fromVideoEmbed(meta);
    final index = controller.selection.baseOffset;
    final length = controller.selection.extentOffset - index;

    // 如果有选中文本，先删除
    if (length > 0) {
      controller.replaceText(index, length, embed, null);
    } else {
      controller.document.insert(index, embed);
      controller.updateSelection(
        TextSelection.collapsed(offset: index + 1),
        ChangeSource.local,
      );
    }
  }

  /// 解析失败时以纯文本链接形式插入
  void _insertFallbackLink(String url) {
    final index = controller.selection.baseOffset;
    final length = controller.selection.extentOffset - index;

    final linkText = url.length > 60 ? '${url.substring(0, 57)}...' : url;

    if (length > 0) {
      controller.replaceText(index, length, linkText, null);
    } else {
      controller.document.insert(index, linkText);
    }

    // 应用链接样式
    controller.formatText(index, linkText.length, LinkAttribute(url));
    controller.updateSelection(
      TextSelection.collapsed(offset: index + linkText.length),
      ChangeSource.local,
    );
  }
}

/// B 站 URL 输入对话框
class _BilibiliUrlInputDialog extends StatefulWidget {
  final Future<void> Function(String url) onConfirm;

  const _BilibiliUrlInputDialog({required this.onConfirm});

  @override
  State<_BilibiliUrlInputDialog> createState() =>
      _BilibiliUrlInputDialogState();
}

class _BilibiliUrlInputDialogState extends State<_BilibiliUrlInputDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入视频链接');
      return;
    }

    // 基础校验：是否含 bilibili 或 BV 号
    final hasBilibili = url.contains('bilibili.com') ||
        url.contains('b23.tv') ||
        url.startsWith('BV');
    if (!hasBilibili) {
      setState(() => _error = '请输入有效的 B 站视频链接');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (mounted) {
      Navigator.of(context).pop();
    }

    await widget.onConfirm(url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? GuideTokens.dialogBgDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: GuideTokens.bilibiliPink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 18,
                    color: GuideTokens.bilibiliPink,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '插入 B 站视频',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : GuideTokens.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 输入框
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '粘贴 B 站视频链接，例如 https://www.bilibili.com/video/BV...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color:
                      isDark ? GuideTokens.textSecondaryLight : GuideTokens.textTertiaryLight,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : GuideTokens.bilibiliFallbackLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : GuideTokens.bilibiliInputBorderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : GuideTokens.bilibiliInputBorderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: GuideTokens.bilibiliPink,
                    width: 1.5,
                  ),
                ),
                errorText: _error,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : GuideTokens.textPrimaryLight,
              ),
              onSubmitted: (_) => _handleConfirm(),
            ),
            const SizedBox(height: 8),
            // 提示文字
            Text(
              '支持 bilibili.com/video/BV... 或 b23.tv 短链',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? GuideTokens.textSecondaryLight : GuideTokens.textTertiaryLight,
              ),
            ),
            const SizedBox(height: 20),
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark
                          ? GuideTokens.textTertiaryDark
                          : GuideTokens.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: GuideTokens.bilibiliPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('确认插入'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
