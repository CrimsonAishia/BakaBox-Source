import '../api/api.dart';
import '../exceptions/app_exception.dart';

/// 错误处理工具类
///
/// 统一处理各种异常，返回用户友好的错误信息
class ErrorUtils {
  /// 从异常中提取用户友好的错误信息
  ///
  /// 优先级：
  /// 1. AppException（所有自定义异常的基类，包括 UpdateException、ApiException、FileValidationException 等）
  /// 2. 常见网络错误返回友好提示
  /// 3. 其他异常返回通用错误信息
  static String getErrorMessage(Object e, {String? defaultMessage}) {
    // AppException 及其子类直接返回 message
    if (e is AppException) {
      return e.message;
    }

    final errorStr = e.toString();

    // 网络相关错误
    if (errorStr.contains('SocketException') ||
        errorStr.contains('NetworkException') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('Connection reset')) {
      return '网络连接失败，请检查网络设置';
    }

    if (errorStr.contains('TimeoutException') ||
        errorStr.contains('timeout') ||
        errorStr.contains('Timeout')) {
      return '请求超时，请稍后重试';
    }

    if (errorStr.contains('HandshakeException') ||
        errorStr.contains('CERTIFICATE_VERIFY_FAILED')) {
      return '安全连接失败，请检查网络环境';
    }

    // 服务器错误
    if (errorStr.contains('500') ||
        errorStr.contains('Internal Server Error')) {
      return '服务器内部错误，请稍后重试';
    }

    if (errorStr.contains('502') || errorStr.contains('Bad Gateway')) {
      return '服务器暂时不可用，请稍后重试';
    }

    if (errorStr.contains('503') || errorStr.contains('Service Unavailable')) {
      return '服务暂时不可用，请稍后重试';
    }

    if (errorStr.contains('404') || errorStr.contains('Not Found')) {
      return '请求的资源不存在';
    }

    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return '登录已过期，请重新登录';
    }

    if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
      return '没有权限执行此操作';
    }

    if (errorStr.contains('429') || errorStr.contains('Too Many Requests')) {
      return '操作太频繁，请稍后再试';
    }

    // 文件相关错误
    if (errorStr.contains('FileSystemException')) {
      return '文件操作失败';
    }

    // 格式错误
    if (errorStr.contains('FormatException') ||
        errorStr.contains('Invalid') ||
        errorStr.contains('format')) {
      return '数据格式错误';
    }

    // 清理 Exception: 前缀
    if (errorStr.startsWith('Exception:')) {
      return errorStr.replaceFirst('Exception:', '').trim();
    }

    // 返回默认消息或通用错误
    return defaultMessage ?? '操作失败，请稍后重试';
  }

  /// 判断是否为网络错误
  static bool isNetworkError(Object e) {
    final errorStr = e.toString();
    return errorStr.contains('SocketException') ||
        errorStr.contains('NetworkException') ||
        errorStr.contains('Connection') ||
        errorStr.contains('TimeoutException') ||
        errorStr.contains('timeout');
  }

  /// 判断是否为认证错误
  static bool isAuthError(Object e) {
    if (e is ApiException) {
      return e.code == 401;
    }
    final errorStr = e.toString();
    return errorStr.contains('401') ||
        errorStr.contains('Unauthorized') ||
        errorStr.contains('登录');
  }

  /// 判断是否为限速错误（429）
  static bool isRateLimitError(Object e) {
    if (e is ApiException) {
      return e.code == 429;
    }
    final errorStr = e.toString();
    return errorStr.contains('429') ||
        errorStr.contains('Too Many Requests');
  }

  /// 判断是否为资源不存在（404）
  static bool isNotFoundError(Object e) {
    if (e is ApiException) {
      return e.code == 404;
    }
    final errorStr = e.toString();
    return errorStr.contains('404') ||
        errorStr.contains('Not Found');
  }

  /// 判断是否为权限不足（403）
  static bool isForbiddenError(Object e) {
    if (e is ApiException) {
      return e.code == 403;
    }
    final errorStr = e.toString();
    return errorStr.contains('403') ||
        errorStr.contains('Forbidden');
  }

  /// 判断是否为数据冲突（409）
  static bool isConflictError(Object e) {
    if (e is ApiException) {
      return e.code == 409;
    }
    final errorStr = e.toString();
    return errorStr.contains('409') ||
        errorStr.contains('Conflict');
  }

  /// 判断是否为服务端错误（5xx）
  static bool isServerError(Object e) {
    if (e is ApiException) {
      return e.code >= 500 && e.code < 600;
    }
    final errorStr = e.toString();
    return errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('Internal Server Error') ||
        errorStr.contains('Bad Gateway') ||
        errorStr.contains('Service Unavailable');
  }
}
