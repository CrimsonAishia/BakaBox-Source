import 'package:flutter/material.dart';

/// 设置项布局组件（用于游戏设置等）
class SettingsItem extends StatelessWidget {
  final String label;
  final String? description;
  final Widget control;
  final bool alignTop;

  const SettingsItem({
    super.key,
    required this.label,
    this.description,
    required this.control,
    this.alignTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF5F5F5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: alignTop ? 6 : 0),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF333333),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF666666),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: control),
        ],
      ),
    );
  }
}

/// 应用设置项布局组件（卡片样式）
class AppSettingItem extends StatelessWidget {
  final String title;
  final String description;
  final Widget? value;
  final Widget action;

  const AppSettingItem({
    super.key,
    required this.title,
    required this.description,
    this.value,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                : [const Color(0xFFFAFBFC), const Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: value!,
                ),
              ),
            action,
          ],
        ),
      ),
    );
  }
}
