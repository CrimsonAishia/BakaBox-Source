import 'package:flutter/material.dart';

/// 被踢出大厅时的全屏遮罩提示
///
/// 根据 [reason] 显示不同的文案和操作按钮：
/// - `duplicate_login`：账号在其他地方登录，提供"重新登录"按钮
/// - `device_conflict`：设备冲突，提供"知道了"按钮
/// - `admin_kick`：管理员踢出，显示原因，提供"知道了"按钮
class LobbyKickedOverlay extends StatelessWidget {
  final String reason;
  final String? message;
  final VoidCallback onDismiss;

  const LobbyKickedOverlay({
    super.key,
    required this.reason,
    this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark
          ? Colors.black.withValues(alpha: 0.85)
          : Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 56,
                color: _iconColor,
              ),
              const SizedBox(height: 16),
              Text(
                _title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _buttonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _buttonText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    switch (reason) {
      case 'duplicate_login':
        return Icons.devices_other;
      case 'device_conflict':
        return Icons.phonelink_erase;
      case 'admin_kick':
        return Icons.gavel;
      case 'pc_session_active':
        return Icons.computer;
      default:
        return Icons.error_outline;
    }
  }

  Color get _iconColor {
    switch (reason) {
      case 'duplicate_login':
        return const Color(0xFFF59E0B);
      case 'device_conflict':
        return const Color(0xFFF97316);
      case 'admin_kick':
        return const Color(0xFFEF4444);
      case 'pc_session_active':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String get _title {
    switch (reason) {
      case 'duplicate_login':
        return '账号已在其他地方登录';
      case 'device_conflict':
        return '设备连接冲突';
      case 'admin_kick':
        return '已被管理员踢出';
      case 'pc_session_active':
        return '电脑端已在线';
      default:
        return '连接已断开';
    }
  }

  String get _subtitle {
    switch (reason) {
      case 'duplicate_login':
        return '你的账号在另一个客户端登录，当前连接已被断开。';
      case 'device_conflict':
        return '该设备已有其他活跃连接，当前连接已被断开。';
      case 'admin_kick':
        if (message != null && message!.isNotEmpty) {
          return '原因：$message';
        }
        return '你已被管理员从大厅中移除。';
      case 'pc_session_active':
        return '当前账号已在电脑端登录大厅，手机端暂时无法接入。';
      default:
        return message ?? '连接已被服务器断开。';
    }
  }

  String get _buttonText {
    switch (reason) {
      case 'duplicate_login':
        return '重新登录';
      default:
        return '知道了';
    }
  }

  Color get _buttonColor {
    switch (reason) {
      case 'duplicate_login':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF64748B);
    }
  }
}
