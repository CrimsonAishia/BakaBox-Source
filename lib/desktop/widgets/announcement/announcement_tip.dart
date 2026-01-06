import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/core.dart';
import 'announcement_dialog.dart';

/// 新公告提示组件
/// 
/// 当有未读公告时，延迟显示提示框
class AnnouncementTip extends StatefulWidget {
  const AnnouncementTip({super.key});

  @override
  State<AnnouncementTip> createState() => _AnnouncementTipState();
}

class _AnnouncementTipState extends State<AnnouncementTip> {
  bool _showTip = false;
  bool _tipDismissed = false;
  Timer? _showTimer;
  int _lastUnreadCount = 0;
  bool _initialized = false;

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  void _scheduleTip(int unreadCount) {
    // 取消之前的定时器
    _showTimer?.cancel();
    
    // 如果已经手动关闭过，不再显示
    if (_tipDismissed) return;
    
    // 如果没有未读公告，不显示
    if (unreadCount == 0) {
      if (_showTip) {
        setState(() => _showTip = false);
      }
      return;
    }
    
    // 延迟 5 秒后显示提示（与旧项目一致）
    _showTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_tipDismissed && unreadCount > 0) {
        setState(() => _showTip = true);
      }
    });
  }

  void _dismissTip() {
    setState(() {
      _showTip = false;
      _tipDismissed = true;
    });
  }

  void _openAnnouncements() {
    _dismissTip();
    AnnouncementDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BlocListener<AnnouncementBloc, AnnouncementState>(
      listenWhen: (previous, current) => 
          previous.unreadCount != current.unreadCount ||
          previous.isLoading != current.isLoading,
      listener: (context, state) {
        // 初始化：当首次加载完成且有未读公告时，触发提示
        if (!_initialized && !state.isLoading && state.unreadCount > 0) {
          _initialized = true;
          _lastUnreadCount = state.unreadCount;
          _scheduleTip(state.unreadCount);
          return;
        }
        
        // 当未读数量从 0 变为有值时，重置 dismissed 状态
        if (_lastUnreadCount == 0 && state.unreadCount > 0) {
          _tipDismissed = false;
        }
        _lastUnreadCount = state.unreadCount;
        _scheduleTip(state.unreadCount);
      },
      child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          if (!_showTip || state.unreadCount == 0) {
            return const SizedBox.shrink();
          }
          
          // 居右显示
          return Positioned(
            top: 56,
            right: 12,
            child: _buildTipCard(isDark, state.unreadCount),
          );
        },
      ),
    );
  }


  Widget _buildTipCard(bool isDark, int unreadCount) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1E293B)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9800).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: _openAnnouncements,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    // 图标
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.campaign,
                        color: Color(0xFFFF9800),
                        size: 22,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 800.ms,
                    ),
                    const SizedBox(width: 12),
                    // 文字内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '新公告通知',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark 
                                    ? Colors.white70 
                                    : const Color(0xFF6B7280),
                              ),
                              children: [
                                const TextSpan(text: '您有 '),
                                TextSpan(
                                  text: '$unreadCount',
                                  style: const TextStyle(
                                    color: Color(0xFFFF9800),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(text: ' 条未读公告'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _dismissTip,
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                      ),
                      splashRadius: 16,
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
            ),
      )
      .animate()
      .fadeIn(duration: 300.ms)
      .slideY(begin: -0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
    );
  }
}
