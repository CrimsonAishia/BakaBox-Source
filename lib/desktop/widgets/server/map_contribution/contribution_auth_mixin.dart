import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../login_dialog.dart';
import '../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/credit_constants.dart';

mixin ContributionAuthMixin<T extends StatefulWidget> on State<T> {
  /// 检查登录状态
  bool checkLogin() {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      showLoginPrompt();
      return false;
    }
    return true;
  }

  /// 检查积分是否足够
  bool checkCredits() {
    final authState = context.read<AuthBloc>().state;
    final userInfo = authState.userInfo;
    if (userInfo == null) return false;

    final credits = int.tryParse(userInfo.credits ?? '0') ?? 0;
    if (credits < CreditConstants.minCredits) {
      showCreditsPrompt(credits);
      return false;
    }
    return true;
  }

  /// 显示登录提示
  void showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要登录'),
        content: const Text('请先登录论坛账户后再进行此操作'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              LoginDialog.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  /// 显示积分不足提示
  void showCreditsPrompt(int currentCredits) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(CreditConstants.insufficientCreditsTitle),
        content: Text(
          CreditConstants.getMapContributionCreditsMessage(
            CreditConstants.minCredits,
            currentCredits,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
