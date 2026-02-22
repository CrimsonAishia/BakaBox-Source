import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../tts_download_dialog.dart';

/// TTS 设置视图
class TtsSettingsView extends StatelessWidget {
  final bool isDark;
  final MapSubscriptionState state;

  const TtsSettingsView({
    super.key,
    required this.isDark,
    required this.state,
  });

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TTS 状态卡片
                _buildStatusCard(context),
                const SizedBox(height: 14),
                // TTS 开关
                if (state.isTtsModelDownloaded) ...[
                  _buildTtsToggle(context),
                  const SizedBox(height: 14),
                  // 音量设置
                  _buildVolumeSlider(context),
                  const SizedBox(height: 14),
                  // 语速设置
                  _buildSpeedSlider(context),
                  const SizedBox(height: 18),
                  // 操作按钮
                  _buildActionButtons(context),
                ],
              ],
            ),
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
            color: Color(0xFF6366F1),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'TTS 语音播报',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const Spacer(),
          // 状态标签
          if (state.isTtsModelDownloaded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: state.isTtsEnabled
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFF3F4F6)),
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
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.isTtsEnabled ? '已启用' : '已关闭',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: state.isTtsEnabled
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
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
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
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
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  state.isTtsModelDownloaded
                      ? Icons.check_circle_rounded
                      : Icons.download_rounded,
                  size: 24,
                  color: state.isTtsModelDownloaded
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
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
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.isTtsModelDownloaded
                          ? '语音播报功能可正常使用'
                          : '需要下载语音模型才能使用播报功能',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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

  /// TTS 开关
  Widget _buildTtsToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.power_settings_new_rounded,
            size: 20,
            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '启用语音播报',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '开启后，地图变更时会自动播报',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: state.isTtsEnabled,
            onChanged: (v) => context.read<MapSubscriptionBloc>().add(
                  MapSubscriptionToggleGlobalTts(enabled: v),
                ),
            activeTrackColor: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  /// 音量滑块
  Widget _buildVolumeSlider(BuildContext context) {
    // 确保值在有效范围内（最大 300%）
    final volumeValue = state.ttsVolume.clamp(0.0, 3.0);
    return _buildSliderCard(
      context: context,
      icon: Icons.volume_up_rounded,
      title: '播报音量',
      value: volumeValue,
      min: 0.0,
      max: 3.0,
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
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
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
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
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
              activeTrackColor: const Color(0xFF6366F1),
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE5E7EB),
              thumbColor: const Color(0xFF6366F1),
              overlayColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
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
            icon: isTesting ? Icons.hourglass_empty_rounded : Icons.play_arrow_rounded,
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
                    ? const Color(0xFF6366F1).withValues(alpha: 0.6)
                    : const Color(0xFF6366F1))
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(10),
            border: isPrimary
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE5E7EB),
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
                      isPrimary ? Colors.white : const Color(0xFF6366F1),
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF374151)),
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPrimary
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF374151)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
