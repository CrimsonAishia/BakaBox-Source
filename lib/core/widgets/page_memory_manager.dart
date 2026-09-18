import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/log_service.dart';
import '../services/lobby_image_cache_service.dart';

/// 页面内存管理器
///
/// 替代 KeyedSubtree 或 IndexedStack。
/// - 支持按需懒加载页面（不在 activePages 里的页面不构建）
/// - 支持 KeepAlive 状态保留（切出时放入后台并隐藏，维持状态）
/// - 支持超时自动回收（切出后开始倒计时，超时则将其 Dispose 并强制清理图片缓存）
class PageMemoryManager extends StatefulWidget {
  final int currentIndex;
  final Duration cacheDuration;
  final List<Widget Function(BuildContext)> builders;

  const PageMemoryManager({
    super.key,
    required this.currentIndex,
    required this.builders,
    this.cacheDuration = const Duration(minutes: 3),
  });

  @override
  State<PageMemoryManager> createState() => _PageMemoryManagerState();
}

class _PageMemoryManagerState extends State<PageMemoryManager> {
  // 维护存活的页面索引，确保页面在 KeepAlive 期间也能接收到最新的 widget 属性
  final Set<int> _activeIndices = {};

  // 维护后台页面的超时倒计时
  final Map<int, Timer> _pageTimers = {};

  @override
  void initState() {
    super.initState();
    _activatePage(widget.currentIndex);
  }

  @override
  void didUpdateWidget(PageMemoryManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _activatePage(widget.currentIndex);
      _scheduleDeactivation(oldWidget.currentIndex);
    }
  }

  /// 激活（访问）页面
  void _activatePage(int index) {
    // 取消倒计时，因为用户切回来了
    _pageTimers[index]?.cancel();
    _pageTimers.remove(index);

    // 记录该索引处于存活状态
    if (!_activeIndices.contains(index)) {
      setState(() {
        _activeIndices.add(index);
      });
    }
  }

  /// 将页面置于后台并开始倒计时
  void _scheduleDeactivation(int index) {
    _pageTimers[index]?.cancel();

    _pageTimers[index] = Timer(widget.cacheDuration, () {
      if (mounted) {
        setState(() {
          _activeIndices.remove(index);
          _pageTimers.remove(index);
        });

        LogService.i('[PageMemoryManager] 回收后台闲置页面: 索引 $index');

        // 主动强制清理底层图片缓存，释放内存囤积
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        // 清理大厅服务自己维护的 LRU raw 图片字节缓存
        LobbyImageCacheService.instance.clearMemoryCache();
      }
    });
  }

  @override
  void dispose() {
    for (final timer in _pageTimers.values) {
      timer.cancel();
    }
    _pageTimers.clear();
    _activeIndices.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 Stack 堆叠所有存活的页面
    return Stack(
      children: List.generate(widget.builders.length, (index) {
        final isActive = index == widget.currentIndex;
        final isCached = _activeIndices.contains(index);

        // 如果既不是当前页面，又没有被缓存，则不渲染（占位）
        if (!isActive && !isCached) {
          return const SizedBox.shrink();
        }

        // 调用最新的 builder 获取 widget，触发子页面的 didUpdateWidget
        final child = widget.builders[index](context);

        // 使用 Offstage 和 TickerMode 将后台页面隐藏并暂停动画计算
        return Offstage(
          offstage: !isActive,
          child: TickerMode(enabled: isActive, child: child),
        );
      }),
    );
  }
}
