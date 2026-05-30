import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/core.dart';
import '../../core/models/map_tag_models.dart';
import '../../core/utils/map_runtime_utils.dart';
import 'animated_player_count.dart';

class ServerListItem extends StatelessWidget {
  final ExtendedServerItem server;
  final VoidCallback? onTap;

  const ServerListItem({super.key, required this.server, this.onTap});

  ServerInfo? get _serverInfo {
    if (server.serverData != null) return server.serverData;
    if (server.serverItem.serverData == null) return null;
    try {
      return ServerInfo.fromJson(server.serverItem.serverData!);
    } catch (e) {
      return null;
    }
  }

  String get _serverName {
    return _serverInfo?.hostName ?? server.serverItem.address ?? '未知服务器';
  }

  String get _mapName {
    return _serverInfo?.map ?? '未知地图';
  }

  String get _mapDisplayName {
    final mapLabel = server.mapInfo?.mapLabel;
    // 确保中文名不为空字符串
    final chineseName = (mapLabel?.isNotEmpty == true) ? mapLabel : null;
    // 显示格式：有中文名时 "中文名 (英文名)"，否则只显示英文名
    return chineseName != null ? '$chineseName ($_mapName)' : _mapName;
  }

  int get _currentPlayers => _serverInfo?.players ?? 0;
  int get _maxPlayers => _serverInfo?.maxPlayers ?? 64;
  bool get _hasServerData => _serverInfo != null;

  String get _serverStatusText {
    if (server.hasError) return '数据获取失败';
    if (server.isLoading) return '数据获取中...';
    if (!_hasServerData) return '服务器离线或数据缺失';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 165,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  MapBackground.fromMap(
                    mapName: _serverInfo?.map,
                    mapUrl: server.mapInfo?.mapUrl,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _hasServerData
                        ? _buildNormalContent()
                        : _buildFallbackContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getPlayerCountColor(int current, int max) {
    if (max <= 0) return const Color(0xFF4CAF50);
    final ratio = current / max;
    if (ratio < 0.5) return const Color(0xFF4CAF50);
    if (ratio < 0.8) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getMapRuntimeDisplay() {
    if (server.mapRuntimeError) return '获取失败';
    if (server.mapRuntimeFetching) return '加载中...';
    final mapRuntime = server.mapRuntime;
    if (mapRuntime != null) return _formatDuration(mapRuntime.currentRuntime);
    return '未知';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '小于1分钟';
    if (seconds < 3600) return '${seconds ~/ 60}分';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return minutes > 0 ? '$hours时$minutes分' : '$hours时';
  }

  /// 检测是否为僵尸地图
  ///
  /// 僵尸地图前缀：ze_（zombie escape）、zm_（zombie mod）
  bool _isZombieMap(String? mapName) {
    if (mapName == null || mapName.isEmpty) return false;
    final lowerName = mapName.toLowerCase();
    return lowerName.startsWith('ze_') || lowerName.startsWith('zm_');
  }

  /// 构建比分显示组件
  ///
  /// 普通模式：CT(蓝) X : Y T(黄) - 用文字标签
  /// 僵尸模式：人类(绿) X : Y 僵尸(红) - 用人和骷髅图标
  /// 数据过期（unknown）：全部灰色显示
  Widget _buildScoreDisplay(
    int ctScore,
    int tScore,
    String? mapName, {
    String? dataQuality,
  }) {
    final isZombie = _isZombieMap(mapName);
    final isUnknown = dataQuality == 'unknown';

    // 颜色定义（unknown 时全部灰色）
    final Color leftColor;
    final Color rightColor;

    if (isUnknown) {
      leftColor = const Color(0xFF9CA3AF); // 灰色
      rightColor = const Color(0xFF9CA3AF); // 灰色
    } else if (isZombie) {
      leftColor = const Color(0xFF22C55E); // 人类 - 绿色
      rightColor = const Color(0xFFEF4444); // 僵尸 - 红色
    } else {
      leftColor = const Color(0xFF3B82F6); // CT - 蓝色
      rightColor = const Color(0xFFEAB308); // T - 黄色
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 僵尸模式用图标，普通模式用文字
        if (isZombie)
          Icon(MdiIcons.runFast, size: 12, color: leftColor)
        else
          Text(
            'CT',
            style: TextStyle(
              color: leftColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(width: 3),
        Text(
          '$ctScore',
          style: TextStyle(
            color: leftColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            ':',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$tScore',
          style: TextStyle(
            color: rightColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        if (isZombie)
          Icon(MdiIcons.biohazard, size: 12, color: rightColor)
        else
          Text(
            'T',
            style: TextStyle(
              color: rightColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  String get _serverAddress {
    return server.serverItem.address ??
        server.serverItem.serverAddress ??
        '未知地址';
  }

  void _copyConnectCommand(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: 'connect $address'));
    ToastUtils.showSuccess(context, '已复制连接命令');
  }

  Widget _buildNormalContent() {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 服务器名称
          Text(
            _serverName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          // 地图名称（图标 + 滚动文本）
          Row(
            children: [
              Icon(
                MdiIcons.map,
                size: 18,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AutoScrollingText(
                  text: _mapDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(1, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // IP 地址 + 复制按钮
          Row(
            children: [
              Icon(
                MdiIcons.ip,
                size: 18,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Text(
                _serverAddress,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'monospace',
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                    Shadow(color: Colors.black, blurRadius: 6),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _copyConnectCommand(context, _serverAddress),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(Icons.copy, size: 16, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // 标签行
          _buildMapTagRow(server.mapInfo?.tags ?? []),
          const SizedBox(height: 6),
          // 底部信息行
          Row(
            children: [
              _buildInfoChip(
                child: AnimatedPlayerCount(
                  currentPlayers: _currentPlayers,
                  maxPlayers: _maxPlayers,
                  queueCount: server.queueCount,
                  warmupCount: server.warmupCount,
                  iconColor: _getPlayerCountColor(_currentPlayers, _maxPlayers),
                  textStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _getPlayerCountColor(_currentPlayers, _maxPlayers),
                  ),
                ),
              ),
              if (!server.mapRuntimeError &&
                  (server.mapRuntime != null || server.mapRuntimeFetching)) ...[
                const SizedBox(width: 6),
                _buildInfoChip(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getMapRuntimeDisplay(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (!MapRuntimeUtils.isWarmingUp(
                      server.mapRuntime,
                      fetchedAt: server.mapRuntimeLastFetched,
                      mapName: server.serverData?.map,
                      hasError: server.mapRuntimeError,
                    ) &&
                    server.teamScores?.ctScore != null &&
                    server.teamScores?.tScore != null &&
                    (server.teamScores!.ctScore! > 0 ||
                        server.teamScores!.tScore! > 0))
                  _buildInfoChip(
                    child: _buildScoreDisplay(
                      server.teamScores!.ctScore!,
                      server.teamScores!.tScore!,
                      _mapName,
                      dataQuality: server.teamScores!.dataQuality,
                    ),
                  )
                else if (server.mapRuntime?.weeklyOccurrences != null)
                  _buildInfoChip(
                    child: Text(
                      '7天内出现${server.mapRuntime!.weeklyOccurrences + 1}次',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 地图标签行（复刻桌面端）
  Widget _buildMapTagRow(List<MapTagSimple> tags) {
    if (tags.isEmpty) {
      return Row(
        children: [
          Icon(
            MdiIcons.tagOffOutline,
            size: 18,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Text(
              '暂无标签',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          MdiIcons.tagOutline,
          size: 18,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < tags.length; i++) ...[
                  _buildTagChip(tags[i]),
                  if (i < tags.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 单个标签（复刻桌面端样式）
  Widget _buildTagChip(MapTagSimple tag) {
    final tagColorValue = tag.colorValue;

    if (tagColorValue != null) {
      final darkColor = Color.lerp(tagColorValue, Colors.black, 0.2)!;
      final lightColor = Color.lerp(tagColorValue, Colors.white, 0.6)!;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightColor.withValues(alpha: 0.4),
              tagColorValue.withValues(alpha: 0.5),
              darkColor.withValues(alpha: 0.45),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tagColorValue.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: tagColorValue.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: tagColorValue.withValues(alpha: 0.8),
                blurRadius: 2,
                offset: const Offset(0, 0),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildFallbackContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _serverName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black45,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              server.hasError
                  ? Icons.error_outline
                  : server.isLoading
                  ? Icons.hourglass_empty
                  : Icons.info_outline,
              color: server.hasError
                  ? Colors.red.shade300
                  : Colors.orange.shade300,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _serverStatusText,
                style: TextStyle(
                  color: server.hasError
                      ? Colors.red.shade300
                      : Colors.orange.shade300,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.ads_click, size: 13, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                '点击查看历史',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AutoScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _AutoScrollingText({required this.text, required this.style});

  @override
  State<_AutoScrollingText> createState() => _AutoScrollingTextState();
}

class _AutoScrollingTextState extends State<_AutoScrollingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late ScrollController _scrollController;
  bool _needsScrolling = false;
  Timer? _forwardDelayTimer;
  Timer? _reverseDelayTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollingNeeded();
    });
  }

  @override
  void didUpdateWidget(_AutoScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _forwardDelayTimer?.cancel();
      _reverseDelayTimer?.cancel();
      _animationController.stop();
      _animationController.reset();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfScrollingNeeded();
      });
    }
  }

  void _checkIfScrollingNeeded() {
    if (!mounted) return;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final availableWidth = renderBox.size.width;
      _needsScrolling = textPainter.width > availableWidth;

      if (_needsScrolling) {
        _startScrolling();
      } else {
        _animationController.stop();
      }
    }
  }

  void _startScrolling() {
    if (!_needsScrolling || !mounted) return;
    if (!_scrollController.hasClients) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) return;

    _animation = Tween<double>(begin: 0.0, end: maxScrollExtent).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _animation.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animation.value);
      }
    });

    _animationController.addStatusListener((status) {
      if (!mounted) return;

      if (status == AnimationStatus.completed) {
        _reverseDelayTimer?.cancel();
        _reverseDelayTimer = Timer(const Duration(seconds: 1), () {
          if (mounted && _needsScrolling) {
            _animationController.reverse();
          }
        });
      } else if (status == AnimationStatus.dismissed) {
        _forwardDelayTimer?.cancel();
        _forwardDelayTimer = Timer(const Duration(seconds: 1), () {
          if (mounted && _needsScrolling) {
            _animationController.forward();
          }
        });
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _forwardDelayTimer?.cancel();
    _reverseDelayTimer?.cancel();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
