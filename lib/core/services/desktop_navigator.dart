import 'package:flutter/material.dart';

/// 桌面端跨模块导航抽象
///
/// 攻略模块在 [CommunityGuideScreen] 内自维护视图切换，
/// 此接口统一暴露跨模块跳转能力（如：编辑器 → 地图数据库），
/// 实现层在 `desktop_home_screen.dart` 通过 [DesktopNavigatorProvider] 暴露。
abstract class DesktopNavigator {
  /// 打开攻略列表，[mapName] 非空时按地图筛选
  void openGuides({String? mapName});

  /// 打开攻略详情页
  void openGuideDetail(int id);

  /// 打开攻略编辑器；[guideId] 非空时为编辑模式，[prefillMapName] 预填关联地图
  void openGuideEditor({int? guideId, String? prefillMapName});

  /// 切换到工具箱并打开地图数据库，[mapName] 非空时定位到对应地图详情
  void openMapDatabase({String? mapName});

  /// 打开「我的中心」
  void openMine();
}

/// InheritedWidget 用于在子树中访问 DesktopNavigator
class DesktopNavigatorProvider extends InheritedWidget {
  final DesktopNavigator navigator;

  const DesktopNavigatorProvider({
    super.key,
    required this.navigator,
    required super.child,
  });

  /// 从子树中获取 [DesktopNavigator] 实例；不在树中时返回 null
  static DesktopNavigator? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DesktopNavigatorProvider>()
        ?.navigator;
  }

  @override
  bool updateShouldNotify(DesktopNavigatorProvider oldWidget) {
    return navigator != oldWidget.navigator;
  }
}
