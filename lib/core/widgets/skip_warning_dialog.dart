import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../constants/app_colors.dart';

/// 跳过警告项（用于 [SkipWarningDialog] 列出受影响的功能）
class SkipWarningItem {
  final IconData icon;
  final String text;
  const SkipWarningItem({required this.icon, required this.text});
}

/// 通用的"跳过"二次确认弹窗
///
/// 当用户尝试跳过某个必填配置（如游戏路径、Steam 路径等）时使用，
/// 用于提示跳过后会失去哪些能力，并要求用户二次确认。
///
/// 使用方法：
/// ```dart
/// final confirmed = await SkipWarningDialog.show(
///   context,
///   title: '跳过游戏路径设置？',
///   description: '未设置游戏路径将导致以下功能无法使用：',
///   items: const [
///     SkipWarningItem(icon: Icons.rocket, text: '一键加入服务器'),
///   ],
///   hint: '你可以稍后在「设置」中配置游戏路径。',
/// );
/// ```
class SkipWarningDialog extends StatelessWidget {
  final String title;
  final String description;
  final List<SkipWarningItem> items;
  final String? hint;
  final String confirmText;
  final String cancelText;

  const SkipWarningDialog({
    super.key,
    required this.title,
    required this.description,
    required this.items,
    this.hint,
    this.confirmText = '仍然跳过',
    this.cancelText = '返回设置',
  });

  /// 静态便捷方法，返回 true 表示用户确认跳过，false 或 null 表示取消
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String description,
    required List<SkipWarningItem> items,
    String? hint,
    String confirmText = '仍然跳过',
    String cancelText = '返回设置',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => SkipWarningDialog(
        title: title,
        description: description,
        items: items,
        hint: hint,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.slate800 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.amber500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              MdiIcons.alertCircleOutline,
              color: AppColors.amber500,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.white : AppColors.slate800,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : AppColors.slate500,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(items.length, (index) {
            final item = items[index];
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
              child: _WarningItemRow(
                icon: item.icon,
                text: item.text,
                isDark: isDark,
              ),
            );
          }),
          if (hint != null) ...[
            const SizedBox(height: 16),
            Text(
              hint!,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : AppColors.slate400,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.slate500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.amber500,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

class _WarningItemRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _WarningItemRow({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.red500),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : AppColors.gray700,
          ),
        ),
      ],
    );
  }
}
