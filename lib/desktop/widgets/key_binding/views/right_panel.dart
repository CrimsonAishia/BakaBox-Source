import 'package:flutter/material.dart';
import '../../../../core/models/key_config_models.dart';
import 'autoexec_view.dart';
import 'config_detail_view.dart';
import 'edit_view.dart';
import 'publish_view.dart';

/// 右侧面板：根据模式显示不同内容
class RightPanel extends StatelessWidget {
  final int mode;
  final KeyConfig? editingConfig;
  final VoidCallback? onEditComplete;
  final void Function(KeyConfig config)? onEditConfig;

  const RightPanel({
    super.key,
    required this.mode,
    this.editingConfig,
    this.onEditComplete,
    this.onEditConfig,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: switch (mode) {
          1 => AutoexecView(),
          2 => PublishView(),
          3 =>
            editingConfig != null
                ? EditView(config: editingConfig!, onComplete: onEditComplete)
                : ConfigDetailView(onEditConfig: onEditConfig),
          _ => ConfigDetailView(onEditConfig: onEditConfig),
        },
      ),
    );
  }
}
