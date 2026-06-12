import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/bloc/settings/settings_state.dart';
import '../../core/services/app_exit_service.dart';
import '../../core/services/obs_server_service.dart';
import '../../core/services/tray_service.dart';
import '../../core/constants/app_colors.dart';

class ExitDialog extends StatefulWidget {
  const ExitDialog({super.key});

  @override
  State<ExitDialog> createState() => _ExitDialogState();

  /// 显示退出确认对话框
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ExitDialog(),
    );
  }

  static Future<bool> handleWindowClose(
    BuildContext context, {
    required AppExitBehavior behavior,
  }) async {
    switch (behavior) {
      case AppExitBehavior.ask:
        final result = await show(context);
        if (result == true) {
          await _exitApplication();
        } else if (result == false) {
          await _hideToTray();
        }
        return false;
      case AppExitBehavior.exit:
        await _exitApplication();
        return false;
      case AppExitBehavior.minimizeToTray:
        await _hideToTray();
        return false;
    }
  }

  static Future<void> _hideToTray() async {
    await TrayService.instance.initialize();
    await windowManager.hide();
  }

  static Future<void> _exitApplication() async {
    await AppExitService.instance.exitApplication();
  }
}

class _ExitDialogState extends State<ExitDialog> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _iconAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconScaleAnimation;
  Timer? _iconDelayTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _iconScaleAnimation = CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.elasticOut,
    );

    _animationController.forward();

    _iconDelayTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _iconAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _iconDelayTimer?.cancel();
    _animationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  void _handleExit() {
    HapticFeedback.mediumImpact();
    // 退出前清空 OBS 显示（如果服务正在运行）
    final obsService = ObsServerService();
    if (obsService.isRunning) {
      obsService.clearDisplay();
    }
    Navigator.of(context).pop(true);
  }

  void _handleHideToTray() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: isDark ? 0.3 : 0.15,
                  ),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                ),
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: isDark ? 0.2 : 0.08,
                  ),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 14,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      hoverColor: const Color(
                        0xFF0080FF,
                      ).withValues(alpha: 0.08),
                      onTap: () => Navigator.of(context).pop(),
                      child: Ink(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          MdiIcons.close,
                          size: 18,
                          color: colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 32, bottom: 16),
                      child: ScaleTransition(
                        scale: _iconScaleAnimation,
                        child:
                            Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFFEF4444,
                                        ).withValues(alpha: 0.1),
                                        const Color(
                                          0xFFDC2626,
                                        ).withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFEF4444,
                                      ).withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    MdiIcons.exitToApp,
                                    size: 28,
                                    color: AppColors.red500,
                                  ),
                                )
                                .animate()
                                .scale(
                                  delay: 200.ms,
                                  duration: 400.ms,
                                  curve: Curves.elasticOut,
                                )
                                .shimmer(
                                  delay: 300.ms,
                                  duration: 800.ms,
                                  colors: [
                                    Colors.transparent,
                                    const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.1),
                                    Colors.transparent,
                                  ],
                                ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      child:
                          Text(
                                '确认退出',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              )
                              .animate()
                              .fadeIn(delay: 100.ms, duration: 300.ms)
                              .slideY(
                                begin: 0.3,
                                end: 0,
                                delay: 100.ms,
                                duration: 300.ms,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      child:
                          Text(
                                '确定要退出 BakaBox 应用吗？',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              )
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 300.ms)
                              .slideY(
                                begin: 0.3,
                                end: 0,
                                delay: 200.ms,
                                duration: 300.ms,
                              ),
                    ),
                    const SizedBox(height: 32),
                    _buildButtons(context, theme, colorScheme),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      child: Row(
        children: [
          Expanded(
            child:
                Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          hoverColor: const Color(
                            0xFF0080FF,
                          ).withValues(alpha: 0.06),
                          onTap: _handleHideToTray,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  MdiIcons.trayArrowDown,
                                  size: 18,
                                  color: colorScheme.onSurface,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '隐藏到托盘',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 300.ms)
                    .slideX(
                      begin: -0.3,
                      end: 0,
                      delay: 300.ms,
                      duration: 300.ms,
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.red500, AppColors.red600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          hoverColor: Colors.white.withValues(alpha: 0.08),
                          onTap: _handleExit,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  MdiIcons.exitToApp,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '退出',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 300.ms)
                    .slideX(begin: 0.3, end: 0, delay: 400.ms, duration: 300.ms)
                    .shimmer(
                      delay: 600.ms,
                      duration: 1200.ms,
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
