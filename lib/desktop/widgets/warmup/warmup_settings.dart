import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/warmup/warmup_bloc.dart';
import '../../../core/bloc/warmup/warmup_event.dart';
import '../../../core/bloc/warmup/warmup_state.dart';

/// 暖服设置组件
class WarmupSettings extends StatefulWidget {
  final WarmupBlocState state;

  const WarmupSettings({super.key, required this.state});

  @override
  State<WarmupSettings> createState() => _WarmupSettingsState();
}

class _WarmupSettingsState extends State<WarmupSettings> {
  late int _targetPlayers;

  @override
  void initState() {
    super.initState();
    _targetPlayers = widget.state.config.targetPlayers;
  }

  @override
  void didUpdateWidget(WarmupSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.config.targetPlayers !=
        oldWidget.state.config.targetPlayers) {
      setState(() {
        _targetPlayers = widget.state.config.targetPlayers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                MdiIcons.tuneVariant,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '暖服设置',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTargetPlayersSlider(context),
          const SizedBox(height: 16),
          _buildFloatingWindowSwitch(context, isDark),
        ],
      ),
    );
  }

  Widget _buildTargetPlayersSlider(BuildContext context) {
    // 暖服人数范围：1 ~ 服务器最大人数×0.6
    // 获取不到服务器最大人数时不兜底，只允许 1 人。
    final maxTarget = widget.state.maxTargetPlayers;
    final effectiveTarget = _targetPlayers.clamp(1, maxTarget);
    // max==min 时 Slider 会出现除零（NaN），需禁用滑块
    final isSingleValue = maxTarget <= 1;
    final divisions = maxTarget > 1 ? maxTarget - 1 : null;
    final sliderEnabled = !widget.state.isWarmupActive && !isSingleValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '目标人数',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium!.color!,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$effectiveTarget 人',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '1',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium!.color!.withValues(alpha: 0.5),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.orange,
                  inactiveTrackColor: Colors.orange.withValues(alpha: 0.1),
                  thumbColor: Colors.orange,
                  overlayColor: Colors.orange.withValues(alpha: 0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  // max==min 时固定为 0~1 占位，禁用交互避免除零
                  value: isSingleValue ? 1 : effectiveTarget.toDouble(),
                  min: 1,
                  max: isSingleValue ? 2 : maxTarget.toDouble(),
                  divisions: isSingleValue ? null : divisions,
                  onChanged: sliderEnabled
                      ? (value) {
                          setState(() {
                            _targetPlayers = value.round();
                          });
                        }
                      : null,
                  onChangeEnd: sliderEnabled
                      ? (value) {
                          context.read<WarmupBloc>().add(
                            WarmupSetTargetPlayers(value.round()),
                          );
                        }
                      : null,
                ),
              ),
            ),
            Text(
              '$maxTarget',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium!.color!.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isSingleValue ? '无法获取服务器最大人数，暖服人数限制为 1 人' : '有效人数 = 服务器人数 + 暖服人数',
          style: TextStyle(
            fontSize: 12,
            color: isSingleValue
                ? Colors.orange.withValues(alpha: 0.9)
                : Theme.of(
                    context,
                  ).textTheme.bodyMedium!.color!.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// 浮动窗口显示开关
  Widget _buildFloatingWindowSwitch(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                MdiIcons.pictureInPictureBottomRight,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '浮动窗口显示',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: widget.state.config.showFloatingWindow,
          onChanged: (value) {
            context.read<WarmupBloc>().add(WarmupSetShowFloatingWindow(value));
          },
        ),
      ],
    );
  }
}
