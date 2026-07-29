import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/toast_utils.dart';

class ServerCardMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final String? copyText;

  const ServerCardMarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.copyText,
  });

  @override
  State<ServerCardMarqueeText> createState() => _ServerCardMarqueeTextState();
}

class _ServerCardMarqueeTextState extends State<ServerCardMarqueeText> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currentStyle = _isHovered
        ? widget.style.copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          )
        : widget.style;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.text,
        preferBelow: false,
        verticalOffset: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        waitDuration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: widget.copyText ?? widget.text),
            );
            ToastUtils.showSuccess(context, '已复制地图名称');
          },
          child: Text(
            widget.text,
            style: currentStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
