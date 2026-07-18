import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/widgets/image_viewer_dialog.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/game_path_service.dart';

class WorkshopMissingDialog extends StatefulWidget {
  final String reason;

  const WorkshopMissingDialog({super.key, required this.reason});

  static Future<void> checkAndShow(BuildContext context) async {
    final reason = await _checkWorkshopItem();
    if (reason != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WorkshopMissingDialog(reason: reason),
      );
    }
  }

  static Future<String?> _checkWorkshopItem() async {
    const String workshopId = '3191706064';
    try {
      final steamappsPath = await GamePathService().getSteamappsPath();
      if (steamappsPath != null && steamappsPath.isNotEmpty) {
        final dirPath =
            '$steamappsPath\\workshop\\content\\730\\$workshopId';
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          return '未检测到 ZED Addons 必备组件 (ID: $workshopId)。';
        }

        // 检查大小
        int totalSize = 0;
        await for (final file in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (file is File) {
            totalSize += await file.length();
            if (totalSize >= 1024 * 1024) {
              return null; // 只要超过 1MB 就认为正常，停止遍历节省性能
            }
          }
        }

        // 如果小于 1MB，认为大小异常
        if (totalSize < 1024 * 1024) {
          return 'ZED Addons 组件大小异常（不足 1MB），可能下载未完成或文件已损坏。';
        }
      }
    } catch (e) {
      // ignore
    }
    return null; // 正常
  }

  @override
  State<WorkshopMissingDialog> createState() => _WorkshopMissingDialogState();
}

class _WorkshopMissingDialogState extends State<WorkshopMissingDialog> {
  Timer? _timer;
  bool _isChecking = false;
  bool _isImageHovering = false;

  @override
  void initState() {
    super.initState();
    // 弹窗出现后自动轮询，一旦正常则自动关闭
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _doCheck();
    });
  }

  Future<void> _doCheck() async {
    if (_isChecking) return;
    _isChecking = true;
    final reason = await WorkshopMissingDialog._checkWorkshopItem();
    if (reason == null && mounted) {
      Navigator.of(context).pop(); // 下载完成，自动关闭
    }
    _isChecking = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openWorkshop() {
    launchUrlString(
      'steam://openurl/https://steamcommunity.com/sharedfiles/filedetails/?id=3191706064',
    );
  }

  Widget _buildTutorialStep(String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.blue500.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.blue500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '缺少 ZED Addons 必备组件',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '本社区服务器依赖此创意工坊内容',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.reason,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '订阅教程：',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _buildTutorialStep('1', '点击下方「前往订阅」按钮，将唤起您的 Steam 客户端。'),
          _buildTutorialStep('2', '在打开的创意工坊页面中，找到并点击绿色的【订阅】按钮。'),
          Padding(
            padding: const EdgeInsets.only(left: 26.0, bottom: 8.0, right: 8.0),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isImageHovering = true),
              onExit: (_) => setState(() => _isImageHovering = false),
              child: GestureDetector(
                onTap: () => ImageViewerDialog.show(
                  context,
                  imageUrls: ['assets/images/tutorials/zed_addons_subscribe_guide.png'],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/images/tutorials/zed_addons_subscribe_guide.png',
                          fit: BoxFit.contain,
                        ),
                        if (_isImageHovering)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.3),
                              child: const Icon(
                                Icons.zoom_in_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildTutorialStep('3', '观察 Steam 底部下载进度，耐心等待游戏资源下载完毕。'),
          _buildTutorialStep('4', '下载完成后，本弹窗会自动检测并关闭，无需手动操作。'),
        ],
      ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('稍后再说', style: TextStyle(color: Colors.grey)),
        ),
        FilledButton.icon(
          onPressed: _openWorkshop,
          icon: Icon(MdiIcons.steam, size: 18),
          label: const Text('前往订阅 / 查看进度'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
