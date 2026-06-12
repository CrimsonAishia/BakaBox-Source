import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/models/lobby_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/lobby_image_cache_service.dart';
import '../../../desktop/widgets/common_scroll_indicator.dart';
import 'lobby_panel_shell.dart';
import '../../../core/constants/app_colors.dart';

/// 设置面板
class LobbySettingsPanel extends StatelessWidget {
  final LobbyState state;

  const LobbySettingsPanel({super.key, required this.state});

  bool _isPending(String key) => state.pendingSettings[key] == true;

  @override
  Widget build(BuildContext context) {
    return LobbyPanelShell(
      width: 520,
      title: '大厅设置',
      onClose: () =>
          context.read<LobbyBloc>().add(const LobbyPanelsDismissed()),
      child: SizedBox(
        height: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '角色选择',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 225,
              child: _LobbySpriteGrid(
                sprites: state.availableSprites,
                selectedId: state.selectedSpriteId,
                isLocked: state.isAnonymous && !AuthService.instance.isLoggedIn,
                isPending: state.isSpriteChangePending,
                onSelect: (id) =>
                    context.read<LobbyBloc>().add(LobbySpriteSelected(id)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 匿名模式（需要冷却和pending状态）
                    _SettingsSwitchTile(
                      title: '匿名模式',
                      subtitle: _isPending('anonymous')
                          ? '请求中...'
                          : (state.anonymousSwitchCooldownSeconds > 0
                                ? '请稍候...'
                                : (state.isAnonymous
                                      ? (AuthService.instance.isLoggedIn
                                            ? '以匿名形式展示给其他用户'
                                            : '登录后可关闭匿名')
                                      : '公开身份展示给其他用户')),
                      value: state.isAnonymous,
                      onChanged:
                          (!AuthService.instance.isLoggedIn ||
                              _isPending('anonymous') ||
                              state.anonymousSwitchCooldownSeconds > 0)
                          ? null
                          : (value) => context.read<LobbyBloc>().add(
                              LobbyAnonymousToggled(value),
                            ),
                      isLoading:
                          _isPending('anonymous') ||
                          state.anonymousSwitchCooldownSeconds > 0,
                      loadingSeconds: state.anonymousSwitchCooldownSeconds > 0
                          ? state.anonymousSwitchCooldownSeconds
                          : null,
                      isPending: _isPending('anonymous'),
                      isLocked: !AuthService.instance.isLoggedIn,
                    ),
                    // 使用 Steam 名称
                    _SettingsSwitchTile(
                      title: '使用Steam名称',
                      subtitle: _isPending('useSteamName')
                          ? '请求中...'
                          : (state.steamNameSwitchCooldownSeconds > 0
                                ? '请稍候...'
                                : '在大厅中优先展示您的Steam昵称'),
                      value: state.useSteamName,
                      onChanged:
                          (!AuthService.instance.isLoggedIn ||
                              state.isAnonymous ||
                              _isPending('useSteamName') ||
                              state.steamNameSwitchCooldownSeconds > 0)
                          ? null
                          : (value) => context.read<LobbyBloc>().add(
                              LobbyUseSteamNameToggled(value),
                            ),
                      isLoading:
                          _isPending('useSteamName') ||
                          state.steamNameSwitchCooldownSeconds > 0,
                      loadingSeconds: state.steamNameSwitchCooldownSeconds > 0
                          ? state.steamNameSwitchCooldownSeconds
                          : null,
                      isPending: _isPending('useSteamName'),
                      isLocked:
                          !AuthService.instance.isLoggedIn ||
                          state.isAnonymous, // 匿名和未登录用户不能使用
                    ),
                    // 显示昵称
                    _SettingsSwitchTile(
                      title: '显示昵称',
                      value: state.showNameplates,
                      onChanged: (value) => context.read<LobbyBloc>().add(
                        LobbyNameplatesToggled(value),
                      ),
                    ),
                    // 显示气泡
                    _SettingsSwitchTile(
                      title: '显示气泡',
                      value: state.showChatBubbles,
                      onChanged: (value) => context.read<LobbyBloc>().add(
                        LobbyChatBubblesToggled(value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 带滚动指示器的角色网格
class _LobbySpriteGrid extends StatefulWidget {
  final List<LobbySprite> sprites;
  final String? selectedId;
  final bool isLocked;
  final bool isPending;
  final void Function(String id) onSelect;

  const _LobbySpriteGrid({
    required this.sprites,
    required this.selectedId,
    required this.isLocked,
    this.isPending = false,
    required this.onSelect,
  });

  @override
  State<_LobbySpriteGrid> createState() => _LobbySpriteGridState();
}

class _LobbySpriteGridState extends State<_LobbySpriteGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateScrollIndicators(),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sprites.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '暂无可用角色',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.sprites
                .map(
                  (sprite) => LobbySpriteChoiceCard(
                    sprite: sprite,
                    selected: sprite.id == widget.selectedId,
                    isLocked: widget.isLocked && !sprite.isDefault,
                    onTap: () => widget.onSelect(sprite.id),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        if (_canScrollUp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(
              isTop: true,
              color: Colors.white54,
              bgColor: AppColors.slate900,
            ),
          ),
        if (_canScrollDown)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(
              isTop: false,
              color: Colors.white54,
              bgColor: AppColors.slate900,
            ),
          ),
        // 切换中遮罩层
        if (widget.isPending)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 角色选择卡片
class LobbySpriteChoiceCard extends StatefulWidget {
  final LobbySprite sprite;
  final bool selected;
  final bool isLocked;
  final VoidCallback onTap;

  const LobbySpriteChoiceCard({
    super.key,
    required this.sprite,
    required this.selected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  State<LobbySpriteChoiceCard> createState() => _LobbySpriteChoiceCardState();
}

class _LobbySpriteChoiceCardState extends State<LobbySpriteChoiceCard> {
  Uint8List? _cachedImageBytes;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(LobbySpriteChoiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sprite.previewUrl != widget.sprite.previewUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final previewUrl = widget.sprite.previewUrl ?? widget.sprite.spriteUrl;
    if (previewUrl == null || previewUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
        _cachedImageBytes = null;
      });
    }

    try {
      final bytes = await LobbyImageCacheService.instance.getImage(previewUrl);
      if (mounted) {
        setState(() {
          _cachedImageBytes = bytes;
          _isLoading = false;
          _loadFailed = bytes == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = widget.sprite.previewUrl ?? widget.sprite.spriteUrl;
    final isLocked = widget.isLocked;

    return AnimatedScale(
      scale: widget.selected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: isLocked ? null : widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 102,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: widget.selected ? 0.18 : 0.05,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected
                  ? widget.sprite.accentColor
                  : Colors.white.withValues(alpha: 0.1),
              width: widget.selected ? 2.5 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: widget.sprite.accentColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              widget.sprite.accentColor.withValues(
                                alpha: isLocked ? 0.4 : 0.95,
                              ),
                              widget.sprite.accentColor.withValues(
                                alpha: isLocked ? 0.2 : 0.45,
                              ),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.sprite.accentColor.withValues(
                                alpha: isLocked ? 0.1 : 0.24,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _buildImage(previewUrl),
                      ),
                      if (isLocked)
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white70,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.sprite.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.selected
                          ? Colors.white
                          : isLocked
                          ? Colors.white54
                          : Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: widget.selected
                          ? FontWeight.w800
                          : FontWeight.w700,
                    ),
                  ),
                ],
              ),
              // 选中标记（固定绿色 + 白勾）
              if (widget.selected)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.green500,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green500.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String? previewUrl) {
    if (previewUrl == null || previewUrl.isEmpty) {
      return const Icon(Icons.person, color: Colors.white, size: 30);
    }

    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    if (_loadFailed || _cachedImageBytes == null) {
      return const Icon(Icons.person, color: Colors.white, size: 30);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(
        _cachedImageBytes!,
        width: 72,
        height: 72,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, color: Colors.white, size: 30);
        },
      ),
    );
  }
}

/// 统一的设置开关组件
class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isLoading;
  final int? loadingSeconds;
  final bool isPending;
  final bool isLocked;

  const _SettingsSwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.isLoading = false,
    this.loadingSeconds,
    this.isPending = false,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = isLoading || isLocked;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isLocked ? 0.02 : 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : () => onChanged?.call(!value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Switch
                IgnorePointer(
                  ignoring: true,
                  child: SizedBox(
                    width: 44,
                    height: 24,
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: isLocked
                          ? Colors.white70
                          : Colors.white,
                      activeTrackColor: isLocked
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.green500,
                      inactiveThumbColor: Colors.white70,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 标题和描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isLocked ? Colors.white38 : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: isLoading
                                ? Colors.orange
                                : (isLocked ? Colors.white24 : Colors.white54),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 加载指示
                if (isPending)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                    ),
                  )
                else if (isLoading && loadingSeconds != null)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: loadingSeconds! / 3,
                          strokeWidth: 2,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF60A5FA),
                          ),
                        ),
                        Text(
                          '$loadingSeconds',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
