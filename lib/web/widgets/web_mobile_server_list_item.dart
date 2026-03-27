import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../models/web_server_list_models.dart';
import '../widgets/web_map_background.dart';

class WebMobileServerListItem extends StatelessWidget {
  final WebServerItem server;
  final VoidCallback? onTap;

  const WebMobileServerListItem({
    super.key,
    required this.server,
    this.onTap,
  });

  String get _serverName {
    return server.name.isNotEmpty ? server.name : '未知服务器';
  }

  String get _mapName {
    return server.mapName ?? '未知地图';
  }

  String get _mapDisplayName {
    if (server.mapLabel != null && server.mapLabel!.isNotEmpty) {
      return '${server.mapLabel!}($_mapName)';
    }
    return _mapName.toLowerCase();
  }

  int get _currentPlayers => server.players ?? 0;
  int get _maxPlayers => server.maxPlayers ?? 64;
  String get _serverAddress => server.address ?? '未知地址';
  bool get _hasServerData => !server.isOffline && !server.isLoading;

  String get _serverStatusText {
    if (server.isLoading) return '数据获取中...';
    if (!_hasServerData) return '服务器离线或数据缺失';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 170,
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
                  WebMapBackground.fromMap(
                    mapName: server.mapName,
                    mapUrl: server.mapImageUrl,
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
                    padding: const EdgeInsets.all(16),
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
    final mapRuntime = server.runtimeMinutes;
    if (mapRuntime != null) return _formatDuration(mapRuntime * 60);
    return '未知';
  }

  String _getMapRunCountDisplay() {
    final weeklyOccurrences = server.weeklyOccurrences;
    if (weeklyOccurrences != null) return '7天内出现${weeklyOccurrences + 1}次';
    return '未知';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '小于1分钟';
    if (seconds < 3600) return '${seconds ~/ 60}分';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return minutes > 0 ? '$hours时$minutes分' : '$hours时';
  }

  Widget _buildNormalContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '地图: ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _AutoScrollingText(
                text: _mapDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '地址: ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                _serverAddress,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildInfoChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people,
                    size: 14,
                    color: _getPlayerCountColor(_currentPlayers, _maxPlayers),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_currentPlayers/$_maxPlayers',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getPlayerCountColor(_currentPlayers, _maxPlayers),
                    ),
                  ),
                ],
              ),
            ),
            if (server.runtimeMinutes != null || server.weeklyOccurrences != null) ...[
              const SizedBox(width: 6),
              _buildInfoChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getMapRuntimeDisplay(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildInfoChip(
                child: _buildScoreOrOccurrence(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildScoreOrOccurrence() {
    final score = server.score;
    final hasValidScore = score != null &&
        !server.isCustom &&
        (score.ctScore > 0 || score.tScore > 0 || score.dataQuality == 'unknown');

    if (hasValidScore) {
      final isZombie = _isZombieMap(server.mapName);
      final isUnknown = score.dataQuality == 'unknown';

      final Color leftColor;
      final Color rightColor;
      final Color iconColor;

      if (isUnknown) {
        leftColor = const Color(0xFF9CA3AF);
        rightColor = const Color(0xFF9CA3AF);
        iconColor = const Color(0xFF9CA3AF);
      } else if (isZombie) {
        leftColor = const Color(0xFF22C55E);
        rightColor = const Color(0xFFEF4444);
        iconColor = const Color(0xFF6B7280);
      } else {
        leftColor = const Color(0xFF3B82F6);
        rightColor = const Color(0xFFEAB308);
        iconColor = const Color(0xFF6B7280);
      }

      final leftLabel = isZombie ? '人类' : 'CT';
      final rightLabel = isZombie ? '僵尸' : 'T';

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$leftLabel ${score.ctScore}',
            style: TextStyle(
              color: leftColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              MdiIcons.swordCross,
              size: 11,
              color: iconColor,
            ),
          ),
          Text(
            '${score.tScore} $rightLabel',
            style: TextStyle(
              color: rightColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Text(
      _getMapRunCountDisplay(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
    );
  }

  bool _isZombieMap(String? mapName) {
    if (mapName == null || mapName.isEmpty) {
      return false;
    }
    final lowerName = mapName.toLowerCase();
    return lowerName.startsWith('ze_') || lowerName.startsWith('zm_');
  }

  Widget _buildFallbackContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              server.isLoading ? Icons.hourglass_empty : Icons.info_outline,
              color: server.isLoading ? Colors.orange.shade300 : Colors.red.shade300,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _serverStatusText,
                style: TextStyle(
                  color: server.isLoading ? Colors.orange.shade300 : Colors.red.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          '地址: $_serverAddress',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 6),
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
              Icon(Icons.ads_click, size: 14, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                '点击查看历史',
                style: TextStyle(fontSize: 11, color: Colors.white70),
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
    if (!_needsScrolling) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return ClipRect(
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}
