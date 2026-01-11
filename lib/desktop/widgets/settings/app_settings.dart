import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import 'settings_group_title.dart';
import 'settings_item.dart';

/// 应用设置组件
class AppSettings extends StatelessWidget {
  final SettingsState settingsState;

  const AppSettings({
    super.key,
    required this.settingsState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '应用设置',
          hasGlow: true,
          icon: MdiIcons.cog,
        ),
        AppSettingItem(
          title: '挤服成功音效音量',
          description: '调节挤服成功时播放音效的音量大小',
          value: _VolumeSlider(settingsState: settingsState),
          action: ElevatedButton.icon(
            onPressed: settingsState.audioVolume <= 0
                ? null
                : () {
                    context.read<SettingsBloc>().add(SettingsTestAudio());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('测试音效播放，音量: ${(settingsState.audioVolume * 100).toInt()}%'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF0080FF),
                      ),
                    );
                  },
            icon: Icon(MdiIcons.play, size: 14),
            label: const Text('试听'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0080FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final SettingsState settingsState;

  const _VolumeSlider({required this.settingsState});

  @override
  Widget build(BuildContext context) {
    final volumePercent = (settingsState.audioVolume * 100).toInt();
    final isMuted = settingsState.audioVolume <= 0;

    return Row(
      children: [
        Icon(
          isMuted ? MdiIcons.volumeOff : MdiIcons.volumeHigh,
          size: 20,
          color: isMuted ? Colors.grey : const Color(0xFF0080FF),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0080FF),
              inactiveTrackColor: const Color(0xFF0080FF).withValues(alpha: 0.2),
              thumbColor: const Color(0xFF0080FF),
              overlayColor: const Color(0xFF0080FF).withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: settingsState.audioVolume,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '$volumePercent%',
              onChanged: (value) {
                context.read<SettingsBloc>().add(SettingsSetAudioVolume(value));
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            isMuted ? '静音' : '$volumePercent%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isMuted ? Colors.grey : const Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
