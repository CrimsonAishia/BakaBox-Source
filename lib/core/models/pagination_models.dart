/// 通用分页参数模型
class PaginationParams {
  final int pageIndex;
  final int pageSize;

  const PaginationParams({this.pageIndex = 1, this.pageSize = 20});

  /// 转换为请求体 JSON（包含 pagination 包装）
  Map<String, dynamic> toJson() => {
    'pagination': {'pageIndex': pageIndex, 'pageSize': pageSize},
  };

  /// 转换为纯 JSON（不包含 pagination 包装）
  Map<String, dynamic> toPlainJson() => {
    'pageIndex': pageIndex,
    'pageSize': pageSize,
  };
}
