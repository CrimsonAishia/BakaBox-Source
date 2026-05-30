import 'package:flutter/material.dart';
import '../../core/models/server_models.dart';
import '../../core/utils/category_utils.dart';

/// 服务器分类卡片组件
/// 显示分类图标、名称、服务器数量和在线人数
///
/// Requirements: 2.1, 2.2, 2.3
class CategoryCard extends StatelessWidget {
  final ServerCategory category;
  final bool isSelected;
  final int onlineCount;
  final bool isLoadingOnlineCount;
  final VoidCallback? onTap;
  final VoidCallback? onDelete; // 删除回调（仅自定义分类）
  final VoidCallback? onEdit; // 编辑回调（仅自定义分类）

  const CategoryCard({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onlineCount = 0,
    this.isLoadingOnlineCount = false,
    this.onTap,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = CategoryUtils.getCategoryColor(category.category);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: categoryColor, width: 2)
            : Border.all(
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFE5E7EB),
                width: 1,
              ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: categoryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: isDark
              ? const Color(0xFF475569)
              : const Color(0xFFF3F4F6),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 分类图标
                _buildCategoryIcon(categoryColor),
                const SizedBox(width: 15),
                // 分类信息
                Expanded(child: _buildCategoryInfo(isDark)),
                // 在线人数（自定义分类不显示）
                if (!category.isCustom) _buildOnlineCount(),
                // 编辑按钮（仅自定义分类）
                if (category.isCustom && onEdit != null) ...[
                  const SizedBox(width: 8),
                  _buildEditButton(context, isDark),
                ],
                // 删除按钮（仅自定义分类）
                if (category.isCustom && onDelete != null) ...[
                  const SizedBox(width: 4),
                  _buildDeleteButton(context, isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建编辑按钮
  Widget _buildEditButton(BuildContext context, bool isDark) {
    return Tooltip(
      message: '编辑分类',
      child: InkWell(
        onTap: () => onEdit?.call(),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.edit_outlined,
            size: 18,
            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  /// 构建删除按钮
  Widget _buildDeleteButton(BuildContext context, bool isDark) {
    return Tooltip(
      message: '删除分类',
      child: InkWell(
        onTap: () => _showDeleteConfirmDialog(context),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: const Icon(
            Icons.delete_outline,
            size: 18,
            color: Color(0xFFEF4444),
          ),
        ),
      ),
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除分类 "${category.modelName}" 吗？\n该分类下的所有服务器也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 构建分类图标
  Widget _buildCategoryIcon(Color categoryColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: category.isFromApi
            ? const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : CategoryUtils.getCategoryGradient(category.category),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        category.isFromApi
            ? Icons.api_rounded // 或者使用 Icons.language_rounded 🌐
            : CategoryUtils.getCategoryIcon(category.modelName),
        color: Colors.white,
        size: 22,
      ),
    );
  }

  /// 构建分类信息（名称和服务器数量）
  Widget _buildCategoryInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 分类名称（允许最多三行）
        Text(
          category.modelName ?? '未知分类',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontSize: 15,
            height: 1.2,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // 服务器数量
        Text(
          '${category.serverList.length}个服务器',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  /// 构建在线人数标签
  Widget _buildOnlineCount() {
    // 显示加载动画（由外部传入的 isLoadingOnlineCount 控制）
    if (isLoadingOnlineCount) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF9CA3AF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const SizedBox(
          width: 50,
          height: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9CA3AF)),
                ),
              ),
              SizedBox(width: 4),
              Text(
                '加载中',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isZeroOnline = onlineCount == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isZeroOnline
            ? const Color(0xFF9CA3AF).withValues(alpha: 0.1)
            : const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$onlineCount在线',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isZeroOnline
              ? const Color(0xFF9CA3AF)
              : const Color(0xFF10B981),
          fontSize: 13,
        ),
      ),
    );
  }
}
