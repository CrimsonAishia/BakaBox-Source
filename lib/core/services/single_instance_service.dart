import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

/// 单实例服务
///
/// 负责管理 Windows 平台的单实例检查和窗口唤醒。
///
/// 设计要点：
/// - 第二个实例必须在「打开 Hive 存储之前」就退出，否则会卡在被首个实例
///   独占锁定的 box 文件上，表现为「程序未响应 + 任务管理器残留进程」。
/// - 因此本服务通过 [ensureSingleInstance] 返回 `bool`，由调用方
///   （window_launcher）在初始化存储之前决定是否 `exit(0)`。
/// - 唤醒已运行实例时只负责「显示 + 置前」，不触碰托盘等其它资源。
class SingleInstanceService {
  SingleInstanceService._();

  static final SingleInstanceService instance = SingleInstanceService._();

  /// 单实例唯一标识符（只能使用 a-z, 0-9, _ 和 -）
  static const _key = 'BakaBox_CS2_Launcher';

  /// 防止重复检查（同一进程内 [ensureSingleInstance] 只应生效一次）
  bool _checked = false;

  /// 确保单实例运行
  ///
  /// 返回值：
  /// - `true`  当前是首个实例，可以继续启动；
  /// - `false` 已有实例在运行（已通知其唤醒窗口），调用方应立即退出进程，
  ///   且**不要**进行任何存储/窗口初始化。
  Future<bool> ensureSingleInstance(List<String> args) async {
    // 非 Windows 平台不做单实例限制
    if (!Platform.isWindows) return true;

    // 同一进程内重复调用直接放行（首个实例已持有 mutex）
    if (_checked) return true;
    _checked = true;

    var isSecondInstance = false;

    try {
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        _key,
        onSecondWindow: _wakeExistingInstance,
        // 关闭包内置的原生置前逻辑，统一由 _wakeExistingInstance 通过
        // window_manager 处理，避免与 window_manager 的可见性状态不一致。
        bringWindowToFront: false,
        // 关键：第二个实例不在包内部 exit(0)，而是把控制权交回调用方，
        // 让其在「初始化存储之前」干净退出，规避 Hive 文件锁死锁。
        exitFunction: () async {
          isSecondInstance = true;
        },
      );
    } catch (e) {
      // 单实例检查链路异常（插件未就绪、沙箱限制等）。
      // 此时无法可靠判断，保守放行以保证用户至少能启动程序。
      debugPrint('[SingleInstance] 单实例检查失败，放行启动: $e');
      return true;
    }

    if (isSecondInstance) {
      debugPrint('[SingleInstance] 检测到已有实例运行，当前进程将退出');
      return false;
    }

    return true;
  }

  /// 唤醒已存在的窗口实例
  ///
  /// 运行在**首个实例**进程中：当用户重复启动程序时，第二个实例会通过
  /// 命名管道通知到这里，负责把主窗口重新显示并拉到前台。
  ///
  /// 注意：
  /// - 这里**不能**销毁托盘图标——销毁托盘是退出流程的职责。
  /// - frameless + 多窗口场景下单纯 `focus()` 经常抢不到前台，
  ///   这里用一次 `alwaysOnTop` 翻转强制把窗口提到最上层后再取消。
  /// - 全程包裹 try/catch，任何一步失败都不应影响已运行实例继续工作。
  Future<void> _wakeExistingInstance(List<String> args) async {
    try {
      // 1. 若窗口被隐藏（最小化到托盘），重新显示
      final isVisible = await windowManager.isVisible();
      if (!isVisible) {
        await windowManager.show();
      }

      // 2. 若窗口被最小化，恢复它
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }

      // 3. 确保任务栏可见（防御：避免之前被 skipTaskbar 隐藏）
      await windowManager.setSkipTaskbar(false);

      // 4. 显示并取得焦点
      await windowManager.show();
      await windowManager.focus();

      // 5. 强制置前：alwaysOnTop 翻转，绕过系统前台抢占限制
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setAlwaysOnTop(false);
    } catch (e) {
      // 唤醒失败不影响已运行实例继续工作
      debugPrint('[SingleInstance] 唤醒已运行实例失败: $e');
    }
  }
}
