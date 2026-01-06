import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/core.dart';

class UpdateLogItem extends StatefulWidget {
  final SteamWorkChangeLog log;
  final bool isLatest;

  const UpdateLogItem({
    super.key,
    required this.log,
    this.isLatest = false,
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.isLatest 
                        ? colorScheme.error.withValues(alpha: 0.15)
                        : colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: widget.isLatest 
                        ? colorScheme.error.withValues(alpha: 0.1)
                        : colorScheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: widget.isLatest
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.surface,
                              colorScheme.errorContainer.withValues(alpha: 0.3),
                              colorScheme.errorContainer.withValues(alpha: 0.2),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.surface,
                              colorScheme.surfaceContainer,
                              colorScheme.surfaceContainerLow,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                    border: Border.all(
                      color: widget.isLatest
                          ? colorScheme.error.withValues(alpha: 0.2)
                          : colorScheme.outline.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      if (widget.isLatest)
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  colorScheme.error.withValues(alpha: 0.05),
                                  colorScheme.error.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isLatest)
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.error,
                                    colorScheme.error.withValues(alpha: 0.8),
                                    colorScheme.error.withValues(alpha: 0.6),
                                    colorScheme.error.withValues(alpha: 0.8),
                                    colorScheme.error,
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                            ).animate().shimmer(duration: 2000.ms, delay: 500.ms),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(context, colorScheme),
                                const SizedBox(height: 20),
                                _buildContentArea(context, colorScheme),
                              ],
                            ),
                          ),
                        ],
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isLatest
                  ? [colorScheme.error, colorScheme.error.withValues(alpha: 0.8)]
                  : [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.isLatest
                    ? colorScheme.error.withValues(alpha: 0.3)
                    : colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  widget.isLatest ? Icons.new_releases_rounded : Icons.schedule_rounded,
                  size: 14,
                  color: widget.isLatest ? colorScheme.onError : colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.formatDate(widget.log.updateTime),
                style: TextStyle(
                  color: widget.isLatest ? colorScheme.onError : colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildCopyButton(context, colorScheme),
      ],
    );
  }

  Widget _buildCopyButton(BuildContext context, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.surface, colorScheme.surfaceContainer],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copyContent(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.copy_rounded, size: 18, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2), width: 1),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = widget.log.rawHtml.isNotEmpty ? widget.log.rawHtml : widget.log.content;
    
    if (content.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '暂无更新内容',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.log.rawHtml.isNotEmpty && _containsHtmlTags(widget.log.rawHtml)) {
      return Html(
        data: widget.log.rawHtml,
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
        },
      );
    } else {
      return Text(
        content,
        style: TextStyle(fontSize: 14, color: colorScheme.onSurface, height: 1.6, fontWeight: FontWeight.w400),
      );
    }
  }

  bool _containsHtmlTags(String text) => RegExp(r'<[^>]+>').hasMatch(text);

  void _copyContent(BuildContext context) {
    final timeStr = Formatters.formatDateTime(widget.log.updateTime);
    final content = widget.log.rawHtml.isNotEmpty 
        ? Formatters.htmlToText(widget.log.rawHtml)
        : widget.log.content;
    
    final copyText = '更新时间：$timeStr\n\n$content';
    Clipboard.setData(ClipboardData(text: copyText));
    ToastUtils.showSuccess(context, '内容已复制到剪贴板');
  }
}
