import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/bloc/update/update_bloc.dart';
import '../../../core/bloc/update/update_event.dart';
import '../../../core/bloc/update/update_state.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/update_models.dart';
import '../../../core/widgets/update_dialog.dart';
import 'settings_group_title.dart';
import 'settings_buttons.dart';

/// 关于设置组件
class AboutSettings extends StatelessWidget {
  final SettingsState settingsState;

  const AboutSettings({
    super.key,
    required this.settingsState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '关于',
          icon: MdiIcons.informationOutline,
        ),
        _buildUpdateInfoGrid(context),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF0EA5E9), width: 4)),
          ),
          child: const Text(
            '💡 应用启动时会自动检查更新。如果有新版本，将在后台下载并提示您安装。更新过程中请不要关闭应用程序。',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateInfoGrid(BuildContext context) {
    return BlocConsumer<UpdateBloc, UpdateState>(
      listener: (context, updateState) {
        if (updateState.status == UpdateStatus.available && updateState.updateInfo != null) {
          UpdateDialog.show(context, updateState.updateInfo!);
        } else if (updateState.status == UpdateStatus.idle &&
            updateState.updateInfo != null &&
            !updateState.updateInfo!.hasUpdate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前已是最新版本'), backgroundColor: Colors.green),
          );
        }
      },
      builder: (context, updateState) {
        return Column(
          children: [
            _UpdateInfoItem(
              icon: MdiIcons.tagOutline,
              iconColor: const Color(0xFF0080FF),
              label: '当前版本',
              value: Text(
                'v${settingsState.appVersion.isNotEmpty ? settingsState.appVersion : AppConstants.appVersion}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0080FF)),
              ),
              action: SettingsPrimaryButton(
                onPressed: updateState.isChecking ? null : () => _checkForUpdates(context),
                label: updateState.isChecking ? '检查中...' : '检查更新',
                icon: MdiIcons.refresh,
                isLoading: updateState.isChecking,
              ),
            ),
            _UpdateInfoItem(
              icon: MdiIcons.accountOutline,
              iconColor: const Color(0xFF10B981),
              label: '开发者',
              value: const Text(
                AppConstants.appAuthor,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              action: const SizedBox.shrink(),
            ),
            _UpdateInfoItem(
              icon: MdiIcons.fileDocumentOutline,
              iconColor: const Color(0xFFF59E0B),
              label: '许可证',
              value: const Text(
                AppConstants.appLicense,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              action: const SizedBox.shrink(),
            ),
            _UpdateInfoItem(
              icon: MdiIcons.copyright,
              iconColor: const Color(0xFF8B5CF6),
              label: '版权信息',
              value: const Text(
                AppConstants.appCopyright,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              action: const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  void _checkForUpdates(BuildContext context) {
    context.read<UpdateBloc>().add(UpdateCheck());
  }
}

class _UpdateInfoItem extends StatelessWidget {
  final String label;
  final Widget value;
  final Widget action;
  final IconData? icon;
  final Color? iconColor;

  const _UpdateInfoItem({
    required this.label,
    required this.value,
    required this.action,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [const Color(0xFFFAFBFC), const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF0080FF)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor ?? const Color(0xFF0080FF)),
            ),
            const SizedBox(width: 16),
          ],
          SizedBox(
            width: icon != null ? 100 : 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: value,
            ),
          ),
          action,
        ],
      ),
    );
  }
}
