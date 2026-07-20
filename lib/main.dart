import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:leak_tracker/leak_tracker.dart';

import 'app/platform_app.dart';
import 'core/utils/log_service.dart';

/// 应用入口
///
/// 职责：
/// 1. 初始化 Flutter 绑定
/// 2. 记录启动时间
/// 3. 根据平台分发到对应的启动流程
///
/// 全局错误兜底（关键）：
/// - 通过 `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError`
///   吃掉未捕获的同步/异步异常，避免 Dart runtime 在进程退出瞬间因未处理异常
///   触发 fatal 终止，加剧原生侧 COM/CRT 卸载阶段的崩溃概率。
/// - 尤其是退出流程中大量原生插件在 dispose，任何一处漏网的 async 异常都
///   可能升级为进程 crash，配合 WER 缺失的机器就变成 "Unknown Hard Error" 弹窗。
Future<void> main(List<String> args) async {
  if (kDebugMode || kProfileMode) {
    LeakTracking.start();
  }
  await runZonedGuarded<Future<void>>(
    () async {
      // Flutter 框架内的错误（build / layout / paint 等同步异常）
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _safeLogError(
          '[FlutterError] ${details.summary}',
          details.exception,
          details.stack,
        );
      };

      // 平台层未处理的异步异常（原生调用、Isolate 未捕获等）
      // 返回 true 表示已处理，不再升级为 fatal
      PlatformDispatcher.instance.onError = (error, stack) {
        _safeLogError('[PlatformError]', error, stack);
        return true;
      };

      await runPlatformApp(args);
    },
    (error, stack) {
      // 落到这里的通常是启动阶段的 async 异常
      _safeLogError('[ZoneError]', error, stack);
    },
  );
}

/// 安全打日志：LogService 未初始化时也不会抛异常
void _safeLogError(String message, Object error, StackTrace? stack) {
  try {
    LogService.e(message, error, stack);
  } catch (_) {
    // 极端情况兜底
    debugPrint('$message: $error\n$stack');
  }
}
