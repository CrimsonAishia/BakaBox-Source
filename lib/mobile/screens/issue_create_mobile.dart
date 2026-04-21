import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:io';
import '../../core/core.dart';
import '../../core/services/app_info_service.dart';
import '../../core/services/quill_delta_codec.dart';

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
  final _scrollController = ScrollController();
  final _titleFieldKey = GlobalKey();
  IssueType _selectedType = IssueType.bug;
  bool _isSubmitting = false;
  List<String> _imageUrls = [];
  
  // 草稿相关
  bool _showDraftPrompt = false;
  DraftData? _savedDraft;
  
  // 实时验证状态
  String? _titleError;
  String? _contentError;

  @override
  void initState() {
    super.initState();
    _checkDraftExists();
    // 监听标题输入，实时验证
    _titleController.addListener(_validateTitle);
    // 监听内容输入，实时验证
    _contentController.addListener(_validateContent);
  }

  @override
  void dispose() {
    _titleController.removeListener(_validateTitle);
    _contentController.removeListener(_validateContent);
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 实时验证标题
  void _validateTitle() {
    final value = _titleController.text.trim();
    String? error;
    
    if (value.isEmpty) {
      error = null; // 空值不显示错误，等提交时再提示
    } else if (value.length < 5) {
      error = '标题至少需要 5 个字符（当前 ${value.length} 个）';
    } else if (value.length > 150) {
      error = '标题最多 150 个字符（当前 ${value.length} 个）';
    }
    
    if (_titleError != error) {
      setState(() => _titleError = error);
    }
  }
  
  /// 实时验证内容
  void _validateContent() {
    final plainText = _contentController.document.toPlainText().trim();
    String? error;
    
    if (plainText.isEmpty) {
      error = null; // 空值不显示错误，等提交时再提示
    } else if (plainText.length < 20) {
      error = '内容至少需要 20 个字符（当前 ${plainText.length} 个）';
    } else if (plainText.length > 2000) {
      error = '内容最多 2000 个字符（当前 ${plainText.length} 个）';
    }
    
    if (_contentError != error) {
      setState(() => _contentError = error);
    }
  }

  /// 检查是否有草稿
  Future<void> _checkDraftExists() async {
    try {
      final hasDraft = await DraftService().hasDraft('issue_create');
      if (hasDraft) {
        final draft = await DraftService().restoreDraft('issue_create');
        if (draft != null && mounted) {
          setState(() {
            _savedDraft = draft;
            _showDraftPrompt = true;
          });
        }
      }
    } catch (e) {
      LogService.e('检查草稿失败', e);
    }
  }

  /// 恢复草稿
  void _restoreDraft() {
    if (_savedDraft == null) return;
    
    // 恢复标题
    if (_savedDraft!.metadata?['title'] != null) {
      _titleController.text = _savedDraft!.metadata!['title'] as String;
    }
    
    // 恢复类型
    if (_savedDraft!.metadata?['type'] != null) {
      final typeValue = _savedDraft!.metadata!['type'] as String;
      _selectedType = IssueType.values.firstWhere(
        (t) => t.value == typeValue,
        orElse: () => IssueType.bug,
      );
    }
    
    // 恢复内容
    if (_savedDraft!.content.isNotEmpty) {
      try {
        final document = QuillDeltaCodec.decode(_savedDraft!.content);
        _contentController.document = document;
      } catch (e) {
        LogService.e('解码草稿内容失败', e);
      }
    }
    
    // 恢复图片
    _imageUrls = _savedDraft!.imageUrls;
    
    setState(() {
      _showDraftPrompt = false;
      _savedDraft = null;
    });
    
    ToastUtils.showSuccess(context, '草稿已恢复');
  }

  /// 忽略草稿
  void _ignoreDraft() {
    DraftService().deleteDraft('issue_create');
    setState(() {
      _showDraftPrompt = false;
      _savedDraft = null;
    });
  }

  DeviceInfo _collectDeviceInfo() {
    return DeviceInfo(
      appVersion: AppInfoService.instance.version,
      platform: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      deviceModel: 'Mobile',
    );
  }
  
  /// 滚动到标题字段
  void _scrollToTitle() {
    final context = _titleFieldKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1, // 滚动到顶部 10% 的位置
      );
    }
  }

  Future<void> _saveDraft() async {
    final plainText = _contentController.document.toPlainText().trim();
    if (plainText.isEmpty && _titleController.text.trim().isEmpty) {
      ToastUtils.showWarning(context, '内容为空，无需保存草稿');
      return;
    }

    try {
      final content = QuillDeltaCodec.encode(_contentController.document);
      
      await DraftService().saveDraft(
        draftId: 'issue_create',
        content: content,
        imageUrls: _imageUrls,
        metadata: {
          'title': _titleController.text.trim(),
          'type': _selectedType.value,
        },
      );
      
      if (mounted) {
        ToastUtils.showSuccess(context, '草稿已保存');
      }
    } catch (e) {
      LogService.e('保存草稿失败', e);
      if (mounted) {
        ToastUtils.showError(context, '保存草稿失败');
      }
    }
  }

  Future<void> _submit() async {
    // 先验证标题
    final titleValue = _titleController.text.trim();
    if (titleValue.isEmpty) {
      setState(() => _titleError = '请输入标题');
      _scrollToTitle();
      ToastUtils.showError(context, '请输入标题');
      return;
    }
    if (titleValue.length < 5) {
      setState(() => _titleError = '标题至少需要 5 个字符（当前 ${titleValue.length} 个）');
      _scrollToTitle();
      ToastUtils.showError(context, '标题至少需要 5 个字符');
      return;
    }
    if (titleValue.length > 150) {
      setState(() => _titleError = '标题最多 150 个字符（当前 ${titleValue.length} 个）');
      _scrollToTitle();
      ToastUtils.showError(context, '标题最多 150 个字符');
      return;
    }
    
    // 验证内容长度
    final plainText = _contentController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      setState(() => _contentError = '请输入详细描述');
      ToastUtils.showError(context, '请输入详细描述');
      return;
    }
    if (plainText.length < 20) {
      setState(() => _contentError = '内容至少需要 20 个字符（当前 ${plainText.length} 个）');
      ToastUtils.showError(context, '内容至少需要 20 个字符');
      return;
    }
    if (plainText.length > 2000) {
      setState(() => _contentError = '内容最多 2000 个字符（当前 ${plainText.length} 个）');
      ToastUtils.showError(context, '内容最多 2000 个字符');
      return;
    }
    
    // 表单验证
    if (!_formKey.currentState!.validate()) {
      _scrollToTitle();
      return;
    }

    final content = QuillDeltaCodec.encode(_contentController.document);

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
      if (issue != null) {
        // 提交成功后删除草稿
        await DraftService().deleteDraft('issue_create');
        
        if (!mounted) return;
        
        ToastUtils.showSuccess(context, '反馈提交成功');
        context.read<IssueBloc>().add(const IssueRefresh());
        context.pop();
      }
    } catch (e) {
      LogService.e('提交反馈失败', e);
      if (mounted) {
        ToastUtils.showError(context, ErrorUtils.getErrorMessage(e, defaultMessage: '提交失败，请稍后重试'));
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
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 草稿恢复提示条
              if (_showDraftPrompt) _buildDraftPrompt(context),
              if (_showDraftPrompt) const SizedBox(height: 16),
              
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

  /// 草稿恢复提示条
  Widget _buildDraftPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0080FF);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
            primaryColor.withValues(alpha: isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.restore_rounded,
              size: 24,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '发现未保存的草稿',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '是否恢复之前编辑的内容？',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              TextButton(
                onPressed: _ignoreDraft,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(60, 32),
                ),
                child: const Text('忽略', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: _restoreDraft,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('恢复', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
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
        // 保存草稿按钮
        if (!_isSubmitting)
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _saveDraft,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('草稿'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0080FF),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return switch (type) {
      IssueType.bug => (
        const Color(0xFFDC2626),
        isDark ? const Color(0xFFDC2626).withValues(alpha: 0.15) : const Color(0xFFFEE2E2),
        MdiIcons.bug,
      ),
      IssueType.feature => (
        const Color(0xFF2563EB),
        isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFDBEAFE),
        MdiIcons.lightbulbOnOutline,
      ),
      IssueType.question => (
        const Color(0xFF059669),
        isDark ? const Color(0xFF059669).withValues(alpha: 0.15) : const Color(0xFFD1FAE5),
        MdiIcons.helpCircleOutline,
      ),
    };
  }


  Widget _buildTitleField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleLength = _titleController.text.trim().length;
    final isOverLimit = titleLength > 150;
    final isNearLimit = titleLength > 130;
    
    return Column(
      key: _titleFieldKey,
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
            const Spacer(),
            // 字数统计
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isOverLimit 
                    ? const Color(0xFFFEE2E2) 
                    : isNearLimit 
                        ? const Color(0xFFFEF3C7)
                        : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$titleLength/150',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isOverLimit 
                      ? const Color(0xFFDC2626)
                      : isNearLimit
                          ? const Color(0xFFF59E0B)
                          : colorScheme.onSurfaceVariant,
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
              color: isOverLimit 
                  ? const Color(0xFFDC2626)
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: isOverLimit ? 2 : 1,
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
            maxLength: 150,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (value) => setState(() {}),
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
              if (value.trim().length > 150) return '标题最多 150 个字符';
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
    final contentLength = _contentController.document.toPlainText().trim().length;
    final hasError = _contentError != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: hasError ? const Color(0xFFDC2626) : const Color(0xFF0080FF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '详细描述',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: hasError ? const Color(0xFFDC2626) : colorScheme.onSurface,
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
            const Spacer(),
            // 字数统计
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: contentLength > 2000 
                    ? const Color(0xFFFEE2E2)
                    : contentLength < 20 && contentLength > 0
                        ? const Color(0xFFFEF3C7)
                        : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$contentLength/2000',
                style: TextStyle(
                  color: contentLength > 2000 
                      ? const Color(0xFFDC2626)
                      : contentLength < 20 && contentLength > 0
                          ? const Color(0xFFF59E0B)
                          : colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 错误提示（在编辑器上方）
        if (hasError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _contentError!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError 
                  ? const Color(0xFFDC2626)
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: hasError ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: hasError 
                    ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                    : colorScheme.shadow.withValues(alpha: 0.05),
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
                maxLength: 2000,
                maxImages: 8,
                compactMode: true,
                draftId: 'issue_create',
                enableDraftManualSave: true,
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
    final isDark = theme.brightness == Brightness.dark;
    final deviceInfo = _collectDeviceInfo();
    final primaryColor = const Color(0xFF0080FF);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
            primaryColor.withValues(alpha: isDark ? 0.05 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              MdiIcons.cellphoneInformation,
              size: 22,
              color: primaryColor,
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
                        color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '自动附加',
                        style: TextStyle(
                          color: primaryColor,
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
