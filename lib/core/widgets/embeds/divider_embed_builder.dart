import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../constants/app_colors.dart';

/// 水平分割线 BlockEmbed 类型标识
///
/// 与 flutter_quill 内置 markdown 解析器使用同一个常量 `divider`，
/// 这样从 Markdown `---` 解析出的 hr 可与本组件互通。
const String dividerEmbedType = 'divider';

/// 水平分割线 CustomBlockEmbed
///
/// Delta 格式:
/// ```jsonc
/// { "insert": { "divider": "hr" } }
/// ```
class DividerBlockEmbed extends CustomBlockEmbed {
  const DividerBlockEmbed() : super(dividerEmbedType, 'hr');
}

/// 水平分割线 EmbedBuilder（编辑态 + 只读态共用）
class DividerEmbedBuilder extends EmbedBuilder {
  const DividerEmbedBuilder();

  @override
  String get key => dividerEmbedType;

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : AppColors.slate400.withValues(alpha: 0.45),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
