import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/core.dart';

/// 以底部弹出方式显示聊天面板
Future<void> showChatBottomSheet(BuildContext context, LobbyBloc bloc) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    // 让系统把键盘 viewInsets 传入 builder 的 MediaQuery
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        BlocProvider.value(value: bloc, child: const ChatBottomSheetMobile()),
  );
}

/// 移动端聊天底部弹出面板
class ChatBottomSheetMobile extends StatefulWidget {
  const ChatBottomSheetMobile({super.key});

  @override
  State<ChatBottomSheetMobile> createState() => _ChatBottomSheetMobileState();
}

class _ChatBottomSheetMobileState extends State<ChatBottomSheetMobile> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // 键盘弹出后滚动到底部（最新消息）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (messageDay == today) {
      return _timeFormat.format(timestamp);
    }
    return _dateTimeFormat.format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardHeight = mq.viewInsets.bottom;
    final screenHeight = mq.size.height;
    // 键盘弹出时，面板最大高度需减去键盘高度，保证输入框始终可见
    final maxHeight = (screenHeight * 0.7) - keyboardHeight;

    return Padding(
      // 将整个面板顶起，避免被键盘遮挡
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight.clamp(200.0, screenHeight * 0.85),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: BlocBuilder<LobbyBloc, LobbyState>(
          builder: (context, state) {
            final messages = state.messages.length > 50
                ? state.messages.sublist(state.messages.length - 50)
                : state.messages;

            return SafeArea(
              top: false,
              // 键盘已通过 Padding 处理，底部 SafeArea 不再重复添加
              bottom: keyboardHeight == 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(),
                  _buildHeader(context),
                  Flexible(child: _buildMessageList(context, messages)),
                  _buildInputBar(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 22,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          const Text(
            '大厅聊天',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close,
                size: 20,
                color: Colors.white.withValues(alpha: 0.54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, List<LobbyMessage> messages) {
    if (messages.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '暂无消息',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      reverse: true,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return _buildMessageItem(context, message);
      },
    );
  }

  Widget _buildMessageItem(BuildContext context, LobbyMessage message) {
    if (message.type == LobbyMessageType.broadcast) {
      return _buildBroadcastMessage(message);
    }

    final isSystem = message.type == LobbyMessageType.system;
    final nameColor = _getNameColor(message);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '[${_formatTime(message.timestamp)}] ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: '${message.displayName}: ',
              style: TextStyle(
                color: nameColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: message.content,
              style: TextStyle(
                color: isSystem
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastMessage(LobbyMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
        ),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign, color: Color(0xFFFBBF24), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${message.displayName}: ',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: message.content,
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, LobbyState state) {
    final isAnonymous = state.isAnonymous;
    final isCoolingDown = state.chatCooldownSeconds > 0;
    final isDisabled = isAnonymous || isCoolingDown;

    String hintText;
    if (isAnonymous) {
      hintText = '登录后即可参与聊天';
    } else if (isCoolingDown) {
      hintText = '${state.chatCooldownSeconds}秒后可发送';
    } else {
      hintText = '输入消息...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              readOnly: isAnonymous,
              enabled: !isCoolingDown,
              maxLength: 50,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                counterText: '',
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF38BDF8),
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
              onChanged: (_) {},
              onSubmitted: (_) => _submitMessage(context),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white70),
            onPressed: isDisabled ? null : () => _submitMessage(context),
          ),
        ],
      ),
    );
  }

  void _submitMessage(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<LobbyBloc>().add(LobbyChatSubmitted(text));
    _controller.clear();
  }
}

/// Returns the name color based on message type and anonymous status.
///
/// Exposed as a top-level function for property-based testing.
Color getMessageNameColor(LobbyMessage message) {
  switch (message.type) {
    case LobbyMessageType.system:
      return const Color(0xFFFFB74D); // 橙色
    case LobbyMessageType.broadcast:
      return const Color(0xFFFBBF24); // 黄色
    case LobbyMessageType.user:
      return message.isAnonymous
          ? const Color(0xFFB0BEC5) // 灰蓝色
          : const Color(0xFF81D4FA); // 浅蓝色
  }
}

/// Extension to keep the private method using the shared function.
extension on _ChatBottomSheetMobileState {
  Color _getNameColor(LobbyMessage message) => getMessageNameColor(message);
}
