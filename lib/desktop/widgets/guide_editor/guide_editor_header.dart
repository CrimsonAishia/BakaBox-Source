import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/guide_editor/guide_editor_bloc.dart';
import '../../../core/bloc/guide_editor/guide_editor_state.dart';
import '../../../core/widgets/guide/guide_tokens.dart';
import '../guide/community_guide/community_guide_theme.dart';

/// 攻略编辑器顶部导航栏
///
/// 仅放置左侧元素：返回按钮 / 标题 / 保存状态文本。
/// 右上角不放按钮，避免被 Windows 窗口控制按钮（最小化/最大化/关闭）遮挡。
/// 保存草稿 / 提交 操作移至 Sidebar 底部。
class GuideEditorHeader extends StatelessWidget {
  /// 返回按钮回调
  final VoidCallback? onBack;

  /// 编辑的攻略 ID；非空表示编辑模式，null 表示新建
  final int? guideId;

  const GuideEditorHeader({
    super.key,
    this.onBack,
    this.guideId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: BlocBuilder<GuideEditorBloc, GuideEditorState>(
        builder: (context, editorState) {
          return Row(
            children: [
              _CircleBackButton(onTap: onBack),
              const SizedBox(width: 14),
              Text(
                guideId != null ? '编辑攻略' : '新建攻略',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 12),
              _StatusText(
                phase: editorState.phase,
                lastSavedAt: editorState.lastSavedAt,
                isEditingExisting: guideId != null,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 圆形返回按钮（hover 时高亮）
class _CircleBackButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _CircleBackButton({this.onTap});

  @override
  State<_CircleBackButton> createState() => _CircleBackButtonState();
}

class _CircleBackButtonState extends State<_CircleBackButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    final baseBg = colors.chipInactiveBg;
    final hoverBg = colors.hoverHighlight;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _hovering ? hoverBg : baseBg,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: Icon(
              Icons.arrow_back_rounded,
              color: colors.iconPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// 编辑器保存状态文本（idle / saving / conflict / published / error）
class _StatusText extends StatefulWidget {
  final EditorPhase phase;
  final DateTime? lastSavedAt;
  final bool isEditingExisting;

  const _StatusText({
    required this.phase,
    this.lastSavedAt,
    this.isEditingExisting = false,
  });

  @override
  State<_StatusText> createState() => _StatusTextState();
}

class _StatusTextState extends State<_StatusText> {
  String? _currentText;
  // 每次文本变化时自增，保证 AnimatedSwitcher 的 key 唯一，
  // 避免文本回退到之前的值时与正在淡出的旧子节点产生重复 key。
  int _sequence = 0;

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    final text = _getStatusText();
    final color = _getStatusColor(colors);

    if (text != _currentText) {
      _currentText = text;
      _sequence++;
    }

    return AnimatedSwitcher(
      duration: GuideTokens.durationFast,
      child: Text(
        text,
        key: ValueKey('$_sequence:$text'),
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 根据当前 phase 返回显示文本
  String _getStatusText() {
    return switch (widget.phase) {
      EditorPhase.idle => widget.lastSavedAt != null ? '已保存' : '未保存',
      EditorPhase.saving => '正在保存...',
      EditorPhase.savingRemote => '同步至云端...',
      EditorPhase.conflict => '版本冲突',
      EditorPhase.publishing => widget.isEditingExisting ? '提交中...' : '发布中...',
      EditorPhase.submitted => widget.isEditingExisting ? '已提交' : '已发布',
      EditorPhase.error => '保存失败',
    };
  }

  /// 根据当前 phase 返回颜色
  Color _getStatusColor(CommunityGuideColors colors) {
    return switch (widget.phase) {
      EditorPhase.idle => colors.textTertiary,
      EditorPhase.saving ||
      EditorPhase.savingRemote =>
        colors.accentBlue,
      EditorPhase.conflict => GuideTokens.statusPending,
      EditorPhase.publishing => colors.accentBlue,
      EditorPhase.submitted => GuideTokens.shareGreen,
      EditorPhase.error => GuideTokens.statusRejected,
    };
  }
}
