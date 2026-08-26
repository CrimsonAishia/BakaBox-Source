import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../../core/models/key_config_models.dart';
import '../../../../../core/utils/key_placeholder_parser.dart';
import '../components/common_widgets.dart' as common;
import '../components/vote_widgets.dart';
import '../views/comments_view.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/rich_text_viewer.dart';
import '../components/key_capture_dialog.dart';
import '../../common_scroll_indicator.dart';

class ConfigDetailDialog extends StatefulWidget {
  final KeyConfig initialConfig;
  final void Function(KeyConfig config)? onEditConfig;

  const ConfigDetailDialog({
    super.key,
    required this.initialConfig,
    this.onEditConfig,
  });

  static void show(
    BuildContext context, {
    required KeyConfig config,
    void Function(KeyConfig)? onEditConfig,
  }) {
    final bloc = context.read<KeyBindingBloc>();
    final authBloc = context.read<AuthBloc>();

    // 设置当前选中的配置
    bloc.add(KeyBindingSelectConfig(config));

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ConfigDetail',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: authBloc),
          ],
          child: ConfigDetailDialog(
            initialConfig: config,
            onEditConfig: onEditConfig,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 12 * animation.value,
            sigmaY: 12 * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<ConfigDetailDialog> createState() => _ConfigDetailDialogState();
}

class _ConfigDetailDialogState extends State<ConfigDetailDialog> {
  int _currentStep = 0;
  late int _configId;
  final ScrollController _codeScrollController = ScrollController();
  final ScrollController _step1ScrollController = ScrollController();
  bool _showStep1TopIndicator = false;
  bool _showStep1BottomIndicator = false;

  @override
  void initState() {
    super.initState();
    _configId = widget.initialConfig.id;
    _step1ScrollController.addListener(_updateStep1ScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateStep1ScrollIndicators(),
    );
  }

  @override
  void dispose() {
    _step1ScrollController.removeListener(_updateStep1ScrollIndicators);
    _step1ScrollController.dispose();
    _codeScrollController.dispose();
    super.dispose();
  }

  void _updateStep1ScrollIndicators() {
    if (!_step1ScrollController.hasClients) return;
    final pos = _step1ScrollController.position;
    final showTop = pos.pixels > pos.minScrollExtent;
    final showBottom = pos.pixels < pos.maxScrollExtent;
    if (_showStep1TopIndicator != showTop ||
        _showStep1BottomIndicator != showBottom) {
      setState(() {
        _showStep1TopIndicator = showTop;
        _showStep1BottomIndicator = showBottom;
      });
    }
  }

  void _scrollToNextUnset(String script, KeyBindingState state) {
    final lines = script.split('\n');
    final pattern = KeyPlaceholderParser.placeholderPattern;
    for (int i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        bool hasUnset = false;
        final matches = pattern.allMatches(lines[i]);
        for (final match in matches) {
          final label = match.group(1)!;
          if (!state.keyBindings.containsKey(label) ||
              state.keyBindings[label]!.isEmpty) {
            hasUnset = true;
            break;
          }
        }
        if (hasUnset) {
          // Line height is ~ 14 * 2.2 = 30.8. Add buffer for padding.
          final targetOffset = i * 30.8 - 40;
          if (_codeScrollController.hasClients) {
            _codeScrollController.animateTo(
              targetOffset.clamp(
                0.0,
                _codeScrollController.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: BlocBuilder<KeyBindingBloc, KeyBindingState>(
        builder: (context, state) {
          final cfg = state.selectedConfig ?? widget.initialConfig;

          if (cfg.id != _configId) {
            // 被选中配置发生变化（极少发生，因为这是个模态弹窗，不能点列表了）
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _configId = cfg.id;
                  _currentStep = 0;
                });
              }
            });
          }

          final placeholders = KeyPlaceholderParser.parse(cfg.config);
          final bool needsKeybind = cfg.needsKeybind && placeholders.isNotEmpty;
          final allBound =
              !cfg.needsKeybind ||
              placeholders.isEmpty ||
              KeyPlaceholderParser.validate(cfg.config, state.keyBindings);
          final applied = state.isConfigApplied(cfg.configId);
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            width: 860,
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 800),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent,
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildHeroHeader(cfg, state, applied, context),
                        _buildStepper(needsKeybind),
                        Expanded(
                          child: _buildCurrentStepContent(
                            cfg,
                            placeholders,
                            state,
                            needsKeybind,
                            applied,
                          ),
                        ),
                        _buildFooterControls(
                          cfg,
                          placeholders,
                          state,
                          needsKeybind,
                          allBound,
                          applied,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroHeader(
    KeyConfig config,
    KeyBindingState state,
    bool applied,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwner = config.isOwner;
    final isMock = config.id < 0;
    final hasPending = config.isApproved && isOwner && config.hasPendingChange;

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate700 : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              config.needsKeybind
                  ? MdiIcons.keyboardOutline
                  : MdiIcons.codeJson,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    common.Badge(
                      label: config.category,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    common.Badge(
                      label: config.needsKeybind ? '需绑定' : '自动',
                      color: config.needsKeybind
                          ? AppColors.amber500
                          : AppColors.emerald500,
                    ),
                    if (applied) ...[
                      const SizedBox(width: 6),
                      common.Badge(
                        label: '已应用',
                        color: AppColors.emerald500,
                        filled: true,
                      ),
                    ],
                    if (isOwner) ...[
                      const SizedBox(width: 6),
                      common.Badge(
                        label: '我的',
                        color: AppColors.violet500,
                        filled: true,
                      ),
                    ],
                    if (hasPending) ...[
                      const SizedBox(width: 6),
                      common.Badge(
                        label: '变更审核中',
                        color: AppColors.amber500,
                        filled: true,
                      ),
                    ],
                    const SizedBox(width: 16),
                    if (!isMock) ...[
                      Icon(
                        MdiIcons.downloadOutline,
                        size: 14,
                        color: isDark ? Colors.white38 : AppColors.gray500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${config.useCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : AppColors.gray500,
                        ),
                      ),
                      if (config.isApproved) ...[
                        const SizedBox(width: 12),
                        Icon(
                          MdiIcons.commentOutline,
                          size: 14,
                          color: isDark ? Colors.white38 : AppColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${config.commentCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : AppColors.gray500,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  if (!isMock)
                    DetailVoteButtons(config: config, isOwner: isOwner),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(bool needsKeybind) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> steps = ['了解配置'];
    if (needsKeybind) steps.add('按键设置');
    steps.add('预览与应用');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e1e2e) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate700 : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index % 2 != 0) {
            final stepIndex = index ~/ 2;
            final isCompleted = _currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: isCompleted
                    ? AppColors.primary
                    : (isDark ? AppColors.slate600 : Colors.grey[200]),
              ),
            );
          } else {
            final stepIndex = index ~/ 2;
            final isActive = _currentStep == stepIndex;
            final isCompleted = _currentStep > stepIndex;
            final color = isActive || isCompleted
                ? AppColors.primary
                : (isDark ? AppColors.slate600 : Colors.grey[400]!);

            return Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? color : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isCompleted
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.primary,
                        )
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : color,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Text(
                  steps[stepIndex],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive
                        ? (isDark ? Colors.white : Colors.black87)
                        : color,
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent(
    KeyConfig cfg,
    List<KeyPlaceholder> placeholders,
    KeyBindingState state,
    bool needsKeybind,
    bool applied,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMock = cfg.id < 0;

    if (_currentStep == 0) {
      Widget content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '关于此配置',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.slate700 : Colors.grey[200]!,
              ),
            ),
            child: RichTextViewer(
              content: cfg.description,
              textStyle: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : AppColors.gray700,
                height: 1.8,
              ),
            ),
          ),
        ],
      );

      return Stack(
        children: [
          if (cfg.isApproved && !isMock)
            ConfigCommentsView(
              key: ValueKey('comments_${cfg.id}'),
              config: cfg,
              content: content,
              scrollController: _step1ScrollController,
              topIndicator: _showStep1TopIndicator
                  ? CommonScrollIndicator(
                      isTop: true,
                      bgColor: isDark ? AppColors.slate800 : Colors.white,
                    )
                  : null,
              bottomIndicator: _showStep1BottomIndicator
                  ? CommonScrollIndicator(
                      isTop: false,
                      bgColor: isDark ? AppColors.slate800 : Colors.white,
                    )
                  : null,
            )
          else ...[
            SingleChildScrollView(
              controller: _step1ScrollController,
              padding: const EdgeInsets.all(32),
              child: content,
            ),
            if (_showStep1TopIndicator)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: CommonScrollIndicator(
                  isTop: true,
                  bgColor: isDark ? AppColors.slate800 : Colors.white,
                ),
              ),
            if (_showStep1BottomIndicator)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CommonScrollIndicator(
                  isTop: false,
                  bgColor: isDark ? AppColors.slate800 : Colors.white,
                ),
              ),
          ],
        ],
      );
    } else if (needsKeybind && _currentStep == 1) {
      final int boundCount = placeholders
          .where(
            (p) =>
                state.keyBindings.containsKey(p.label) &&
                state.keyBindings[p.label]!.isNotEmpty,
          )
          .length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 32,
              right: 32,
              top: 32,
              bottom: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '点击下方代码中的高亮卡片绑定实体按键',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    if (boundCount < placeholders.length) ...[
                      TextButton.icon(
                        onPressed: () => _scrollToNextUnset(cfg.config, state),
                        icon: const Icon(
                          Icons.arrow_downward,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          '定位下一个',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      '已绑定 $boundCount / ${placeholders.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: boundCount == placeholders.length
                            ? AppColors.emerald500
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 24),
              child: _buildCodeEditorView(
                cfg.config,
                state,
                context,
                isDark,
                true,
              ),
            ),
          ),
        ],
      );
    } else {
      // Step 3
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 32,
              right: 32,
              top: 32,
              bottom: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 24,
                    color: AppColors.emerald500,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎉 配置准备就绪',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已写入本地配置，请务必重启游戏以使其生效。',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 24),
              child: _buildCodeEditorView(
                cfg.config,
                state,
                context,
                isDark,
                false,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCodeEditorView(
    String script,
    KeyBindingState state,
    BuildContext context,
    bool isDark,
    bool interactive,
  ) {
    final lines = script.split('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.slate900
            : const Color(0xFF1E1E1E), // 现代代码编辑器配色
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.slate700 : Colors.black87),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _codeScrollController,
        itemCount: lines.length,
        itemBuilder: (context, index) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 2.2, // 与文字行高一致
                      color: isDark ? Colors.white38 : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SelectableText.rich(
                  _buildInlineScriptSpan(
                    lines[index],
                    state,
                    context,
                    isDark,
                    interactive,
                  ),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 2.2,
                    color: const Color(0xFFD4D4D4), // VSCode 默认文本颜色
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TextSpan _buildInlineScriptSpan(
    String script,
    KeyBindingState state,
    BuildContext context,
    bool isDark,
    bool interactive,
  ) {
    final spans = <InlineSpan>[];
    final pattern = KeyPlaceholderParser.placeholderPattern;

    script.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        final label = match.group(1)!;
        final defaultKey = match.group(2);
        final boundKey = state.keyBindings[label] ?? defaultKey;

        if (interactive) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _InlineKeyCard(
                label: label,
                boundKey: boundKey,
                isDark: isDark,
                onTap: (anchorContext) {
                  KeyCaptureDialog.show(
                    context,
                    title: '绑定按键',
                    subtitle: '请按下你想绑定到【$label】的按键',
                  ).then((keyName) {
                    if (keyName != null && context.mounted) {
                      context.read<KeyBindingBloc>().add(
                        KeyBindingSetKeyBinding(label: label, key: keyName),
                      );
                    }
                  });
                },
                onClear: () {
                  context.read<KeyBindingBloc>().add(
                    KeyBindingClearKeyBinding(label),
                  );
                },
              ),
            ),
          );
        } else {
          // Non-interactive highlighting
          spans.add(
            TextSpan(
              text: boundKey?.toUpperCase() ?? '未绑定',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          );
        }
        return '';
      },
      onNonMatch: (String text) {
        spans.add(TextSpan(text: text));
        return '';
      },
    );

    return TextSpan(children: spans);
  }

  Widget _buildFooterControls(
    KeyConfig cfg,
    List<KeyPlaceholder> placeholders,
    KeyBindingState state,
    bool needsKeybind,
    bool allBound,
    bool applied,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int maxSteps = needsKeybind ? 2 : 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.slate700 : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('上一步'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            )
          else
            const SizedBox.shrink(),

          if (_currentStep < maxSteps)
            FilledButton.icon(
              onPressed: (_currentStep == 1 && !allBound)
                  ? null
                  : () {
                      setState(() => _currentStep++);
                    },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(_currentStep == maxSteps - 1 ? '前往应用' : '下一步'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            )
          else
            Row(
              children: [
                if (applied) ...[
                  OutlinedButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () => context.read<KeyBindingBloc>().add(
                            KeyBindingRemoveAppliedConfig(cfg.configId),
                          ),
                    icon: Icon(MdiIcons.closeCircleOutline, size: 18),
                    label: const Text('取消应用'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red500,
                      side: BorderSide(
                        color: AppColors.red500.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                FilledButton.icon(
                  onPressed: state.isSaving
                      ? null
                      : () => context.read<KeyBindingBloc>().add(
                          KeyBindingApplyConfig(
                            config: cfg,
                            keyBindings: state.keyBindings,
                          ),
                        ),
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          applied ? Icons.refresh : Icons.rocket_launch,
                          size: 18,
                        ),
                  label: Text(
                    state.isSaving ? '正在写入...' : (applied ? '重新应用' : '立即应用到本地'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: applied
                        ? AppColors.emerald500
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class AuditStatusBanner extends StatelessWidget {
  final KeyConfig config;
  final void Function(KeyConfig config)? onEditConfig;

  const AuditStatusBanner({super.key, required this.config, this.onEditConfig});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPending = config.isPending;
    final statusColor = isPending ? AppColors.amber500 : AppColors.red500;
    final statusIcon = isPending
        ? MdiIcons.clockOutline
        : MdiIcons.alertCircleOutline;
    final statusText = isPending ? '审核中' : '审核失败';
    final statusMessage = isPending
        ? '等待管理员审核'
        : (config.auditRemark.isNotEmpty ? config.auditRemark : '未通过审核');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 24, color: statusColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
          if (!isPending && onEditConfig != null)
            FilledButton.icon(
              onPressed: () => onEditConfig!(config),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('重新编辑'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.red500),
            ),
        ],
      ),
    );
  }
}

class _InlineKeyCard extends StatefulWidget {
  final String label;
  final String? boundKey;
  final void Function(BuildContext context) onTap;
  final VoidCallback onClear;
  final bool isDark;

  const _InlineKeyCard({
    required this.label,
    this.boundKey,
    required this.onTap,
    required this.onClear,
    required this.isDark,
  });

  @override
  State<_InlineKeyCard> createState() => _InlineKeyCardState();
}

class _InlineKeyCardState extends State<_InlineKeyCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.boundKey != null && widget.boundKey!.isNotEmpty;

    // Unbound: Emerald Green; Bound: Primary
    final baseColor = hasKey ? AppColors.primary : AppColors.emerald500;
    final textColor = hasKey ? AppColors.primary : const Color(0xFF6EE7B7);
    final bgColor = hasKey
        ? baseColor.withValues(alpha: _isHovered ? 0.25 : 0.15)
        : baseColor.withValues(alpha: _isHovered ? 0.3 : 0.2);
    final borderColor = hasKey ? baseColor : baseColor.withValues(alpha: 0.8);
    final shadowColor = baseColor.withValues(alpha: _isHovered ? 0.6 : 0.3);

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              hasKey ? widget.boundKey!.toUpperCase() : '此处需要设置按键',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: textColor,
                height: 1.2,
                shadows: [
                  Shadow(
                    color: textColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          if (hasKey) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                // Prevent tap from bubbling to the card
                widget.onClear();
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.red500.withValues(
                    alpha: 0.2,
                  ), // Distinct red color for clear button
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: AppColors.red500,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final innerCard = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: hasKey ? Border.all(color: borderColor, width: 1.5) : null,
      ),
      child: content,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(hasKey ? 6 : 7.5),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: _isHovered ? 12 : 6,
                spreadRadius: 0,
              ),
            ],
          ),
          child: hasKey
              ? innerCard
              : ClipRRect(
                  borderRadius: BorderRadius.circular(7.5),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: -50,
                        bottom: -50,
                        left: -50,
                        right: -50,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (_, __) {
                            return Transform.rotate(
                              angle: _controller.value * 2 * math.pi,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: SweepGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.emerald500,
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(
                          1.5,
                        ), // creates the 1.5px border
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? AppColors.slate900
                              : const Color(
                                  0xFF1E1E1E,
                                ), // Opaque background to hide gradient in the center
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: innerCard,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
