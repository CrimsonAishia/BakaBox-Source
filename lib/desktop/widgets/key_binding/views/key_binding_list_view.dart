import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../../core/models/key_config_models.dart';
import '../components/key_binding_card.dart';
import '../components/config_history_dialog.dart';
import '../components/key_capture_dialog.dart';
import '../data/basic_configs.dart';
import '../data/key_binding_assets.dart';
import '../../../../core/constants/app_colors.dart';

class CfgItem {
  final String keyName;
  final String command;
  final String? fullScript;
  final String? description;
  const CfgItem(
    this.keyName,
    this.command, {
    this.fullScript,
    this.description,
  });
}

class CfgCategory {
  final String name;
  final List<CfgItem> items;
  const CfgCategory(this.name, this.items);
}

class BasicTabView extends StatefulWidget {
  const BasicTabView({super.key});

  @override
  State<BasicTabView> createState() => _BasicTabViewState();
}

class _BasicTabViewState extends State<BasicTabView> {
  List<CfgCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loading = false;
    _categories = basicConfigCategories;
  }

  IconData _getIconForCategory(String name) {
    if (name.contains('武器')) return MdiIcons.pistol;
    if (name.contains('道具')) return MdiIcons.bomb;
    if (name.contains('ZE')) return MdiIcons.skull;
    if (name.contains('通用')) return MdiIcons.tune;
    if (name.contains('视角') || name.contains('第三人称') || name.contains('出窍')) {
      return MdiIcons.eye;
    }
    return MdiIcons.keyboardSettings;
  }

  Future<void> _handleBindItem(CfgItem item) async {
    final key = await KeyCaptureDialog.show(
      context,
      title: '绑定按键',
      subtitle: '请按下您想要绑定到【${item.keyName}】的物理按键...',
    );
    if (key != null && key.isNotEmpty && mounted) {
      final mockConfig = KeyConfig(
        id: -1,
        configId: 'basic_${item.keyName}',
        name: item.keyName,
        description: item.description ?? '快速绑定: ${item.keyName}',
        categoryId: 0,
        category: '基础',
        config: item.fullScript ?? 'bind "{{KEY:按键}}" "${item.command}"',
        needsKeybind: true,
        userID: -1,
        isActive: true,
        sort: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        auditStatus: KeyConfigAuditStatus.approved,
      );
      context.read<KeyBindingBloc>().add(
        KeyBindingApplyConfig(config: mockConfig, keyBindings: {'按键': key}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        final rawKeyword = state.searchKeyword?.trim().toLowerCase() ?? '';

        List<CfgCategory> displayCategories = _categories;
        if (rawKeyword.isNotEmpty) {
          final keywords = rawKeyword
              .split(RegExp(r'\s+'))
              .where((k) => k.isNotEmpty)
              .toList();
          displayCategories = [];
          for (var cat in _categories) {
            final filteredItems = cat.items.where((item) {
              final textToSearch = '${item.keyName} ${item.command}'
                  .toLowerCase();
              return keywords.every((kw) => textToSearch.contains(kw));
            }).toList();

            if (filteredItems.isNotEmpty) {
              displayCategories.add(CfgCategory(cat.name, filteredItems));
            }
          }
        }

        if (displayCategories.isEmpty) {
          return Center(
            child: Text(
              _categories.isEmpty ? '暂无基础配置' : '未找到匹配的基础配置',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: displayCategories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 32),
          itemBuilder: (context, index) {
            final category = displayCategories[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分类标题
                Row(
                  children: [
                    Icon(
                      _getIconForCategory(category.name),
                      size: 24,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 该分类下的卡片网格
                MasonryGridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  itemCount: category.items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = category.items[itemIndex];
                    final applied = state.isConfigApplied(
                      'basic_${item.keyName}',
                    );
                    final appliedBindings = state.getAppliedKeyBindings(
                      'basic_${item.keyName}',
                    );
                    return KeyBindingCard(
                      icon: _getIconForCategory(category.name),
                      title: item.keyName,
                      description: item.description ?? '',
                      category: null,
                      isApplied: applied,
                      appliedBindings: appliedBindings,
                      imageUrl: keyBindingImageAssets[item.keyName],
                      fallbackId: item.keyName.hashCode,
                      showOpenButton: false,
                      onTap: () => _handleBindItem(item),
                      onCancelApply: () {
                        context.read<KeyBindingBloc>().add(
                          KeyBindingRemoveAppliedConfig(
                            'basic_${item.keyName}',
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class MarketTabView extends StatelessWidget {
  final void Function(KeyConfig) onConfigTap;
  final void Function(KeyConfig) onEditConfig;

  const MarketTabView({
    super.key,
    required this.onConfigTap,
    required this.onEditConfig,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeyBindingBloc, KeyBindingState>(
      builder: (context, state) {
        final isLoading = state.isLoading || state.isLoadingMyConfigs;
        final configs = state.showMyConfigs
            ? state.filteredMyConfigs
            : state.filteredConfigs;

        if (isLoading && configs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (configs.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    MdiIcons.cloudOffOutline,
                    size: 64,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '暂无云端配置',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '当前搜索条件未找到任何社区分享的配置',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              ],
            ),
          );
        }

        return MasonryGridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          padding: const EdgeInsets.all(16),
          itemCount: configs.length,
          itemBuilder: (context, index) {
            final cfg = configs[index];
            final applied = state.isConfigApplied(cfg.configId);
            final appliedBindings = state.getAppliedKeyBindings(cfg.configId);

            return KeyBindingCard(
              icon: MdiIcons.fileCodeOutline,
              title: cfg.name,
              showCover: false,
              description: cfg.description.isEmpty ? '无描述' : cfg.description,
              category: cfg.category.isEmpty ? null : cfg.category,
              isApplied: applied,
              appliedBindings: appliedBindings,
              fallbackId: cfg.id,
              authorName: cfg.userNickname,
              authorAvatar: cfg.userAvatar,
              useCount: cfg.useCount,
              commentCount: cfg.commentCount,
              likeCount: cfg.voteCount,
              updatedAt: cfg.updatedAt,
              isOwner: cfg.isOwner,
              isApproved: cfg.isApproved,
              isPending: cfg.isPending,
              hasPendingChange: cfg.hasPendingChange,
              pendingChangeType: cfg.pendingChangeType,
              isRejected: cfg.isRejected,
              auditRemark: cfg.auditRemark,
              onTap: () {
                context.read<KeyBindingBloc>().add(KeyBindingSelectConfig(cfg));
                onConfigTap(cfg);
              },
              onEdit: () {
                context.read<KeyBindingBloc>().add(KeyBindingSelectConfig(cfg));
                onEditConfig(cfg);
              },
              onDelete: (reason) {
                context.read<KeyBindingBloc>().add(
                  KeyBindingDeleteConfig(cfg.id, editReason: reason),
                );
              },
              onCancelAudit: () {
                if (cfg.hasPendingChange) {
                  context.read<KeyBindingBloc>().add(
                    KeyBindingCancelChangeRequest(cfg.id),
                  );
                } else if (cfg.isPending) {
                  // For a new config that is pending audit, 'cancelling' is effectively deleting it.
                  context.read<KeyBindingBloc>().add(
                    KeyBindingDeleteConfig(cfg.id),
                  );
                }
              },
              onCancelApply: () {
                context.read<KeyBindingBloc>().add(
                  KeyBindingRemoveAppliedConfig(cfg.configId),
                );
              },
              onShowHistory: () {
                showDialog(
                  context: context,
                  builder: (context) => ConfigHistoryDialog(configId: cfg.id),
                );
              },
            );
          },
        );
      },
    );
  }
}
