import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../bloc/feature_status/feature_status_bloc.dart';
import '../bloc/feature_status/feature_status_state.dart';
import '../models/feature_status_models.dart';

/// 功能门控组件
///
/// 根据功能状态决定是否显示子组件或禁用提示
class FeatureGate extends StatelessWidget {
  final FeatureType feature;
  final Widget child;
  final Widget? disabledWidget;
  final bool showDisabledMessage;

  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.disabledWidget,
    this.showDisabledMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeatureStatusBloc, FeatureStatusState>(
      builder: (context, state) {
        // 如果状态还在加载中，显示子组件但禁用交互（通过透明遮罩）
        // 如果已加载完成，根据实际状态判断
        final shouldShowDisabled =
            state.loadState == FeatureStatusLoadState.loaded &&
            !state.status.getStatus(feature).enabled;

        if (shouldShowDisabled) {
          // 功能禁用时显示禁用组件或默认提示
          final featureStatus = state.status.getStatus(feature);
          return disabledWidget ??
              _buildDefaultDisabledWidget(context, state, featureStatus);
        }

        // 其他情况（loading、initial、loaded+enabled）都显示子组件
        return child;
      },
    );
  }

  Widget _buildDefaultDisabledWidget(
    BuildContext context,
    FeatureStatusState state,
    FeatureStatus featureStatus,
  ) {
    if (!showDisabledMessage) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = featureStatus.message.isNotEmpty
        ? featureStatus.message
        : '该功能暂未开放';

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                MdiIcons.lockOutline,
                size: 40,
                color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${feature.displayName}暂不可用',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF374151).withValues(alpha: 0.5)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    MdiIcons.informationOutline,
                    size: 16,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 功能状态检查工具类
class FeatureStatusChecker {
  /// 检查功能是否启用
  ///
  /// 注意：如果功能状态还在加载中或加载失败，返回 false（安全优先）
  /// 只有明确加载成功且功能启用时才返回 true
  static bool isEnabled(BuildContext context, FeatureType feature) {
    try {
      final state = context.read<FeatureStatusBloc>().state;

      // 只有加载成功时才检查实际状态
      if (state.loadState == FeatureStatusLoadState.loaded) {
        return state.status.getStatus(feature).enabled;
      }

      // 其他情况（initial、loading、error）都返回 false
      return false;
    } catch (e) {
      // 如果 Bloc 不可用，默认禁用（安全优先）
      return false;
    }
  }

  /// 获取功能禁用提示信息
  ///
  /// 根据不同的加载状态返回不同的提示信息
  static String getDisabledMessage(BuildContext context, FeatureType feature) {
    try {
      final state = context.read<FeatureStatusBloc>().state;

      // 根据加载状态返回不同提示
      switch (state.loadState) {
        case FeatureStatusLoadState.initial:
        case FeatureStatusLoadState.loading:
          return '功能状态加载中，请稍后再试';
        case FeatureStatusLoadState.error:
          return state.errorMessage ?? '服务暂时不可用，请稍后再试';
        case FeatureStatusLoadState.loaded:
          return state.getDisabledMessage(feature);
      }
    } catch (e) {
      return '服务暂时不可用，请稍后再试';
    }
  }

  /// 检查功能并显示提示（如果禁用）
  /// 返回 true 表示功能启用，false 表示功能禁用
  static bool checkAndShowToast(
    BuildContext context,
    FeatureType feature, {
    void Function(BuildContext, String)? showToast,
  }) {
    final enabled = isEnabled(context, feature);
    if (!enabled && showToast != null) {
      showToast(context, getDisabledMessage(context, feature));
    }
    return enabled;
  }
}
