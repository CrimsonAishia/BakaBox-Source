import 'package:flutter/material.dart';

import '../../core/services/app_permission_service.dart';
import '../../core/constants/app_colors.dart';

/// 应用权限引导弹窗
///
/// 应用启动时弹出，引导用户授予：
/// 1. 通知权限（接收广播消息）
/// 2. 电池优化白名单（防止被系统杀死）
class AppPermissionDialog extends StatefulWidget {
  /// [forceRequired] 为 true 时不显示跳过按钮，必须完成所有权限步骤
  const AppPermissionDialog({super.key, this.forceRequired = false});

  final bool forceRequired;

  /// 显示权限引导弹窗，返回用户是否完成了引导
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AppPermissionDialog(),
    );
    return result ?? false;
  }

  /// 在启动时强制显示权限引导弹窗（不可跳过）
  static Future<void> showOnStartup(BuildContext context) async {
    final shouldShow = await AppPermissionService.shouldShowPermissionGuide();
    if (!shouldShow) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AppPermissionDialog(forceRequired: true),
    );
  }

  @override
  State<AppPermissionDialog> createState() => _AppPermissionDialogState();
}

class _AppPermissionDialogState extends State<AppPermissionDialog> {
  bool _notificationGranted = false;
  bool _batteryGranted = false;
  bool _requesting = false;
  bool _finishing = false;
  int _currentStep = 0; // 0=通知, 1=电池

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final status = await AppPermissionService.checkPermissionStatus();
    if (!mounted) return;
    setState(() {
      _notificationGranted = status.notificationGranted;
      _batteryGranted = status.batteryOptimizationIgnored;
      if (_notificationGranted && _batteryGranted) {
        _currentStep = 2;
      } else if (_notificationGranted) {
        _currentStep = 1;
      } else {
        _currentStep = 0;
      }
    });
    // 所有权限都已授权，自动完成
    if (status.allGranted) {
      await _finish();
    }
  }

  Future<void> _requestNotification() async {
    setState(() => _requesting = true);
    final granted = await AppPermissionService.requestNotificationPermission();
    if (!mounted) return;
    setState(() {
      _notificationGranted = granted;
      _requesting = false;
      // 推进到下一步
      if (_currentStep == 0) {
        // 如果电池权限已经授权，直接跳到完成
        _currentStep = _batteryGranted ? 2 : 1;
      }
    });
    // 如果两个权限都已授权且非强制模式，自动完成
    if (_notificationGranted && _batteryGranted && !widget.forceRequired) {
      await _finish();
    }
  }

  Future<void> _requestBattery() async {
    setState(() => _requesting = true);
    final granted =
        await AppPermissionService.requestIgnoreBatteryOptimization();
    if (!mounted) return;
    setState(() {
      _batteryGranted = granted;
      _requesting = false;
      _currentStep = 2;
    });
    // 强制模式下等用户点"进入应用"；非强制模式自动完成
    if (!widget.forceRequired) {
      await _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await AppPermissionService.markPermissionsAsked();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2030) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final subtitleColor = isDark ? Colors.white70 : AppColors.gray500;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 48,
              color: AppColors.indigo500,
            ),
            const SizedBox(height: 12),
            Text(
              '应用权限设置',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.forceRequired
                  ? '以下权限为应用正常运行所必需，请逐项授权后继续'
                  : '为了保证应用功能正常运行，需要以下权限',
              style: TextStyle(fontSize: 13, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPermissionItem(
              icon: Icons.notifications_active_outlined,
              title: '通知权限',
              description: '接收广播消息和系统通知',
              granted: _notificationGranted,
              isActive: _currentStep == 0,
              onRequest: _currentStep == 0 && !_requesting
                  ? _requestNotification
                  : null,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              icon: Icons.battery_saver_outlined,
              title: '电池优化白名单',
              description: '防止系统在后台关闭应用，保持连接稳定',
              granted: _batteryGranted,
              isActive: _currentStep == 1,
              onRequest: _currentStep == 1 && !_requesting
                  ? _requestBattery
                  : null,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            if (_currentStep >= 2)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requesting ? null : _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('进入应用'),
                ),
              )
            else
              Row(
                children: [
                  if (!widget.forceRequired) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: _requesting ? null : _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: subtitleColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('跳过'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: widget.forceRequired ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _requesting
                          ? null
                          : () {
                              if (_currentStep == 0) {
                                _requestNotification();
                              } else if (_currentStep == 1) {
                                _requestBattery();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.indigo500,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.slate200,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _requesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('授权'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required bool isActive,
    required VoidCallback? onRequest,
    required bool isDark,
  }) {
    const activeColor = AppColors.indigo500;
    const grantedColor = AppColors.emerald500;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : AppColors.gray300;

    final Color borderColor;
    final Color iconColor;
    final Color titleColor;

    if (granted) {
      borderColor = grantedColor.withValues(alpha: 0.3);
      iconColor = grantedColor;
      titleColor = isDark ? Colors.white : AppColors.gray800;
    } else if (isActive) {
      borderColor = activeColor.withValues(alpha: 0.5);
      iconColor = activeColor;
      titleColor = isDark ? Colors.white : AppColors.gray800;
    } else {
      borderColor = inactiveColor;
      iconColor = inactiveColor;
      titleColor = isDark
          ? Colors.white.withValues(alpha: 0.4)
          : AppColors.gray400;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        color: granted
            ? grantedColor.withValues(alpha: 0.05)
            : isActive
            ? activeColor.withValues(alpha: 0.05)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (granted ? grantedColor : iconColor).withValues(
                alpha: 0.1,
              ),
            ),
            child: Icon(
              granted ? Icons.check_rounded : icon,
              size: 22,
              color: granted ? grantedColor : iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
          if (granted) Icon(Icons.check_circle, size: 22, color: grantedColor),
        ],
      ),
    );
  }
}
