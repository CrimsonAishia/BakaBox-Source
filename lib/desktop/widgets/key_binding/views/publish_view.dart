import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../core/bloc/auth/auth_event.dart';
import '../../../../core/bloc/auth/auth_state.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/constants/credit_constants.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/utils/key_placeholder_parser.dart';
import '../components/form_widgets.dart';
import '../../login_dialog.dart';
import '../../../../core/constants/app_colors.dart';

/// 发布视图
///
/// 包括：
/// - 登录提示
/// - 发布表单（名称、描述、分类、类型、脚本）
/// - 积分检查
/// - 按键占位符插入
class PublishView extends StatefulWidget {
  const PublishView({super.key});

  @override
  State<PublishView> createState() => _PublishViewState();
}

class _PublishViewState extends State<PublishView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _scriptCtrl = TextEditingController();
  int? _categoryId;
  bool _needsKey = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserCredits();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scriptCtrl.dispose();
    super.dispose();
  }

  void _refreshUserCredits() {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated) {
      context.read<AuthBloc>().add(const AuthRefreshRequested());
    }
  }

  bool _checkCredits() {
    final authState = context.read<AuthBloc>().state;
    final userInfo = authState.userInfo;
    if (userInfo == null) return false;

    final credits = int.tryParse(userInfo.credits ?? '0') ?? 0;
    if (credits < CreditConstants.minCredits) {
      _showCreditsPrompt(credits);
      return false;
    }
    return true;
  }

  void _showCreditsPrompt(int currentCredits) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? AppColors.slate800 : null,
        title: Row(
          children: [
            Icon(
              MdiIcons.starCircleOutline,
              color: AppColors.amber500,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              CreditConstants.insufficientCreditsTitle,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : null,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CreditConstants.getPublishConfigCreditsMessage(
                CreditConstants.minCredits,
              ),
              style: TextStyle(color: isDark ? Colors.white70 : null),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  CreditConstants.getCurrentCreditsLabel(),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                Text(
                  '$currentCredits',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.red500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              CreditConstants.creditsAcquisitionHint,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (!authState.isAuthenticated) {
          return _buildLoginPrompt();
        }
        return _buildPublishForm(context, authState);
      },
    );
  }

  Widget _buildLoginPrompt() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              MdiIcons.accountLockOutline,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '登录后发布配置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1a1a2e),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '分享你的配置给其他玩家',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => LoginDialog.show(context),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('去登录'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishForm(BuildContext context, AuthState authState) {
    final credits = int.tryParse(authState.userInfo?.credits ?? '0') ?? 0;
    final hasEnoughCredits = credits >= CreditConstants.minCredits;

    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        if (_categoryId == null && state.categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _categoryId == null) {
              setState(() => _categoryId = state.categories.first.id);
            }
          });
        }

        final placeholders = KeyPlaceholderParser.parse(_scriptCtrl.text);

        return Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConfigFormInput(
                        label: '配置名称',
                        hint: '给配置起个名字',
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      ConfigFormInput(
                        label: '配置描述',
                        hint: '简单描述功能',
                        controller: _descCtrl,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      // 分类选择
                      _buildSectionLabel('选择分类'),
                      const SizedBox(height: 8),
                      CategoryChips(
                        categories: state.categories,
                        selectedId: _categoryId,
                        onSelected: (id) => setState(() => _categoryId = id),
                      ),
                      const SizedBox(height: 16),
                      // 类型选择
                      _buildSectionLabel('配置类型'),
                      const SizedBox(height: 8),
                      ConfigTypeSelector(
                        needsKey: _needsKey,
                        onChanged: (v) => setState(() => _needsKey = v),
                      ),
                      const SizedBox(height: 16),
                      // 脚本编辑
                      _buildScriptHeader(),
                      const SizedBox(height: 8),
                      ScriptEditor(
                        controller: _scriptCtrl,
                        needsKey: _needsKey,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_needsKey && placeholders.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        PlaceholderTagList(
                          placeholders: placeholders,
                          scriptController: _scriptCtrl,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(state, hasEnoughCredits),
          ],
        );
      },
    );
  }

  Widget _buildSectionLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white54 : Colors.grey[600],
      ),
    );
  }

  Widget _buildScriptHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          '配置脚本',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        if (_needsKey) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.amber500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '需要按键绑定',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.amber500,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (_needsKey)
          InsertPlaceholderButton(
            onPressed: () => PlaceholderInsertHelper.showInsertDialog(
              context,
              scriptController: _scriptCtrl,
              onInserted: () => setState(() {}),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            isDark ? AppColors.slate800 : Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              MdiIcons.rocketLaunchOutline,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '发布新配置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '分享给社区',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : AppColors.gray500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(KeyBindingState state, bool hasEnoughCredits) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final hasDesc = _descCtrl.text.trim().isNotEmpty;
    final hasScript = _scriptCtrl.text.trim().isNotEmpty;
    final hasCategory = _categoryId != null;
    final hasPlaceholders = KeyPlaceholderParser.hasPlaceholders(
      _scriptCtrl.text,
    );
    const double fixedHeight = 44.0;

    String? hint;
    if (!hasEnoughCredits) {
      hint = '积分不足，无法发布';
    } else if (!hasName) {
      hint = '请输入配置名称';
    } else if (!hasDesc) {
      hint = '请输入配置描述';
    } else if (!hasCategory) {
      hint = '请选择分类';
    } else if (!hasScript) {
      hint = '请输入配置脚本';
    } else if (_needsKey && !hasPlaceholders) {
      hint = '请在脚本中插入按键绑定';
    }

    final hintColor = !hasEnoughCredits
        ? AppColors.red500
        : AppColors.amber500;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate700 : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.slate600 : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          if (hint != null)
            Expanded(
              child: Container(
                height: fixedHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: hintColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hintColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MdiIcons.informationOutline,
                      size: 18,
                      color: hintColor,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          SizedBox(
            height: fixedHeight,
            child: TextButton(
              onPressed: _clear,
              child: const Text('清空', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: fixedHeight,
            child: FilledButton.icon(
              onPressed: (state.isPublishing || hint != null) ? null : _submit,
              icon: state.isPublishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      MdiIcons.rocketLaunchOutline,
                      size: 14,
                      color: Colors.white,
                    ),
              label: Text(
                state.isPublishing ? '发布中' : '发布',
                style: const TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clear() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _scriptCtrl.clear();
    setState(() {
      _categoryId = null;
      _needsKey = false;
    });
  }

  void _submit() {
    if (!_checkCredits()) return;

    if (_formKey.currentState?.validate() == true && _categoryId != null) {
      final configId =
          'cfg_${DateTime.now().millisecondsSinceEpoch}_${_nameCtrl.text.trim().hashCode.abs()}';

      context.read<KeyBindingBloc>().add(
        KeyBindingPublishConfig(
          KeyConfigCreateRequest(
            configId: configId,
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            categoryId: _categoryId!,
            config: _scriptCtrl.text,
            needsKeybind: _needsKey,
          ),
        ),
      );
      _clear();
    }
  }
}
