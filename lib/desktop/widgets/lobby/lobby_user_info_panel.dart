import 'package:flutter/material.dart';

import '../../../core/models/lobby_models.dart';
import '../../../core/models/proto/lobby.pb.dart' as pb;
import '../../../core/services/lobby_nakama_service.dart';
import '../../../core/utils/log_service.dart';

/// 游戏风格的用户信息面板
///
/// 点击在线面板中的已登录用户时弹出，通过 RPC steam_user_info 获取详细数据。
/// 使用用户的 Nakama UUID（serverUserId）查询，服务端自动关联其绑定的 Steam 信息。
class LobbyUserInfoPanel extends StatefulWidget {
  final LobbyUser user;
  final VoidCallback onClose;

  const LobbyUserInfoPanel({
    super.key,
    required this.user,
    required this.onClose,
  });

  /// 以对话框形式显示用户信息面板
  static Future<void> show(BuildContext context, LobbyUser user) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: LobbyUserInfoPanel(
          user: user,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  State<LobbyUserInfoPanel> createState() => _LobbyUserInfoPanelState();
}

class _LobbyUserInfoPanelState extends State<LobbyUserInfoPanel>
    with SingleTickerProviderStateMixin {
  pb.SteamUserInfoResponse? _userInfo;
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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    // 使用用户的 Nakama UUID（serverUserId）查询信息
    // 服务端会自动查询该用户绑定的 Steam64 ID，支持查询任意已登录用户
    final nakamaUserId = widget.user.serverUserId;
    if (nakamaUserId == null || nakamaUserId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '无法获取该用户的信息';
      });
      return;
    }

    try {
      final result = await LobbyNakamaService.instance.rpcSteamUserInfo(nakamaUserId);
      if (!mounted) return;
      if (result != null && result.code == 0) {
        setState(() {
          _userInfo = result;
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
      LogService.w('[LobbyUserInfoPanel] 加载用户信息失败: $e');
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
            width: 480,
            constraints: const BoxConstraints(maxHeight: 620),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1F2E),
                  Color(0xFF0F1624),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2A3A5C),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFF1D9BF0).withValues(alpha: 0.08),
                  blurRadius: 60,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1D9BF0).withValues(alpha: 0.15),
            const Color(0xFF0B66C2).withValues(alpha: 0.08),
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
          // 用户头像
          _buildAvatar(),
          const SizedBox(width: 14),
          // 用户名和状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userInfo?.steamName.isNotEmpty == true
                      ? _userInfo!.steamName
                      : widget.user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (_userInfo != null) ...[
                  Row(
                    children: [
                      _buildVipBadge(_userInfo!.donatorLevel),
                      const SizedBox(width: 8),
                      if (_userInfo!.donateEnd.isNotEmpty)
                        Text(
                          '到期 ${_userInfo!.donateEnd}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        )
                      else if (_userInfo!.donatorLevel > 0)
                        Text(
                          '永久',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      if (_userInfo!.joinDate.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '加入于 ${_userInfo!.joinDate}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else
                  Text(
                    widget.user.statusText ?? '在线',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // 关闭按钮
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

  Widget _buildAvatar() {
    final avatarUrl = _userInfo?.avatarUrl.isNotEmpty == true
        ? _userInfo!.avatarUrl
        : widget.user.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF1D9BF0).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D9BF0).withValues(alpha: 0.2),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                avatarUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
              )
            : _buildFallbackAvatar(),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFF1D9BF0).withValues(alpha: 0.2),
      child: const Icon(Icons.person, color: Colors.white54, size: 28),
    );
  }

  Widget _buildVipBadge(int level) {
    if (level <= 0) return const SizedBox.shrink();
    final color = level >= 10
        ? const Color(0xFFFFD700)
        : level >= 5
            ? const Color(0xFFFF8C00)
            : const Color(0xFF4ADE80);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '捐助者 Lv.$level',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
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
                const Color(0xFF1D9BF0).withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在加载玩家信息...',
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
    final info = _userInfo!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CS2 游戏数据
          _buildSectionTitle('CS2 游戏数据', Icons.sports_esports),
          const SizedBox(height: 8),
          _buildInfoCard([
            _InfoItem('金', _formatNumber(info.cs2Gold.toInt())),
            _InfoItem('点', _formatNumber(info.cs2Point.toInt())),
            _InfoItem('已消耗点', _formatNumber(info.cs2SpentPoint.toInt())),
          ]),
          const SizedBox(height: 10),
          _buildInfoCard([
            _InfoItem('今日在线', _formatDuration(info.onlineTimeDay.toInt())),
            _InfoItem('累计在线', _formatDuration(info.onlineTimeTotal.toInt())),
          ]),
          const SizedBox(height: 10),
          // PTS 排名
          _buildPtsRankCard(info),
          const SizedBox(height: 16),

          // CS:S / CS:GO 通用数据
          if (info.csgoGold.toInt() > 0 || info.csgoOnlineTime.toInt() > 0) ...[
            _buildSectionTitle('CS:S / CS:GO 通用数据', Icons.gamepad),
            const SizedBox(height: 8),
            _buildInfoCard([
              _InfoItem('金币', _formatNumber(info.csgoGold.toInt())),
              if (info.csgoOnlineTime.toInt() > 0)
                _InfoItem('累计在线', _formatDuration(info.csgoOnlineTime.toInt())),
            ]),
            const SizedBox(height: 16),
          ],

          // CS:GO 游戏数据
          if (_hasCsgoData(info)) ...[
            _buildSectionTitle('CS:GO 游戏数据', Icons.shield),
            const SizedBox(height: 8),
            _buildCsgoSection(info),
            const SizedBox(height: 16),
          ],

          // CS:S 游戏数据
          if (_hasCssData(info)) ...[
            _buildSectionTitle('CS:S 游戏数据', Icons.sports_kabaddi),
            const SizedBox(height: 8),
            _buildCssSection(info),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1D9BF0), size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<_InfoItem> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.value.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      entry.value.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPtsRankCard(pb.SteamUserInfoResponse info) {
    final modes = <_PtsMode>[
      _PtsMode('娱乐服', info.mgPts.toInt(), info.mgPtsRank.toInt(), info.mgPtsTotal.toInt()),
      _PtsMode('滑翔服', info.surfPts.toInt(), info.surfPtsRank.toInt(), info.surfPtsTotal.toInt()),
      _PtsMode('连跳服', info.bhopPts.toInt(), info.bhopPtsRank.toInt(), info.bhopPtsTotal.toInt()),
      _PtsMode('攀岩服', info.kzPts.toInt(), info.kzPtsRank.toInt(), info.kzPtsTotal.toInt()),
    ];

    // 只显示有数据的模式
    final activeModes = modes.where((m) => m.pts > 0 || m.rank > 0).toList();
    if (activeModes.isEmpty) {
      return _buildInfoCard([
        const _InfoItem('PTS 排名', '暂无数据'),
      ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          // 表头
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '模式',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'PTS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '排名',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ...activeModes.map((mode) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        mode.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        mode.pts > 0 ? _formatNumber(mode.pts) : '--',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mode.pts > 0
                              ? const Color(0xFF4ADE80)
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        mode.rank > 0 ? '#${mode.rank}' : '--',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mode.rank > 0
                              ? const Color(0xFFFFD700)
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  bool _hasCsgoData(pb.SteamUserInfoResponse info) {
    return info.csgoZombiePts.toInt() > 0 ||
        info.csgoZombieKill.toInt() > 0 ||
        info.csgoMgPts.toInt() > 0 ||
        info.csgoSurfPts.toInt() > 0 ||
        info.csgoTttInnocentPts.toInt() > 0;
  }

  Widget _buildCsgoSection(pb.SteamUserInfoResponse info) {
    return Column(
      children: [
        if (info.csgoZombiePts.toInt() > 0 || info.csgoZombieKill.toInt() > 0)
          _buildInfoCard([
            _InfoItem('僵尸感染 PTS', _formatNumber(info.csgoZombiePts.toInt())),
            _InfoItem('僵尸击杀', _formatNumber(info.csgoZombieKill.toInt())),
            if (info.csgoZombieKnife.toInt() > 0)
              _InfoItem('刀杀', _formatNumber(info.csgoZombieKnife.toInt())),
            if (info.csgoZombieKickAss.toInt() > 0)
              _InfoItem('爆菊', _formatNumber(info.csgoZombieKickAss.toInt())),
            if (info.csgoZombieLostAss.toInt() > 0)
              _InfoItem('被爆菊', _formatNumber(info.csgoZombieLostAss.toInt())),
            if (info.csgoZombieProLevel.toInt() > 0)
              _InfoItem('高玩等级', '${info.csgoZombieProLevel}'),
          ]),
        if (info.csgoMgPts.toInt() > 0 ||
            info.csgoSurfPts.toInt() > 0 ||
            info.csgoBhopPts.toInt() > 0 ||
            info.csgoKzPts.toInt() > 0) ...[
          const SizedBox(height: 8),
          _buildInfoCard([
            if (info.csgoMgPts.toInt() > 0)
              _InfoItem('娱乐服 PTS', _formatNumber(info.csgoMgPts.toInt())),
            if (info.csgoSurfPts.toInt() > 0)
              _InfoItem('滑翔服 PTS', _formatNumber(info.csgoSurfPts.toInt())),
            if (info.csgoBhopPts.toInt() > 0)
              _InfoItem('连跳服 PTS', _formatNumber(info.csgoBhopPts.toInt())),
            if (info.csgoKzPts.toInt() > 0)
              _InfoItem('攀岩服 PTS', _formatNumber(info.csgoKzPts.toInt())),
          ]),
        ],
        if (info.csgoTttInnocentPts.toInt() > 0 ||
            info.csgoTttDetectivePts.toInt() > 0 ||
            info.csgoTttTraitorPts.toInt() > 0) ...[
          const SizedBox(height: 8),
          _buildInfoCard([
            _InfoItem('TTT 平民 PTS', _formatNumber(info.csgoTttInnocentPts.toInt())),
            _InfoItem('TTT 侦探 PTS', _formatNumber(info.csgoTttDetectivePts.toInt())),
            _InfoItem('TTT 叛徒 PTS', _formatNumber(info.csgoTttTraitorPts.toInt())),
          ]),
        ],
      ],
    );
  }

  bool _hasCssData(pb.SteamUserInfoResponse info) {
    return info.cssZombiePts.toInt() > 0 ||
        info.cssZombieKill.toInt() > 0 ||
        info.cssTitanPts.toInt() > 0 ||
        info.cssTttPts.toInt() > 0;
  }

  Widget _buildCssSection(pb.SteamUserInfoResponse info) {
    return Column(
      children: [
        if (info.cssZombiePts.toInt() > 0 || info.cssZombieKill.toInt() > 0)
          _buildInfoCard([
            _InfoItem('僵尸感染 PTS', _formatNumber(info.cssZombiePts.toInt())),
            _InfoItem('僵尸击杀', _formatNumber(info.cssZombieKill.toInt())),
            if (info.cssZombieKnife.toInt() > 0)
              _InfoItem('刀杀', _formatNumber(info.cssZombieKnife.toInt())),
            if (info.cssZombieKickAss.toInt() > 0)
              _InfoItem('爆菊', _formatNumber(info.cssZombieKickAss.toInt())),
            if (info.cssZombieProLevel.toInt() > 0)
              _InfoItem('高玩等级', '${info.cssZombieProLevel}'),
          ]),
        if (info.cssTitanPts.toInt() > 0 ||
            info.cssTitanKills.toInt() > 0) ...[
          const SizedBox(height: 8),
          _buildInfoCard([
            _InfoItem('進撃の巨人 PTS', _formatNumber(info.cssTitanPts.toInt())),
            if (info.cssTitanKills.toInt() > 0)
              _InfoItem('巨人击杀', _formatNumber(info.cssTitanKills.toInt())),
            if (info.cssTitanSpecialKills.toInt() > 0)
              _InfoItem('特殊击杀', _formatNumber(info.cssTitanSpecialKills.toInt())),
            if (info.cssTitanHumanKills.toInt() > 0)
              _InfoItem('人类击杀', _formatNumber(info.cssTitanHumanKills.toInt())),
            if (info.cssTitanAssists.toInt() > 0)
              _InfoItem('助攻', _formatNumber(info.cssTitanAssists.toInt())),
          ]),
        ],
        if (info.cssTttPts.toInt() > 0) ...[
          const SizedBox(height: 8),
          _buildInfoCard([
            _InfoItem('TTT PTS', _formatNumber(info.cssTttPts.toInt())),
            if (info.cssTttWrongKill.toInt() > 0)
              _InfoItem('错误击杀', _formatNumber(info.cssTttWrongKill.toInt())),
            if (info.cssTttKarma.toInt() > 0)
              _InfoItem('Karma', _formatNumber(info.cssTttKarma.toInt())),
          ]),
        ],
      ],
    );
  }

  /// 格式化数字（添加千分位分隔符）
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

  /// 格式化时长（秒 → 小时分钟）
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0分';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours小时${minutes > 0 ? '$minutes分' : ''}';
    }
    return '$minutes分';
  }
}

/// 信息项数据
class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

/// PTS 模式数据
class _PtsMode {
  final String name;
  final int pts;
  final int rank;
  final int total;
  const _PtsMode(this.name, this.pts, this.rank, this.total);
}
