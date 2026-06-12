import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../../../core/services/tts_service.dart';
import '../../common_scroll_indicator.dart';
import '../../tts_download_dialog.dart';
import '../../../../core/constants/app_colors.dart';

/// TTS 设置视图
class TtsSettingsView extends StatefulWidget {
  final bool isDark;
  final MapSubscriptionState state;

  const TtsSettingsView({super.key, required this.isDark, required this.state});

  @override
  State<TtsSettingsView> createState() => _TtsSettingsViewState();
}

class _TtsSettingsViewState extends State<TtsSettingsView> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  bool get isDark => widget.isDark;
  MapSubscriptionState get state => widget.state;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        _buildHeader(context),
        const Divider(height: 1),
        // 内容区
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TTS 状态卡片
                    _buildStatusCard(context),
                    const SizedBox(height: 14),
                    // 音量/语速/说话人设置（模型下载后显示）
                    if (state.isTtsModelDownloaded) ...[
                      // 音量设置
                      _buildVolumeSlider(context),
                      const SizedBox(height: 14),
                      // 语速设置
                      _buildSpeedSlider(context),
                      const SizedBox(height: 14),
                      // 说话人选择（多音色模型）
                      _buildSpeakerSelector(context),
                      const SizedBox(height: 18),
                      // 操作按钮
                      _buildActionButtons(context),
                    ],
                  ],
                ),
              ),
              if (_canScrollUp)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: CommonScrollIndicator(isTop: true),
                ),
              if (_canScrollDown)
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CommonScrollIndicator(isTop: false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 标题栏
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          const Icon(
            Icons.record_voice_over_rounded,
            color: AppColors.indigo500,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'TTS 语音播报',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.gray800,
            ),
          ),
          const Spacer(),
          // 状态标签
          if (state.isTtsModelDownloaded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: state.isTtsEnabled
                    ? AppColors.emerald500.withValues(alpha: 0.12)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.gray100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    state.isTtsEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 12,
                    color: state.isTtsEnabled
                        ? AppColors.emerald500
                        : (isDark ? Colors.white38 : AppColors.gray400),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.isTtsEnabled ? '已启用' : '已关闭',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: state.isTtsEnabled
                          ? AppColors.emerald500
                          : (isDark ? Colors.white38 : AppColors.gray400),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// TTS 状态卡片
  Widget _buildStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: state.isTtsModelDownloaded
                      ? AppColors.emerald500.withValues(alpha: 0.12)
                      : AppColors.amber500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  state.isTtsModelDownloaded
                      ? Icons.check_circle_rounded
                      : Icons.download_rounded,
                  size: 24,
                  color: state.isTtsModelDownloaded
                      ? AppColors.emerald500
                      : AppColors.amber500,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isTtsModelDownloaded ? 'TTS 模型已就绪' : 'TTS 模型未下载',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.isTtsModelDownloaded
                          ? '语音播报功能可正常使用'
                          : '需要下载语音模型才能使用播报功能',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white54
                            : AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              // 管理按钮
              _buildActionButton(
                context: context,
                icon: Icons.settings_rounded,
                label: '管理模型',
                onTap: () => TtsDownloadDialog.show(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 音量滑块
  Widget _buildVolumeSlider(BuildContext context) {
    // 确保值在有效范围内（最大 200%）
    final volumeValue = state.ttsVolume.clamp(0.0, 2.0);
    return _buildSliderCard(
      context: context,
      icon: Icons.volume_up_rounded,
      title: '播报音量',
      value: volumeValue,
      min: 0.0,
      max: 2.0,
      displayValue: '${(volumeValue * 100).round()}%',
      onChanged: (v) => context.read<MapSubscriptionBloc>().add(
        MapSubscriptionSetTtsVolume(volume: v),
      ),
    );
  }

  /// 语速滑块
  Widget _buildSpeedSlider(BuildContext context) {
    // 确保值在有效范围内
    final speedValue = state.ttsSpeed.clamp(0.5, 2.0);
    return _buildSliderCard(
      context: context,
      icon: Icons.speed_rounded,
      title: '播报语速',
      value: speedValue,
      min: 0.5,
      max: 2.0,
      displayValue: '${speedValue.toStringAsFixed(1)}x',
      onChanged: (v) => context.read<MapSubscriptionBloc>().add(
        MapSubscriptionSetTtsSpeed(speed: v),
      ),
    );
  }

  /// 说话人选择器（多音色模型）
  Widget _buildSpeakerSelector(BuildContext context) {
    // 获取当前选中模型的信息
    final selectedModel = TtsService.availableModels.firstWhere(
      (m) => m.id == state.selectedTtsModelId,
      orElse: () => TtsService.availableModels.first,
    );

    // 如果模型只有一个说话人，不显示选择器
    if (selectedModel.speakerCount <= 1) {
      return const SizedBox.shrink();
    }

    final speakerId = state.ttsSpeakerId.clamp(
      0,
      selectedModel.speakerCount - 1,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_rounded,
                size: 18,
                color: isDark ? Colors.white60 : AppColors.gray500,
              ),
              const SizedBox(width: 10),
              Text(
                '说话人',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.gray800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.indigo500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${speakerId + 1} / ${selectedModel.speakerCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.indigo500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.indigo500,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.gray200,
              thumbColor: AppColors.indigo500,
              overlayColor: AppColors.indigo500.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: speakerId.toDouble(),
              min: 0,
              max: (selectedModel.speakerCount - 1).toDouble(),
              divisions: selectedModel.speakerCount - 1,
              onChanged: (v) => context.read<MapSubscriptionBloc>().add(
                MapSubscriptionSetTtsSpeakerId(speakerId: v.round()),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '当前模型支持 ${selectedModel.speakerCount} 种音色，拖动滑块选择不同的说话人',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  /// 通用滑块卡片
  Widget _buildSliderCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? Colors.white60 : AppColors.gray500,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.gray800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.indigo500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.indigo500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.indigo500,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.gray200,
              thumbColor: AppColors.indigo500,
              overlayColor: AppColors.indigo500.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// 操作按钮区域
  Widget _buildActionButtons(BuildContext context) {
    final isTesting = state.isTtsTesting;
    final phase = state.ttsTestingPhase;
    final label = isTesting
        ? (phase == 'playing' ? '播报中...' : '生成中...')
        : '测试播报';

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: isTesting
                ? Icons.hourglass_empty_rounded
                : Icons.play_arrow_rounded,
            label: label,
            isPrimary: true,
            isLoading: isTesting,
            onTap: isTesting
                ? () {}
                : () => context.read<MapSubscriptionBloc>().add(
                    const MapSubscriptionTestTts(),
                  ),
          ),
        ),
      ],
    );
  }

  /// 操作按钮
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    bool isPrimary = false,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isPrimary
                ? (isLoading
                      ? AppColors.indigo500.withValues(alpha: 0.6)
                      : AppColors.indigo500)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.gray100),
            borderRadius: BorderRadius.circular(10),
            border: isPrimary
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.gray200,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPrimary ? Colors.white : AppColors.indigo500,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.gray700),
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPrimary
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.gray700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
