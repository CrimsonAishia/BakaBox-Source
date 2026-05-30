import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/utils/log_service.dart';

class PathInvalidDialog extends StatelessWidget {
  const PathInvalidDialog({super.key});

  @override
  Widget build(BuildContext context) {
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
                Row(
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
                          const Text(
                            '游戏路径已失效',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          BlocBuilder<SettingsBloc, SettingsState>(
                            builder: (context, state) {
                              return Text(
                                state.pathValidationMessage ??
                                    '由于目录移动或磁盘更换，您之前设置的 CS2 或 Steam 路径已失效。请重新配置以确保核心服务正常运行。',
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
                  ],
                ),
                const SizedBox(height: 32),
                BlocBuilder<SettingsBloc, SettingsState>(
                  builder: (context, state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: 20),
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
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: BlocBuilder<SettingsBloc, SettingsState>(
                    builder: (context, state) {
                      return FilledButton(
                        onPressed: () {
                          // 手动触发一次校验，如果成功通过，BlocListener会自动关闭弹窗
                          context.read<SettingsBloc>().add(
                            SettingsCheckPathsValidity(),
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '保存并重试',
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
