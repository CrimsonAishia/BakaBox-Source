import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/models/key_config_models.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/constants/app_colors.dart';

/// 我的变更申请列表视图
class ChangeRequestsView extends StatefulWidget {
  const ChangeRequestsView({super.key});

  @override
  State<ChangeRequestsView> createState() => _ChangeRequestsViewState();
}

class _ChangeRequestsViewState extends State<ChangeRequestsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeyBindingBloc>().add(const KeyBindingLoadChangeRequests());
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _buildHeader(context, isDark),
        Expanded(child: _buildList(context, isDark)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.amber500.withValues(alpha: 0.06),
            isDark ? AppColors.slate800 : Colors.white,
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
              color: AppColors.amber500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              MdiIcons.clipboardTextClockOutline,
              size: 18,
              color: AppColors.amber500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的变更申请',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '已通过配置的编辑/删除申请，等待管理员审核',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<KeyBindingBloc, KeyBindingState>(
            builder: (context, state) => Tooltip(
              message: '刷新',
              child: IconButton(
                onPressed: state.isLoadingChangeRequests
                    ? null
                    : () => context.read<KeyBindingBloc>().add(
                        const KeyBindingLoadChangeRequests(
                          showSuccessMessage: true,
                        ),
                      ),
                icon: state.isLoadingChangeRequests
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                style: IconButton.styleFrom(
                  foregroundColor: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, bool isDark) {
    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        if (state.isLoadingChangeRequests && state.changeRequests.isEmpty) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (state.changeRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  MdiIcons.clipboardCheckOutline,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  '暂无变更申请',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '对已通过的配置发起编辑或删除申请后会显示在这里',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white24 : Colors.grey[350],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.changeRequests.length,
          itemBuilder: (context, i) =>
              _ChangeRequestCard(request: state.changeRequests[i]),
        );
      },
    );
  }
}

class _ChangeRequestCard extends StatelessWidget {
  final KeyConfigChangeRequest request;

  const _ChangeRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = request.changeType == KeyConfigChangeType.edit;

    final (
      statusColor,
      statusIcon,
      statusLabel,
    ) = switch (request.auditStatus) {
      KeyConfigAuditStatus.pending => (
        AppColors.amber500,
        MdiIcons.clockOutline,
        '审核中',
      ),
      KeyConfigAuditStatus.approved => (
        AppColors.emerald500,
        MdiIcons.checkCircleOutline,
        '已通过',
      ),
      KeyConfigAuditStatus.rejected => (
        AppColors.red500,
        MdiIcons.closeCircleOutline,
        '已拒绝',
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate700 : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate600 : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：配置名 + 类型 + 状态
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isEdit
                                ? AppColors.violet500
                                : AppColors.red500)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEdit
                            ? MdiIcons.pencilOutline
                            : MdiIcons.deleteOutline,
                        size: 12,
                        color: isEdit
                            ? AppColors.violet500
                            : AppColors.red500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        request.changeType.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isEdit
                              ? AppColors.violet500
                              : AppColors.red500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.originalConfigName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 理由
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  MdiIcons.commentTextOutline,
                  size: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.editReason,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.gray500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 拒绝备注
          if (request.isRejected && request.auditRemark.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.red500.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.red500.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    MdiIcons.alertCircleOutline,
                    size: 13,
                    color: AppColors.red500,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '拒绝原因：${request.auditRemark}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.red500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 底部：时间信息
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.slate600 : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  MdiIcons.clockOutline,
                  size: 12,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  '提交于 ${Formatters.formatDateTime(request.createdAt.toIso8601String())}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                ),
                if (request.auditAt != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    MdiIcons.checkOutline,
                    size: 12,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '审核于 ${Formatters.formatDateTime(request.auditAt!.toIso8601String())}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
