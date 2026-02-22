import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../core/services/tts_service.dart';

/// TTS 模型管理弹窗
///
/// 支持多模型选择、下载、删除。
/// 模型标注「国内」/「国外」区域标签。
class TtsDownloadDialog extends StatefulWidget {
  const TtsDownloadDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<MapSubscriptionBloc>(),
        child: const TtsDownloadDialog(),
      ),
    );
  }

  @override
  State<TtsDownloadDialog> createState() => _TtsDownloadDialogState();
}

class _TtsDownloadDialogState extends State<TtsDownloadDialog> {
  final TtsService _ttsService = TtsService();
  String? _downloadingModelId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 520,
        child: BlocListener<MapSubscriptionBloc, MapSubscriptionState>(
          listenWhen: (prev, curr) =>
              prev.ttsDownloadStatus != curr.ttsDownloadStatus,
          listener: (context, state) {
            // 下载完成后刷新状态
            if (state.ttsDownloadStatus == TtsDownloadStatus.completed) {
              // 延迟一下确保 StorageUtils 已经写入完成
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() => _downloadingModelId = null);
                }
              });
            } else if (state.ttsDownloadStatus == TtsDownloadStatus.failed) {
              setState(() => _downloadingModelId = null);
            }
          },
          child: BlocBuilder<MapSubscriptionBloc, MapSubscriptionState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    _buildHeader(isDark),
                    const SizedBox(height: 16),
                    // 模型列表标题
                    _buildSectionTitle(isDark, '可用模型'),
                    const SizedBox(height: 8),
                    // 模型列表
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: TtsService.availableModels.length,
                        itemBuilder: (_, i) {
                          final model = TtsService.availableModels[i];
                          return _buildModelCard(isDark, model, state);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 关闭按钮
                    _buildBottomActions(isDark, state),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.record_voice_over_rounded,
            color: Color(0xFF6366F1),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TTS 语音模型',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '管理语音合成模型，用于地图订阅提醒',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const Spacer(),
        _HoverIconButton(
          icon: Icons.close_rounded,
          onPressed: () => Navigator.of(context).pop(),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(bool isDark, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
      ),
    );
  }

  Widget _buildModelCard(
    bool isDark,
    TtsModelInfo model,
    MapSubscriptionState state,
  ) {
    final isDownloaded = _ttsService.isModelDownloadedById(model.id);
    final isSelected = isDownloaded && state.selectedTtsModelId == model.id;
    final isDomestic = model.region == TtsModelRegion.domestic;
    final isDownloading =
        _downloadingModelId == model.id &&
        state.ttsDownloadStatus == TtsDownloadStatus.downloading;
    final isExtracting =
        _downloadingModelId == model.id &&
        state.ttsDownloadStatus == TtsDownloadStatus.extracting;
    final isFailed =
        _downloadingModelId == model.id &&
        state.ttsDownloadStatus == TtsDownloadStatus.failed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _HoverContainer(
        isDark: isDark,
        isSelected: isSelected,
        onTap: isDownloaded
            ? () {
                context.read<MapSubscriptionBloc>().add(
                  MapSubscriptionSelectTtsModel(modelId: model.id),
                );
              }
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 选中标记
                if (isSelected)
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                // 模型信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            model.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 区域标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDomestic
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.12)
                                  : const Color(
                                      0xFF6366F1,
                                    ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isDomestic ? '国内' : '国外',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDomestic
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          // 已下载标记
                          if (isDownloaded) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${model.description} · ${model.language} · ${model.estimatedSize}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                // 操作按钮
                _buildModelActions(
                  isDark,
                  model,
                  state,
                  isDownloaded,
                  isSelected,
                  isDownloading,
                  isExtracting,
                ),
              ],
            ),
            // 下载进度条（在模型卡片内）
            if (isDownloading || isExtracting) ...[
              const SizedBox(height: 10),
              _buildInlineProgress(isDark, state, isExtracting),
            ],
            // 错误提示
            if (isFailed && state.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelActions(
    bool isDark,
    TtsModelInfo model,
    MapSubscriptionState state,
    bool isDownloaded,
    bool isSelected,
    bool isDownloading,
    bool isExtracting,
  ) {
    if (isDownloading || isExtracting) {
      // 下载中显示取消按钮
      return _HoverButton(
        onPressed: () {
          _ttsService.cancelDownload();
          setState(() => _downloadingModelId = null);
          context.read<MapSubscriptionBloc>().add(const MapSubscriptionLoad());
        },
        isDark: isDark,
        icon: Icons.close_rounded,
        label: '取消',
        isDestructive: true,
      );
    }

    if (!isDownloaded) {
      // 未下载显示下载按钮（普通下载和加速下载）
      final hasAcceleration = model.acceleratedUrl != null;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 国内下载按钮（优先显示，仅当有加速地址时显示）
          if (hasAcceleration) ...[
            Tooltip(
              message: '使用国内镜像下载（推荐）',
              child: _HoverButton(
                onPressed:
                    state.ttsDownloadStatus == TtsDownloadStatus.downloading
                    ? null
                    : () {
                        setState(() => _downloadingModelId = model.id);
                        context.read<MapSubscriptionBloc>().add(
                          MapSubscriptionDownloadTtsModel(
                            modelId: model.id,
                            useAcceleration: true,
                          ),
                        );
                      },
                isDark: isDark,
                icon: Icons.download_rounded,
                label: '国内下载',
                isAccent: true,
              ),
            ),
            const SizedBox(width: 6),
          ],
          // 国外下载按钮
          Tooltip(
            message: hasAcceleration ? '从 GitHub 直接下载' : '下载模型',
            child: _HoverButton(
              onPressed: state.ttsDownloadStatus == TtsDownloadStatus.downloading
                  ? null
                  : () {
                      setState(() => _downloadingModelId = model.id);
                      context.read<MapSubscriptionBloc>().add(
                        MapSubscriptionDownloadTtsModel(modelId: model.id),
                      );
                    },
              isDark: isDark,
              icon: Icons.public_rounded,
              label: hasAcceleration ? '国外下载' : '下载',
            ),
          ),
        ],
      );
    }

    // 已下载显示应用和删除按钮
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isSelected)
          _HoverButton(
            onPressed: () {
              context.read<MapSubscriptionBloc>().add(
                MapSubscriptionSelectTtsModel(modelId: model.id),
              );
            },
            isDark: isDark,
            icon: Icons.check_rounded,
            label: '应用',
          ),
        if (!isSelected) const SizedBox(width: 6),
        _HoverIconButton(
          icon: Icons.delete_outline_rounded,
          onPressed: () => _confirmDelete(model),
          isDark: isDark,
          isDestructive: true,
          tooltip: '删除模型',
        ),
      ],
    );
  }

  Widget _buildInlineProgress(
    bool isDark,
    MapSubscriptionState state,
    bool isExtracting,
  ) {
    final percent = (state.ttsDownloadProgress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: isExtracting ? null : state.ttsDownloadProgress,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isExtracting ? '解压中...' : '下载中... $percent%',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(TtsModelInfo model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模型'),
        content: Text('确定要删除 ${model.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _ttsService.deleteModel(modelId: model.id);
      if (mounted) {
        context.read<MapSubscriptionBloc>().add(const MapSubscriptionLoad());
      }
    }
  }

  Widget _buildBottomActions(bool isDark, MapSubscriptionState state) {
    return Row(
      children: [
        // 提示信息
        Expanded(
          child: Text(
            state.isTtsModelDownloaded
                ? '当前使用: ${_ttsService.selectedModelInfo.name}'
                : '请下载一个模型以启用语音提醒',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            ),
          ),
        ),
        _HoverButton(
          onPressed: () => Navigator.of(context).pop(),
          isDark: isDark,
          label: '关闭',
          isOutlined: true,
        ),
      ],
    );
  }
}

/// 带 hover 效果的容器
class _HoverContainer extends StatefulWidget {
  final bool isDark;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget child;

  const _HoverContainer({
    required this.isDark,
    required this.isSelected,
    required this.child,
    this.onTap,
  });

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.isDark
                      ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                      : const Color(0xFF6366F1).withValues(alpha: 0.06))
                : _isHovered
                ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF3F4F6))
                : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                  : _isHovered
                  ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : const Color(0xFFD1D5DB))
                  : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE5E7EB)),
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 带 hover 效果的按钮
class _HoverButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isDark;
  final IconData? icon;
  final String label;
  final bool isDestructive;
  final bool isOutlined;
  final bool isLoading;

  /// 是否使用强调色（用于加速下载等特殊按钮）
  final bool isAccent;

  const _HoverButton({
    required this.onPressed,
    required this.isDark,
    required this.label,
    this.icon,
    this.isDestructive = false,
    this.isOutlined = false,
    this.isLoading = false,
    this.isAccent = false,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final baseColor = widget.isDestructive
        ? Colors.redAccent
        : widget.isAccent
        ? const Color(0xFF10B981) // 绿色强调色
        : const Color(0xFF6366F1);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isOutlined
                ? (_isHovered && isEnabled
                      ? (widget.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFF3F4F6))
                      : Colors.transparent)
                : (_isHovered && isEnabled
                      ? baseColor.withValues(alpha: 0.2)
                      : baseColor.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(6),
            border: widget.isOutlined
                ? Border.all(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFFD1D5DB),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 14,
                  color: isEnabled
                      ? (widget.isOutlined
                            ? (widget.isDark
                                  ? Colors.white70
                                  : const Color(0xFF4B5563))
                            : baseColor)
                      : (widget.isDark
                            ? Colors.white24
                            : const Color(0xFFD1D5DB)),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isEnabled
                      ? (widget.isOutlined
                            ? (widget.isDark
                                  ? Colors.white70
                                  : const Color(0xFF4B5563))
                            : baseColor)
                      : (widget.isDark
                            ? Colors.white24
                            : const Color(0xFFD1D5DB)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的图标按钮
class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDark;
  final bool isDestructive;
  final String? tooltip;

  const _HoverIconButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
    this.isDestructive = false,
    this.tooltip,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final baseColor = widget.isDestructive
        ? Colors.redAccent
        : (widget.isDark ? Colors.white54 : const Color(0xFF9CA3AF));
    final hoverColor = widget.isDestructive
        ? Colors.redAccent
        : (widget.isDark ? Colors.white : const Color(0xFF4B5563));

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered && isEnabled
                ? (widget.isDestructive
                      ? Colors.redAccent.withValues(alpha: 0.1)
                      : (widget.isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFF3F4F6)))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: isEnabled
                ? (_isHovered ? hoverColor : baseColor)
                : (widget.isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
