import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../constants/app_constants.dart';
import '../utils/log_service.dart';

class TrayService with TrayListener {
  TrayService._();

  static final TrayService instance = TrayService._();

  bool _initialized = false;
  bool _listenerAttached = false;

  Future<void> initialize() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    if (!_listenerAttached) {
      trayManager.addListener(this);
      _listenerAttached = true;
    }

    if (_initialized) {
      return;
    }

    await trayManager.setIcon(_iconPath);
    await trayManager.setToolTip(AppConstants.appName);
    await trayManager.setContextMenu(_buildMenu());
    _initialized = true;
    LogService.d('[TrayService] 系统托盘已初始化');
  }

  Future<void> dispose() async {
    if (_listenerAttached) {
      trayManager.removeListener(this);
      _listenerAttached = false;
    }
    if (_initialized) {
      await trayManager.destroy();
      _initialized = false;
      LogService.d('[TrayService] 系统托盘已销毁');
    }
  }

  Future<void> showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> toggleMainWindow() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await showMainWindow();
    }
  }

  Menu _buildMenu() {
    return Menu(
      items: [
        MenuItem(
          key: 'show',
          label: '显示主窗口',
          onClick: (_) => unawaited(showMainWindow()),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: '退出程序',
          onClick: (_) => unawaited(_exitApplication()),
        ),
      ],
    );
  }

  String get _iconPath {
    if (Platform.isWindows) {
      return 'assets/images/logo.ico';
    }
    return 'assets/images/logo.png';
  }

  Future<void> _exitApplication() async {
    await dispose();
    await windowManager.close();
  }

  @override
  void onTrayIconMouseDown() {
    if (Platform.isWindows) {
      unawaited(toggleMainWindow());
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    if (Platform.isWindows) {
      unawaited(trayManager.popUpContextMenu());
    }
  }
}
