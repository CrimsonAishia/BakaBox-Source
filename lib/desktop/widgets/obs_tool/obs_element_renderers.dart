import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/models/server_models.dart';
import '../../../../core/services/server_address_mapping_service.dart';
import '../../../../core/services/source_server_service.dart';
import '../../../../core/widgets/map_background.dart';
import 'obs_utils.dart';

/// 构建元素预览组件
Widget buildElementMock(
  Map<String, dynamic> el,
  ExtendedServerItem? mockServer,
  bool isConnected, [
  SourceServerInfo? queriedInfo,
  MapData? queriedMapData,
  String? queriedDisplayName,
  String? queriedAddress,
]) {
  final String elementType = el['type']?.toString() ?? '';

  if (elementType == 'server_card') {
    return buildServerCardMock(
      el,
      mockServer,
      queriedInfo,
      queriedMapData,
      queriedDisplayName,
      queriedAddress,
    );
  } else if (elementType == 'text') {
    return buildTextMock(
      el,
      mockServer,
      queriedInfo,
      queriedMapData,
      queriedDisplayName,
      queriedAddress,
    );
  }

  // 默认返回空容器，避免未知类型导致异常
  return const SizedBox();
}

/// 构建带模糊效果的地图背景
Widget _buildMapBackgroundWithBlur(
  ExtendedServerItem? mockServer,
  SourceServerInfo? queriedInfo,
  String? mapRawName,
  String? mapUrl,
  double blur,
) {
  final hasServerData = mockServer != null || queriedInfo != null;

  Widget background;
  if (hasServerData) {
    background = MapBackground(
      mapName: mapRawName ?? '',
      imageUrl: mapUrl,
      cacheWidth: 800,
      cacheHeight: 330,
    );
  } else {
    background = Image.asset(
      'assets/images/default-map-bg.jpg',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1e1e1e)),
    );
  }

  // 如果需要模糊效果，用 ImageFiltered 包裹
  if (blur > 0) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: background,
    );
  }

  return background;
}

/// 构建服务器卡片预览
Widget buildServerCardMock(
  Map<String, dynamic> el,
  ExtendedServerItem? mockServer, [
  SourceServerInfo? queriedInfo,
  MapData? queriedMapData,
  String? queriedDisplayName,
  String? queriedAddress,
]) {
  final double titleFontSize = (el['titleFontSize'] ?? 20.0).toDouble();
  final double mapFontSize = (el['mapFontSize'] ?? 16.0).toDouble();
  final double ipFontSize = (el['ipFontSize'] ?? 15.0).toDouble();

  const double borderWidth = 2.0;
  const double borderRadius = 6.0;

  const Color bc = Color(0x990080FF);

  final bool useQueriedData = mockServer == null && queriedInfo != null;

  final serverName = useQueriedData
      ? (queriedDisplayName ?? queriedInfo.name)
      : (mockServer != null
            ? mockServer.serverItem.getDisplayName(
                mockServer.serverData?.hostName,
              )
            : '示例服务器');

  final addressMapping = ServerAddressMappingService();
  final rawIp = useQueriedData
      ? (queriedAddress ?? '未知地址')
      : (mockServer != null
            ? (mockServer.serverItem.address ??
                  mockServer.serverItem.serverAddress ??
                  '未知地址')
            : '127.0.0.1:25565');
  final ip = addressMapping.getDomainAddress(rawIp);

  final players = useQueriedData
      ? queriedInfo.players
      : (mockServer?.serverData?.players ?? 0);

  final maxPlayers = useQueriedData
      ? queriedInfo.maxPlayers
      : (mockServer?.serverData?.maxPlayers ?? 64);

  final mapName = useQueriedData
      ? (queriedMapData != null && queriedMapData.mapLabel.isNotEmpty
            ? '${queriedMapData.mapLabel}(${queriedInfo.map})'
            : queriedInfo.map)
      : getMapDisplayName(mockServer);

  final mapUrl = useQueriedData
      ? queriedMapData?.mapUrl
      : mockServer?.mapInfo?.mapUrl;

  final mapRawName = useQueriedData
      ? queriedInfo.map
      : mockServer?.serverData?.map;

  Color playersColor = const Color(0xFF0080FF);
  Color playersBgColor = Colors.white;
  if (players >= maxPlayers && maxPlayers > 0) {
    playersColor = const Color(0xFFF44336);
    playersBgColor = const Color(0xFFFEEAEA);
  } else if (players >= maxPlayers * 0.8 && maxPlayers > 0) {
    playersColor = const Color(0xFFFF9800);
    playersBgColor = const Color(0xFFFFF9E6);
  }

  return Container(
    width: 450,
    height: 140,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: const Color(0xFF1e1e1e),
      border: Border.all(color: bc, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(
        borderRadius > borderWidth ? borderRadius - borderWidth : 0,
      ),
      child: Stack(
        children: [
          // 地图背景 - 有服务器数据时显示地图背景，否则显示默认背景
          if (el['showMapImage'] ?? true)
            Positioned.fill(
              child: _buildMapBackgroundWithBlur(
                mockServer,
                queriedInfo,
                mapRawName,
                mapUrl,
                el['bgBlur'] ?? 0.0,
              ),
            ),
          // 渐变遮罩
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(
                      alpha: (el['gradientOpacity'] ?? 0.6).toDouble(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 内容区域
          Padding(
            padding: const EdgeInsets.all(17),
            child: Stack(
              children: [
                // 左侧信息
                if (el['showTitle'] ?? true)
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 120,
                    child: Text(
                      serverName,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          const Shadow(color: Colors.black, blurRadius: 3),
                          const Shadow(color: Colors.black, blurRadius: 8),
                          const Shadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                          ),
                          const Shadow(
                            color: Colors.black,
                            offset: Offset(-1, -1),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (el['showMap'] ?? true)
                  Positioned(
                    left: 0,
                    top: 45,
                    child: Row(
                      children: [
                        Text(
                          '地图：',
                          style: TextStyle(
                            fontSize: mapFontSize,
                            color: Colors.white,
                            shadows: [
                              const Shadow(color: Colors.black, blurRadius: 2),
                              const Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                        ),
                        Text(
                          mapName,
                          style: TextStyle(
                            fontSize: mapFontSize,
                            color: Colors.white,
                            shadows: [
                              const Shadow(color: Colors.black, blurRadius: 2),
                              const Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (el['showIp'] ?? true)
                  Positioned(
                    left: 0,
                    top: 72,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ip,
                          style: TextStyle(
                            fontSize: ipFontSize,
                            fontFamily: 'monospace',
                            color: Colors.white,
                            shadows: [
                              const Shadow(color: Colors.black, blurRadius: 2),
                              const Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // 右侧信息
                if (el['showPlayers'] ?? true)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: playersBgColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$players',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: playersColor,
                              height: 1,
                            ),
                          ),
                          Text(
                            '/',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              color: const Color(0xFF9CA3AF),
                              height: 1,
                            ),
                          ),
                          Text(
                            '$maxPlayers',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 构建文本预览组件
Widget buildTextMock(
  Map<String, dynamic> el,
  ExtendedServerItem? mockServer, [
  SourceServerInfo? queriedInfo,
  MapData? queriedMapData,
  String? queriedDisplayName,
  String? queriedAddress,
]) {
  final String textColorHex = el['textColor'] ?? el['color'] ?? '#FFFFFF';
  final String bgColorHex = el['backgroundColor'] ?? '#80000000';
  final Color textColor = parseColor(textColorHex);
  final Color bgColor = parseColor(bgColorHex);
  final bool showBackground = el['showBackground'] ?? true;

  final double padding = (el['padding'] ?? 12.0).toDouble();
  final double borderRadius = (el['borderRadius'] ?? 8.0).toDouble();

  final bool showTextShadow = el['showTextShadow'] ?? true;
  final double shadowBlur = (el['shadowBlur'] ?? 4.0).toDouble();
  final double shadowOffset = (el['shadowOffset'] ?? 2.0).toDouble();

  // 文字描边设置
  final bool showTextStroke = el['showTextStroke'] ?? false;
  final double strokeWidth = (el['strokeWidth'] ?? 2.0).toDouble();
  final String strokeColorHex = el['strokeColor'] ?? '#000000';
  final Color strokeColor = parseColor(strokeColorHex);

  final String textAlign = el['textAlign'] ?? 'left';

  String template = el['template']?.toString() ?? '';

  final bool useQueriedData = mockServer == null && queriedInfo != null;

  if (useQueriedData) {
    final serverName = queriedDisplayName ?? queriedInfo.name;
    final rawIp = queriedAddress ?? '未知地址';
    final displayIp = ServerAddressMappingService().getDomainAddress(rawIp);
    final mapDisplay =
        queriedMapData != null && queriedMapData.mapLabel.isNotEmpty
        ? '${queriedMapData.mapLabel}(${queriedInfo.map})'
        : queriedInfo.map;
    template = template
        .replaceAll('{serverName}', serverName)
        .replaceAll(
          '{players}',
          '${queriedInfo.players}/${queriedInfo.maxPlayers}',
        )
        .replaceAll('{ip}', displayIp)
        .replaceAll('{map}', mapDisplay);
  } else if (mockServer != null) {
    final serverName = mockServer.serverItem.getDisplayName(
      mockServer.serverData?.hostName,
    );
    final rawIp =
        mockServer.serverItem.address ??
        mockServer.serverItem.serverAddress ??
        '127.0.0.1';
    final displayIp = ServerAddressMappingService().getDomainAddress(rawIp);
    template = template
        .replaceAll('{serverName}', serverName)
        .replaceAll(
          '{players}',
          '${mockServer.serverData?.players ?? 0}/${mockServer.serverData?.maxPlayers ?? 64}',
        )
        .replaceAll('{ip}', displayIp)
        .replaceAll('{map}', getMapDisplayName(mockServer));
  } else {
    template = template
        .replaceAll('{serverName}', '示例服务器')
        .replaceAll('{players}', '0/64')
        .replaceAll('{ip}', '127.0.0.1')
        .replaceAll('{map}', 'de_dust2');
  }

  // 清理未识别的变量占位符
  template = _cleanUnknownVariables(template);

  // 构建文字样式
  final textStyle = TextStyle(
    color: textColor,
    fontSize: el['fontSize']?.toDouble() ?? 24.0,
    fontWeight: el['fontWeight'] == 'bold'
        ? FontWeight.bold
        : FontWeight.normal,
    fontStyle: el['fontStyle'] == 'italic'
        ? FontStyle.italic
        : FontStyle.normal,
    decoration: el['decoration'] == 'underline'
        ? TextDecoration.underline
        : null,
    height: 1.4,
    shadows: showTextShadow
        ? [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: shadowBlur,
              offset: Offset(shadowOffset, shadowOffset),
            ),
          ]
        : null,
  );

  // 文字内容组件
  final textWidget = Text(
    template,
    textAlign: _getTextAlign(textAlign),
    style: textStyle,
  );

  // 如果需要描边，使用多层 text-shadow 模拟外描边效果（与 OBS 端保持一致）
  // 这样描边只会在文字外侧，不会侵入文字内部
  final contentWidget = showTextStroke
      ? Text(
          template,
          textAlign: _getTextAlign(textAlign),
          style: textStyle.copyWith(
            shadows: [
              Shadow(color: strokeColor, offset: Offset(strokeWidth, 0)),
              Shadow(color: strokeColor, offset: Offset(-strokeWidth, 0)),
              Shadow(color: strokeColor, offset: Offset(0, strokeWidth)),
              Shadow(color: strokeColor, offset: Offset(0, -strokeWidth)),
              Shadow(
                color: strokeColor,
                offset: Offset(strokeWidth, strokeWidth),
              ),
              Shadow(
                color: strokeColor,
                offset: Offset(-strokeWidth, strokeWidth),
              ),
              Shadow(
                color: strokeColor,
                offset: Offset(strokeWidth, -strokeWidth),
              ),
              Shadow(
                color: strokeColor,
                offset: Offset(-strokeWidth, -strokeWidth),
              ),
            ],
          ),
        )
      : textWidget;

  return Container(
    padding: EdgeInsets.all(padding),
    decoration: showBackground
        ? BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
          )
        : null,
    child: contentWidget,
  );
}

TextAlign _getTextAlign(String align) {
  switch (align) {
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    default:
      return TextAlign.left;
  }
}

/// 清理未识别的变量占位符
String _cleanUnknownVariables(String template) {
  // 匹配任何 {xxx} 格式的占位符，其中 xxx 不是已知的变量名
  return template.replaceAllMapped(
    RegExp(r'\{(?!serverName|players|ip|map\b)(\w+)\}'),
    (match) => '',
  );
}
