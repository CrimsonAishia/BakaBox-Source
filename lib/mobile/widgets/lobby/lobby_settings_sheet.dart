import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/models/lobby_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/lobby_image_cache_service.dart';
import '../../../core/constants/app_colors.dart';

/// 移动端大厅设置 BottomSheet 组件
///
/// 提供角色选择、匿名模式、显示名牌、显示聊天气泡开关。
/// 移动端不显示"使用 Steam 名称"和"聊天透明度"选项。
class LobbySettingsSheet extends StatelessWidget {
  const LobbySettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: BlocBuilder<LobbyBloc, LobbyState>(
        builder: (context, state) {
          final bool anonymousCooldown =
              state.anonymousSwitchCooldownSeconds > 0;
          final bool anonymousPending = state.pendingSettings.containsKey(
            'anonymous',
          );

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(),
                  _buildHeader(context),
                  // 角色选择
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      '角色选择',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 130,
                    child: _LobbySpriteRow(
                      sprites: state.availableSprites,
                      selectedId: state.selectedSpriteId,
                      isLocked:
                          state.isAnonymous && !AuthService.instance.isLoggedIn,
                      isPending: state.isSpriteChangePending,
                      onSelect: (id) => context.read<LobbyBloc>().add(
                        LobbySpriteSelected(id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 匿名模式
                  _buildSwitchTile(
                    title: '匿名模式',
                    subtitle: anonymousCooldown
                        ? '冷却中 ${state.anonymousSwitchCooldownSeconds}s'
                        : null,
                    value: state.isAnonymous,
                    onChanged:
                        !AuthService.instance.isLoggedIn ||
                            (anonymousCooldown || anonymousPending)
                        ? null
                        : (value) {
                            context.read<LobbyBloc>().add(
                              LobbyAnonymousToggled(value),
                            );
                          },
                  ),
                  // 显示名牌
                  _buildSwitchTile(
                    title: '显示名牌',
                    value: state.showNameplates,
                    onChanged: state.pendingSettings.containsKey('nameplates')
                        ? null
                        : (value) {
                            context.read<LobbyBloc>().add(
                              LobbyNameplatesToggled(value),
                            );
                          },
                  ),
                  // 显示聊天气泡
                  _buildSwitchTile(
                    title: '显示聊天气泡',
                    value: state.showChatBubbles,
                    onChanged: state.pendingSettings.containsKey('chatBubbles')
                        ? null
                        : (value) {
                            context.read<LobbyBloc>().add(
                              LobbyChatBubblesToggled(value),
                            );
                          },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.settings_outlined,
            size: 20,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          const Text(
            '大厅设置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.sky400,
    );
  }
}

// ─── 角色选择组件 ──────────────────────────────────────────

/// 单行横向滚动的角色列表（带左右滚动指示器）
class _LobbySpriteRow extends StatefulWidget {
  final List<LobbySprite> sprites;
  final String? selectedId;
  final bool isLocked;
  final bool isPending;
  final void Function(String id) onSelect;

  const _LobbySpriteRow({
    required this.sprites,
    required this.selectedId,
    required this.isLocked,
    this.isPending = false,
    required this.onSelect,
  });

  @override
  State<_LobbySpriteRow> createState() => _LobbySpriteRowState();
}

class _LobbySpriteRowState extends State<_LobbySpriteRow> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

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
    final canLeft = position.pixels > 0;
    final canRight = position.pixels < position.maxScrollExtent;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
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

    const bg = AppColors.slate900;

    return Stack(
      children: [
        ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: widget.sprites.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final sprite = widget.sprites[index];
            return _LobbySpriteChoiceCard(
              sprite: sprite,
              selected: sprite.id == widget.selectedId,
              isLocked: widget.isLocked && !sprite.isDefault,
              onTap: () => widget.onSelect(sprite.id),
            );
          },
        ),
        if (_canScrollLeft)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      bg.withValues(alpha: 0.95),
                      bg.withValues(alpha: 0),
                    ],
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white54.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
            ),
          ),
        if (_canScrollRight)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      bg.withValues(alpha: 0.95),
                      bg.withValues(alpha: 0),
                    ],
                  ),
                ),
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white54.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
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
                  width: 22,
                  height: 22,
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

/// 角色选择卡片（与桌面端一致）
class _LobbySpriteChoiceCard extends StatefulWidget {
  final LobbySprite sprite;
  final bool selected;
  final bool isLocked;
  final VoidCallback onTap;

  const _LobbySpriteChoiceCard({
    required this.sprite,
    required this.selected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  State<_LobbySpriteChoiceCard> createState() => _LobbySpriteChoiceCardState();
}

class _LobbySpriteChoiceCardState extends State<_LobbySpriteChoiceCard> {
  Uint8List? _cachedImageBytes;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_LobbySpriteChoiceCard oldWidget) {
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
