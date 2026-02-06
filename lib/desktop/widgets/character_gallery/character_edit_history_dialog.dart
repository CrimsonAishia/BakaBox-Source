import 'package:flutter/material.dart';
import '../../../core/api/character_api.dart';
import '../../../core/models/character_models.dart';
import '../../../core/utils/formatters.dart';
import 'character_gallery_theme.dart';

/// 编辑历史对话框（时间线风格）
class EditHistoryDialog extends StatefulWidget {
  final EditTargetType targetType;
  final int targetId;
  final String targetName;

  const EditHistoryDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetName,
  });

  @override
  State<EditHistoryDialog> createState() => _EditHistoryDialogState();
}

class _EditHistoryDialogState extends State<EditHistoryDialog> {
  final CharacterApi _api = CharacterApi();
  List<ContentEditHistoryItem> _historyItems = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _total = 0;
  static const int _pageSize = 10;

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
      final response = await _api.getContentEditHistory(
        targetType: widget.targetType,
        targetId: widget.targetId,
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

  String _getTargetTypeLabel() {
    return switch (widget.targetType) {
      EditTargetType.subModel => '子模型',
      EditTargetType.spellCard => '符卡',
      EditTargetType.zombieSkill => '技能',
    };
  }

  String _getFieldLabel(String field) {
    return switch (field) {
      'create' => '创建',
      'description' => '描述',
      'damage' => '伤害',
      'cooldown' => '冷却',
      'cost' => '消耗',
      'range' => '范围',
      'special' => '特殊效果',
      'tips' => '提示',
      'acquisition_type' => '获取类型',
      'acquisition_cost' => '获取价格',
      'custom_source' => '自定义来源',
      'name' => '名称',
      'type' => '类型',
      'icon_url' => '图标',
      'sub_model_id' => '子模型',
      'tier' => '评级',
      _ => field,
    };
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return AlertDialog(
      backgroundColor: washiColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scrollBrown.withValues(alpha: 0.6), width: 2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: _buildTitle(context),
      content: SizedBox(width: 520, height: 420, child: _buildContent(context)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
            ),
          ),
          child: Text(
            '关闭',
            style: TextStyle(color: scrollBrown, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scrollBrown.withValues(alpha: 0.15),
                scrollBrown.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scrollBrown.withValues(alpha: 0.2)),
          ),
          child: Icon(Icons.history_rounded, size: 22, color: scrollBrown),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '编辑历史',
                style: TextStyle(
                  color: inkColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: CharacterGalleryTheme.getVermillion(
                        context,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTargetTypeLabel(),
                      style: TextStyle(
                        color: CharacterGalleryTheme.getVermillion(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.targetName,
                      style: TextStyle(
                        color: inkColor.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_total > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CharacterGalleryTheme.getGold(
                context,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CharacterGalleryTheme.getGold(
                  context,
                ).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '$_total 条记录',
              style: TextStyle(
                color: CharacterGalleryTheme.getGold(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: CharacterGalleryTheme.getVermillion(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '加载中...',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.5),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CharacterGalleryTheme.getVermillion(
                  context,
                ).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: CharacterGalleryTheme.getVermillion(
                  context,
                ).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadHistory,
              icon: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: CharacterGalleryTheme.getVermillion(context),
              ),
              label: Text(
                '重试',
                style: TextStyle(
                  color: CharacterGalleryTheme.getVermillion(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: CharacterGalleryTheme.getVermillion(
                      context,
                    ).withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_historyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scrollBrown.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Text('📜', style: TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无编辑记录',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.5),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '该内容尚未被编辑过',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _historyItems.length,
            itemBuilder: (context, index) {
              final item = _historyItems[index];
              final isLast = index == _historyItems.length - 1;
              return _buildTimelineItem(context, item, isLast);
            },
          ),
        ),
        // 分页控制
        if (_total > _pageSize)
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scrollBrown.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(
                  context: context,
                  icon: Icons.chevron_left_rounded,
                  enabled: _currentPage > 1,
                  onTap: () {
                    setState(() => _currentPage--);
                    _loadHistory();
                  },
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scrollBrown.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$_currentPage / ${(_total / _pageSize).ceil()}',
                    style: TextStyle(
                      color: inkColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _buildPageButton(
                  context: context,
                  icon: Icons.chevron_right_rounded,
                  enabled: _currentPage < (_total / _pageSize).ceil(),
                  onTap: () {
                    setState(() => _currentPage++);
                    _loadHistory();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPageButton({
    required BuildContext context,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled
                ? scrollBrown.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? scrollBrown : scrollBrown.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    ContentEditHistoryItem item,
    bool isLast,
  ) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间线
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // 时间线节点
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: CharacterGalleryTheme.getVermillion(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: CharacterGalleryTheme.getVermillion(
                          context,
                        ).withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                // 连接线
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            CharacterGalleryTheme.getVermillion(
                              context,
                            ).withValues(alpha: 0.4),
                            scrollBrown.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 内容卡片
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scrollBrown.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: inkColor.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部：版本 + 字段 + 时间
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              CharacterGalleryTheme.getGold(
                                context,
                              ).withValues(alpha: 0.2),
                              CharacterGalleryTheme.getGold(
                                context,
                              ).withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: CharacterGalleryTheme.getGold(
                              context,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'v${item.version}',
                          style: TextStyle(
                            color: CharacterGalleryTheme.getGold(context),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: CharacterGalleryTheme.getVermillion(
                            context,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getFieldLabel(item.fieldChanged),
                          style: TextStyle(
                            color: CharacterGalleryTheme.getVermillion(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: inkColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.formatDate(item.editedAt),
                        style: TextStyle(
                          color: inkColor.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 编辑者
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: scrollBrown.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: scrollBrown,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.editorName ?? '用户${item.editorId}',
                        style: TextStyle(
                          color: inkColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 变更内容
                  _buildChangeContent(context, item),
                  // 编辑原因
                  if (item.editReason != null &&
                      item.editReason!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scrollBrown.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          left: BorderSide(
                            color: scrollBrown.withValues(alpha: 0.3),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 14,
                            color: scrollBrown.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.editReason!,
                              style: TextStyle(
                                color: inkColor.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildChangeContent(
    BuildContext context,
    ContentEditHistoryItem item,
  ) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: washiColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 旧值
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: inkColor.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '旧值',
                      style: TextStyle(
                        color: inkColor.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: inputBg.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatValueDisplay(item.fieldChanged, item.oldValue),
                    style: TextStyle(
                      color: inkColor.withValues(alpha: 0.5),
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: inkColor.withValues(alpha: 0.3),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // 箭头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: CharacterGalleryTheme.getVermillion(
                context,
              ).withValues(alpha: 0.5),
            ),
          ),
          // 新值
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: CharacterGalleryTheme.getVermillion(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '新值',
                      style: TextStyle(
                        color: CharacterGalleryTheme.getVermillion(
                          context,
                        ).withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CharacterGalleryTheme.getVermillion(
                      context,
                    ).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: CharacterGalleryTheme.getVermillion(
                        context,
                      ).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    _formatValueDisplay(item.fieldChanged, item.newValue),
                    style: TextStyle(
                      color: inkColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
