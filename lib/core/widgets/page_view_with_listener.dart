import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// 页面生命周期状态
enum PageLifecycleState { active, inactive }

/// 页面生命周期回调接口
abstract class PageLifecycleAware {
  void onPageActive();
  void onPageInactive();
}

/// 页面状态Provider
class PageStateProvider extends InheritedWidget {
  final int currentPageIndex;
  final PageLifecycleState pageState;
  final int pageIndex;

  const PageStateProvider({
    super.key,
    required this.currentPageIndex,
    required this.pageState,
    required this.pageIndex,
    required super.child,
  });

  static PageStateProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PageStateProvider>();
  }

  @override
  bool updateShouldNotify(PageStateProvider oldWidget) {
    return oldWidget.currentPageIndex != currentPageIndex ||
        oldWidget.pageState != pageState ||
        oldWidget.pageIndex != pageIndex;
  }
}

/// 支持页面切换监听的PageView组件
class PageViewWithListener extends StatefulWidget {
  final List<Widget> children;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final ScrollPhysics? physics;
  final bool pageSnapping;
  final bool reverse;
  final Axis scrollDirection;
  final DragStartBehavior dragStartBehavior;
  final bool allowImplicitScrolling;
  final String? restorationId;
  final Clip clipBehavior;
  final bool padEnds;

  const PageViewWithListener({
    super.key,
    required this.children,
    this.controller,
    this.onPageChanged,
    this.physics,
    this.pageSnapping = true,
    this.reverse = false,
    this.scrollDirection = Axis.horizontal,
    this.dragStartBehavior = DragStartBehavior.start,
    this.allowImplicitScrolling = false,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.padEnds = true,
  });

  @override
  State<PageViewWithListener> createState() => _PageViewWithListenerState();
}

class _PageViewWithListenerState extends State<PageViewWithListener> {
  late PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = widget.controller ?? PageController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _pageController.dispose();
    }
    super.dispose();
  }

  void _handlePageChanged(int index) {
    if (_currentPageIndex != index) {
      setState(() {
        _currentPageIndex = index;
      });
    }
    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _handlePageChanged,
      physics: widget.physics,
      pageSnapping: widget.pageSnapping,
      reverse: widget.reverse,
      scrollDirection: widget.scrollDirection,
      dragStartBehavior: widget.dragStartBehavior,
      allowImplicitScrolling: widget.allowImplicitScrolling,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      padEnds: widget.padEnds,
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return PageStateProvider(
          currentPageIndex: _currentPageIndex,
          pageState: _currentPageIndex == index
              ? PageLifecycleState.active
              : PageLifecycleState.inactive,
          pageIndex: index,
          child: widget.children[index],
        );
      },
    );
  }
}

/// 页面生命周期Mixin
mixin PageLifecycleMixin<T extends StatefulWidget> on State<T>
    implements PageLifecycleAware {
  bool _isPageActive = false;
  PageLifecycleState? _lastState;

  bool get isPageActive => _isPageActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final pageProvider = PageStateProvider.of(context);
    if (pageProvider != null) {
      final currentState = pageProvider.pageState;

      if (_lastState != currentState) {
        _lastState = currentState;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            switch (currentState) {
              case PageLifecycleState.active:
                onPageActive();
                break;
              case PageLifecycleState.inactive:
                onPageInactive();
                break;
            }
          }
        });
      }
    }
  }

  @override
  void onPageActive() {
    if (!_isPageActive) {
      _isPageActive = true;
      onPageBecameActive();
    }
  }

  @override
  void onPageInactive() {
    if (_isPageActive) {
      _isPageActive = false;
      onPageBecameInactive();
    }
  }

  void onPageBecameActive() {}
  void onPageBecameInactive() {}
}
