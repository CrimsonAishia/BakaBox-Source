import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/bloc/warmup/warmup_bloc.dart';
import '../../../core/bloc/warmup/warmup_event.dart';
import '../../../core/bloc/warmup/warmup_state.dart';

/// 暖服倒计时弹窗（叠加在暖服窗口上方）
class WarmupCountdownDialog extends StatelessWidget {
  final WarmupBlocState state;

  const WarmupCountdownDialog({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.isCountdownActive && !state.isLaunching) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width,
      height: size.height,
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '暖服人数已达标！',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.isLaunching ? '正在启动游戏...' : '游戏即将启动并加入服务器',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 48),

            // 倒计时圆环
            if (!state.isLaunching)
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: state.countdownSeconds / 60.0,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.orange,
                      ),
                    ),
                    Center(
                      child: Text(
                        '${state.countdownSeconds}',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(
                width: 160,
                height: 160,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ),

            const SizedBox(height: 64),

            // 按钮组
            if (!state.isLaunching)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Material(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        context.read<WarmupBloc>().add(
                          const WarmupCountdownCancel(),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: Colors.white24,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Material(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        context.read<WarmupBloc>().add(
                          const WarmupLaunchGame(),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: Colors.orange.withValues(alpha: 0.8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              MdiIcons.gamepad,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '立即加入',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
