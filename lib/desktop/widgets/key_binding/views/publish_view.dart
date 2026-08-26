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
import '../components/floating_stepper.dart';
import '../components/section_card.dart';
import '../../login_dialog.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../../../core/services/quill_delta_codec.dart';

/// 发布视图
class PublishView extends StatefulWidget {
  const PublishView({super.key});

  @override
  State<PublishView> createState() => _PublishViewState();
}

class _PublishViewState extends State<PublishView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = RichTextEditor.createController();
  final _scriptCtrl = RichScriptEditingController();
  final _scrollController = ScrollController();
  final _section1Key = GlobalKey();
  final _section2Key = GlobalKey();
  final _section3Key = GlobalKey();

  int? _categoryId;
  int _activeStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    _descCtrl.addListener(() => setState(() {}));
    _scriptCtrl.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserCredits();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    int newIndex = 0;
    if (maxScroll > 0 && offset >= maxScroll - 20) {
      // 触底时如果不够高，直接选中最后一个步骤
      newIndex = 2;
    } else if (offset > 600) {
      newIndex = 2;
    } else if (offset > 200) {
      newIndex = 1;
    }

    if (newIndex != _activeStepIndex) {
      setState(() => _activeStepIndex = newIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scriptCtrl.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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

    return BlocConsumer<KeyBindingBloc, KeyBindingState>(
      listenWhen: (previous, current) =>
          previous.isPublishing && !current.isPublishing,
      listener: (context, state) {
        if (state.error == null) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final hasName = _nameCtrl.text.trim().isNotEmpty;
        final hasDesc = _descCtrl.document.toPlainText().trim().isNotEmpty;
        final hasScript = _scriptCtrl.text.trim().isNotEmpty;
        final hasCategory = _categoryId != null;

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 200),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionCard(
                            cardKey: _section1Key,
                            icon: MdiIcons.informationOutline,
                            title: '1. 基本信息',
                            subtitle: '好的名称和详细描述能帮助别人更好地了解这个配置。',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ConfigFormInput(
                                  label: '配置名称',
                                  hint: '给配置起个名字（建议简单明了）',
                                  controller: _nameCtrl,
                                  maxLength: 10,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                const SectionLabel('配置描述'),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 240,
                                  child: RichTextEditor(
                                    controller: _descCtrl,
                                    maxLength: 200,
                                    maxImages: 0, // 禁止上传图片
                                    hintText: '简单描述配置的用途和功能...',
                                    compactMode: true,
                                    draftId: null,
                                    enableDraftManualSave: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SectionCard(
                            cardKey: _section2Key,
                            icon: MdiIcons.shapeOutline,
                            title: '2. 分类与标签',
                            subtitle: '选择最适合这个配置的分类。',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CategoryChips(
                                  categories: state.categories,
                                  selectedId: _categoryId,
                                  onSelected: (id) =>
                                      setState(() => _categoryId = id),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SectionCard(
                            cardKey: _section3Key,
                            icon: MdiIcons.codeJson,
                            title: '3. 脚本编辑',
                            subtitle: '在此编写你的配置代码。点击右上角按钮可以插入占位符，让用户能够自定义按键。',
                            headerTrailing: InsertPlaceholderButton(
                              onPressed: () =>
                                  PlaceholderInsertHelper.showInsertDialog(
                                    context,
                                    scriptController: _scriptCtrl,
                                    onInserted: () => setState(() {}),
                                  ),
                            ),
                            child: ScriptEditor(
                              controller: _scriptCtrl,
                              needsKey: true,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ], // closes children
                      ), // closes Column
                    ), // closes Form
                  ), // closes SingleChildScrollView
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: FloatingStepper(
                      activeIndex: _activeStepIndex,
                      steps: const ['基本信息', '分类与标签', '脚本编辑'],
                      completedSteps: [
                        hasName && hasDesc,
                        hasCategory,
                        hasScript,
                      ],
                      onStepTapped: (index) {
                        if (index == 0) _scrollToSection(_section1Key);
                        if (index == 1) _scrollToSection(_section2Key);
                        if (index == 2) _scrollToSection(_section3Key);
                      },
                    ),
                  ),
                ], // closes Stack children
              ), // closes Stack
            ), // closes Expanded
            _buildBottomBar(state, hasEnoughCredits),
          ], // closes Column children
        ); // closes Column
      },
    );
  }

  Widget _buildBottomBar(KeyBindingState state, bool hasEnoughCredits) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final hasDesc = _descCtrl.document.toPlainText().trim().isNotEmpty;
    final hasScript = _scriptCtrl.text.trim().isNotEmpty;
    final hasCategory = _categoryId != null;
    const double fixedHeight = 48.0;

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
    }

    final hintColor = !hasEnoughCredits ? AppColors.red500 : AppColors.amber500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (hint != null)
            Expanded(
              child: Container(
                height: fixedHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      size: 20,
                      color: hintColor,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
          const SizedBox(width: 16),
          SizedBox(
            height: fixedHeight,
            child: TextButton(
              onPressed: _clear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Text(
                '清空内容',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: fixedHeight,
            child: FilledButton.icon(
              onPressed: (state.isPublishing || hint != null) ? null : _submit,
              icon: state.isPublishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      MdiIcons.rocketLaunchOutline,
                      size: 18,
                      color: Colors.white,
                    ),
              label: Text(
                state.isPublishing ? '发布中...' : '发布配置',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            description: QuillDeltaCodec.encode(_descCtrl.document),
            categoryId: _categoryId!,
            config: _scriptCtrl.text,
            needsKeybind: KeyPlaceholderParser.hasPlaceholders(
              _scriptCtrl.text,
            ),
          ),
        ),
      );
      _clear();
    }
  }
}
