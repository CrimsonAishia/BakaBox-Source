import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/core.dart';

class UpdateLogItem extends StatefulWidget {
  final SteamWorkChangeLog log;
  final bool isLatest;
  final String? keyword; // 搜索关键词，用于高亮

  const UpdateLogItem({
    super.key,
    required this.log,
    this.isLatest = false,
    this.keyword,
  });

  @override
  State<UpdateLogItem> createState() => _UpdateLogItemState();
}

class _UpdateLogItemState extends State<UpdateLogItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _animationController.forward();
  void _onTapUp(TapUpDetails details) => _animationController.reverse();
  void _onTapCancel() => _animationController.reverse();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.isLatest 
                        ? colorScheme.error.withValues(alpha: 0.12)
                        : colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border.all(
                      color: widget.isLatest
                          ? colorScheme.error.withValues(alpha: 0.3)
                          : colorScheme.outline.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isLatest)
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.error,
                                colorScheme.error.withValues(alpha: 0.7),
                                colorScheme.error,
                              ],
                            ),
                          ),
                        ).animate().shimmer(duration: 2000.ms, delay: 500.ms),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(context, colorScheme),
                            const SizedBox(height: 12),
                            _buildContentArea(context, colorScheme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isLatest
              ? [colorScheme.error, colorScheme.error.withValues(alpha: 0.85)]
              : [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isLatest ? Icons.new_releases_rounded : Icons.schedule_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            Formatters.formatDate(widget.log.updateTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildContentArea(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = widget.log.rawHtml.isNotEmpty ? widget.log.rawHtml : widget.log.content;
    
    if (content.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            '暂无更新内容',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // 如果有搜索关键字，对内容进行高亮处理
    final keyword = widget.keyword?.trim() ?? '';
    final processedContent = keyword.isNotEmpty 
        ? _highlightKeyword(content, keyword)
        : content;

    if (widget.log.rawHtml.isNotEmpty && _containsHtmlTags(widget.log.rawHtml)) {
      return Html(
        data: processedContent,
        style: {
          "body": Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(14),
            color: colorScheme.onSurface,
            lineHeight: const LineHeight(1.6),
            fontWeight: FontWeight.w400,
          ),
          "p": Style(margin: Margins.only(bottom: 12), fontSize: FontSize(14), lineHeight: const LineHeight(1.6)),
          "br": Style(margin: Margins.only(bottom: 6)),
          "ul": Style(margin: Margins.only(left: 20, bottom: 12)),
          "ol": Style(margin: Margins.only(left: 20, bottom: 12)),
          "li": Style(margin: Margins.only(bottom: 4), fontSize: FontSize(14), lineHeight: const LineHeight(1.6)),
          "h1": Style(fontSize: FontSize(20), fontWeight: FontWeight.bold, margin: Margins.only(bottom: 12), color: colorScheme.onSurface),
          "h2": Style(fontSize: FontSize(18), fontWeight: FontWeight.bold, margin: Margins.only(bottom: 10), color: colorScheme.onSurface),
          "h3": Style(fontSize: FontSize(16), fontWeight: FontWeight.w600, margin: Margins.only(bottom: 8), color: colorScheme.onSurfaceVariant),
          "strong": Style(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          "b": Style(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          "em": Style(fontStyle: FontStyle.italic),
          "i": Style(fontStyle: FontStyle.italic),
          // 搜索高亮样式
          "mark": Style(
            backgroundColor: const Color(0xFFFEF08A),
            color: const Color(0xFF92400E),
            padding: HtmlPaddings.symmetric(horizontal: 2),
          ),
        },
      );
    } else {
      return Html(
        data: processedContent,
        style: {
          "body": Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(14),
            color: colorScheme.onSurface,
            lineHeight: const LineHeight(1.6),
            fontWeight: FontWeight.w400,
          ),
          "mark": Style(
            backgroundColor: const Color(0xFFFEF08A),
            color: const Color(0xFF92400E),
            padding: HtmlPaddings.symmetric(horizontal: 2),
          ),
        },
      );
    }
  }

  /// 高亮搜索关键字
  /// 只处理 HTML 标签外的文本内容，避免破坏 HTML 结构
  String _highlightKeyword(String html, String keyword) {
    if (keyword.isEmpty) return html;
    
    // 转义正则特殊字符
    final escapedKeyword = RegExp.escape(keyword);
    
    // 使用正则匹配，但排除 HTML 标签内的内容
    final result = StringBuffer();
    var lastEnd = 0;
    
    // 匹配 HTML 标签
    final tagRegex = RegExp(r'<[^>]*>');
    final matches = tagRegex.allMatches(html);
    
    for (final match in matches) {
      // 处理标签之前的文本
      if (match.start > lastEnd) {
        final textBefore = html.substring(lastEnd, match.start);
        result.write(_highlightText(textBefore, escapedKeyword));
      }
      // 保留标签原样
      result.write(match.group(0));
      lastEnd = match.end;
    }
    
    // 处理最后一个标签之后的文本
    if (lastEnd < html.length) {
      final textAfter = html.substring(lastEnd);
      result.write(_highlightText(textAfter, escapedKeyword));
    }
    
    return result.toString();
  }
  
  /// 对纯文本进行关键字高亮
  String _highlightText(String text, String escapedKeyword) {
    final regex = RegExp(escapedKeyword, caseSensitive: false);
    return text.replaceAllMapped(regex, (match) {
      return '<mark>${match.group(0)}</mark>';
    });
  }

  bool _containsHtmlTags(String text) => RegExp(r'<[^>]+>').hasMatch(text);
}
