import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/bloc/update/update_bloc.dart';
import '../../../core/bloc/update/update_event.dart';
import '../../../core/bloc/update/update_state.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'settings_group_title.dart';
import 'settings_buttons.dart';
import '../../../core/constants/app_colors.dart';

/// 关于设置组件
class AboutSettings extends StatelessWidget {
  final SettingsState settingsState;

  const AboutSettings({super.key, required this.settingsState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(title: '关于', icon: MdiIcons.informationOutline),
        _buildUpdateInfoGrid(context),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isDark ? AppColors.sky400 : const Color(0xFF0EA5E9),
                width: 4,
              ),
            ),
          ),
          child: Text(
            '💡 应用启动时会自动检查更新。如果有新版本，将在后台下载并提示您安装。更新过程中请不要关闭应用程序。',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.gray500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateInfoGrid(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<UpdateBloc, UpdateState>(
      builder: (context, updateState) {
        return Column(
          children: [
            _UpdateInfoItem(
              icon: MdiIcons.tagOutline,
              iconColor: AppColors.primary,
              label: '当前版本',
              value: Text(
                'v${settingsState.appVersion}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.gray700,
                ),
              ),
              action: SettingsPrimaryButton(
                onPressed: updateState.isChecking
                    ? null
                    : () => _checkForUpdates(context),
                label: updateState.isChecking ? '检查中...' : '检查更新',
                icon: MdiIcons.refresh,
                isLoading: updateState.isChecking,
              ),
            ),
            _UpdateInfoItem(
              icon: MdiIcons.accountOutline,
              iconColor: AppColors.emerald500,
              label: '开发者',
              value: Row(
                children: [
                  ClipOval(
                    child: DiskCachedImage(
                      imageUrl:
                          'https://bbs.zombieden.cn/uc_server/data/avatar/000/04/21/47_avatar_middle.jpg',
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: 42,
                        height: 42,
                        color: isDark ? AppColors.slate600 : AppColors.gray200,
                        child: const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                      errorWidget: Container(
                        width: 42,
                        height: 42,
                        color: isDark ? AppColors.slate600 : AppColors.gray200,
                        child: const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppConstants.appAuthor,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.gray700,
                    ),
                  ),
                ],
              ),
              action: const SizedBox.shrink(),
            ),
            _UpdateInfoItem(
              icon: MdiIcons.github,
              iconColor: AppColors.indigo500,
              label: '开源地址',
              value: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConstants.appRepoUrl,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : AppColors.blue500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '代码会在稳定后同步更新🐛',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white38 : AppColors.gray400,
                    ),
                  ),
                ],
              ),
              action: SettingsPrimaryButton(
                onPressed: () => _openRepoUrl(),
                label: '打开',
                icon: MdiIcons.openInNew,
              ),
            ),
            _UpdateInfoItem(
              icon: MdiIcons.copyright,
              iconColor: AppColors.violet500,
              label: '版权信息',
              value: Text(
                AppConstants.appCopyright,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : AppColors.gray500,
                ),
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

  static Future<void> _openRepoUrl() async {
    final uri = Uri.parse(AppConstants.appRepoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
              ? [AppColors.slate700, AppColors.slate800]
              : [const Color(0xFFFAFBFC), AppColors.slate50],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate600 : AppColors.gray200,
        ),
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
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? AppColors.primary,
              ),
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
                color: isDark ? Colors.white : AppColors.gray700,
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
