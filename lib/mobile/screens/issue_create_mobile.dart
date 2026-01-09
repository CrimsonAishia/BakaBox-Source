import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:io';
import '../../core/core.dart';
import '../../core/services/quill_markdown_converter.dart';

/// 创建 Issue 移动端页面
class IssueCreateMobile extends StatefulWidget {
  const IssueCreateMobile({super.key});

  @override
  State<IssueCreateMobile> createState() => _IssueCreateMobileState();
}

class _IssueCreateMobileState extends State<IssueCreateMobile> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = quill.QuillController.basic();
  IssueType _selectedType = IssueType.bug;
  bool _isSubmitting = false;
  List<String> _imageUrls = [];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  DeviceInfo _collectDeviceInfo() {
    return DeviceInfo(
      appVersion: AppConstants.appVersion,
      platform: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      deviceModel: 'Mobile',
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // 验证内容长度
    final content = QuillMarkdownConverter.toMarkdown(_contentController.document).trim();
    if (content.isEmpty) {
      ToastUtils.showWarning(context, '请输入详细描述');
      return;
    }
    if (content.length < 10) {
      ToastUtils.showWarning(context, '详细描述至少 10 个字符');
      return;
    }
    if (content.length > 5000) {
      ToastUtils.showWarning(context, '详细描述最多 5000 个字符');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      ToastUtils.showWarning(context, '请先登录');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = CreateIssueRequest(
        type: _selectedType.value,
        title: _titleController.text.trim(),
        content: content,
        images: _imageUrls,
        deviceInfo: _collectDeviceInfo(),
      );

      final issue = await IssueApi().createIssue(request);
      if (issue != null && mounted) {
        ToastUtils.showSuccess(context, '反馈提交成功');
        context.read<IssueBloc>().add(const IssueRefresh());
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeSelector(context).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 24),
              _buildTitleField(context).animate().fadeIn(duration: 300.ms, delay: 100.ms),
              const SizedBox(height: 24),
              _buildContentField(context).animate().fadeIn(duration: 300.ms, delay: 200.ms),
              if (_selectedType == IssueType.bug) ...[
                const SizedBox(height: 24),
                _buildDeviceInfoCard(context).animate().fadeIn(duration: 300.ms, delay: 300.ms),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AppBar(
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
          onPressed: () => context.pop(),
          tooltip: '关闭',
        ),
      ),
      title: Text(
        '提交反馈',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.appBarTheme.foregroundColor,
        ),
      ).animate().fadeIn(duration: 300.ms),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: _isSubmitting
              ? Container(
                  width: 80,
                  height: 40,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0080FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '提交',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
        ),
      ],
    );
  }


  Widget _buildTypeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF0080FF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '反馈类型',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: IssueType.values.map((type) {
            final isSelected = _selectedType == type;
            final (color, bgColor, icon) = _getTypeStyle(type);
            
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type != IssueType.values.last ? 12 : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? bgColor : colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : colorScheme.outline.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.2),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.15) : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            size: 22,
                            color: isSelected ? color : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          type.label,
                          style: TextStyle(
                            color: isSelected ? color : colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 获取问题类型的样式配置
  (Color, Color, IconData) _getTypeStyle(IssueType type) {
    return switch (type) {
      IssueType.bug => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), MdiIcons.bug),
      IssueType.feature => (const Color(0xFF2563EB), const Color(0xFFDBEAFE), MdiIcons.lightbulbOnOutline),
      IssueType.question => (const Color(0xFF059669), const Color(0xFFD1FAE5), MdiIcons.helpCircleOutline),
    };
  }


  Widget _buildTitleField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF0080FF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '标题',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '必填',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: TextFormField(
            controller: _titleController,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: '简洁描述你的问题或建议',
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  MdiIcons.formatTitle,
                  color: const Color(0xFF0080FF),
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '请输入标题';
              if (value.trim().length < 5) return '标题至少 5 个字符';
              if (value.trim().length > 100) return '标题最多 100 个字符';
              return null;
            },
          ),
        ),
      ],
    );
  }


  Widget _buildContentField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF0080FF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '详细描述',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '必填',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 300,
              child: RichTextEditor(
                controller: _contentController,
                hintText: _selectedType == IssueType.bug
                    ? '请详细描述问题，包括：问题现象、复现步骤、期望行为'
                    : '请详细描述你的建议或问题...',
                maxLength: 5000,
                maxImages: 5,
                compactMode: true,
                onImagesChanged: (urls) {
                  setState(() {
                    _imageUrls = urls;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildDeviceInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = _collectDeviceInfo();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0080FF).withValues(alpha: 0.08),
            const Color(0xFF0080FF).withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0080FF).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0080FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              MdiIcons.cellphoneInformation,
              size: 22,
              color: const Color(0xFF0080FF),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '设备信息',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0080FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '自动附加',
                        style: TextStyle(
                          color: Color(0xFF0080FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${deviceInfo.appVersion} · ${deviceInfo.platform} · ${deviceInfo.osVersion}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            MdiIcons.checkCircle,
            size: 20,
            color: const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }
}
