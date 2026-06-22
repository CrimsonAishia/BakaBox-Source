import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/core.dart';

/// 移动端广播发送对话框
///
/// 参考桌面端风格，支持多行输入、冷却状态显示。
class BroadcastDialogMobile extends StatefulWidget {
  const BroadcastDialogMobile({super.key});

  @override
  State<BroadcastDialogMobile> createState() => _BroadcastDialogMobileState();
}

class _BroadcastDialogMobileState extends State<BroadcastDialogMobile> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  static const int _maxLength = 50;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<LobbyBloc>().add(LobbyBroadcastSubmitted(text));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark ? Colors.white : AppColors.slate800;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : AppColors.slate500;
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.slate100;
    final inputBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.slate200;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.slate400;

    return BlocBuilder<LobbyBloc, LobbyState>(
      buildWhen: (previous, current) =>
          previous.broadcastCooldownSeconds != current.broadcastCooldownSeconds,
      builder: (context, state) {
        final isInCooldown = state.broadcastCooldownSeconds > 0;
        final canSubmit = !isInCooldown && _controller.text.trim().isNotEmpty;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.indigo500, AppColors.violet500],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.campaign,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '全服广播',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 副标题
                Text(
                  isInCooldown
                      ? '冷却中，请 ${state.broadcastCooldownSeconds} 秒后再试'
                      : '发送的消息将广播给房间内所有在线玩家',
                  style: TextStyle(
                    fontSize: 13,
                    color: isInCooldown ? AppColors.red500 : secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                // 输入框
                Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: inputBorder),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLength: _maxLength,
                    maxLines: 3,
                    minLines: 2,
                    enabled: !isInCooldown,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: isInCooldown ? '冷却中...' : '输入广播内容...',
                      hintStyle: TextStyle(color: hintColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      counterStyle: TextStyle(color: hintColor, fontSize: 11),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 16),
                // 按钮行
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryTextColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: canSubmit ? _handleSubmit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.indigo500,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.slate200,
                        disabledForegroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : AppColors.slate400,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isInCooldown
                            ? '${state.broadcastCooldownSeconds}s 后可发送'
                            : '发送广播',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
