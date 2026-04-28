import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:win32_registry/win32_registry.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';

import '../utils/log_service.dart';

/// 广播通知服务 - 将大厅广播消息转为 Windows 系统通知
///
/// 仅在 Windows 桌面端生效，其他平台静默降级。
/// 通过注册自定义 AUMID，使通知标题显示 "BakaBox" 而非 PowerShell。
class BroadcastNotificationService {
  static final BroadcastNotificationService instance =
      BroadcastNotificationService._();

  BroadcastNotificationService._();

  static const String _appId = 'BakaBox.App';
  static const String _appDisplayName = 'BakaBox';
  static const String _registryPath =
      r'Software\Classes\AppUserModelId\BakaBox.App';

  WindowsNotification? _plugin;
  final Random _random = Random();

  /// 初始化通知服务（仅 Windows）
  Future<void> init() async {
    if (!Platform.isWindows) return;
    try {
      await _registerAumid();
      _plugin = WindowsNotification(applicationId: _appId);
      LogService.i('[BroadcastNotification] 初始化完成，AUMID: $_appId');
    } catch (e) {
      LogService.e('[BroadcastNotification] 初始化失败，降级使用 PowerShell AUMID', e);
      try {
        const fallbackId =
            r'{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27}\WindowsPowerShell\v1.0\powershell.exe';
        _plugin = WindowsNotification(applicationId: fallbackId);
      } catch (_) {}
    }
  }

  /// 向注册表写入自定义 AUMID
  Future<void> _registerAumid() async {
    try {
      // 获取应用图标路径（exe 同级 data/flutter_assets/assets/images/logo.ico）
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final iconPath = '$exeDir\\data\\flutter_assets\\assets\\images\\logo.ico';

      final key = Registry.currentUser.createKey(_registryPath);
      key.createValue(
        const RegistryValue('DisplayName', RegistryValueType.string, _appDisplayName),
      );
      key.createValue(
        RegistryValue('IconUri', RegistryValueType.string, iconPath),
      );
      key.close();
      LogService.d('[BroadcastNotification] AUMID 注册成功，图标: $iconPath');
    } catch (e) {
      LogService.w('[BroadcastNotification] AUMID 注册失败: $e');
      rethrow;
    }
  }

  /// 显示广播通知
  ///
  /// 布局：左侧圆形头像，右侧上方用户名，右侧下方广播内容。
  /// 顶部 app 标题固定为 "BakaBox 大厅广播"。
  Future<void> showBroadcastNotification({
    required String sender,
    required String content,
    String? avatarUrl,
  }) async {
    if (_plugin == null) return;
    try {
      // 非 MSIX 打包的 Win32 应用无法直接加载网络图片，需先下载到本地
      String? localAvatarPath;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        localAvatarPath = await _downloadAvatarToTemp(avatarUrl);
      }

      final id = 'broadcast_${_random.nextInt(100000)}';
      final message = NotificationMessage.fromCustomTemplate(
        id,
        group: 'lobby_broadcast',
      );
      _plugin!.showNotificationCustomTemplate(
        message,
        _buildToastXml(sender: sender, content: content, localAvatarPath: localAvatarPath),
      );
    } catch (e) {
      LogService.e('[BroadcastNotification] 显示通知失败', e);
    }
  }

  /// 下载头像到临时目录，返回本地文件路径；失败返回 null
  Future<String?> _downloadAvatarToTemp(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final tempDir = await getTemporaryDirectory();
      final ext = p.extension(Uri.parse(url).path).isNotEmpty
          ? p.extension(Uri.parse(url).path)
          : '.jpg';
      final fileName = 'baka_avatar_${url.hashCode.abs()}$ext';
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsBytes(response.bodyBytes);
      LogService.d('[BroadcastNotification] 头像已缓存: ${file.path}');
      return file.path;
    } catch (e) {
      LogService.w('[BroadcastNotification] 头像下载失败，将使用默认图标: $e');
      return null;
    }
  }

  /// 构建 Toast XML
  ///
  /// 有头像时：appLogoOverride 使用本地缓存的头像路径
  /// 无头像时：使用应用 logo
  String _buildToastXml({
    required String sender,
    required String content,
    String? localAvatarPath,
  }) {
    final safeSender = _escapeXml(sender);
    final safeContent = _escapeXml(content);
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final iconPath = _escapeXml('$exeDir\\data\\flutter_assets\\assets\\images\\logo.png');

    final imageSrc = localAvatarPath != null
        ? _escapeXml(localAvatarPath)
        : iconPath;
    final cropAttr = localAvatarPath != null ? ' hint-crop="circle"' : '';

    return '''
<toast>
  <visual>
    <binding template="ToastGeneric">
      <image placement="appLogoOverride"$cropAttr src="$imageSrc"/>
      <text>BakaBox 大厅广播</text>
      <text hint-style="body" hint-bold="true">$safeSender</text>
      <text hint-style="captionSubtle" hint-wrap="true">$safeContent</text>
    </binding>
  </visual>
</toast>''';
  }

  String _escapeXml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
