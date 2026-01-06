import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/core.dart';
import '../widgets/page_layout.dart';
import '../widgets/selective_cache_dialog.dart';

/// 设置页面 - 桌面端
/// 使用 PageLayout 统一布局
class SettingsDesktop extends StatefulWidget {
  const SettingsDesktop({super.key});

  @override
  State<SettingsDesktop> createState() => _SettingsDesktopState();
}

class _SettingsDesktopState extends State<SettingsDesktop> {
  final TextEditingController _customLaunchOptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsBloc>().add(SettingsRefreshCacheSize());
      context.read<SettingsBloc>().add(SettingsLoadCacheDetails());
    });
  }

  @override
  void dispose() {
    _customLaunchOptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return PageLayout(
            title: '设置',
            subtitle: '自定义您的应用体验',
            headerActions: _buildHeaderActions(),
            child: _buildSettingsContent(settingsState),
          );
        },
      ),
    );
  }

  /// 头部操作按钮
  Widget _buildHeaderActions() {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return ElevatedButton.icon(
          onPressed: state.isLoading ? null : _saveSettings,
          icon: state.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(MdiIcons.contentSave, size: 18),
          label: const Text('保存设置'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0080FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      },
    );
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('设置已保存'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 设置内容区域
  Widget _buildSettingsContent(SettingsState settingsState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 外观设置
            _buildAppearanceSettingsGroup(settingsState),
            const SizedBox(height: 30),
            // 游戏设置
            _buildGameSettingsGroup(settingsState),
            const SizedBox(height: 30),
            // 应用设置
            _buildAppSettingsGroup(settingsState),
            const SizedBox(height: 30),
            // 缓存管理
            _buildCacheManagementGroup(settingsState),
            const SizedBox(height: 30),
            // 关于
            _buildAboutGroup(settingsState),
          ],
        ),
      ),
    );
  }

  // ==================== 设置组标题 ====================

  Widget _buildSettingsGroupTitle(String title, {bool hasGlow = false, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0080FF).withValues(alpha: 0.15),
                    const Color(0xFF0080FF).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF0080FF)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: -0.5,
                    shadows: hasGlow
                        ? [
                            Shadow(
                              color: const Color(0xFF0080FF).withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0080FF), Color(0xFF00D4FF)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 外观设置 ====================

  Widget _buildAppearanceSettingsGroup(SettingsState settingsState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsGroupTitle('外观设置', hasGlow: true, icon: MdiIcons.palette),
        _buildAppSettingItem(
          title: '主题模式',
          description: '选择应用的外观主题，可跟随系统或手动设置',
          value: _buildThemeModeSelector(settingsState, isDark),
          action: const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// 主题模式选择器
  Widget _buildThemeModeSelector(SettingsState settingsState, bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildThemeModeOption(
          icon: MdiIcons.themeLightDark,
          label: '跟随系统',
          isSelected: settingsState.themeMode == ThemeMode.system,
          isDark: isDark,
          onTap: () => context
              .read<SettingsBloc>()
              .add(const SettingsSetThemeMode(ThemeMode.system)),
        ),
        _buildThemeModeOption(
          icon: MdiIcons.weatherSunny,
          label: '浅色',
          isSelected: settingsState.themeMode == ThemeMode.light,
          isDark: isDark,
          onTap: () => context
              .read<SettingsBloc>()
              .add(const SettingsSetThemeMode(ThemeMode.light)),
        ),
        _buildThemeModeOption(
          icon: MdiIcons.weatherNight,
          label: '深色',
          isSelected: settingsState.themeMode == ThemeMode.dark,
          isDark: isDark,
          onTap: () => context
              .read<SettingsBloc>()
              .add(const SettingsSetThemeMode(ThemeMode.dark)),
        ),
      ],
    );
  }

  Widget _buildThemeModeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
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
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF0080FF)
                  : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
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
              Icon(MdiIcons.checkCircle, size: 16, color: const Color(0xFF0080FF)),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== 游戏设置 ====================

  Widget _buildGameSettingsGroup(SettingsState settingsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsGroupTitle('游戏设置', hasGlow: true, icon: MdiIcons.gamepadVariant),
        // 启动平台
        _buildSettingItem(
          label: '启动平台',
          control: _buildLaunchPlatformSelector(settingsState),
        ),
        // 游戏安装路径
        _buildSettingItem(
          label: '游戏安装路径',
          control: _buildPathSelector(
            path: settingsState.gamePath,
            placeholder: '例如: C:\\Program Files (x86)\\Steam\\steamapps\\common\\Counter-Strike Global Offensive',
            onDetect: () => context.read<SettingsBloc>().add(SettingsDetectGamePath()),
            onSelect: () => _selectGamePath(),
            isDetecting: settingsState.isDetectingPath,
            errorMessage: settingsState.gamePathError,
          ),
        ),
        // Steam安装路径
        _buildSettingItem(
          label: 'Steam安装路径',
          control: _buildPathSelector(
            path: settingsState.steamPath,
            placeholder: '例如: C:\\Program Files (x86)\\Steam',
            onDetect: () => context.read<SettingsBloc>().add(SettingsDetectSteamPath()),
            onSelect: () => _selectSteamPath(),
            isDetecting: settingsState.isDetectingPath,
            errorMessage: settingsState.steamPathError,
          ),
        ),
        // 自定义启动选项
        _buildSettingItem(
          label: '自定义启动选项',
          description: '选择预设选项或输入自定义启动参数',
          control: _buildLaunchOptionsControl(settingsState),
          alignTop: true,
        ),
        // 当前已选择的启动选项
        _buildSettingItem(
          label: '当前已选择的启动选项',
          control: _buildSelectedLaunchOptions(settingsState),
        ),
      ],
    );
  }

  /// 设置项布局
  Widget _buildSettingItem({
    required String label,
    String? description,
    required Widget control,
    bool alignTop = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF5F5F5), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          // 标签区域
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: alignTop ? 6 : 0),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF333333),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF666666),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 控件区域
          Expanded(child: control),
        ],
      ),
    );
  }

  /// 启动平台选择器
  Widget _buildLaunchPlatformSelector(SettingsState settingsState) {
    return Row(
      children: [
        _buildPlatformOption(
          icon: MdiIcons.steam,
          label: 'Steam平台',
          isSelected: settingsState.launchPlatform == LaunchPlatformType.worldwide,
          onTap: () => context.read<SettingsBloc>().add(
            const SettingsSetLaunchPlatform(LaunchPlatformType.worldwide),
          ),
        ),
        const SizedBox(width: 12),
        _buildPlatformOption(
          icon: MdiIcons.earth,
          label: '完美平台',
          isSelected: settingsState.launchPlatform == LaunchPlatformType.perfect,
          onTap: () => context.read<SettingsBloc>().add(
            const SettingsSetLaunchPlatform(LaunchPlatformType.perfect),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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
                    const Color(0xFF0080FF).withValues(alpha: 0.15),
                    const Color(0xFF00D4FF).withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF334155) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(12),
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
                    ? const Color(0xFF0080FF).withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB))
                        .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? const Color(0xFF0080FF)
                    : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0080FF)
                    : (isDark ? Colors.white : const Color(0xFF374151)),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(MdiIcons.checkCircle, size: 18, color: const Color(0xFF0080FF)),
            ],
          ],
        ),
      ),
    );
  }

  /// 路径选择器
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasError
                        ? Colors.red.withValues(alpha: 0.5)
                        : (isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Text(
                  hasPath ? path! : placeholder,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasPath
                        ? (isDark ? Colors.white : const Color(0xFF374151))
                        : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: isDetecting ? null : onDetect,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                foregroundColor: isDark ? Colors.white70 : null,
                side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
              ),
              child: isDetecting
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('自动检测'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: onSelect,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                foregroundColor: isDark ? Colors.white70 : null,
                side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
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
                  Icon(MdiIcons.alertCircleOutline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        Text(errorMessage, style: const TextStyle(fontSize: 12, color: Colors.red)),
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
      final result = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择游戏安装目录');
      if (result != null && mounted) {
        context.read<SettingsBloc>().add(SettingsSetGamePath(result));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('游戏路径已设置'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择路径失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectSteamPath() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择Steam安装目录');
      if (result != null && mounted) {
        context.read<SettingsBloc>().add(SettingsSetSteamPath(result));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Steam路径已设置'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择路径失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 常用启动选项列表
  static const List<Map<String, String>> _availableLaunchOptions = [
    {'value': '-novid', 'label': '跳过开场动画 (-novid)'},
    {'value': '-console', 'label': '启动时打开控制台 (-console)'},
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

  Widget _buildLaunchOptionsControl(SettingsState settingsState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableLaunchOptions.map((option) {
            final isSelected = settingsState.launchOptions.contains(option['value']);
            return FilterChip(
              label: Text(
                option['label']!,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF374151)),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  context.read<SettingsBloc>().add(SettingsAddLaunchOption(option['value']!));
                } else {
                  context.read<SettingsBloc>().add(SettingsRemoveLaunchOption(option['value']!));
                }
              },
              selectedColor: const Color(0xFF0080FF),
              checkmarkColor: Colors.white,
              backgroundColor: isDark ? const Color(0xFF334155) : null,
              side: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // 手动输入框
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customLaunchOptionController,
                decoration: InputDecoration(
                  hintText: '输入自定义启动参数，如 -w 1920 -h 1080',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0080FF)),
                  ),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF374151),
                ),
                onSubmitted: _addCustomLaunchOption,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _addCustomLaunchOption(_customLaunchOptionController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0080FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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

  Widget _buildSelectedLaunchOptions(SettingsState settingsState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (settingsState.launchOptions.isEmpty) {
      return Text(
        '暂无选择的启动选项',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: settingsState.launchOptions.map((option) {
        return Chip(
          label: Text(
            option,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
          ),
          deleteIcon: Icon(
            Icons.close,
            size: 14,
            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
          ),
          onDeleted: () =>
              context.read<SettingsBloc>().add(SettingsRemoveLaunchOption(option)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: isDark ? const Color(0xFF334155) : null,
          side: BorderSide(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
          ),
        );
      }).toList(),
    );
  }

  // ==================== 应用设置 ====================

  Widget _buildAppSettingsGroup(SettingsState settingsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsGroupTitle('应用设置', hasGlow: true, icon: MdiIcons.cog),
        // 启动动画设置
        _buildAppSettingItem(
          title: '启动动画',
          description: '控制应用启动时是否显示logo动画效果',
          action: Switch(
            value: settingsState.enableStartupAnimation,
            onChanged: (value) {
              context.read<SettingsBloc>().add(SettingsSetStartupAnimation(value));
            },
            activeColor: const Color(0xFF0080FF),
          ),
        ),
        // 音效音量设置
        _buildAppSettingItem(
          title: '挤服成功音效音量',
          description: '调节挤服成功时播放音效的音量大小',
          value: _buildVolumeSlider(settingsState),
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

  /// 应用设置项布局
  Widget _buildAppSettingItem({
    required String title,
    required String description,
    Widget? value,
    required Widget action,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                : [const Color(0xFFFAFBFC), const Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 标签区域
            SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // 值区域
            if (value != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: value,
                ),
              ),
            // 操作区域
            action,
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeSlider(SettingsState settingsState) {
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

  // ==================== 缓存管理 ====================

  Widget _buildCacheManagementGroup(SettingsState settingsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsGroupTitle('缓存管理', icon: MdiIcons.database),
        // 缓存信息网格
        _buildCacheInfoGrid(settingsState),
        const SizedBox(height: 15),
        // 缓存说明
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF3B82F6), width: 4)),
          ),
          child: const Text(
            '💡 统计包括缓存数据库、应用数据、临时文件和日志文件。定期清理可以释放磁盘空间。所有数据现在保存在用户目录下，不会因为应用更新而丢失。您可以选择性清理不同类型的内容。',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  /// 缓存信息网格
  Widget _buildCacheInfoGrid(SettingsState settingsState) {
    final totalSize = settingsState.cacheDetails.isNotEmpty
        ? settingsState.formattedTotalCacheSize
        : settingsState.cacheSize;

    return Column(
      children: [
        // 缓存大小
        _buildCacheInfoItem(
          icon: MdiIcons.harddisk,
          iconColor: const Color(0xFF0080FF),
          label: '缓存大小',
          value: settingsState.isLoadingCacheDetails
              ? const Text('计算中...', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)))
              : Text(
                  totalSize,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0080FF)),
                ),
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOutlinedButton(
                onPressed: settingsState.isLoadingCacheDetails || settingsState.cacheDetails.isEmpty
                    ? null
                    : () => _openSelectiveCacheDialog(settingsState),
                label: '选择性清理',
                icon: MdiIcons.filterVariant,
              ),
              const SizedBox(width: 8),
              _buildDangerButton(
                onPressed: settingsState.isLoading ? null : _clearAllCache,
                label: '清理缓存',
                icon: MdiIcons.deleteOutline,
                isLoading: settingsState.isLoading,
              ),
            ],
          ),
        ),
        // 缓存项数量
        _buildCacheInfoItem(
          icon: MdiIcons.packageVariant,
          iconColor: const Color(0xFF10B981),
          label: '缓存项数量',
          value: settingsState.isLoadingCacheDetails
              ? const Text('统计中...', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)))
              : Text(
                  '${settingsState.cacheDetails.length} 个缓存类型',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                ),
          action: _buildOutlinedButton(
            onPressed: settingsState.isLoadingCacheDetails
                ? null
                : () => context.read<SettingsBloc>().add(SettingsLoadCacheDetails()),
            label: '刷新',
            icon: MdiIcons.refresh,
            isLoading: settingsState.isLoadingCacheDetails,
          ),
        ),
      ],
    );
  }

  /// 统一的轮廓按钮样式
  Widget _buildOutlinedButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white70 : const Color(0xFF374151),
        side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// 统一的危险按钮样式
  Widget _buildDangerButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  /// 统一的主要按钮样式
  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0080FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  /// 缓存信息项
  Widget _buildCacheInfoItem({
    required String label,
    required Widget value,
    required Widget action,
    IconData? icon,
    Color? iconColor,
  }) {
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

  void _openSelectiveCacheDialog(SettingsState settingsState) {
    SelectiveCacheDialog.show(
      context,
      cacheDetails: settingsState.cacheDetails,
      onConfirm: (selectedTypes) {
        context.read<SettingsBloc>().add(SettingsClearSelectedCache(selectedTypes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已清除 ${selectedTypes.length} 种缓存'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  void _clearAllCache() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.deleteAlertOutline, color: Colors.red),
            const SizedBox(width: 8),
            const Text('清除所有缓存'),
          ],
        ),
        content: const Text('确定要清除所有缓存吗？这将删除临时文件和服务器列表缓存，不会影响您的设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SettingsBloc>().add(SettingsClearAllCache());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('所有缓存已清除'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('确定清除'),
          ),
        ],
      ),
    );
  }

  // ==================== 关于 ====================

  Widget _buildAboutGroup(SettingsState settingsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsGroupTitle('关于', icon: MdiIcons.informationOutline),
        // 版本信息
        _buildUpdateInfoGrid(settingsState),
        const SizedBox(height: 15),
        // 更新说明
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

  /// 更新信息网格
  Widget _buildUpdateInfoGrid(SettingsState settingsState) {
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
            // 当前版本
            _buildUpdateInfoItem(
              icon: MdiIcons.tagOutline,
              iconColor: const Color(0xFF0080FF),
              label: '当前版本',
              value: Text(
                'v${settingsState.appVersion.isNotEmpty ? settingsState.appVersion : AppConstants.appVersion}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0080FF)),
              ),
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPrimaryButton(
                    onPressed: updateState.isChecking ? null : _checkForUpdates,
                    label: updateState.isChecking ? '检查中...' : '检查更新',
                    icon: MdiIcons.refresh,
                    isLoading: updateState.isChecking,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 更新信息项
  Widget _buildUpdateInfoItem({
    required String label,
    required Widget value,
    required Widget action,
    IconData? icon,
    Color? iconColor,
  }) {
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

  void _checkForUpdates() {
    context.read<UpdateBloc>().add(UpdateCheck());
  }
}
