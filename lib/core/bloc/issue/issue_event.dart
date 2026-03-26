import 'package:equatable/equatable.dart';

abstract class IssueEvent extends Equatable {
  const IssueEvent();
  @override
  List<Object?> get props => [];
}

/// 获取 Issue 列表
class IssueFetch extends IssueEvent {
  final String? type;
  final String status;
  final String sort;
  final String? keyword;

  const IssueFetch({
    this.type,
    this.status = 'open',
    this.sort = 'created_at DESC',
    this.keyword,
  });

  @override
  List<Object?> get props => [type, status, sort, keyword];
}

/// 获取我的 Issue 列表
class IssueFetchMine extends IssueEvent {
  final String? type;
  final String? status;
  final String? sort;

  const IssueFetchMine({this.type, this.status, this.sort});

  @override
  List<Object?> get props => [type, status, sort];
}

/// 加载更多
class IssueLoadMore extends IssueEvent {
  const IssueLoadMore();
}

/// 刷新列表
class IssueRefresh extends IssueEvent {
  const IssueRefresh();
}

/// 搜索
class IssueSearch extends IssueEvent {
  final String keyword;
  const IssueSearch(this.keyword);
  @override
  List<Object?> get props => [keyword];
}

/// 切换类型筛选
class IssueFilterType extends IssueEvent {
  final String? type;
  const IssueFilterType(this.type);
  @override
  List<Object?> get props => [type];
}

/// 切换状态筛选
class IssueFilterStatus extends IssueEvent {
  final String status;
  const IssueFilterStatus(this.status);
  @override
  List<Object?> get props => [status];
}

/// 切换排序
class IssueSort extends IssueEvent {
  final String sort;
  const IssueSort(this.sort);
  @override
  List<Object?> get props => [sort];
}

/// 切换视图模式（全部/我的）
class IssueSwitchView extends IssueEvent {
  final bool showMine;
  const IssueSwitchView(this.showMine);
  @override
  List<Object?> get props => [showMine];
}

/// 清除错误
class IssueClearError extends IssueEvent {
  const IssueClearError();
}

/// 重置状态
class IssueReset extends IssueEvent {
  const IssueReset();
}

/// 跳转到指定页
class IssueGoToPage extends IssueEvent {
  final int page;
  const IssueGoToPage(this.page);
  @override
  List<Object?> get props => [page];
}
