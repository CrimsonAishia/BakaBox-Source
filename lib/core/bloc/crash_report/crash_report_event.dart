import 'package:equatable/equatable.dart';

abstract class CrashReportEvent extends Equatable {
  const CrashReportEvent();
  @override
  List<Object?> get props => [];
}

/// 拉取公开列表
class CrashReportFetch extends CrashReportEvent {
  final String severity;
  final String category;
  final String sort;
  final String? keyword;
  final String? signature;
  final bool clearSignature;

  const CrashReportFetch({
    this.severity = 'all',
    this.category = 'all',
    this.sort = 'created_at DESC',
    this.keyword,
    this.signature,
    this.clearSignature = false,
  });

  @override
  List<Object?> get props => [severity, category, sort, keyword, signature, clearSignature];
}

/// 拉取我的列表（本地扫描 .mdmp 文件）
class CrashReportFetchMine extends CrashReportEvent {
  const CrashReportFetchMine();
}

/// 加载某个本地崩溃的解析详情
class CrashReportLoadLocalDetail extends CrashReportEvent {
  final String path;
  const CrashReportLoadLocalDetail(this.path);
  @override
  List<Object?> get props => [path];
}

/// 关闭本地详情
class CrashReportCloseLocalDetail extends CrashReportEvent {
  const CrashReportCloseLocalDetail();
}

/// 删除某个本地 mdmp 文件（不可恢复）
class CrashReportDeleteLocal extends CrashReportEvent {
  final String path;
  const CrashReportDeleteLocal(this.path);
  @override
  List<Object?> get props => [path];
}

/// 加载更多
class CrashReportLoadMore extends CrashReportEvent {
  const CrashReportLoadMore();
}

/// 刷新
class CrashReportRefresh extends CrashReportEvent {
  const CrashReportRefresh();
}

/// 切换「全部 / 我的」
class CrashReportSwitchView extends CrashReportEvent {
  final bool showMine;
  const CrashReportSwitchView(this.showMine);
  @override
  List<Object?> get props => [showMine];
}

/// 切换严重度过滤
class CrashReportFilterSeverity extends CrashReportEvent {
  final String severity;
  const CrashReportFilterSeverity(this.severity);
  @override
  List<Object?> get props => [severity];
}

/// 切换类别过滤
class CrashReportFilterCategory extends CrashReportEvent {
  final String category;
  const CrashReportFilterCategory(this.category);
  @override
  List<Object?> get props => [category];
}

/// 关键字搜索（节流后调用）
class CrashReportSearch extends CrashReportEvent {
  final String keyword;
  const CrashReportSearch(this.keyword);
  @override
  List<Object?> get props => [keyword];
}

/// 加载远端详情
class CrashReportLoadDetail extends CrashReportEvent {
  final int id;
  const CrashReportLoadDetail(this.id);
  @override
  List<Object?> get props => [id];
}

/// 关闭远端详情
class CrashReportCloseDetail extends CrashReportEvent {
  const CrashReportCloseDetail();
}

/// 拉取社区聚合数据
class CrashReportFetchStats extends CrashReportEvent {
  const CrashReportFetchStats();
}

/// 清除错误
class CrashReportClearError extends CrashReportEvent {
  const CrashReportClearError();
}
