import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/server_time_converter.dart';

part 'key_config_models.g.dart';

/// 用于 copyWith 中区分 null 和未传值的哨兵对象
const _sentinel = Object();

/// 投票类型
enum KeyConfigVoteType {
  @JsonValue('up')
  up,
  @JsonValue('down')
  down,
}

/// 审核状态
enum KeyConfigAuditStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected;

  String get value => switch (this) {
    KeyConfigAuditStatus.pending => 'pending',
    KeyConfigAuditStatus.approved => 'approved',
    KeyConfigAuditStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    KeyConfigAuditStatus.pending => '待审核',
    KeyConfigAuditStatus.approved => '已通过',
    KeyConfigAuditStatus.rejected => '已拒绝',
  };
}

/// 按键配置模型
@JsonSerializable()
class KeyConfig extends Equatable {
  final int id;
  final String configId;
  final String name;
  final String description;
  final int categoryId;
  final String category;
  final String? icon;
  final String config;
  final bool needsKeybind;
  final int userID;
  final bool isActive;
  final int sort;
  @ServerTimeConverter()
  final DateTime createdAt;
  @ServerTimeConverter()
  final DateTime updatedAt;

  // 用户信息（可选，由后端返回，仅列表接口返回）
  final String? userNickname;
  final String? userAvatar;

  // 投票信息（仅列表接口返回）
  @JsonKey(defaultValue: 0)
  final int upCount;
  @JsonKey(defaultValue: 0)
  final int downCount;
  @JsonKey(defaultValue: 0)
  final int voteCount;
  @JsonKey(defaultValue: false)
  final bool hasVoted;
  final String? voteType;
  @JsonKey(defaultValue: false)
  final bool isOwner;

  // 审核信息
  @JsonKey(defaultValue: KeyConfigAuditStatus.approved)
  final KeyConfigAuditStatus auditStatus;
  @JsonKey(defaultValue: '')
  final String auditRemark;
  @NullableServerTimeConverter()
  final DateTime? auditAt;

  // 新增字段：应用次数、评论数、编辑理由
  @JsonKey(defaultValue: 0)
  final int useCount;
  @JsonKey(defaultValue: 0)
  final int commentCount;
  final String? editReason;

  const KeyConfig({
    required this.id,
    required this.configId,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.category,
    this.icon,
    required this.config,
    required this.needsKeybind,
    required this.userID,
    required this.isActive,
    required this.sort,
    required this.createdAt,
    required this.updatedAt,
    this.userNickname,
    this.userAvatar,
    this.upCount = 0,
    this.downCount = 0,
    this.voteCount = 0,
    this.hasVoted = false,
    this.voteType,
    this.isOwner = false,
    this.auditStatus = KeyConfigAuditStatus.approved,
    this.auditRemark = '',
    this.auditAt,
    this.useCount = 0,
    this.commentCount = 0,
    this.editReason,
  });

  /// 获取投票类型枚举
  KeyConfigVoteType? get voteTypeEnum {
    if (voteType == 'up') return KeyConfigVoteType.up;
    if (voteType == 'down') return KeyConfigVoteType.down;
    return null;
  }

  /// 是否待审核
  bool get isPending => auditStatus == KeyConfigAuditStatus.pending;

  /// 是否已通过
  bool get isApproved => auditStatus == KeyConfigAuditStatus.approved;

  /// 是否已拒绝
  bool get isRejected => auditStatus == KeyConfigAuditStatus.rejected;

  factory KeyConfig.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigToJson(this);

  KeyConfig copyWith({
    int? id,
    String? configId,
    String? name,
    String? description,
    int? categoryId,
    String? category,
    String? icon,
    String? config,
    bool? needsKeybind,
    int? userID,
    bool? isActive,
    int? sort,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userNickname,
    String? userAvatar,
    int? upCount,
    int? downCount,
    int? voteCount,
    bool? hasVoted,
    Object? voteType = _sentinel,
    bool? isOwner,
    KeyConfigAuditStatus? auditStatus,
    String? auditRemark,
    Object? auditAt = _sentinel,
    int? useCount,
    int? commentCount,
    Object? editReason = _sentinel,
  }) {
    return KeyConfig(
      id: id ?? this.id,
      configId: configId ?? this.configId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      config: config ?? this.config,
      needsKeybind: needsKeybind ?? this.needsKeybind,
      userID: userID ?? this.userID,
      isActive: isActive ?? this.isActive,
      sort: sort ?? this.sort,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userNickname: userNickname ?? this.userNickname,
      userAvatar: userAvatar ?? this.userAvatar,
      upCount: upCount ?? this.upCount,
      downCount: downCount ?? this.downCount,
      voteCount: voteCount ?? this.voteCount,
      hasVoted: hasVoted ?? this.hasVoted,
      voteType: voteType == _sentinel ? this.voteType : voteType as String?,
      isOwner: isOwner ?? this.isOwner,
      auditStatus: auditStatus ?? this.auditStatus,
      auditRemark: auditRemark ?? this.auditRemark,
      auditAt: auditAt == _sentinel ? this.auditAt : auditAt as DateTime?,
      useCount: useCount ?? this.useCount,
      commentCount: commentCount ?? this.commentCount,
      editReason: editReason == _sentinel
          ? this.editReason
          : editReason as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    configId,
    name,
    description,
    categoryId,
    category,
    icon,
    config,
    needsKeybind,
    userID,
    isActive,
    sort,
    createdAt,
    updatedAt,
    userNickname,
    userAvatar,
    upCount,
    downCount,
    voteCount,
    hasVoted,
    voteType,
    isOwner,
    auditStatus,
    auditRemark,
    auditAt,
    useCount,
    commentCount,
    editReason,
  ];
}

/// 配置列表响应
@JsonSerializable()
class KeyConfigListResponse extends Equatable {
  @JsonKey(defaultValue: [])
  final List<KeyConfig> items;
  final int total;

  const KeyConfigListResponse({required this.items, required this.total});

  factory KeyConfigListResponse.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigListResponseToJson(this);

  @override
  List<Object?> get props => [items, total];
}

/// 配置分类模型
@JsonSerializable()
class KeyConfigCategory extends Equatable {
  final int id;
  final String name;

  const KeyConfigCategory({required this.id, required this.name});

  factory KeyConfigCategory.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigCategoryToJson(this);

  @override
  String toString() => name;

  @override
  List<Object?> get props => [id, name];
}

/// 创建配置请求
@JsonSerializable()
class KeyConfigCreateRequest extends Equatable {
  final String configId; // 业务标识符
  final String name;
  final String description;
  final int categoryId;
  final String? icon;
  final String config;
  final bool needsKeybind;
  final bool? isActive;
  final int? sort;

  const KeyConfigCreateRequest({
    required this.configId,
    required this.name,
    required this.description,
    required this.categoryId,
    this.icon,
    required this.config,
    required this.needsKeybind,
    this.isActive,
    this.sort,
  });

  factory KeyConfigCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigCreateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigCreateRequestToJson(this);

  @override
  List<Object?> get props => [
    configId,
    name,
    description,
    categoryId,
    icon,
    config,
    needsKeybind,
    isActive,
    sort,
  ];
}

/// autoexec.cfg 中的配置块
class ConfigBlock extends Equatable {
  final String configId;
  final String? configName;
  final String content;
  final Map<String, String> keyBindings;
  final bool isManaged;

  const ConfigBlock({
    required this.configId,
    this.configName,
    required this.content,
    required this.keyBindings,
    this.isManaged = true,
  });

  /// 获取显示名称（优先使用配置名称，否则使用ID）
  String get displayName => configName ?? configId;

  ConfigBlock copyWith({
    String? configId,
    String? configName,
    String? content,
    Map<String, String>? keyBindings,
    bool? isManaged,
  }) {
    return ConfigBlock(
      configId: configId ?? this.configId,
      configName: configName ?? this.configName,
      content: content ?? this.content,
      keyBindings: keyBindings ?? this.keyBindings,
      isManaged: isManaged ?? this.isManaged,
    );
  }

  @override
  List<Object?> get props => [
    configId,
    configName,
    content,
    keyBindings,
    isManaged,
  ];
}

/// 投票响应
@JsonSerializable()
class KeyConfigVoteResponse extends Equatable {
  final bool success;
  @JsonKey(defaultValue: 0)
  final int upCount;
  @JsonKey(defaultValue: 0)
  final int downCount;
  @JsonKey(defaultValue: 0)
  final int voteCount;
  final bool hasVoted;
  final String? voteType;

  const KeyConfigVoteResponse({
    required this.success,
    this.upCount = 0,
    this.downCount = 0,
    this.voteCount = 0,
    required this.hasVoted,
    this.voteType,
  });

  factory KeyConfigVoteResponse.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigVoteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigVoteResponseToJson(this);

  @override
  List<Object?> get props => [
    success,
    upCount,
    downCount,
    voteCount,
    hasVoted,
    voteType,
  ];
}

/// 按键配置评论模型
@JsonSerializable()
class KeyConfigComment extends Equatable {
  final int id;
  final int configId;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  final bool isAdmin;
  final String content;
  @JsonKey(defaultValue: [])
  final List<String> images;
  final int? replyToId;
  @JsonKey(defaultValue: 0)
  final int replyCount;
  @ServerTimeConverter()
  final DateTime createdAt;
  @NullableServerTimeConverter()
  final DateTime? updatedAt;

  const KeyConfigComment({
    required this.id,
    required this.configId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.isAdmin = false,
    required this.content,
    this.images = const [],
    this.replyToId,
    this.replyCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory KeyConfigComment.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigCommentFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigCommentToJson(this);

  @override
  List<Object?> get props => [
    id,
    configId,
    authorId,
    authorName,
    authorAvatar,
    isAdmin,
    content,
    images,
    replyToId,
    replyCount,
    createdAt,
    updatedAt,
  ];
}

/// 评论列表响应
@JsonSerializable()
class KeyConfigCommentListResponse extends Equatable {
  final int total;
  @JsonKey(defaultValue: [])
  final List<KeyConfigComment> items;

  const KeyConfigCommentListResponse({
    required this.total,
    this.items = const [],
  });

  factory KeyConfigCommentListResponse.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigCommentListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigCommentListResponseToJson(this);

  @override
  List<Object?> get props => [total, items];
}

/// 创建评论响应
@JsonSerializable()
class KeyConfigCreateCommentResponse extends Equatable {
  final int id;
  final String content;
  @ServerTimeConverter()
  final DateTime createdAt;

  const KeyConfigCreateCommentResponse({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  factory KeyConfigCreateCommentResponse.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigCreateCommentResponseFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigCreateCommentResponseToJson(this);

  @override
  List<Object?> get props => [id, content, createdAt];
}

/// 应用配置响应
@JsonSerializable()
class KeyConfigUseResponse extends Equatable {
  final int useCount;

  const KeyConfigUseResponse({required this.useCount});

  factory KeyConfigUseResponse.fromJson(Map<String, dynamic> json) =>
      _$KeyConfigUseResponseFromJson(json);
  Map<String, dynamic> toJson() => _$KeyConfigUseResponseToJson(this);

  @override
  List<Object?> get props => [useCount];
}
