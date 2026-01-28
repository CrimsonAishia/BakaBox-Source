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
import '../components/common_widgets.dart';
import '../../login_dialog.dart';

/// 发布视图
/// 
/// TODO: 从原 key_binding_tool.dart 中提取完整的 _PublishView 实现
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
        backgroundColor: isDark ? const Color(0xFF1E293B) : null,
        title: Row(
          children: [
            Icon(MdiIcons.starCircleOutline, color: const Color(0xFFf59e0b), size: 24),
            const SizedBox(width: 10),
            Text(CreditConstants.insufficientCreditsTitle, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : null)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CreditConstants.getPublishConfigCreditsMessage(CreditConstants.minCredits),
              style: TextStyle(color: isDark ? Colors.white70 : null),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(CreditConstants.getCurrentCreditsLabel(), style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                Text('$currentCredits', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFef4444))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              CreditConstants.creditsAcquisitionHint,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey[500]),
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
              color: const Color(0xFF0080FF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(MdiIcons.accountLockOutline, size: 32, color: const Color(0xFF0080FF)),
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
              backgroundColor: const Color(0xFF0080FF),
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
                      _buildInput('配置名称', '给配置起个名字', _nameCtrl),
                      const SizedBox(height: 12),
                      _buildInput('配置描述', '简单描述功能', _descCtrl, maxLines: 2),
                      const SizedBox(height: 16),
                      // 分类选择
                      Text('选择分类', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildCategoryChips(state.categories),
                      const SizedBox(height: 16),
                      // 类型选择
                      Text('配置类型', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildTypeSelector(),
                      const SizedBox(height: 16),
                      // 脚本编辑
                      Row(
                        children: [
                          Text('配置脚本', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey[600])),
                          if (_needsKey) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFf59e0b).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '需要按键绑定',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFf59e0b)),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (_needsKey) _buildInsertBtn(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildScriptEditor(),
                      if (_needsKey && placeholders.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildPlaceholderTags(placeholders),
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

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0080FF).withValues(alpha: 0.06),
            isDark ? const Color(0xFF1E293B) : Colors.white,
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
              color: const Color(0xFF0080FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(MdiIcons.rocketLaunchOutline, size: 18, color: const Color(0xFF0080FF)),
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
                  color: isDark ? Colors.white54 : const Color(0xFF6b7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController ctrl, {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF1a1a2e),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0080FF)),
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) => v?.trim().isEmpty == true ? '必填' : null,
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<KeyConfigCategory> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((c) {
        final sel = _categoryId == c.id;
        return HoverChip(
          label: c.name,
          selected: sel,
          onTap: () => setState(() => _categoryId = c.id),
        );
      }).toList(),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: HoverTypeOption(
            icon: MdiIcons.autoFix,
            title: '自动应用',
            selected: !_needsKey,
            onTap: () => setState(() => _needsKey = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HoverTypeOption(
            icon: MdiIcons.keyboardOutline,
            title: '按键绑定',
            selected: _needsKey,
            onTap: () => setState(() => _needsKey = true),
          ),
        ),
      ],
    );
  }

  Widget _buildInsertBtn() {
    return FilledButton.icon(
      onPressed: _insertPlaceholder,
      icon: Icon(MdiIcons.keyboardOutline, size: 16),
      label: const Text('插入按键绑定', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0080FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildScriptEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: _scriptCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: isDark ? const Color(0xFFcdd6f4) : const Color(0xFF374151),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: _needsKey ? '输入脚本，使用 {{KEY:名称}} 插入按键占位符' : '输入脚本...',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v?.trim().isEmpty == true) return '必填';
              if (_needsKey && !KeyPlaceholderParser.hasPlaceholders(v!)) return '需包含按键占位符';
              return null;
            },
          ),
        ),
        if (_needsKey) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0080FF).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF0080FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: const Color(0xFF0080FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '点击右上角按钮在脚本中插入按键绑定点，使用者可以自己选择按键',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholderTags(List<KeyPlaceholder> placeholders) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(MdiIcons.keyboardOutline, size: 12, color: const Color(0xFFf59e0b)),
            const SizedBox(width: 6),
            Text(
              '已添加的按键占位符',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: placeholders.map((p) => PlaceholderTag(
            label: p.label,
            onRemove: () {
              _scriptCtrl.text = _scriptCtrl.text.replaceAll('{{KEY:${p.label}}}', '');
              setState(() {});
            },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomBar(KeyBindingState state, bool hasEnoughCredits) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final hasDesc = _descCtrl.text.trim().isNotEmpty;
    final hasScript = _scriptCtrl.text.trim().isNotEmpty;
    final hasCategory = _categoryId != null;
    
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
    
    final hintColor = !hasEnoughCredits ? const Color(0xFFef4444) : const Color(0xFFf59e0b);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF475569) : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          if (hint != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: hintColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hintColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(MdiIcons.informationOutline, size: 18, color: hintColor),
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
          TextButton(
            onPressed: _clear,
            child: const Text('清空', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: (state.isPublishing || hint != null) ? null : _submit,
            icon: state.isPublishing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(MdiIcons.rocketLaunchOutline, size: 14, color: Colors.white),
            label: Text(
              state.isPublishing ? '发布中' : '发布',
              style: const TextStyle(fontSize: 12),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0080FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  void _insertPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(MdiIcons.keyboardOutline, size: 18, color: const Color(0xFF0080FF)),
            ),
            const SizedBox(width: 10),
            Text('插入按键绑定', style: TextStyle(fontSize: 15, color: isDark ? Colors.white : null)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '给这个按键位置起个说明，使用者会根据这个说明选择按键',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : null),
              decoration: InputDecoration(
                labelText: '按键说明',
                hintText: '例如：触发键1、触发键2',
                helperText: '将在脚本中插入 {{KEY:按键说明}}',
                helperStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!),
                ),
                prefixIcon: Icon(MdiIcons.tagOutline, size: 18),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _doInsert(v.trim());
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton.icon(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _doInsert(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('插入'),
          ),
        ],
      ),
    );
  }

  void _doInsert(String label) {
    final ph = ' {{KEY:$label}} ';
    final text = _scriptCtrl.text;
    final sel = _scriptCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    
    final newText = text.replaceRange(start, end, ph);
    final newCursorPos = start + ph.length;
    
    _scriptCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
    setState(() {});
  }

  void _submit() {
    if (!_checkCredits()) return;
    
    if (_formKey.currentState?.validate() == true && _categoryId != null) {
      final configId = 'cfg_${DateTime.now().millisecondsSinceEpoch}_${_nameCtrl.text.trim().hashCode.abs()}';
      
      context.read<KeyBindingBloc>().add(KeyBindingPublishConfig(
        KeyConfigCreateRequest(
          configId: configId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          categoryId: _categoryId!,
          config: _scriptCtrl.text,
          needsKeybind: _needsKey,
        ),
      ));
      _clear();
    }
  }
}
