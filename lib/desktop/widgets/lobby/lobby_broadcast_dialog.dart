import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/constants/app_colors.dart';

/// 全服广播发送弹窗
class LobbyBroadcastDialog extends StatefulWidget {
  /// 紧凑模式：适配小容器（如浮动聊天面板），卡片宽度自适应，内边距缩小
  final bool compact;

  const LobbyBroadcastDialog({super.key, this.compact = false});

  @override
  State<LobbyBroadcastDialog> createState() => _LobbyBroadcastDialogState();
}

class _LobbyBroadcastDialogState extends State<LobbyBroadcastDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const int _maxLength = 100;

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

  void _onSubmit() {
    final content = _controller.text.trim();
    if (content.isNotEmpty) {
      context.read<LobbyBloc>().add(LobbyBroadcastSubmitted(content));
    }
  }

  void _onCancel() {
    context.read<LobbyBloc>().add(const LobbyBroadcastDialogToggled());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 根据主题设置颜色
    final textColor = isDark ? Colors.white : AppColors.slate800;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : AppColors.slate500;
    final inputTextColor = isDark ? Colors.white : AppColors.slate800;
    final inputBackgroundColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.slate100;
    final inputBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.slate200;
    final inputHintTextColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.slate400;
    final inputCounterTextColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.slate400;

    return BlocBuilder<LobbyBloc, LobbyState>(
      buildWhen: (previous, current) =>
          previous.broadcastCooldownSeconds != current.broadcastCooldownSeconds,
      builder: (context, state) {
        final isInCooldown = state.broadcastCooldownSeconds > 0;
        final canSubmit = !isInCooldown && _controller.text.trim().isNotEmpty;

        return GestureDetector(
          onTap: _onCancel,
          child: Container(
            color: Colors.black54,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: widget.compact ? double.infinity : 400,
                  margin: widget.compact
                      ? const EdgeInsets.all(12)
                      : EdgeInsets.zero,
                  padding: EdgeInsets.all(widget.compact ? 16 : 24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(
                      widget.compact ? 14 : 20,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(widget.compact ? 7 : 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.indigo500, AppColors.violet500],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.campaign,
                              color: Colors.white,
                              size: widget.compact ? 18 : 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '全服广播',
                            style: TextStyle(
                              fontSize: widget.compact ? 15 : 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isInCooldown
                            ? '冷却中，请 ${state.broadcastCooldownSeconds} 秒后再试'
                            : '发送的消息将广播给房间内所有在线玩家',
                        style: TextStyle(
                          fontSize: 12,
                          color: isInCooldown
                              ? AppColors.red500
                              : secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 输入框
                      Container(
                        decoration: BoxDecoration(
                          color: inputBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: inputBorderColor),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLength: _maxLength,
                          maxLines: 8,
                          enabled: !isInCooldown,
                          style: TextStyle(
                            color: inputTextColor,
                            fontSize: widget.compact ? 13 : 15,
                          ),
                          decoration: InputDecoration(
                            hintText: isInCooldown ? '冷却中...' : '输入广播内容...',
                            hintStyle: TextStyle(color: inputHintTextColor),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(
                              widget.compact ? 12 : 16,
                            ),
                            counterStyle: TextStyle(
                              color: inputCounterTextColor,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _onSubmit(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _onCancel,
                            style: TextButton.styleFrom(
                              foregroundColor: secondaryTextColor,
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.compact ? 12 : 20,
                                vertical: widget.compact ? 8 : 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: canSubmit ? _onSubmit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.indigo500,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : AppColors.slate200,
                              disabledForegroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : AppColors.slate400,
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.compact ? 16 : 24,
                                vertical: widget.compact ? 8 : 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              isInCooldown
                                  ? '${state.broadcastCooldownSeconds}s 后可发送'
                                  : '发送广播',
                              style: TextStyle(
                                fontSize: widget.compact ? 12 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
