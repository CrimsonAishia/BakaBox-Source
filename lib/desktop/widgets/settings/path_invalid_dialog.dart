import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/utils/log_service.dart';
import '../../../core/widgets/skip_warning_dialog.dart';

class PathInvalidDialog extends StatelessWidget {
  const PathInvalidDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 监听 SettingsBloc 的状态，如果 isPathInvalidated 变为 false，则自动关闭弹窗
    return BlocListener<SettingsBloc, SettingsState>(
      listenWhen: (previous, current) =>
          previous.isPathInvalidated && !current.isPathInvalidated,
      listener: (context, state) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: PopScope(
        // 阻止返回键关闭弹窗
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：标题区 + 右上角跳过按钮（OOBE 风格）
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        MdiIcons.alertCircleOutline,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocBuilder<SettingsBloc, SettingsState>(
                            buildWhen: (p, c) =>
                                p.isGamePathInvalid != c.isGamePathInvalid ||
                                p.isSteamPathInvalid != c.isSteamPathInvalid,
                            builder: (context, state) {
                              return Text(
                                _buildTitle(state),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          BlocBuilder<SettingsBloc, SettingsState>(
                            buildWhen: (p, c) =>
                                p.pathValidationMessage !=
                                c.pathValidationMessage,
                            builder: (context, state) {
                              return Text(
                                state.pathValidationMessage ??
                                    '由于目录移动或磁盘更换，您之前设置的路径已失效。请重新配置以确保核心服务正常运行。',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // 右上角跳过按钮（OOBE 顶部跳过按钮同款样式）
                    TextButton(
                      onPressed: () => _confirmAndSkip(context),
                      child: Text(
                        '跳过',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                BlocBuilder<SettingsBloc, SettingsState>(
                  // 仅当具体失效项变化时重建，避免无关 state 变更（如音量调整）触发重绘
                  buildWhen: (previous, current) =>
                      previous.isGamePathInvalid != current.isGamePathInvalid ||
                      previous.isSteamPathInvalid !=
                          current.isSteamPathInvalid ||
                      previous.gamePath != current.gamePath ||
                      previous.steamPath != current.steamPath ||
                      previous.gamePathError != current.gamePathError ||
                      previous.steamPathError != current.steamPathError ||
                      previous.isDetectingPath != current.isDetectingPath,
                  builder: (context, state) {
                    final selectors = <Widget>[];

                    if (state.isGamePathInvalid) {
                      selectors.add(
                        _PathSelector(
                          label: '游戏安装路径',
                          path: state.gamePath,
                          placeholder:
                              '例如: C:\\Program Files (x86)\\Steam\\steamapps\\common\\Counter-Strike Global Offensive',
                          onDetect: () => context.read<SettingsBloc>().add(
                            SettingsDetectGamePath(),
                          ),
                          onSelect: () => _selectGamePath(context),
                          isDetecting: state.isDetectingPath,
                          errorMessage: state.gamePathError,
                        ),
                      );
                    }

                    if (state.isSteamPathInvalid) {
                      if (selectors.isNotEmpty) {
                        selectors.add(const SizedBox(height: 20));
                      }
                      selectors.add(
                        _PathSelector(
                          label: 'Steam安装路径',
                          path: state.steamPath,
                          placeholder: '例如: C:\\Program Files (x86)\\Steam',
                          onDetect: () => context.read<SettingsBloc>().add(
                            SettingsDetectSteamPath(),
                          ),
                          onSelect: () => _selectSteamPath(context),
                          isDetecting: state.isDetectingPath,
                          errorMessage: state.steamPathError,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: selectors,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        MdiIcons.informationOutline,
                        color: Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '选择有效路径后将自动关闭此弹窗，无需手动确认。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 根据失效项动态构造标题
  String _buildTitle(SettingsState state) {
    if (state.isGamePathInvalid && state.isSteamPathInvalid) {
      return '游戏路径与 Steam 路径已失效';
    }
    if (state.isGamePathInvalid) {
      return '游戏路径已失效';
    }
    if (state.isSteamPathInvalid) {
      return 'Steam 路径已失效';
    }
    // 兜底：理论上不会出现（弹窗不会在两者都有效时显示）
    return '路径已失效';
  }

  /// 弹出 OOBE 同款警告弹窗，确认后清空所有失效路径
  Future<void> _confirmAndSkip(BuildContext context) async {
    final state = context.read<SettingsBloc>().state;
    if (!state.isGamePathInvalid && !state.isSteamPathInvalid) return;

    // 根据失效项动态生成标题与影响列表
    final brokenPaths = <String>[];
    if (state.isGamePathInvalid) brokenPaths.add('游戏路径');
    if (state.isSteamPathInvalid) brokenPaths.add('Steam 路径');

    final confirmed = await SkipWarningDialog.show(
      context,
      title: '跳过${brokenPaths.join("与")}设置？',
      description: '清空失效路径后，以下功能将无法使用：',
      items: [
        SkipWarningItem(
          icon: MdiIcons.rocketLaunchOutline,
          text: '一键加入服务器',
        ),
        SkipWarningItem(
          icon: MdiIcons.accountGroupOutline,
          text: '自动挤服 / 控制台监控',
        ),
        SkipWarningItem(icon: MdiIcons.cogOutline, text: '自动配置游戏参数'),
      ],
      hint: '你可以稍后在「设置 → 游戏设置」中重新配置。',
    );

    if (!confirmed || !context.mounted) return;

    final bloc = context.read<SettingsBloc>();
    if (state.isGamePathInvalid) {
      bloc.add(SettingsClearGamePath());
    }
    if (state.isSteamPathInvalid) {
      bloc.add(SettingsClearSteamPath());
    }
    // SettingsClearGamePath/SteamPath 内部已经会触发 SettingsCheckPathsValidity，
    // 校验通过后 BlocListener 会自动关闭本弹窗。
  }

  Future<void> _selectGamePath(BuildContext context) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择游戏安装目录',
      );
      if (result != null && context.mounted) {
        context.read<SettingsBloc>().add(SettingsSetGamePath(result));
      }
    } catch (e) {
      LogService.e('选择游戏路径失败', e);
    }
  }

  Future<void> _selectSteamPath(BuildContext context) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择Steam安装目录',
      );
      if (result != null && context.mounted) {
        context.read<SettingsBloc>().add(SettingsSetSteamPath(result));
      }
    } catch (e) {
      LogService.e('选择Steam路径失败', e);
    }
  }
}

class _PathSelector extends StatelessWidget {
  final String label;
  final String? path;
  final String placeholder;
  final VoidCallback onDetect;
  final VoidCallback onSelect;
  final bool isDetecting;
  final String? errorMessage;

  const _PathSelector({
    required this.label,
    required this.path,
    required this.placeholder,
    required this.onDetect,
    required this.onSelect,
    required this.isDetecting,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPath = path?.isNotEmpty == true;
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasError
                        ? Colors.red.withValues(alpha: 0.5)
                        : (isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFE2E8F0)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
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
                  vertical: 14,
                ),
              ),
              child: const Text('手动选择'),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }
}
