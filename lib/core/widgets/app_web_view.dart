import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/webview_environment_service.dart';

/// 项目统一的 WebView 封装组件。
///
/// 直接使用 [InAppWebView] 容易遗漏 `webViewEnvironment` 参数，
/// 一旦遗漏，在 Windows 上插件会回退创建「默认 WebView2 环境」
/// （userDataFolder 为 null），WebView2 会把缓存目录建在 exe 同级目录，
/// 安装在 Program Files 等只读位置时还会写入失败。
///
/// 本组件强制注入 [WebViewEnvironmentService.environment]，
/// 确保所有 WebView 都复用「我的文档/BakaBox/cache/webview2」这一可写缓存目录，
/// 调用方无需、也无法再手动指定环境。
///
/// 同时统一了默认行为：
/// - 默认拒绝所有权限请求（摄像头/麦克风/地理位置等），可通过
///   [onPermissionRequest] 覆盖。
class AppWebView extends StatelessWidget {
  const AppWebView({
    super.key,
    this.initialUrlRequest,
    this.initialSettings,
    this.onWebViewCreated,
    this.onLoadStart,
    this.onLoadStop,
    this.onUpdateVisitedHistory,
    this.onReceivedError,
    this.onCreateWindow,
    this.onPermissionRequest,
  });

  /// 初始加载的请求。
  final URLRequest? initialUrlRequest;

  /// WebView 设置。
  final InAppWebViewSettings? initialSettings;

  /// WebView 创建完成回调。
  final void Function(InAppWebViewController controller)? onWebViewCreated;

  /// 页面开始加载回调。
  final void Function(InAppWebViewController controller, WebUri? url)?
  onLoadStart;

  /// 页面加载结束回调。
  final void Function(InAppWebViewController controller, WebUri? url)?
  onLoadStop;

  /// 历史记录更新回调（用于检测 URL 跳转）。
  final void Function(
    InAppWebViewController controller,
    WebUri? url,
    bool? isReload,
  )?
  onUpdateVisitedHistory;

  /// 加载错误回调。
  final void Function(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  )?
  onReceivedError;

  /// 新窗口请求回调。
  final Future<bool?> Function(
    InAppWebViewController controller,
    CreateWindowAction createWindowAction,
  )?
  onCreateWindow;

  /// 权限请求回调。不传时默认拒绝所有权限请求。
  final Future<PermissionResponse?> Function(
    InAppWebViewController controller,
    PermissionRequest request,
  )?
  onPermissionRequest;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      // 关键：强制使用项目统一的可写缓存环境，避免缓存落到安装目录。
      webViewEnvironment: WebViewEnvironmentService.environment,
      initialUrlRequest: initialUrlRequest,
      initialSettings: initialSettings,
      onWebViewCreated: onWebViewCreated,
      onLoadStart: onLoadStart,
      onLoadStop: onLoadStop,
      onUpdateVisitedHistory: onUpdateVisitedHistory,
      onReceivedError: onReceivedError,
      onCreateWindow: onCreateWindow,
      onPermissionRequest: onPermissionRequest ?? _denyPermission,
    );
  }

  /// 默认权限处理：拒绝全部请求。
  static Future<PermissionResponse?> _denyPermission(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.DENY,
    );
  }
}
