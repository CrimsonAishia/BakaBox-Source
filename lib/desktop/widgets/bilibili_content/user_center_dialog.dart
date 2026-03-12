import 'package:flutter/material.dart';
import 'user_center_page.dart';

/// 用户中心弹窗
class BilibiliUserCenterDialog extends StatelessWidget {
  static const double _dialogWidth = 700;
  static const double _dialogHeight = 650;

  const BilibiliUserCenterDialog._();

  /// 显示用户中心弹窗
  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭用户中心',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: _dialogWidth,
              height: _dialogHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: _UserCenterDialogContent(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _UserCenterDialogContent extends StatelessWidget {
  const _UserCenterDialogContent();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BilibiliUserCenterPage(
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
