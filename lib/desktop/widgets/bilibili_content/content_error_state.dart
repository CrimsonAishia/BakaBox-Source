import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/core.dart';

/// B站内容错误状态组件
class BilibiliContentErrorState extends StatelessWidget {
  final String message;

  static const _bilibiliBlue = Color(0xFF00A1D6);

  const BilibiliContentErrorState({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: _bilibiliBlue.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: _bilibiliBlue.withValues(alpha: 0.8))),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => context.read<BilibiliContentBloc>().add(const BilibiliContentFetchRequested(refresh: true)),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: _bilibiliBlue.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(20)),
              child: Text('重试', style: TextStyle(color: _bilibiliBlue, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
