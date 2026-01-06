import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/core.dart';
import 'animated_counter.dart';

class ServerCategoryCard extends StatefulWidget {
  final ServerCategory category;
  final VoidCallback onTap;

  const ServerCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  State<ServerCategoryCard> createState() => _ServerCategoryCardState();
}

class _ServerCategoryCardState extends State<ServerCategoryCard> {
  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryUtils.getCategoryColor(widget.category.modelName);
    
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final onlineCount = widget.category.modelName != null 
            ? state.getCategoryOnlineCount(widget.category.modelName!)
            : 0;
        final isLoading = widget.category.modelName != null 
            ? state.isCategoryLoading(widget.category.modelName!)
            : false;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                        Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 图标容器
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                categoryColor.withValues(alpha: 0.9),
                                categoryColor.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: categoryColor.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            CategoryUtils.getCategoryIcon(widget.category.modelName),
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 分类名称
                        Text(
                          widget.category.modelName ?? '未知分类',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // 在线人数
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: onlineCount == 0 
                                ? Colors.grey.withValues(alpha: 0.1)
                                : categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: onlineCount == 0 
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : categoryColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 16,
                                color: onlineCount == 0 
                                    ? Colors.grey.withValues(alpha: 0.6)
                                    : categoryColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              AnimatedCounter(
                                count: onlineCount,
                                suffix: ' 在线',
                                isLoading: isLoading && onlineCount == 0,
                                loadingText: '加载中',
                                textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: (isLoading && onlineCount == 0) 
                                      ? Colors.grey.withValues(alpha: 0.6)
                                      : onlineCount == 0 
                                          ? Colors.grey.withValues(alpha: 0.6)
                                          : categoryColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 服务器数量
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: categoryColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.dns, size: 16, color: categoryColor.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.category.serverList.length} 服务器',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: categoryColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
