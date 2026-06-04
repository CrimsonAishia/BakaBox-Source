import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/bloc/guide_editor/guide_editor_bloc.dart';
import '../../../core/bloc/guide_editor/guide_editor_event.dart';
import '../../../core/bloc/guide_editor/guide_editor_state.dart';
import '../../../core/services/quill_delta_codec.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/embeds/bilibili_embed_builder.dart';
import '../../../core/widgets/embeds/bilibili_insert_button.dart';
import '../../../core/widgets/embeds/hover_info_insert_button.dart';
import '../../../core/widgets/embeds/image_insert_button.dart';
import '../../../core/widgets/embeds/resizable_image_block_embed.dart';
import '../../../core/widgets/embeds/resizable_image_embed_builder.dart';
import '../../../core/widgets/embeds/resizable_image_uploader.dart';
import '../../../core/widgets/rich_text_editor.dart';
import '../guide/community_guide/community_guide_theme.dart';

/// 攻略编辑器右侧内容区
///
/// 直接坐在页面底色上（无卡片包裹）。
/// 包含：大白色标题输入框 + 标题字数统计 + 富文本编辑器（imageMode: inline）。
class GuideEditorContent extends StatefulWidget {
  const GuideEditorContent({super.key});

  @override
  State<GuideEditorContent> createState() => _GuideEditorContentState();
}

class _GuideEditorContentState extends State<GuideEditorContent> {
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  bool _titleInitialized = false;

  /// 是否已从草稿/服务端加载过正文内容（避免重复加载覆盖用户输入）
  bool _contentInitialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    // 配置 onImagePaste：粘贴图片时上传并插入 resizableImage 节点
    _quillController = QuillController.basic(
      config: QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(
          onImagePaste: _onImagePaste,
        ),
      ),
    );
    _quillController.addListener(_onContentChanged);
  }

  /// 剪贴板粘贴图片回调
  ///
  /// 上传图片并插入 resizableImage 节点，返回 null 阻止 Quill 默认插入原始 image 节点。
  Future<String?> _onImagePaste(Uint8List imageBytes) async {
    await ResizableImageUploader.uploadBytesAndInsert(
      imageBytes,
      _quillController,
      extension: 'png',
      maxImages: GuideEditorBloc.maxImages,
      onError: (msg) {
        if (mounted) ToastUtils.showError(context, msg);
      },
      onSuccess: (msg) {
        if (mounted) ToastUtils.showSuccess(context, msg);
      },
      onLimitReached: (msg) {
        if (mounted) ToastUtils.showWarning(context, msg);
      },
    );
    // 返回 null：已自行插入 resizableImage，阻止 Quill 插入默认 image 节点
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.removeListener(_onContentChanged);
    _quillController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    // 以 Delta JSON 编码正文，保留图片/视频等嵌入节点
    final content = QuillDeltaCodec.encode(_quillController.document);
    final plainTextLength = _quillController.document.toPlainText().trim().length;
    context.read<GuideEditorBloc>().add(UpdateContent(content, plainTextLength: plainTextLength));
  }

  /// 将草稿/服务端的正文内容载入编辑器（仅首次）
  void _loadContentIntoEditor(String content) {
    if (_contentInitialized) return;
    _contentInitialized = true;

    if (content.isEmpty) return;

    try {
      final document = QuillDeltaCodec.decode(content);
      // 临时移除监听，避免载入触发 _onContentChanged 回写
      _quillController.removeListener(_onContentChanged);
      _quillController.document = document;
      _quillController.addListener(_onContentChanged);
    } catch (_) {
      // 解码失败，保持空文档
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GuideEditorBloc, GuideEditorState>(
      listenWhen: (prev, curr) =>
          (!_titleInitialized || !_contentInitialized) && curr.draft != null,
      listener: (context, state) {
        final draft = state.draft;
        if (draft == null) return;
        if (!_titleInitialized) {
          _titleInitialized = true;
          _titleController.text = draft.title ?? '';
        }
        if (!_contentInitialized) {
          _loadContentIntoEditor(draft.content ?? '');
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleInput(controller: _titleController),
            const SizedBox(height: 4),
            // 标题字数（与原型「22 word count」一致，统计的是标题字符数）
            _TitleCountBar(controller: _titleController),
            const SizedBox(height: 1),
            Expanded(
              child: RichTextEditor(
                controller: _quillController,
                hintText: '开始撰写攻略正文...',
                maxLength: 100000,
                maxImages: GuideEditorBloc.maxImages,
                enableHeading: true,
                imageMode: ImageMode.inline,
                enableAdvancedEmbeds: true,
                embedBuilders: const [
                  BilibiliEmbedBuilder(),
                  ResizableImageEmbedBuilder(readOnly: false),
                ],
                extraToolbarButtons: [
                  ImageInsertButton(
                    controller: _quillController,
                    maxImages: GuideEditorBloc.maxImages,
                    getImageCount: _countResizableImages,
                  ),
                  HoverInfoInsertButton(controller: _quillController),
                  BilibiliInsertButton(controller: _quillController),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 统计文档中 resizableImage 节点数量（供 [ImageInsertButton] 判断是否达到上限）
  int _countResizableImages() {
    final delta = _quillController.document.toDelta();
    int count = 0;
    for (final op in delta.operations) {
      if (op.isInsert && op.value is Map) {
        final map = op.value as Map;
        if (map.containsKey(resizableImageEmbedType)) {
          count++;
        }
      }
    }
    return count;
  }
}

/// 标题输入框
///
/// 显式禁用 fill，避免主题级 `inputDecorationTheme.filled=true` 渗透导致背景错乱。
class _TitleInput extends StatelessWidget {  final TextEditingController controller;

  const _TitleInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return TextField(
      controller: controller,
      onChanged: (value) {
        context.read<GuideEditorBloc>().add(UpdateTitle(value));
      },
      maxLength: 60,
      maxLines: null,
      cursorColor: colors.textPrimary,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
        height: 1.3,
        letterSpacing: 0.2,
      ),
      decoration: InputDecoration(
        hintText: '输入攻略标题',
        hintStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: colors.hoverHighlight,
          height: 1.3,
        ),
        // 显式覆盖 InputDecorationTheme，避免主题底色渗透
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        counterText: '',
        contentPadding: EdgeInsets.zero,
        isDense: true,
        isCollapsed: true,
      ),
    );
  }
}

/// 标题字数统计条（实时监听 [TextEditingController]，按字符数统计）
class _TitleCountBar extends StatelessWidget {
  final TextEditingController controller;

  const _TitleCountBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = controller.text.characters.length;
        return Text(
          '$count 字',
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}
