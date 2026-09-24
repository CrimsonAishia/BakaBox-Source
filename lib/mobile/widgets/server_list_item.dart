import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/core.dart';
import '../../core/widgets/marquee_text.dart';
import '../../core/models/map_tag_models.dart';
import '../../core/utils/map_runtime_utils.dart';
import '../../core/utils/map_tag_utils.dart';

class ServerListItem extends StatelessWidget {
  final ExtendedServerItem server;
  final VoidCallback? onTap;

  const ServerListItem({super.key, required this.server, this.onTap});

  ServerInfo? get _serverInfo {
    if (server.serverData != null) return server.serverData;
    return server.serverItem.serverData;
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
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 145,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Full background image
                  Positioned.fill(
                    child: MapBackground.fromMap(
                      mapName: _serverInfo?.map,
                      mapUrl: server.mapInfo?.mapUrl,
                      cacheWidth: 600,
                      cacheHeight: 250,
                    ),
                  ),
                  // Top slight gradient for better text readability
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  if (_hasServerData)
                    _buildModernNormalContent(context)
                  else
                    _buildModernFallbackContent(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getMapRuntimeDisplay() {
    if (server.mapRuntimeError) return '获取失败';
    if (server.mapRuntimeFetching) return '加载中...';
    final mapRuntime = server.mapRuntime;
    if (mapRuntime != null) return _formatDuration(mapRuntime.currentRuntime);
    return '未知';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '<1分';
    if (seconds < 3600) return '${seconds ~/ 60}分';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return minutes > 0 ? '$hours时$minutes分' : '$hours时';
  }

  bool _isZombieMap(String? mapName) {
    if (mapName == null || mapName.isEmpty) return false;
    final lowerName = mapName.toLowerCase();
    return lowerName.startsWith('ze_') || lowerName.startsWith('zm_');
  }

  Widget _buildScoreDisplay(
    int ctScore,
    int tScore,
    String? mapName, {
    String? dataQuality,
  }) {
    final isZombie = _isZombieMap(mapName);
    final isUnknown = dataQuality == 'unknown';

    final Color leftColor;
    final Color rightColor;

    if (isUnknown) {
      leftColor = AppColors.gray400;
      rightColor = AppColors.gray400;
    } else if (isZombie) {
      leftColor = AppColors.green500;
      rightColor = AppColors.red500;
    } else {
      leftColor = AppColors.blue500;
      rightColor = const Color(0xFFEAB308);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            ':',
            style: TextStyle(
              color: AppColors.gray400,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '$tScore',
          style: TextStyle(
            color: rightColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
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

  Widget _buildModernNormalContent(BuildContext context) {
    return Column(
      children: [
        // Top Area (Server Name & Player Badge)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Server Name
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (server.serverData?.password == true) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 6),
                          child: Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 16,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          _serverName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                            letterSpacing: 0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Player Count Badge (Floating top right)
                _buildModernPlayerCountBadge(),
              ],
            ),
          ),
        ),

        // Bottom Area (Gradient Panel)
        Container(
          padding: const EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: 10,
            top: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Map Name & Info Chips
              Row(
                children: [
                  Icon(
                    MdiIcons.map,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: MarqueeText(
                      text: _mapDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Info chips on the right
                  if (!server.mapRuntimeError &&
                      (server.mapRuntime != null ||
                          server.mapRuntimeFetching)) ...[
                    const SizedBox(width: 8),
                    _buildModernInfoChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.green.shade300,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getMapRuntimeDisplay(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score or occurrences
                    Builder(
                      builder: (context) {
                        Widget? rightChip;
                        if (!MapRuntimeUtils.isWarmingUp(
                              server.mapRuntime,
                              fetchedAt: server.mapRuntimeLastFetched,
                              mapName: server.serverData?.map,
                              hasError: server.mapRuntimeError,
                            ) &&
                            server.teamScores?.ctScore != null &&
                            server.teamScores?.tScore != null &&
                            (server.teamScores!.ctScore! > 0 ||
                                server.teamScores!.tScore! > 0)) {
                          rightChip = _buildModernInfoChip(
                            child: _buildScoreDisplay(
                              server.teamScores!.ctScore!,
                              server.teamScores!.tScore!,
                              _mapName,
                              dataQuality: server.teamScores!.dataQuality,
                            ),
                          );
                        } else if (server.mapRuntime?.weeklyOccurrences !=
                            null) {
                          rightChip = _buildModernInfoChip(
                            child: Text(
                              '7天内${server.mapRuntime!.weeklyOccurrences!}次',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                        if (rightChip != null) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: rightChip,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Tags & IP Copy
              Row(
                children: [
                  // Tags
                  Expanded(
                    child: _buildModernMapTagRow(
                      MapTagUtils.prepareTags(
                        server.mapInfo?.tags ?? [],
                        isCustomServer: server.serverItem.isCustom,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // IP Copy Button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _copyConnectCommand(context, _serverAddress),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.copy,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '复制 IP',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernPlayerCountBadge() {
    Color primaryColor;
    if (_currentPlayers >= _maxPlayers && _maxPlayers > 0) {
      primaryColor = const Color(0xFFF44336); // Red
    } else if (_currentPlayers >= _maxPlayers * 0.8 && _maxPlayers > 0) {
      primaryColor = AppColors.orange;
    } else {
      primaryColor = Colors.white;
    }

    final int queueCount = server.queueCount;
    final int warmupCount = server.warmupCount;
    final int extraCount = queueCount + warmupCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$_currentPlayers',
          style: TextStyle(
            color: primaryColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
              Shadow(
                color: Colors.black45,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        if (extraCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: _buildExtraCountBadge(queueCount, warmupCount, extraCount),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '/',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
        Text(
          '$_maxPlayers',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtraCountBadge(
    int queueCount,
    int warmupCount,
    int extraCount,
  ) {
    const shadowList = [
      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
    ];

    if (queueCount > 0 && warmupCount > 0) {
      // 同时存在：使用渐变（红→黄），与桌面端一致
      return ShaderMask(
        shaderCallback: (bounds) =>
            OperationColors.queueWarmupGradient.createShader(bounds),
        child: Text(
          '+$extraCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1,
            shadows: shadowList,
          ),
        ),
      );
    } else if (queueCount > 0) {
      // 仅挤服：红色
      return Text(
        '+$extraCount',
        style: const TextStyle(
          color: OperationColors.queue,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1,
          shadows: shadowList,
        ),
      );
    } else {
      // 仅暖服：黄色
      return Text(
        '+$extraCount',
        style: const TextStyle(
          color: OperationColors.warmup,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1,
          shadows: shadowList,
        ),
      );
    }
  }

  Widget _buildModernMapTagRow(List<MapTagSimple> tags) {
    if (tags.isEmpty) {
      return Row(
        children: [
          Icon(
            MdiIcons.tagOffOutline,
            size: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            '暂无标签',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Icon(
            MdiIcons.tagOutline,
            size: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          for (int i = 0; i < tags.length; i++) ...[
            _buildModernTagChip(tags[i]),
            if (i < tags.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildModernTagChip(MapTagSimple tag) {
    final tagColorValue = tag.colorValue;

    if (tagColorValue != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: tagColorValue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tagColorValue.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            color: Color.lerp(tagColorValue, Colors.white, 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildModernInfoChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }

  Widget _buildModernFallbackContent(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _serverName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: 12,
            top: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: Row(
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
                size: 16,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 12, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      '历史记录',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
