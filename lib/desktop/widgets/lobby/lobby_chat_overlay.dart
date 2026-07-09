import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/models/lobby_models.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/signed_network_image.dart';

/// 大厅聊天输入覆盖层
class LobbyChatOverlay extends StatefulWidget {
  final LobbyState state;
  final TextEditingController controller;
  final FocusNode focusNode;

  const LobbyChatOverlay({
    super.key,
    required this.state,
    required this.controller,
    required this.focusNode,
  });

  @override
  State<LobbyChatOverlay> createState() => _LobbyChatOverlayState();
}

class _LobbyChatOverlayState extends State<LobbyChatOverlay> {
  @override
  void initState() {
    super.initState();
  }

  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('MM-dd HH:mm');

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (messageDay == today) {
      return _timeFormat.format(timestamp);
    }
    return _dateTimeFormat.format(timestamp);
  }

  /// 从 state.users 与 state.allOnlineUsers 构建 userId → avatarUrl 索引。
  /// users 优先（在场景内的用户信息更新更及时），allOnlineUsers 兜底。
  Map<String, String> _buildAvatarLookup(LobbyState lobbyState) {
    final map = <String, String>{};
    // allOnlineUsers 先塞，被 users 覆盖
    for (final u in lobbyState.allOnlineUsers) {
      final url = u.avatarUrl;
      if (url != null && url.isNotEmpty) {
        map[u.userId] = url;
      }
    }
    for (final u in lobbyState.users) {
      final url = u.avatarUrl;
      if (url != null && url.isNotEmpty) {
        map[u.userId] = url;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final recentMessages = widget.state.messages.reversed
        .take(100)
        .toList(growable: false);
    final isChatActive = widget.state.isChatActive;
    // 预构建 userId → avatarUrl 查表，避免每条消息 build 时对
    // users + allOnlineUsers 双层线性扫描。父级重建时 O(N+M) 建一次，
    // item 内查表 O(1)。
    final avatarByUserId = _buildAvatarLookup(widget.state);

    return SizedBox(
      width: 360,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 360,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isChatActive
              ? Colors.black.withValues(
                  alpha: (widget.state.chatOpacity + 0.5).clamp(0.0, 0.95),
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isChatActive
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isChatActive ? '大厅聊天（Enter 发送 / Esc 退出）' : '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            // 聊天消息列表
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: isChatActive ? 300 : 150,
              child: ListView.separated(
                reverse: true,
                // 聊天激活时启用滚动，禁用时阻止滚动传递
                primary: isChatActive,
                physics: isChatActive
                    ? const BouncingScrollPhysics(
                        decelerationRate: ScrollDecelerationRate.fast,
                      )
                    : const NeverScrollableScrollPhysics(),
                itemCount: recentMessages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final message = recentMessages[index];
                  final isBroadcast =
                      message.type == LobbyMessageType.broadcast;
                  // 使用 messageId 作为 Key，确保 reverse 列表在新消息到达导致
                  // 索引整体后移时，Element 能追踪到正确的消息实例，避免
                  // AutomaticKeepAliveClientMixin 保留的 SelectableText 选区
                  // 被"拽"到错误的消息上。
                  final key = ValueKey(message.messageId);

                  // 广播消息特殊样式：黄色加粗内容
                  if (isBroadcast) {
                    return _BroadcastMessageWidget(
                      key: key,
                      message: message,
                      formatTime: _formatTime,
                    );
                  }

                  return _RegularMessageItem(
                    key: key,
                    message: message,
                    avatarUrl: avatarByUserId[message.userId],
                    formatTime: _formatTime,
                  );
                },
              ),
            ),
            if (isChatActive) ...[
              const SizedBox(height: 10),
              Stack(
                children: [
                  TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 50,
                    readOnly: widget.state.selfUser?.isAnonymous ?? false,
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      hintText: widget.state.selfUser?.isAnonymous ?? false
                          ? '登录后即可参与聊天'
                          : '输入消息',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.sky400,
                          width: 1.5,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    onSubmitted: (_) {},
                  ),
                ],
              ),
            ] else
              GestureDetector(
                onTap: () {
                  // 点击"按 Enter 开始聊天"时打开聊天
                  context.read<LobbyBloc>().add(
                    const LobbyChatModeChanged(true),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '按 Enter 开始聊天',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 广播消息特殊样式组件：黄色加粗内容 + 静态渐变底纹 (移除动画以避免历史消息内存/GPU泄漏)
class _BroadcastMessageWidget extends StatelessWidget {
  final LobbyMessage message;
  final String Function(DateTime) formatTime;

  const _BroadcastMessageWidget({
    super.key,
    required this.message,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
        ),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.campaign,
              color: AppColors.amber400,
              size: 16,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${message.displayName}: ',
                        style: const TextStyle(
                          color: AppColors.amber400, // 黄色
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: message.content,
                        style: const TextStyle(
                          color: AppColors.amber400, // 黄色
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegularMessageItem extends StatefulWidget {
  final LobbyMessage message;

  /// 预解析的头像 URL（父级从 users/allOnlineUsers 查表得到），
  /// 避免 item 内做 O(users) 线性扫描。传 null 或空串走 fallback。
  final String? avatarUrl;
  final String Function(DateTime) formatTime;

  const _RegularMessageItem({
    super.key,
    required this.message,
    required this.avatarUrl,
    required this.formatTime,
  });

  @override
  State<_RegularMessageItem> createState() => _RegularMessageItemState();
}

class _RegularMessageItemState extends State<_RegularMessageItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final message = widget.message;
    final isSystem = message.type == LobbyMessageType.system;
    final isAnonymous = message.isAnonymous;
    final isSelf = message.isSelf;

    // 名字与头像边框色
    final nameColor = isSystem
        ? const Color(0xFFFFB74D) // Amber
        : (isSelf
            ? const Color(0xFF1D9BF0) // 主题蓝 (lobbyBlue)
            : (isAnonymous
                ? const Color(0xFF9CA3AF) // 匿名者用偏暗的灰色
                : const Color(0xFFE2E8F0))); // 其他用户用明亮的银灰色

    final initial = message.displayName.isNotEmpty
        ? message.displayName.substring(0, 1).toUpperCase()
        : '?';

    // 匿名/系统消息不显示头像；否则用父级 O(1) 查表得到的 URL。
    final String? avatarUrl = (isSystem || isAnonymous)
        ? null
        : widget.avatarUrl;

    final fallbackText = Text(
      isSystem ? '!' : initial,
      style: TextStyle(
        color: nameColor,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );

    final avatarWidget = Container(
      margin: isSelf
          ? const EdgeInsets.only(top: 2, left: 10)
          : const EdgeInsets.only(top: 2, right: 10),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            nameColor.withValues(alpha: 0.25),
            nameColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: nameColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? SignedNetworkImage(
              url: avatarUrl,
              cacheWidth: 52,
              cacheHeight: 52,
              fallback: fallbackText,
            )
          : fallbackText,
    );

    final textWidget = Expanded(
      child: Column(
        crossAxisAlignment:
            isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isSelf) ...[
                Text(
                  widget.formatTime(message.timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else ...[
                Flexible(
                  child: Text(
                    message.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.formatTime(message.timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isSystem) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFFFB74D)
                            .withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: const Text(
                      'SYSTEM',
                      style: TextStyle(
                        color: Color(0xFFFFB74D),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelf
                    ? [
                        const Color(0xFF1D9BF0).withValues(alpha: 0.25),
                        const Color(0xFF1D9BF0).withValues(alpha: 0.08),
                      ]
                    : (isSystem
                        ? [
                            const Color(0xFFFFB74D).withValues(alpha: 0.15),
                            const Color(0xFFFFB74D).withValues(alpha: 0.05),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.02),
                          ]),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: isSelf
                    ? const Color(0xFF1D9BF0).withValues(alpha: 0.3)
                    : (isSystem
                        ? const Color(0xFFFFB74D).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.08)),
                width: 0.5,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isSelf ? 12 : 4),
                topRight: Radius.circular(isSelf ? 4 : 12),
                bottomLeft: const Radius.circular(12),
                bottomRight: const Radius.circular(12),
              ),
            ),
            child: SelectableText(
              message.content,
              textAlign: TextAlign.left, // 气泡内统一左对齐更易读
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isSelf
            ? [textWidget, avatarWidget]
            : [avatarWidget, textWidget],
      ),
    );
  }
}
