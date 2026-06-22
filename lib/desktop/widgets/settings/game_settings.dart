import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/utils/log_service.dart';
import 'settings_group_title.dart';
import 'settings_item.dart';
import '../../../core/constants/app_colors.dart';

/// 游戏设置组件
class GameSettings extends StatefulWidget {
  final SettingsState settingsState;

  const GameSettings({super.key, required this.settingsState});

  @override
  State<GameSettings> createState() => _GameSettingsState();
}

class _GameSettingsState extends State<GameSettings> {
  final TextEditingController _customLaunchOptionController =
      TextEditingController();

  @override
  void dispose() {
    _customLaunchOptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '游戏设置',
          hasGlow: true,
          icon: MdiIcons.gamepadVariant,
        ),
        SettingsItem(label: '启动平台', control: _buildLaunchPlatformSelector()),
        SettingsItem(
          label: '游戏安装路径',
          control: _buildPathSelector(
            path: widget.settingsState.gamePath,
            placeholder:
                '例如: C:\\Program Files (x86)\\Steam\\steamapps\\common\\Counter-Strike Global Offensive',
            onDetect: () =>
                context.read<SettingsBloc>().add(SettingsDetectGamePath()),
            onSelect: _selectGamePath,
            isDetecting: widget.settingsState.isDetectingPath,
            errorMessage: widget.settingsState.gamePathError,
          ),
        ),
        SettingsItem(
          label: 'Steam安装路径',
          control: _buildPathSelector(
            path: widget.settingsState.steamPath,
            placeholder: '例如: C:\\Program Files (x86)\\Steam',
            onDetect: () =>
                context.read<SettingsBloc>().add(SettingsDetectSteamPath()),
            onSelect: _selectSteamPath,
            isDetecting: widget.settingsState.isDetectingPath,
            errorMessage: widget.settingsState.steamPathError,
          ),
        ),
        SettingsItem(
          label: '自定义启动选项',
          description: '选择预设选项或输入自定义启动参数',
          control: _buildLaunchOptionsControl(),
          alignTop: true,
        ),
        SettingsItem(
          label: '当前已选择的启动选项',
          control: _buildSelectedLaunchOptions(),
        ),
      ],
    );
  }

  Widget _buildLaunchPlatformSelector() {
    return Row(
      children: [
        _PlatformOption(
          icon: MdiIcons.steam,
          label: 'Steam平台',
          isSelected:
              widget.settingsState.launchPlatform ==
              LaunchPlatformType.worldwide,
          onTap: () => context.read<SettingsBloc>().add(
            const SettingsSetLaunchPlatform(LaunchPlatformType.worldwide),
          ),
        ),
        const SizedBox(width: 12),
        _PlatformOption(
          icon: MdiIcons.earth,
          label: '完美平台',
          isSelected:
              widget.settingsState.launchPlatform == LaunchPlatformType.perfect,
          onTap: () => context.read<SettingsBloc>().add(
            const SettingsSetLaunchPlatform(LaunchPlatformType.perfect),
          ),
        ),
      ],
    );
  }

  Widget _buildPathSelector({
    required String? path,
    required String placeholder,
    required VoidCallback onDetect,
    required VoidCallback onSelect,
    required bool isDetecting,
    String? errorMessage,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPath = path?.isNotEmpty == true;
    final hasError = errorMessage != null && errorMessage.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasError
                        ? Colors.red.withValues(alpha: 0.5)
                        : (isDark ? AppColors.slate600 : AppColors.slate200),
                  ),
                ),
                child: Text(
                  hasPath ? path! : placeholder,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasPath
                        ? (isDark ? Colors.white : AppColors.gray700)
                        : (isDark ? Colors.white38 : AppColors.gray400),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: isDetecting ? null : onDetect,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                foregroundColor: isDark ? Colors.white70 : null,
                side: BorderSide(
                  color: isDark ? AppColors.slate600 : AppColors.gray300,
                ),
              ),
              child: isDetecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('自动检测'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: onSelect,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                foregroundColor: isDark ? Colors.white70 : null,
                side: BorderSide(
                  color: isDark ? AppColors.slate600 : AppColors.gray300,
                ),
              ),
              child: const Text('选择路径'),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.alertCircleOutline,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _selectGamePath() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择游戏安装目录',
      );
      if (result != null && mounted) {
        context.read<SettingsBloc>().add(SettingsSetGamePath(result));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('游戏路径已设置'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      LogService.e('选择游戏路径失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('选择路径失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectSteamPath() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择Steam安装目录',
      );
      if (result != null && mounted) {
        context.read<SettingsBloc>().add(SettingsSetSteamPath(result));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Steam路径已设置'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      LogService.e('选择Steam路径失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('选择路径失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static const List<Map<String, String>> _availableLaunchOptions = [
    {'value': '-novid', 'label': '跳过开场动画 (-novid)'},
    {'value': '-high', 'label': '高优先级运行 (-high)'},
    {'value': '-nojoy', 'label': '禁用手柄支持 (-nojoy)'},
    {'value': '-fullscreen', 'label': '全屏模式 (-fullscreen)'},
    {'value': '-windowed', 'label': '窗口模式 (-windowed)'},
    {'value': '-noborder', 'label': '无边框窗口模式 (-noborder)'},
    {'value': '-freq 144', 'label': '144Hz刷新率 (-freq 144)'},
    {'value': '-freq 240', 'label': '240Hz刷新率 (-freq 240)'},
    {'value': '-vulkan', 'label': '使用Vulkan渲染 (-vulkan)'},
    {'value': '-dx11', 'label': '强制使用DirectX 11 (-dx11)'},
    {'value': '+fps_max 0', 'label': '解除帧率限制 (+fps_max 0)'},
    {'value': '+fps_max 240', 'label': '限制帧率240 (+fps_max 240)'},
    {'value': '+fps_max 300', 'label': '限制帧率300 (+fps_max 300)'},
    {'value': '-tickrate 128', 'label': '设置Tickrate为128 (-tickrate 128)'},
    {'value': '+cl_forcepreload 1', 'label': '强制预加载 (+cl_forcepreload 1)'},
    {'value': '+exec autoexec', 'label': '执行autoexec.cfg (+exec autoexec)'},
    {'value': '-allow_third_party_software', 'label': '允许第三方软件'},
  ];

  Widget _buildLaunchOptionsControl() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableLaunchOptions.map((option) {
            final isSelected = widget.settingsState.launchOptions.contains(
              option['value'],
            );
            return FilterChip(
              label: Text(
                option['label']!,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.gray700),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  context.read<SettingsBloc>().add(
                    SettingsAddLaunchOption(option['value']!),
                  );
                } else {
                  context.read<SettingsBloc>().add(
                    SettingsRemoveLaunchOption(option['value']!),
                  );
                }
              },
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              backgroundColor: isDark ? AppColors.slate700 : null,
              side: BorderSide(
                color: isDark ? AppColors.slate600 : AppColors.gray200,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customLaunchOptionController,
                decoration: InputDecoration(
                  hintText: '输入自定义启动参数，如 -w 1920 -h 1080',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : AppColors.gray400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.slate800 : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.slate600 : AppColors.gray200,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.slate600 : AppColors.gray200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.gray700,
                ),
                onSubmitted: _addCustomLaunchOption,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () =>
                  _addCustomLaunchOption(_customLaunchOptionController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '💡 提示：可以从上方选择常用选项，或在输入框中输入自定义参数后点击添加',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : AppColors.gray500,
          ),
        ),
      ],
    );
  }

  void _addCustomLaunchOption(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    context.read<SettingsBloc>().add(SettingsAddLaunchOption(trimmed));
    _customLaunchOptionController.clear();
  }

  Widget _buildSelectedLaunchOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.settingsState.launchOptions.isEmpty) {
      return Text(
        '暂无选择的启动选项',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white38 : AppColors.gray400,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: widget.settingsState.launchOptions.map((option) {
        return Chip(
          label: Text(
            option,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : AppColors.gray700,
            ),
          ),
          deleteIcon: Icon(
            Icons.close,
            size: 14,
            color: isDark ? Colors.white54 : AppColors.gray500,
          ),
          onDeleted: () => context.read<SettingsBloc>().add(
            SettingsRemoveLaunchOption(option),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: isDark ? AppColors.slate700 : null,
          side: BorderSide(
            color: isDark ? AppColors.slate600 : AppColors.gray200,
          ),
        );
      }).toList(),
    );
  }
}

class _PlatformOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlatformOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    const Color(0xFF00D4FF).withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? AppColors.slate700 : AppColors.gray50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.slate600 : AppColors.gray200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? AppColors.slate600 : AppColors.gray200)
                          .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white70 : AppColors.gray500),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white : AppColors.gray700),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(MdiIcons.checkCircle, size: 18, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
