import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import 'settings_group_title.dart';
import 'settings_item.dart';

/// 窗口设置组件
class WindowSettings extends StatelessWidget {
  final SettingsState settingsState;

  const WindowSettings({super.key, required this.settingsState});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '窗口设置',
          hasGlow: true,
          icon: MdiIcons.windowClosedVariant,
        ),
        SettingsItem(
          label: '关闭主窗口时',
          description: '设置点击关闭按钮后的默认行为。',
          control: _ExitBehaviorSelector(settingsState: settingsState),
          alignTop: true,
        ),
      ],
    );
  }
}

class _ExitBehaviorSelector extends StatelessWidget {
  final SettingsState settingsState;

  const _ExitBehaviorSelector({required this.settingsState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppExitBehavior.values.map((behavior) {
            final isSelected = settingsState.appExitBehavior == behavior;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                context.read<SettingsBloc>().add(SettingsSetAppExitBehavior(behavior));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0080FF).withValues(alpha: 0.15),
                            const Color(0xFF00D4FF).withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFF9FAFB)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0080FF)
                        : (isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB)),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0080FF).withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForBehavior(behavior),
                      size: 18,
                      color: isSelected
                          ? const Color(0xFF0080FF)
                          : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      behavior.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF0080FF)
                            : (isDark ? Colors.white : const Color(0xFF374151)),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(
                        MdiIcons.checkCircle,
                        size: 16,
                        color: const Color(0xFF0080FF),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            settingsState.appExitBehavior.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconForBehavior(AppExitBehavior behavior) {
    switch (behavior) {
      case AppExitBehavior.ask:
        return MdiIcons.helpCircleOutline;
      case AppExitBehavior.exit:
        return MdiIcons.exitToApp;
      case AppExitBehavior.minimizeToTray:
        return MdiIcons.trayArrowDown;
    }
  }
}
