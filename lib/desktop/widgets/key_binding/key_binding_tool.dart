import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/bloc/auth/auth_state.dart';
import '../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/key_config_models.dart';
import 'views/key_binding_list_view.dart';
import 'dialogs/config_detail_dialog.dart';
import 'views/autoexec_view.dart';
import 'views/publish_view.dart';
import 'views/edit_view.dart';

import 'components/toolbar_widgets.dart';

/// 按键绑定工具 - 现代化Tab+瀑布流+详情弹窗布局
class KeyBindingTool extends StatefulWidget {
  const KeyBindingTool({super.key});

  @override
  State<KeyBindingTool> createState() => _KeyBindingToolState();
}

class _KeyBindingToolState extends State<KeyBindingTool> {
  // 视图模式: 0: 基础, 1: 市场, 2: 本地配置
  int _viewMode = 0;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<KeyBindingBloc>();
      bloc.add(KeyBindingLoadConfigs());
      bloc.add(KeyBindingLoadCategories());
      bloc.add(KeyBindingLoadAutoexecContent());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showImmersiveDialog(Widget content, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bloc = context.read<KeyBindingBloc>();
    final authBloc = context.read<AuthBloc>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: authBloc),
          ],
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Container(
              width: 860,
              constraints: const BoxConstraints(maxWidth: 860, maxHeight: 800),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.transparent,
                    blurRadius: 0,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate900 : Colors.grey[100],
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? AppColors.slate700
                                : Colors.grey[200]!,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 12 * animation.value,
            sigmaY: 12 * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _openDetailForMarket(KeyConfig config) {
    ConfigDetailDialog.show(context, config: config, onEditConfig: _openEdit);
  }

  void _openEdit(KeyConfig config) {
    _showImmersiveDialog(
      EditView(config: config, onComplete: () => Navigator.pop(context)),
      '编辑配置',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<KeyBindingBloc, KeyBindingState>(
      listenWhen: (previous, current) {
        final successChanged =
            previous.successMessage != current.successMessage &&
            current.successMessage?.isNotEmpty == true;
        final errorChanged =
            previous.error != current.error &&
            current.error?.isNotEmpty == true;
        return successChanged || errorChanged;
      },
      listener: (context, state) {
        if (state.successMessage?.isNotEmpty == true) {
          ToastUtils.showSuccess(context, state.successMessage!);
          // The old logic was closing the overlay if it was an edit/publish action.
          // Since they are now dialogs, maybe the views inside handle Navigator.pop themselves,
          // or we don't automatically close all dialogs here. For Edit/Publish,
          // EditView triggers onComplete on success, and PublishView could pop,
          // but if not, the user can just close it manually. EditView's onComplete handles Edit.
          // For Publish, we might need a similar mechanism. But for now this is fine.
        }
        if (state.error?.isNotEmpty == true) {
          ToastUtils.showError(context, state.error!);
        }
        context.read<KeyBindingBloc>().add(KeyBindingClearMessages());
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : AppColors.gray50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.gray200,
            ),
          ),
          child: Column(
            children: [
              // 现代化头部区域
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Row(
                  children: [
                    // 左侧导航：现代化分段控制器
                    Container(
                      padding: const EdgeInsets.all(4),
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate900 : Colors.grey[200],
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTab('默认', 0, isDark),
                          _buildTab('玩家分享', 1, isDark),
                          _buildTab('本地配置', 2, isDark),
                        ],
                      ),
                    ),
                    if (_viewMode == 1)
                      BlocBuilder<KeyBindingBloc, KeyBindingState>(
                        builder: (context, state) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: _buildActionButton(
                              icon: Icons.refresh_rounded,
                              tooltip: '刷新',
                              isDark: isDark,
                              onPressed: state.isLoading
                                  ? null
                                  : () {
                                      context.read<KeyBindingBloc>().add(
                                        const KeyBindingLoadConfigs(
                                          showSuccessMessage: true,
                                        ),
                                      );
                                      context.read<KeyBindingBloc>().add(
                                        KeyBindingLoadCategories(),
                                      );
                                    },
                            ),
                          );
                        },
                      ),
                    const Spacer(),
                    // 右侧搜索和操作按钮
                    Row(
                      children: [
                        if (_viewMode == 1)
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, authState) {
                              if (!authState.isAuthenticated) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: BlocBuilder<KeyBindingBloc, KeyBindingState>(
                                  builder: (context, keyBindingState) {
                                    final showMyConfigs = keyBindingState.showMyConfigs;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildMyConfigsToggle(context, showMyConfigs, isDark),
                                        const SizedBox(width: 12),
                                        _buildPublishButton(),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        if (_viewMode != 2)
                          SizedBox(
                            width: 240,
                            height: 36,
                            child: SearchField(
                              controller: _searchCtrl,
                              onChanged: (v) =>
                                  context.read<KeyBindingBloc>().add(
                                    KeyBindingSetSearchKeyword(
                                      v.isEmpty ? null : v,
                                    ),
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? AppColors.slate700 : AppColors.gray200,
              ),
              // 视图内容
              Expanded(
                child: Container(
                  color: Colors.transparent,
                  child: IndexedStack(
                    index: _viewMode,
                    children: [
                      BasicTabView(),
                      MarketTabView(
                        onConfigTap: _openDetailForMarket,
                        onEditConfig: _openEdit,
                      ),
                      AutoexecView(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showImmersiveDialog(const PublishView(), '发布配置'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  '发布',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyConfigsToggle(BuildContext context, bool isSelected, bool isDark) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : (isDark ? AppColors.slate900 : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.3)
              : (isDark ? AppColors.slate700 : Colors.grey[300]!),
        ),
        boxShadow: isSelected
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            context.read<KeyBindingBloc>().add(KeyBindingSetShowMyConfigs(!isSelected));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.people_outline : Icons.person_outline,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(width: 4),
                Text(
                  isSelected ? '切换：所有配置' : '切换：我的配置',
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String text, int mode, bool isDark) {
    return _TabButton(
      text: text,
      isSelected: _viewMode == mode,
      isDark: isDark,
      onTap: () {
        if (_viewMode != mode) {
          setState(() => _viewMode = mode);
          if (_searchCtrl.text.isNotEmpty) {
            _searchCtrl.clear();
            context.read<KeyBindingBloc>().add(
              const KeyBindingSetSearchKeyword(null),
            );
          }
        }
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEnabled
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEnabled
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.2))
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05)),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isEnabled
                  ? (isDark ? Colors.white70 : AppColors.primary)
                  : (isDark ? Colors.white30 : Colors.black26),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  final String text;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabButton({
    required this.text,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 28,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.isDark ? AppColors.slate700 : Colors.white)
                : (_hovering
                      ? (widget.isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05))
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
              color: widget.isSelected
                  ? (widget.isDark ? Colors.white : Colors.black87)
                  : (_hovering
                        ? (widget.isDark ? Colors.white : Colors.black87)
                        : (widget.isDark ? Colors.white54 : Colors.black54)),
            ),
          ),
        ),
      ),
    );
  }
}
