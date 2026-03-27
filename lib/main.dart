import 'app/platform_app.dart';

/// 应用入口
///
/// 职责：
/// 1. 初始化 Flutter 绑定
/// 2. 记录启动时间
/// 3. 根据平台分发到对应的启动流程
Future<void> main(List<String> args) async {
  await runPlatformApp(args);
}
