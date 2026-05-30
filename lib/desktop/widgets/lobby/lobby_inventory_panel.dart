import 'package:flutter/material.dart';

import '../../../core/models/lobby_models.dart';
import '../../../core/models/proto/lobby.pb.dart' as pb;
import '../../../core/services/lobby_nakama_service.dart';
import '../../../core/utils/log_service.dart';

/// 库存统计面板
///
/// 通过 RPC inventory_stats 获取玩家库存物品统计信息。
class LobbyInventoryPanel extends StatefulWidget {
  final LobbyUser user;
  final VoidCallback onClose;

  const LobbyInventoryPanel({
    super.key,
    required this.user,
    required this.onClose,
  });

  /// 以对话框形式显示库存统计面板
  static Future<void> show(BuildContext context, LobbyUser user) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: LobbyInventoryPanel(
          user: user,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  State<LobbyInventoryPanel> createState() => _LobbyInventoryPanelState();
}

class _LobbyInventoryPanelState extends State<LobbyInventoryPanel>
    with SingleTickerProviderStateMixin {
  pb.InventoryStatsResponse? _stats;
  bool _isLoading = true;
  String? _error;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final nakamaUserId = widget.user.serverUserId;
    if (nakamaUserId == null || nakamaUserId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '无法获取该用户的信息';
      });
      return;
    }

    try {
      final result = await LobbyNakamaService.instance.rpcInventoryStats(
        nakamaUserId,
      );
      if (!mounted) return;
      if (result != null && result.code == 0) {
        setState(() {
          _stats = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = result?.message.isNotEmpty == true
              ? result!.message
              : '该用户暂未绑定 Steam';
        });
      }
    } catch (e) {
      LogService.w('[LobbyInventoryPanel] 加载库存信息失败: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '加载失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 480),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F2E), Color(0xFF0F1624)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3A5C), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.06),
                  blurRadius: 40,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  if (_isLoading)
                    _buildLoading()
                  else if (_error != null)
                    _buildError()
                  else
                    Flexible(child: _buildContent()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4ADE80).withValues(alpha: 0.12),
            const Color(0xFF22C55E).withValues(alpha: 0.06),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF2A3A5C).withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF4ADE80),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CS2 库存统计',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.user.displayName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF4ADE80).withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在加载库存信息...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withValues(alpha: 0.3),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final stats = _stats!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 物品分类网格
          _buildItemGrid(stats),
          const SizedBox(height: 14),
          // 估算价值
          _buildValueFooter(stats),
        ],
      ),
    );
  }

  Widget _buildValueFooter(pb.InventoryStatsResponse stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '估算价值',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 12,
              ),
            ),
          ),
          // 金币
          Icon(
            Icons.monetization_on_outlined,
            color: const Color(0xFFF59E0B),
            size: 13,
          ),
          const SizedBox(width: 3),
          Text(
            '${_formatNumber(stats.totalGoldValue.toInt())} 金',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '/',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: 12,
              ),
            ),
          ),
          // 积分
          Icon(Icons.bolt, color: const Color(0xFF60A5FA), size: 13),
          const SizedBox(width: 2),
          Text(
            '${_formatNumber(stats.totalPointValue.toInt())} 点',
            style: const TextStyle(
              color: Color(0xFF60A5FA),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemGrid(pb.InventoryStatsResponse stats) {
    final items = <_InventoryItem>[
      _InventoryItem(
        '已购买皮肤',
        stats.skinCount,
        Icons.person_outline,
        const Color(0xFF8B5CF6),
      ),
      _InventoryItem(
        '已解锁符卡',
        stats.spellCount,
        Icons.style_outlined,
        const Color(0xFFF59E0B),
      ),
      _InventoryItem(
        '已解锁弹幕',
        stats.danmakuCount,
        Icons.local_fire_department,
        const Color(0xFFF97316),
      ),
      _InventoryItem(
        '已解锁技能',
        stats.skillCount,
        Icons.auto_awesome,
        const Color(0xFFEAB308),
      ),
      _InventoryItem(
        '已购买刀模',
        stats.knifeCount,
        Icons.content_cut,
        const Color(0xFF94A3B8),
      ),
      _InventoryItem(
        '已购买枪模',
        stats.weaponCount,
        Icons.gps_fixed,
        const Color(0xFF60A5FA),
      ),
      _InventoryItem(
        '已购买 Cheer',
        stats.cheerCount,
        Icons.campaign_outlined,
        const Color(0xFFF472B6),
      ),
      _InventoryItem(
        '菜单皮肤',
        stats.skinmenuCount,
        Icons.view_sidebar_outlined,
        const Color(0xFF2DD4BF),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: item.count > 0
                ? item.color.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: item.count > 0
                  ? item.color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: item.count > 0
                    ? item.color
                    : Colors.white.withValues(alpha: 0.2),
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${item.count}',
                style: TextStyle(
                  color: item.count > 0
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatNumber(int value) {
    if (value == 0) return '0';
    final str = value.toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

/// 库存物品数据
class _InventoryItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _InventoryItem(this.label, this.count, this.icon, this.color);
}
