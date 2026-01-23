/// 应用自定义异常基类
/// 
/// 所有自定义异常都应该实现这个接口
/// ErrorUtils 会自动识别并提取 message
abstract class AppException implements Exception {
  String get message;
  
  @override
  String toString() => message;
}
