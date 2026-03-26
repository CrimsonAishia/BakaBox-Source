import 'package:flutter/material.dart';

import '../../../core/widgets/marquee_text.dart';
import 'floating_window_colors.dart';
import 'floating_window_state.dart';

/// 右侧信息区域 - 自适应宽度
class FloatingInfoArea extends StatelessWidget {
  final FloatingWindowState state;
  final String? serverAddress;
  final String? serverName;

  const FloatingInfoArea({
    super.key,
    required this.state,
    this.serverAddress,
    this.serverName,
  });

  @override
  Widget build(BuildContext context) {
    final color = FloatingWindowColors.fromState(state);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态标题
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            child: Text(
              _getStatusTitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          // 根据状态显示不同内容
          _buildContentArea(),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    // 挤服模式：显示人数+线程+地图
    if (state.isQueueing) {
      return _buildQueueContent();
    }

    // 启动中：只显示简单提示
    if (state.isLaunching) {
      return _buildLaunchingContent();
    }

    // 连接中/加载中：显示地图和服务器
    if (state.isConnecting || state.isLoading) {
      return _buildConnectingContent();
    }

    // 终态：显示结果信息
    if (state.isTerminal) {
      return _buildTerminalContent();
    }

    // 暂停状态：显示消息
    if (state.isPaused) {
      return _buildPausedContent();
    }

    // 默认：显示服务器名
    return _buildDefaultContent();
  }

  /// 挤服模式内容
  Widget _buildQueueContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 人数
        _buildPlayerCount(),
        const SizedBox(height: 4),
        // 线程指示器（单独一行）
        if (state.threadStatuses != null && state.threadStatuses!.isNotEmpty)
          _buildThreadIndicators(),
        // 地图名（格式：英文名(中文名)，过长滚动）
        if (state.mapName != null && state.mapName!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: MarqueeText(
              text: _formatMapName(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// 启动中内容 - 简洁
  Widget _buildLaunchingContent() {
    return Text(
      '请稍候...',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 13,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 连接中/加载中内容
  Widget _buildConnectingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 地图名（格式：英文名(中文名)，过长滚动）
        if (state.mapName != null && state.mapName!.isNotEmpty)
          MarqueeText(
            text: _formatMapName(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        // 服务器地址
        if (serverAddress != null && serverAddress!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              serverAddress!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  /// 格式化地图名：英文名(中文名)，如果没有中文名则只显示英文名
  String _formatMapName() {
    final mapName = state.mapName ?? '';
    final mapNameCn = state.mapNameCn;

    if (mapName.isEmpty) return '';
    if (mapNameCn != null && mapNameCn.isNotEmpty) {
      return '$mapName ($mapNameCn)';
    }
    return mapName;
  }

  /// 终态内容
  Widget _buildTerminalContent() {
    // 成功时显示地图名（格式：英文名(中文名)，过长滚动）
    if (state.isSuccess && state.mapName != null && state.mapName!.isNotEmpty) {
      return MarqueeText(
        text: _formatMapName(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
        ),
      );
    }

    // 失败时显示错误消息
    if (state.message.isNotEmpty) {
      return Text(
        state.message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return const SizedBox.shrink();
  }

  /// 默认内容
  Widget _buildDefaultContent() {
    if (serverName != null && serverName!.isNotEmpty) {
      return Text(
        serverName!,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox.shrink();
  }

  /// 暂停状态内容
  Widget _buildPausedContent() {
    if (state.message.isNotEmpty) {
      return Text(
        state.message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPlayerCount() {
    final current = state.currentPlayers ?? 0;
    final target = state.targetPlayers ?? 0;
    final isNearFull = current >= target - 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$current',
          style: TextStyle(
            color: isNearFull
                ? FloatingWindowColors.serverFull
                : FloatingWindowColors.success,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          ' / $target',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildThreadIndicators() {
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: state.threadStatuses!.map((status) {
        final color = FloatingWindowColors.threadColor(status);
        final isRequesting = status == 'requesting';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isRequesting
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }).toList(),
    );
  }

  String _getStatusTitle() {
    if (state.isIdle) return '准备中';
    if (state.isLaunching) return '启动游戏';
    if (state.isQueueing) return '挤服中';
    if (state.isConnecting) return '连接中';
    if (state.isLoading) return '加载地图';
    if (state.isSuccess) {
      // 根据消息内容判断是启动完成还是加入服务器
      if (state.message.contains('启动')) {
        return '启动完毕';
      }
      return '已加入';
    }
    if (state.isFailed) {
      return state.state == 'timeout' ? '连接超时' : '连接失败';
    }
    if (state.isServerFull) return '服务器满';
    if (state.isPaused) return '已停止';
    return '准备中';
  }
}
