import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/bloc/activity/activity_bloc.dart';
import '../../../../core/models/activity_model.dart';

class ServerCardActivityBadge extends StatelessWidget {
  final String serverAddress;

  const ServerCardActivityBadge({super.key, required this.serverAddress});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityBloc, ActivityState>(
      buildWhen: (previous, current) {
        // 只有在当前服务器对应的活动发生变化时才刷新
        return _getActivities(previous.activities, serverAddress).length !=
            _getActivities(current.activities, serverAddress).length;
      },
      builder: (context, state) {
        final activities = _getActivities(state.activities, serverAddress);
        if (activities.isEmpty) return const SizedBox.shrink();

        return Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  activities.length == 1
                      ? '活动进行中'
                      : '${activities.length}个活动进行中',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<ActivityModel> _getActivities(
    List<ActivityModel> allActivities,
    String address,
  ) {
    return allActivities
        .where((a) => a.serverAddresses.contains(address))
        .toList();
  }
}
