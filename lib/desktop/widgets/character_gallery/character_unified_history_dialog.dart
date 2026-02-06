import 'package:flutter/material.dart';
import '../../../core/api/character_api.dart';
import '../../../core/models/character_models.dart';
import '../../../core/utils/formatters.dart';
import 'character_gallery_theme.dart';

/// 统一编辑历史对话框 - 日式卷轴风格
class UnifiedHistoryDialog extends StatefulWidget {
  final int subModelId;
  final String characterName;
  final String subModelName;
  final CharacterCategory category;

  const UnifiedHistoryDialog({
    super.key,
    required this.subModelId,
    required this.characterName,
    required this.subModelName,
    required this.category,
  });

  @override
  State<UnifiedHistoryDialog> createState() => _UnifiedHistoryDialogState();
}

class _UnifiedHistoryDialogState extends State<UnifiedHistoryDialog> {
  final CharacterApi _api = CharacterApi();
  List<UnifiedEditHistoryItem> _historyItems = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _total = 0;
  static const int _pageSize = 15;

  EditTargetType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.getUnifiedEditHistory(
        subModelId: widget.subModelId,
        pageIndex: _currentPage,
        pageSize: _pageSize,
      );

      if (response != null) {
        setState(() {
          _historyItems = response.list;
          _total = response.total;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '获取编辑历史失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  List<UnifiedEditHistoryItem> get _filteredItems {
    if (_filterType == null) return _historyItems;
    return _historyItems
        .where((item) => item.targetType == _filterType)
        .toList();
  }

  // 将历史记录按申请分组（同一个申请的多个修改合并）
  List<List<UnifiedEditHistoryItem>> get _groupedItems {
    final filtered = _filteredItems;
    final Map<String, List<UnifiedEditHistoryItem>> grouped = {};

    for (final item in filtered) {
      // 使用 editorId + editedAt + version 作为分组键（同一个申请）
      // 注意：editReason 可能为空，所以不用它作为分组键
      final key = '${item.editorId}_${item.editedAt}_${item.version}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped.values.toList();
  }

  String _getTargetTypeLabel(EditTargetType type) {
    return switch (type) {
      EditTargetType.subModel => '基本信息',
      EditTargetType.spellCard => '符卡',
      EditTargetType.zombieSkill => '技能',
    };
  }

  Color _getTargetTypeColor(BuildContext context, EditTargetType type) {
    return switch (type) {
      EditTargetType.subModel => CharacterGalleryTheme.getScrollBrown(context),
      EditTargetType.spellCard => CharacterGalleryTheme.getVermillion(context),
      EditTargetType.zombieSkill => const Color(0xFF4A7C59),
    };
  }

  IconData _getTargetTypeIcon(EditTargetType type) {
    return switch (type) {
      EditTargetType.subModel => Icons.person_outline_rounded,
      EditTargetType.spellCard => Icons.auto_awesome,
      EditTargetType.zombieSkill => Icons.flash_on_rounded,
    };
  }

  String _getFieldLabel(String field) {
    return switch (field) {
      'create' => '创建',
      'delete' => '删除',
      'description' => '描述',
      'damage' => '伤害',
      'cooldown' => '冷却',
      'cost' => '消耗',
      'range' => '范围',
      'special' => '特殊效果',
      'tips' => '提示',
      'acquisition' => '获取方式',
      'acquisition_type' => '获取类型',
      'acquisition_cost' => '获取价格',
      'custom_source' => '自定义来源',
      'name' => '名称',
      'type' => '类型',
      'tier' => '评级',
      _ => field,
    };
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 650,
        height: 580,
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scrollBrown, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilterBar(context),
            Expanded(child: _buildContent(context)),
            if (_total > _pageSize) _buildPagination(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scrollBrown.withValues(alpha: 0.08), washiColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '编辑历史',
              style: TextStyle(
                color: inkColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          if (_total > 0)
            Builder(
              builder: (context) {
                final vermillion = CharacterGalleryTheme.getVermillion(context);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: vermillion.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: vermillion.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 14, color: vermillion),
                      const SizedBox(width: 4),
                      Text(
                        '$_total 条',
                        style: TextStyle(
                          color: vermillion,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: scrollBrown),
            tooltip: '关闭',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final isTouhou = widget.category == CharacterCategory.touhou;
    final isZombie = widget.category == CharacterCategory.zombie;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _buildFilterChip(context, '全部', null, Icons.list_alt_rounded),
          _buildFilterChip(
            context,
            '基本信息',
            EditTargetType.subModel,
            Icons.person_outline_rounded,
          ),
          if (isTouhou)
            _buildFilterChip(
              context,
              '符卡',
              EditTargetType.spellCard,
              Icons.auto_awesome,
            ),
          if (isZombie)
            _buildFilterChip(
              context,
              '技能',
              EditTargetType.zombieSkill,
              Icons.flash_on_rounded,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    EditTargetType? type,
    IconData icon,
  ) {
    final isSelected = _filterType == type;
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final color = type != null
        ? _getTargetTypeColor(context, type)
        : vermillion;
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _filterType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? color : inkColor.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? color : inkColor.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: vermillion,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '加载中...',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: vermillion.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: vermillion.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _loadHistory,
              icon: Icon(Icons.refresh_rounded, size: 16, color: vermillion),
              label: Text(
                '重试',
                style: TextStyle(
                  color: vermillion,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final groupedItems = _groupedItems;
    if (groupedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scrollBrown.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Text('📜', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 14),
            Text(
              _filterType == null ? '暂无编辑记录' : '该分类暂无记录',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.45),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupedItems.length,
      itemBuilder: (context, index) =>
          _buildHistoryCard(context, groupedItems[index], index),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    List<UnifiedEditHistoryItem> items,
    int index,
  ) {
    // 使用第一个项目作为代表获取公共信息
    final firstItem = items.first;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片头部 - 编辑者和时间
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: scrollBrown.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scrollBrown.withValues(alpha: 0.1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      (firstItem.editorAvatar != null &&
                          firstItem.editorAvatar!.isNotEmpty)
                      ? Image.network(
                          firstItem.editorAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: scrollBrown.withValues(alpha: 0.6),
                          ),
                        )
                      : Icon(
                          Icons.edit_outlined,
                          size: 12,
                          color: scrollBrown.withValues(alpha: 0.6),
                        ),
                ),
                Text(
                  firstItem.editorName ?? '用户${firstItem.editorId}',
                  style: TextStyle(
                    color: inkColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  Formatters.formatDate(firstItem.editedAt),
                  style: TextStyle(
                    color: inkColor.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // 卡片内容 - 扁平化显示所有修改
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    if (idx > 0) const SizedBox(height: 12),
                    _buildFlatChangeItem(context, item),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 扁平化的修改项
  Widget _buildFlatChangeItem(
    BuildContext context,
    UnifiedEditHistoryItem item,
  ) {
    final typeColor = _getTargetTypeColor(context, item.targetType);
    final typeIcon = _getTargetTypeIcon(item.targetType);
    final isCreate = item.fieldChanged == 'create';
    final isDelete = item.fieldChanged == 'delete';
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final isSubModel = item.targetType == EditTargetType.subModel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行：图标 + 类型 + 子类型标签 + 名称 + 字段 + 操作标签
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(typeIcon, size: 14, color: typeColor),
            const SizedBox(width: 6),
            Text(
              _getTargetTypeLabel(item.targetType),
              style: TextStyle(
                color: typeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 符卡类型标签
            if (item.targetType == EditTargetType.spellCard &&
                item.spellCardType != null) ...[
              const SizedBox(width: 6),
              _buildSubTypeBadge(context, item.spellCardType!),
            ],
            // 僵尸技能类型标签
            if (item.targetType == EditTargetType.zombieSkill &&
                item.zombieSkillType != null) ...[
              const SizedBox(width: 6),
              _buildSubTypeBadge(context, item.zombieSkillType!),
            ],
            if (!isSubModel && item.targetName != null) ...[
              Text(
                ' · ',
                style: TextStyle(
                  color: inkColor.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
              Flexible(
                child: Text(
                  item.targetName!,
                  style: TextStyle(
                    color: inkColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (!isCreate && !isDelete) ...[
              Text(
                ' · ',
                style: TextStyle(
                  color: inkColor.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
              Text(
                _getFieldLabel(item.fieldChanged),
                style: TextStyle(
                  color: vermillion.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (isCreate || isDelete) ...[
              const SizedBox(width: 6),
              _buildActionBadge(
                isCreate ? '新增' : '删除',
                isCreate ? const Color(0xFF4A7C59) : Colors.red.shade600,
              ),
            ],
          ],
        ),
        // 变更内容
        if (!isCreate &&
            !isDelete &&
            (item.oldValue != null || item.newValue != null)) ...[
          const SizedBox(height: 8),
          _buildCompactChangeDetail(context, item),
        ],
      ],
    );
  }

  /// 子类型标签（符卡类型或技能类型）
  Widget _buildSubTypeBadge(BuildContext context, String subType) {
    final (String label, Color color) = _getSubTypeInfo(context, subType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 获取子类型信息（标签和颜色）
  (String, Color) _getSubTypeInfo(BuildContext context, String subType) {
    final gold = CharacterGalleryTheme.getGold(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return switch (subType) {
      'ultimate' => ('大符卡', gold),
      'passive' => ('被动', const Color(0xFF4A7C59)),
      'normal' => ('小符卡', vermillion),
      'active' => ('主动', vermillion),
      _ => (subType, CharacterGalleryTheme.getScrollBrown(context)),
    };
  }

  // 格式化显示值
  String _formatValueDisplay(String field, String? value) {
    if (value == null || value.isEmpty) return '(空)';

    if (field == 'tier') {
      return switch (value.toLowerCase()) {
        'unranked' => '未评级',
        't0' => 'T0 - 最强',
        't1' => 'T1 - 强力',
        't2' => 'T2 - 优秀',
        't3' => 'T3 - 中等',
        't4' => 'T4 - 一般',
        't5' => 'T5 - 较弱',
        _ => value,
      };
    }
    return value;
  }

  // 紧凑的变更详情
  Widget _buildCompactChangeDetail(
    BuildContext context,
    UnifiedEditHistoryItem item,
  ) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final oldValue = _formatValueDisplay(item.fieldChanged, item.oldValue);
    final newValue = _formatValueDisplay(item.fieldChanged, item.newValue);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scrollBrown.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 旧值
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: inkColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '旧',
                  style: TextStyle(
                    color: inkColor.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  oldValue,
                  style: TextStyle(
                    color: inkColor.withValues(alpha: 0.45),
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: inkColor.withValues(alpha: 0.25),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // 箭头
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 12,
                  color: vermillion.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
          // 新值
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: vermillion.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '新',
                  style: TextStyle(
                    color: vermillion,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  newValue,
                  style: TextStyle(color: inkColor, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPagination(BuildContext context) {
    final totalPages = (_total / _pageSize).ceil();
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scrollBrown.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageArrow(
            context: context,
            icon: Icons.chevron_left_rounded,
            enabled: _currentPage > 1,
            onTap: () {
              setState(() => _currentPage--);
              _loadHistory();
            },
          ),
          const SizedBox(width: 12),
          // 页码指示器
          ...List.generate(totalPages > 5 ? 5 : totalPages, (index) {
            int pageNum;
            if (totalPages <= 5) {
              pageNum = index + 1;
            } else if (_currentPage <= 3) {
              pageNum = index + 1;
            } else if (_currentPage >= totalPages - 2) {
              pageNum = totalPages - 4 + index;
            } else {
              pageNum = _currentPage - 2 + index;
            }
            return _buildPageDot(context, pageNum);
          }),
          const SizedBox(width: 12),
          _buildPageArrow(
            context: context,
            icon: Icons.chevron_right_rounded,
            enabled: _currentPage < totalPages,
            onTap: () {
              setState(() => _currentPage++);
              _loadHistory();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPageArrow({
    required BuildContext context,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: enabled
                ? scrollBrown.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? scrollBrown : scrollBrown.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }

  Widget _buildPageDot(BuildContext context, int pageNum) {
    final isSelected = pageNum == _currentPage;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (pageNum != _currentPage) {
            setState(() => _currentPage = pageNum);
            _loadHistory();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? CharacterGalleryTheme.vermillion
                : scrollBrown.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scrollBrown.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: scrollBrown,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '关闭',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
