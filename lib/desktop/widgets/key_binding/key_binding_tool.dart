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
                                child:
                                    BlocBuilder<
                                      KeyBindingBloc,
                                      KeyBindingState
                                    >(
                                      builder: (context, keyBindingState) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _ModernCategoryDropdown(
                                              state: keyBindingState,
                                              isDark: isDark,
                                            ),
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
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
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

class _ModernCategoryDropdown extends StatefulWidget {
  final KeyBindingState state;
  final bool isDark;

  const _ModernCategoryDropdown({required this.state, required this.isDark});

  @override
  State<_ModernCategoryDropdown> createState() =>
      _ModernCategoryDropdownState();
}

class _ModernCategoryDropdownState extends State<_ModernCategoryDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _hovering = false;

  @override
  void dispose() {
    if (_isOpen) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final isDark = widget.isDark;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.translucent,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (animContext, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, -10 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    constraints: const BoxConstraints(maxHeight: 360),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        children: [
                          _buildDropdownItem(
                            title: '全部配置',
                            icon: Icons.apps,
                            isSelected:
                                !widget.state.showMyConfigs &&
                                widget.state.categoryFilter == null,
                            onTap: () {
                              context.read<KeyBindingBloc>().add(
                                const KeyBindingSetCategoryFilter(null),
                              );
                              context.read<KeyBindingBloc>().add(
                                const KeyBindingSetShowMyConfigs(false),
                              );
                              _closeDropdown();
                            },
                          ),
                          _buildDropdownItem(
                            title: '我的配置',
                            icon: Icons.person_outline,
                            isSelected: widget.state.showMyConfigs,
                            onTap: () {
                              context.read<KeyBindingBloc>().add(
                                const KeyBindingSetCategoryFilter(null),
                              );
                              context.read<KeyBindingBloc>().add(
                                const KeyBindingSetShowMyConfigs(true),
                              );
                              _closeDropdown();
                            },
                          ),
                          if (widget.state.categories.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                '分类',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            ),
                            ...widget.state.categories.map(
                              (c) => _buildDropdownItem(
                                title: c.name,
                                icon: Icons.category_outlined,
                                isSelected:
                                    !widget.state.showMyConfigs &&
                                    widget.state.categoryFilter == c.id,
                                onTap: () {
                                  context.read<KeyBindingBloc>().add(
                                    const KeyBindingSetShowMyConfigs(false),
                                  );
                                  context.read<KeyBindingBloc>().add(
                                    KeyBindingSetCategoryFilter(c.id),
                                  );
                                  _closeDropdown();
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  Widget _buildDropdownItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentLabel = '全部配置';
    IconData currentIcon = Icons.apps;
    if (widget.state.showMyConfigs) {
      currentLabel = '我的配置';
      currentIcon = Icons.person_outline;
    } else if (widget.state.categoryFilter != null) {
      final category = widget.state.categories
          .cast<KeyConfigCategory?>()
          .firstWhere(
            (c) => c?.id == widget.state.categoryFilter,
            orElse: () => null,
          );
      if (category != null) {
        currentLabel = category.name;
        currentIcon = Icons.category_outlined;
      }
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _isOpen || _hovering
                  ? (widget.isDark ? AppColors.slate700 : Colors.grey[200])
                  : (widget.isDark ? AppColors.slate900 : Colors.white),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isOpen
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : (widget.isDark ? AppColors.slate700 : Colors.grey[300]!),
              ),
              boxShadow: _isOpen
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  currentIcon,
                  size: 16,
                  color: _isOpen
                      ? AppColors.primary
                      : (widget.isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(width: 6),
                Text(
                  currentLabel,
                  style: TextStyle(
                    color: _isOpen
                        ? AppColors.primary
                        : (widget.isDark ? Colors.white70 : Colors.black87),
                    fontWeight: _isOpen ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: _isOpen
                        ? AppColors.primary
                        : (widget.isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
