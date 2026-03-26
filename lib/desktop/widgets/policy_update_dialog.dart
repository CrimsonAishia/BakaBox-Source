import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/constants/policy_constants.dart';
import '../../core/services/policy_service.dart';

/// 协议更新对话框
///
/// 当协议版本更新时显示，要求用户重新同意
class PolicyUpdateDialog extends StatefulWidget {
  final VoidCallback onAgreed;

  const PolicyUpdateDialog({super.key, required this.onAgreed});

  /// 显示协议更新对话框
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 不允许点击外部关闭
      builder: (context) =>
          PolicyUpdateDialog(onAgreed: () => Navigator.of(context).pop(true)),
    );
  }

  @override
  State<PolicyUpdateDialog> createState() => _PolicyUpdateDialogState();
}

class _PolicyUpdateDialogState extends State<PolicyUpdateDialog> {
  final PolicyService _policyService = PolicyService();

  bool _agreedToPrivacy = false;
  bool _agreedToTerms = false;
  String? _previousVersion;

  @override
  void initState() {
    super.initState();
    _loadPreviousVersion();
  }

  Future<void> _loadPreviousVersion() async {
    final version = await _policyService.getAgreedVersion();
    setState(() => _previousVersion = version);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor = isDark
        ? Colors.white70
        : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      MdiIcons.fileDocumentEditOutline,
                      color: const Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '协议已更新',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _previousVersion != null
                              ? '版本 $_previousVersion → ${PolicyConstants.version}'
                              : '版本 ${PolicyConstants.version}',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 更新说明
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            MdiIcons.informationOutline,
                            size: 20,
                            color: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '重要更新',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '我们更新了隐私政策和用户协议，请仔细阅读并重新同意后继续使用。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 协议同意选项
                    _buildAgreementCheckbox(
                      isDark: isDark,
                      isChecked: _agreedToPrivacy,
                      onTap: () =>
                          setState(() => _agreedToPrivacy = !_agreedToPrivacy),
                      label: '隐私政策',
                      onViewTap: () => _showPolicyDialog(context, isDark, true),
                    ),
                    const SizedBox(height: 12),
                    _buildAgreementCheckbox(
                      isDark: isDark,
                      isChecked: _agreedToTerms,
                      onTap: () =>
                          setState(() => _agreedToTerms = !_agreedToTerms),
                      label: '用户协议',
                      onViewTap: () =>
                          _showPolicyDialog(context, isDark, false),
                    ),
                  ],
                ),
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '继续使用即表示您同意更新后的协议',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: (_agreedToPrivacy && _agreedToTerms)
                        ? _handleAgree
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      disabledBackgroundColor: const Color(
                        0xFF3B82F6,
                      ).withValues(alpha: 0.3),
                    ),
                    child: const Text('同意并继续', style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建协议复选框
  Widget _buildAgreementCheckbox({
    required bool isDark,
    required bool isChecked,
    required VoidCallback onTap,
    required String label,
    required VoidCallback onViewTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isChecked
                ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            // 复选框
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked
                    ? const Color(0xFF3B82F6)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked
                      ? const Color(0xFF3B82F6)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : const Color(0xFFCBD5E1)),
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            // 文字
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  children: [
                    const TextSpan(text: '我已阅读并同意 '),
                    TextSpan(
                      text: '《$label》',
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 查看按钮
            InkWell(
              onTap: onViewTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '查看',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      MdiIcons.openInNew,
                      size: 12,
                      color: const Color(0xFF3B82F6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示协议详情对话框
  void _showPolicyDialog(
    BuildContext context,
    bool isDark,
    bool isPrivacyPolicy,
  ) {
    showDialog(
      context: context,
      builder: (context) => _PolicyDetailDialog(
        isDark: isDark,
        title: isPrivacyPolicy ? '隐私政策' : '用户协议',
        content: isPrivacyPolicy
            ? PolicyConstants.privacyPolicy
            : PolicyConstants.termsOfService,
      ),
    );
  }

  /// 处理同意
  Future<void> _handleAgree() async {
    try {
      await _policyService.agreeToPolicy();
      widget.onAgreed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }
}

/// 协议详情对话框
class _PolicyDetailDialog extends StatelessWidget {
  final bool isDark;
  final String title;
  final String content;

  const _PolicyDetailDialog({
    required this.isDark,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor = isDark
        ? Colors.white70
        : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        height: 600,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.fileDocumentOutline,
                    color: const Color(0xFF3B82F6),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryTextColor),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            // 内容区域
            Expanded(
              child: Markdown(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: secondaryTextColor,
                  ),
                  h2: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.5,
                  ),
                  h3: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.5,
                  ),
                  listBullet: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                  strong: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  a: const TextStyle(
                    color: Color(0xFF3B82F6),
                    decoration: TextDecoration.underline,
                  ),
                ),
                padding: const EdgeInsets.all(32),
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('我知道了', style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
