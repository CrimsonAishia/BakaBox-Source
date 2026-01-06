import 'package:flutter/material.dart';

import 'floating_icon_area.dart';
import 'floating_info_area.dart';
import 'floating_window_state.dart';

/// 浮窗主体内容 - 左右分栏布局
class FloatingWindowBody extends StatelessWidget {
  final FloatingWindowState state;
  final String? serverAddress;
  final String? serverName;

  const FloatingWindowBody({
    super.key,
    required this.state,
    this.serverAddress,
    this.serverName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧图标区
          FloatingIconArea(state: state),
          // 分隔线
          Container(
            width: 1,
            height: 70,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // 右侧信息区
          FloatingInfoArea(
            state: state,
            serverAddress: serverAddress,
            serverName: serverName,
          ),
        ],
      ),
    );
  }
}
