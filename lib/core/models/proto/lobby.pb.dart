//
//  Generated code. Do not modify.
//  source: proto/lobby.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

enum LobbyEnvelope_Payload {
  loginRequest, 
  logoutRequest, 
  moveRequest, 
  chatSendRequest, 
  profileAnonymousChangeRequest, 
  profileSpriteChangeRequest, 
  profileStatusTextUpdateRequest, 
  profileDisplayNameUpdateRequest, 
  snapshotRequest, 
  assetsRequest, 
  broadcastSendRequest, 
  broadcastCdRequest, 
  portalUseRequest, 
  onlineStatsRequest, 
  profileSteamBindRequest, 
  enterRequest, 
  loginSuccessResponse, 
  loginFailedResponse, 
  logoutSuccessResponse, 
  joinSuccessResponse, 
  snapshotResponse, 
  presenceJoinResponse, 
  presenceLeaveResponse, 
  identityChangedResponse, 
  moveBroadcastResponse, 
  moveRejectResponse, 
  chatMessageResponse, 
  chatRejectResponse, 
  anonymousChangedResponse, 
  spriteChangedResponse, 
  spriteChangeRejectResponse, 
  statusTextBroadcastResponse, 
  displayNameChangedResponse, 
  assetsResponse, 
  assetsUpdatedResponse, 
  portalTeleportResponse, 
  portalUseRejectResponse, 
  broadcastMessageResponse, 
  broadcastRejectResponse, 
  broadcastCdResponse, 
  onlineStatsResponse, 
  systemErrorResponse, 
  systemNoticeResponse, 
  systemKickedResponse, 
  steamBindSuccessResponse, 
  spriteChangeSuccessResponse, 
  presenceDeltaResponse, 
  notSet
}

/// LobbyEnvelope 所有大厅消息的外层包装
class LobbyEnvelope extends $pb.GeneratedMessage {
  factory LobbyEnvelope({
    $core.int? v,
    $core.String? type,
    $fixnum.Int64? ts,
    $core.String? traceId,
    LoginRequest? loginRequest,
    LogoutRequest? logoutRequest,
    MoveRequest? moveRequest,
    ChatSendRequest? chatSendRequest,
    ProfileAnonymousChangeRequest? profileAnonymousChangeRequest,
    ProfileSpriteChangeRequest? profileSpriteChangeRequest,
    ProfileStatusTextUpdateRequest? profileStatusTextUpdateRequest,
    ProfileDisplayNameUpdateRequest? profileDisplayNameUpdateRequest,
    SnapshotRequest? snapshotRequest,
    AssetsRequest? assetsRequest,
    BroadcastSendRequest? broadcastSendRequest,
    BroadcastCDRequest? broadcastCdRequest,
    PortalUseRequest? portalUseRequest,
    OnlineStatsRequest? onlineStatsRequest,
    ProfileSteamBindRequest? profileSteamBindRequest,
    EnterRequest? enterRequest,
    LoginSuccessResponse? loginSuccessResponse,
    LoginFailedResponse? loginFailedResponse,
    LogoutSuccessResponse? logoutSuccessResponse,
    JoinSuccessResponse? joinSuccessResponse,
    SnapshotResponse? snapshotResponse,
    PresenceJoinResponse? presenceJoinResponse,
    PresenceLeaveResponse? presenceLeaveResponse,
    IdentityChangedResponse? identityChangedResponse,
    MoveBroadcastResponse? moveBroadcastResponse,
    MoveRejectResponse? moveRejectResponse,
    ChatMessageResponse? chatMessageResponse,
    ChatRejectResponse? chatRejectResponse,
    AnonymousChangedResponse? anonymousChangedResponse,
    SpriteChangedResponse? spriteChangedResponse,
    SpriteChangeRejectResponse? spriteChangeRejectResponse,
    StatusTextBroadcastResponse? statusTextBroadcastResponse,
    DisplayNameChangedResponse? displayNameChangedResponse,
    AssetsResponse? assetsResponse,
    AssetsUpdatedResponse? assetsUpdatedResponse,
    PortalTeleportResponse? portalTeleportResponse,
    PortalUseRejectResponse? portalUseRejectResponse,
    BroadcastMessageResponse? broadcastMessageResponse,
    BroadcastRejectResponse? broadcastRejectResponse,
    BroadcastCDResponse? broadcastCdResponse,
    OnlineStatsResponse? onlineStatsResponse,
    SystemErrorResponse? systemErrorResponse,
    SystemNoticeResponse? systemNoticeResponse,
    SystemKickedResponse? systemKickedResponse,
    SteamBindSuccessResponse? steamBindSuccessResponse,
    SpriteChangeSuccessResponse? spriteChangeSuccessResponse,
    PresenceDeltaResponse? presenceDeltaResponse,
  }) {
    final $result = create();
    if (v != null) {
      $result.v = v;
    }
    if (type != null) {
      $result.type = type;
    }
    if (ts != null) {
      $result.ts = ts;
    }
    if (traceId != null) {
      $result.traceId = traceId;
    }
    if (loginRequest != null) {
      $result.loginRequest = loginRequest;
    }
    if (logoutRequest != null) {
      $result.logoutRequest = logoutRequest;
    }
    if (moveRequest != null) {
      $result.moveRequest = moveRequest;
    }
    if (chatSendRequest != null) {
      $result.chatSendRequest = chatSendRequest;
    }
    if (profileAnonymousChangeRequest != null) {
      $result.profileAnonymousChangeRequest = profileAnonymousChangeRequest;
    }
    if (profileSpriteChangeRequest != null) {
      $result.profileSpriteChangeRequest = profileSpriteChangeRequest;
    }
    if (profileStatusTextUpdateRequest != null) {
      $result.profileStatusTextUpdateRequest = profileStatusTextUpdateRequest;
    }
    if (profileDisplayNameUpdateRequest != null) {
      $result.profileDisplayNameUpdateRequest = profileDisplayNameUpdateRequest;
    }
    if (snapshotRequest != null) {
      $result.snapshotRequest = snapshotRequest;
    }
    if (assetsRequest != null) {
      $result.assetsRequest = assetsRequest;
    }
    if (broadcastSendRequest != null) {
      $result.broadcastSendRequest = broadcastSendRequest;
    }
    if (broadcastCdRequest != null) {
      $result.broadcastCdRequest = broadcastCdRequest;
    }
    if (portalUseRequest != null) {
      $result.portalUseRequest = portalUseRequest;
    }
    if (onlineStatsRequest != null) {
      $result.onlineStatsRequest = onlineStatsRequest;
    }
    if (profileSteamBindRequest != null) {
      $result.profileSteamBindRequest = profileSteamBindRequest;
    }
    if (enterRequest != null) {
      $result.enterRequest = enterRequest;
    }
    if (loginSuccessResponse != null) {
      $result.loginSuccessResponse = loginSuccessResponse;
    }
    if (loginFailedResponse != null) {
      $result.loginFailedResponse = loginFailedResponse;
    }
    if (logoutSuccessResponse != null) {
      $result.logoutSuccessResponse = logoutSuccessResponse;
    }
    if (joinSuccessResponse != null) {
      $result.joinSuccessResponse = joinSuccessResponse;
    }
    if (snapshotResponse != null) {
      $result.snapshotResponse = snapshotResponse;
    }
    if (presenceJoinResponse != null) {
      $result.presenceJoinResponse = presenceJoinResponse;
    }
    if (presenceLeaveResponse != null) {
      $result.presenceLeaveResponse = presenceLeaveResponse;
    }
    if (identityChangedResponse != null) {
      $result.identityChangedResponse = identityChangedResponse;
    }
    if (moveBroadcastResponse != null) {
      $result.moveBroadcastResponse = moveBroadcastResponse;
    }
    if (moveRejectResponse != null) {
      $result.moveRejectResponse = moveRejectResponse;
    }
    if (chatMessageResponse != null) {
      $result.chatMessageResponse = chatMessageResponse;
    }
    if (chatRejectResponse != null) {
      $result.chatRejectResponse = chatRejectResponse;
    }
    if (anonymousChangedResponse != null) {
      $result.anonymousChangedResponse = anonymousChangedResponse;
    }
    if (spriteChangedResponse != null) {
      $result.spriteChangedResponse = spriteChangedResponse;
    }
    if (spriteChangeRejectResponse != null) {
      $result.spriteChangeRejectResponse = spriteChangeRejectResponse;
    }
    if (statusTextBroadcastResponse != null) {
      $result.statusTextBroadcastResponse = statusTextBroadcastResponse;
    }
    if (displayNameChangedResponse != null) {
      $result.displayNameChangedResponse = displayNameChangedResponse;
    }
    if (assetsResponse != null) {
      $result.assetsResponse = assetsResponse;
    }
    if (assetsUpdatedResponse != null) {
      $result.assetsUpdatedResponse = assetsUpdatedResponse;
    }
    if (portalTeleportResponse != null) {
      $result.portalTeleportResponse = portalTeleportResponse;
    }
    if (portalUseRejectResponse != null) {
      $result.portalUseRejectResponse = portalUseRejectResponse;
    }
    if (broadcastMessageResponse != null) {
      $result.broadcastMessageResponse = broadcastMessageResponse;
    }
    if (broadcastRejectResponse != null) {
      $result.broadcastRejectResponse = broadcastRejectResponse;
    }
    if (broadcastCdResponse != null) {
      $result.broadcastCdResponse = broadcastCdResponse;
    }
    if (onlineStatsResponse != null) {
      $result.onlineStatsResponse = onlineStatsResponse;
    }
    if (systemErrorResponse != null) {
      $result.systemErrorResponse = systemErrorResponse;
    }
    if (systemNoticeResponse != null) {
      $result.systemNoticeResponse = systemNoticeResponse;
    }
    if (systemKickedResponse != null) {
      $result.systemKickedResponse = systemKickedResponse;
    }
    if (steamBindSuccessResponse != null) {
      $result.steamBindSuccessResponse = steamBindSuccessResponse;
    }
    if (spriteChangeSuccessResponse != null) {
      $result.spriteChangeSuccessResponse = spriteChangeSuccessResponse;
    }
    if (presenceDeltaResponse != null) {
      $result.presenceDeltaResponse = presenceDeltaResponse;
    }
    return $result;
  }
  LobbyEnvelope._() : super();
  factory LobbyEnvelope.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyEnvelope.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, LobbyEnvelope_Payload> _LobbyEnvelope_PayloadByTag = {
    10 : LobbyEnvelope_Payload.loginRequest,
    11 : LobbyEnvelope_Payload.logoutRequest,
    12 : LobbyEnvelope_Payload.moveRequest,
    13 : LobbyEnvelope_Payload.chatSendRequest,
    14 : LobbyEnvelope_Payload.profileAnonymousChangeRequest,
    15 : LobbyEnvelope_Payload.profileSpriteChangeRequest,
    16 : LobbyEnvelope_Payload.profileStatusTextUpdateRequest,
    17 : LobbyEnvelope_Payload.profileDisplayNameUpdateRequest,
    18 : LobbyEnvelope_Payload.snapshotRequest,
    19 : LobbyEnvelope_Payload.assetsRequest,
    20 : LobbyEnvelope_Payload.broadcastSendRequest,
    21 : LobbyEnvelope_Payload.broadcastCdRequest,
    22 : LobbyEnvelope_Payload.portalUseRequest,
    23 : LobbyEnvelope_Payload.onlineStatsRequest,
    24 : LobbyEnvelope_Payload.profileSteamBindRequest,
    25 : LobbyEnvelope_Payload.enterRequest,
    50 : LobbyEnvelope_Payload.loginSuccessResponse,
    51 : LobbyEnvelope_Payload.loginFailedResponse,
    52 : LobbyEnvelope_Payload.logoutSuccessResponse,
    53 : LobbyEnvelope_Payload.joinSuccessResponse,
    54 : LobbyEnvelope_Payload.snapshotResponse,
    55 : LobbyEnvelope_Payload.presenceJoinResponse,
    56 : LobbyEnvelope_Payload.presenceLeaveResponse,
    57 : LobbyEnvelope_Payload.identityChangedResponse,
    58 : LobbyEnvelope_Payload.moveBroadcastResponse,
    59 : LobbyEnvelope_Payload.moveRejectResponse,
    60 : LobbyEnvelope_Payload.chatMessageResponse,
    61 : LobbyEnvelope_Payload.chatRejectResponse,
    62 : LobbyEnvelope_Payload.anonymousChangedResponse,
    63 : LobbyEnvelope_Payload.spriteChangedResponse,
    64 : LobbyEnvelope_Payload.spriteChangeRejectResponse,
    65 : LobbyEnvelope_Payload.statusTextBroadcastResponse,
    66 : LobbyEnvelope_Payload.displayNameChangedResponse,
    67 : LobbyEnvelope_Payload.assetsResponse,
    68 : LobbyEnvelope_Payload.assetsUpdatedResponse,
    69 : LobbyEnvelope_Payload.portalTeleportResponse,
    70 : LobbyEnvelope_Payload.portalUseRejectResponse,
    71 : LobbyEnvelope_Payload.broadcastMessageResponse,
    72 : LobbyEnvelope_Payload.broadcastRejectResponse,
    73 : LobbyEnvelope_Payload.broadcastCdResponse,
    74 : LobbyEnvelope_Payload.onlineStatsResponse,
    75 : LobbyEnvelope_Payload.systemErrorResponse,
    76 : LobbyEnvelope_Payload.systemNoticeResponse,
    77 : LobbyEnvelope_Payload.systemKickedResponse,
    78 : LobbyEnvelope_Payload.steamBindSuccessResponse,
    79 : LobbyEnvelope_Payload.spriteChangeSuccessResponse,
    80 : LobbyEnvelope_Payload.presenceDeltaResponse,
    0 : LobbyEnvelope_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyEnvelope', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80])
    ..a<$core.int>(1, _omitFieldNames ? '' : 'v', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'type')
    ..aInt64(3, _omitFieldNames ? '' : 'ts')
    ..aOS(4, _omitFieldNames ? '' : 'traceId')
    ..aOM<LoginRequest>(10, _omitFieldNames ? '' : 'loginRequest', subBuilder: LoginRequest.create)
    ..aOM<LogoutRequest>(11, _omitFieldNames ? '' : 'logoutRequest', subBuilder: LogoutRequest.create)
    ..aOM<MoveRequest>(12, _omitFieldNames ? '' : 'moveRequest', subBuilder: MoveRequest.create)
    ..aOM<ChatSendRequest>(13, _omitFieldNames ? '' : 'chatSendRequest', subBuilder: ChatSendRequest.create)
    ..aOM<ProfileAnonymousChangeRequest>(14, _omitFieldNames ? '' : 'profileAnonymousChangeRequest', subBuilder: ProfileAnonymousChangeRequest.create)
    ..aOM<ProfileSpriteChangeRequest>(15, _omitFieldNames ? '' : 'profileSpriteChangeRequest', subBuilder: ProfileSpriteChangeRequest.create)
    ..aOM<ProfileStatusTextUpdateRequest>(16, _omitFieldNames ? '' : 'profileStatusTextUpdateRequest', subBuilder: ProfileStatusTextUpdateRequest.create)
    ..aOM<ProfileDisplayNameUpdateRequest>(17, _omitFieldNames ? '' : 'profileDisplayNameUpdateRequest', subBuilder: ProfileDisplayNameUpdateRequest.create)
    ..aOM<SnapshotRequest>(18, _omitFieldNames ? '' : 'snapshotRequest', subBuilder: SnapshotRequest.create)
    ..aOM<AssetsRequest>(19, _omitFieldNames ? '' : 'assetsRequest', subBuilder: AssetsRequest.create)
    ..aOM<BroadcastSendRequest>(20, _omitFieldNames ? '' : 'broadcastSendRequest', subBuilder: BroadcastSendRequest.create)
    ..aOM<BroadcastCDRequest>(21, _omitFieldNames ? '' : 'broadcastCdRequest', subBuilder: BroadcastCDRequest.create)
    ..aOM<PortalUseRequest>(22, _omitFieldNames ? '' : 'portalUseRequest', subBuilder: PortalUseRequest.create)
    ..aOM<OnlineStatsRequest>(23, _omitFieldNames ? '' : 'onlineStatsRequest', subBuilder: OnlineStatsRequest.create)
    ..aOM<ProfileSteamBindRequest>(24, _omitFieldNames ? '' : 'profileSteamBindRequest', subBuilder: ProfileSteamBindRequest.create)
    ..aOM<EnterRequest>(25, _omitFieldNames ? '' : 'enterRequest', subBuilder: EnterRequest.create)
    ..aOM<LoginSuccessResponse>(50, _omitFieldNames ? '' : 'loginSuccessResponse', subBuilder: LoginSuccessResponse.create)
    ..aOM<LoginFailedResponse>(51, _omitFieldNames ? '' : 'loginFailedResponse', subBuilder: LoginFailedResponse.create)
    ..aOM<LogoutSuccessResponse>(52, _omitFieldNames ? '' : 'logoutSuccessResponse', subBuilder: LogoutSuccessResponse.create)
    ..aOM<JoinSuccessResponse>(53, _omitFieldNames ? '' : 'joinSuccessResponse', subBuilder: JoinSuccessResponse.create)
    ..aOM<SnapshotResponse>(54, _omitFieldNames ? '' : 'snapshotResponse', subBuilder: SnapshotResponse.create)
    ..aOM<PresenceJoinResponse>(55, _omitFieldNames ? '' : 'presenceJoinResponse', subBuilder: PresenceJoinResponse.create)
    ..aOM<PresenceLeaveResponse>(56, _omitFieldNames ? '' : 'presenceLeaveResponse', subBuilder: PresenceLeaveResponse.create)
    ..aOM<IdentityChangedResponse>(57, _omitFieldNames ? '' : 'identityChangedResponse', subBuilder: IdentityChangedResponse.create)
    ..aOM<MoveBroadcastResponse>(58, _omitFieldNames ? '' : 'moveBroadcastResponse', subBuilder: MoveBroadcastResponse.create)
    ..aOM<MoveRejectResponse>(59, _omitFieldNames ? '' : 'moveRejectResponse', subBuilder: MoveRejectResponse.create)
    ..aOM<ChatMessageResponse>(60, _omitFieldNames ? '' : 'chatMessageResponse', subBuilder: ChatMessageResponse.create)
    ..aOM<ChatRejectResponse>(61, _omitFieldNames ? '' : 'chatRejectResponse', subBuilder: ChatRejectResponse.create)
    ..aOM<AnonymousChangedResponse>(62, _omitFieldNames ? '' : 'anonymousChangedResponse', subBuilder: AnonymousChangedResponse.create)
    ..aOM<SpriteChangedResponse>(63, _omitFieldNames ? '' : 'spriteChangedResponse', subBuilder: SpriteChangedResponse.create)
    ..aOM<SpriteChangeRejectResponse>(64, _omitFieldNames ? '' : 'spriteChangeRejectResponse', subBuilder: SpriteChangeRejectResponse.create)
    ..aOM<StatusTextBroadcastResponse>(65, _omitFieldNames ? '' : 'statusTextBroadcastResponse', subBuilder: StatusTextBroadcastResponse.create)
    ..aOM<DisplayNameChangedResponse>(66, _omitFieldNames ? '' : 'displayNameChangedResponse', subBuilder: DisplayNameChangedResponse.create)
    ..aOM<AssetsResponse>(67, _omitFieldNames ? '' : 'assetsResponse', subBuilder: AssetsResponse.create)
    ..aOM<AssetsUpdatedResponse>(68, _omitFieldNames ? '' : 'assetsUpdatedResponse', subBuilder: AssetsUpdatedResponse.create)
    ..aOM<PortalTeleportResponse>(69, _omitFieldNames ? '' : 'portalTeleportResponse', subBuilder: PortalTeleportResponse.create)
    ..aOM<PortalUseRejectResponse>(70, _omitFieldNames ? '' : 'portalUseRejectResponse', subBuilder: PortalUseRejectResponse.create)
    ..aOM<BroadcastMessageResponse>(71, _omitFieldNames ? '' : 'broadcastMessageResponse', subBuilder: BroadcastMessageResponse.create)
    ..aOM<BroadcastRejectResponse>(72, _omitFieldNames ? '' : 'broadcastRejectResponse', subBuilder: BroadcastRejectResponse.create)
    ..aOM<BroadcastCDResponse>(73, _omitFieldNames ? '' : 'broadcastCdResponse', subBuilder: BroadcastCDResponse.create)
    ..aOM<OnlineStatsResponse>(74, _omitFieldNames ? '' : 'onlineStatsResponse', subBuilder: OnlineStatsResponse.create)
    ..aOM<SystemErrorResponse>(75, _omitFieldNames ? '' : 'systemErrorResponse', subBuilder: SystemErrorResponse.create)
    ..aOM<SystemNoticeResponse>(76, _omitFieldNames ? '' : 'systemNoticeResponse', subBuilder: SystemNoticeResponse.create)
    ..aOM<SystemKickedResponse>(77, _omitFieldNames ? '' : 'systemKickedResponse', subBuilder: SystemKickedResponse.create)
    ..aOM<SteamBindSuccessResponse>(78, _omitFieldNames ? '' : 'steamBindSuccessResponse', subBuilder: SteamBindSuccessResponse.create)
    ..aOM<SpriteChangeSuccessResponse>(79, _omitFieldNames ? '' : 'spriteChangeSuccessResponse', subBuilder: SpriteChangeSuccessResponse.create)
    ..aOM<PresenceDeltaResponse>(80, _omitFieldNames ? '' : 'presenceDeltaResponse', subBuilder: PresenceDeltaResponse.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyEnvelope clone() => LobbyEnvelope()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyEnvelope copyWith(void Function(LobbyEnvelope) updates) => super.copyWith((message) => updates(message as LobbyEnvelope)) as LobbyEnvelope;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyEnvelope create() => LobbyEnvelope._();
  LobbyEnvelope createEmptyInstance() => create();
  static $pb.PbList<LobbyEnvelope> createRepeated() => $pb.PbList<LobbyEnvelope>();
  @$core.pragma('dart2js:noInline')
  static LobbyEnvelope getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyEnvelope>(create);
  static LobbyEnvelope? _defaultInstance;

  LobbyEnvelope_Payload whichPayload() => _LobbyEnvelope_PayloadByTag[$_whichOneof(0)]!;
  void clearPayload() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.int get v => $_getIZ(0);
  @$pb.TagNumber(1)
  set v($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasV() => $_has(0);
  @$pb.TagNumber(1)
  void clearV() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get type => $_getSZ(1);
  @$pb.TagNumber(2)
  set type($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get ts => $_getI64(2);
  @$pb.TagNumber(3)
  set ts($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTs() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get traceId => $_getSZ(3);
  @$pb.TagNumber(4)
  set traceId($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTraceId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTraceId() => clearField(4);

  /// 客户端 -> 服务端
  @$pb.TagNumber(10)
  LoginRequest get loginRequest => $_getN(4);
  @$pb.TagNumber(10)
  set loginRequest(LoginRequest v) { setField(10, v); }
  @$pb.TagNumber(10)
  $core.bool hasLoginRequest() => $_has(4);
  @$pb.TagNumber(10)
  void clearLoginRequest() => clearField(10);
  @$pb.TagNumber(10)
  LoginRequest ensureLoginRequest() => $_ensure(4);

  @$pb.TagNumber(11)
  LogoutRequest get logoutRequest => $_getN(5);
  @$pb.TagNumber(11)
  set logoutRequest(LogoutRequest v) { setField(11, v); }
  @$pb.TagNumber(11)
  $core.bool hasLogoutRequest() => $_has(5);
  @$pb.TagNumber(11)
  void clearLogoutRequest() => clearField(11);
  @$pb.TagNumber(11)
  LogoutRequest ensureLogoutRequest() => $_ensure(5);

  @$pb.TagNumber(12)
  MoveRequest get moveRequest => $_getN(6);
  @$pb.TagNumber(12)
  set moveRequest(MoveRequest v) { setField(12, v); }
  @$pb.TagNumber(12)
  $core.bool hasMoveRequest() => $_has(6);
  @$pb.TagNumber(12)
  void clearMoveRequest() => clearField(12);
  @$pb.TagNumber(12)
  MoveRequest ensureMoveRequest() => $_ensure(6);

  @$pb.TagNumber(13)
  ChatSendRequest get chatSendRequest => $_getN(7);
  @$pb.TagNumber(13)
  set chatSendRequest(ChatSendRequest v) { setField(13, v); }
  @$pb.TagNumber(13)
  $core.bool hasChatSendRequest() => $_has(7);
  @$pb.TagNumber(13)
  void clearChatSendRequest() => clearField(13);
  @$pb.TagNumber(13)
  ChatSendRequest ensureChatSendRequest() => $_ensure(7);

  @$pb.TagNumber(14)
  ProfileAnonymousChangeRequest get profileAnonymousChangeRequest => $_getN(8);
  @$pb.TagNumber(14)
  set profileAnonymousChangeRequest(ProfileAnonymousChangeRequest v) { setField(14, v); }
  @$pb.TagNumber(14)
  $core.bool hasProfileAnonymousChangeRequest() => $_has(8);
  @$pb.TagNumber(14)
  void clearProfileAnonymousChangeRequest() => clearField(14);
  @$pb.TagNumber(14)
  ProfileAnonymousChangeRequest ensureProfileAnonymousChangeRequest() => $_ensure(8);

  @$pb.TagNumber(15)
  ProfileSpriteChangeRequest get profileSpriteChangeRequest => $_getN(9);
  @$pb.TagNumber(15)
  set profileSpriteChangeRequest(ProfileSpriteChangeRequest v) { setField(15, v); }
  @$pb.TagNumber(15)
  $core.bool hasProfileSpriteChangeRequest() => $_has(9);
  @$pb.TagNumber(15)
  void clearProfileSpriteChangeRequest() => clearField(15);
  @$pb.TagNumber(15)
  ProfileSpriteChangeRequest ensureProfileSpriteChangeRequest() => $_ensure(9);

  @$pb.TagNumber(16)
  ProfileStatusTextUpdateRequest get profileStatusTextUpdateRequest => $_getN(10);
  @$pb.TagNumber(16)
  set profileStatusTextUpdateRequest(ProfileStatusTextUpdateRequest v) { setField(16, v); }
  @$pb.TagNumber(16)
  $core.bool hasProfileStatusTextUpdateRequest() => $_has(10);
  @$pb.TagNumber(16)
  void clearProfileStatusTextUpdateRequest() => clearField(16);
  @$pb.TagNumber(16)
  ProfileStatusTextUpdateRequest ensureProfileStatusTextUpdateRequest() => $_ensure(10);

  @$pb.TagNumber(17)
  ProfileDisplayNameUpdateRequest get profileDisplayNameUpdateRequest => $_getN(11);
  @$pb.TagNumber(17)
  set profileDisplayNameUpdateRequest(ProfileDisplayNameUpdateRequest v) { setField(17, v); }
  @$pb.TagNumber(17)
  $core.bool hasProfileDisplayNameUpdateRequest() => $_has(11);
  @$pb.TagNumber(17)
  void clearProfileDisplayNameUpdateRequest() => clearField(17);
  @$pb.TagNumber(17)
  ProfileDisplayNameUpdateRequest ensureProfileDisplayNameUpdateRequest() => $_ensure(11);

  @$pb.TagNumber(18)
  SnapshotRequest get snapshotRequest => $_getN(12);
  @$pb.TagNumber(18)
  set snapshotRequest(SnapshotRequest v) { setField(18, v); }
  @$pb.TagNumber(18)
  $core.bool hasSnapshotRequest() => $_has(12);
  @$pb.TagNumber(18)
  void clearSnapshotRequest() => clearField(18);
  @$pb.TagNumber(18)
  SnapshotRequest ensureSnapshotRequest() => $_ensure(12);

  @$pb.TagNumber(19)
  AssetsRequest get assetsRequest => $_getN(13);
  @$pb.TagNumber(19)
  set assetsRequest(AssetsRequest v) { setField(19, v); }
  @$pb.TagNumber(19)
  $core.bool hasAssetsRequest() => $_has(13);
  @$pb.TagNumber(19)
  void clearAssetsRequest() => clearField(19);
  @$pb.TagNumber(19)
  AssetsRequest ensureAssetsRequest() => $_ensure(13);

  @$pb.TagNumber(20)
  BroadcastSendRequest get broadcastSendRequest => $_getN(14);
  @$pb.TagNumber(20)
  set broadcastSendRequest(BroadcastSendRequest v) { setField(20, v); }
  @$pb.TagNumber(20)
  $core.bool hasBroadcastSendRequest() => $_has(14);
  @$pb.TagNumber(20)
  void clearBroadcastSendRequest() => clearField(20);
  @$pb.TagNumber(20)
  BroadcastSendRequest ensureBroadcastSendRequest() => $_ensure(14);

  @$pb.TagNumber(21)
  BroadcastCDRequest get broadcastCdRequest => $_getN(15);
  @$pb.TagNumber(21)
  set broadcastCdRequest(BroadcastCDRequest v) { setField(21, v); }
  @$pb.TagNumber(21)
  $core.bool hasBroadcastCdRequest() => $_has(15);
  @$pb.TagNumber(21)
  void clearBroadcastCdRequest() => clearField(21);
  @$pb.TagNumber(21)
  BroadcastCDRequest ensureBroadcastCdRequest() => $_ensure(15);

  @$pb.TagNumber(22)
  PortalUseRequest get portalUseRequest => $_getN(16);
  @$pb.TagNumber(22)
  set portalUseRequest(PortalUseRequest v) { setField(22, v); }
  @$pb.TagNumber(22)
  $core.bool hasPortalUseRequest() => $_has(16);
  @$pb.TagNumber(22)
  void clearPortalUseRequest() => clearField(22);
  @$pb.TagNumber(22)
  PortalUseRequest ensurePortalUseRequest() => $_ensure(16);

  @$pb.TagNumber(23)
  OnlineStatsRequest get onlineStatsRequest => $_getN(17);
  @$pb.TagNumber(23)
  set onlineStatsRequest(OnlineStatsRequest v) { setField(23, v); }
  @$pb.TagNumber(23)
  $core.bool hasOnlineStatsRequest() => $_has(17);
  @$pb.TagNumber(23)
  void clearOnlineStatsRequest() => clearField(23);
  @$pb.TagNumber(23)
  OnlineStatsRequest ensureOnlineStatsRequest() => $_ensure(17);

  @$pb.TagNumber(24)
  ProfileSteamBindRequest get profileSteamBindRequest => $_getN(18);
  @$pb.TagNumber(24)
  set profileSteamBindRequest(ProfileSteamBindRequest v) { setField(24, v); }
  @$pb.TagNumber(24)
  $core.bool hasProfileSteamBindRequest() => $_has(18);
  @$pb.TagNumber(24)
  void clearProfileSteamBindRequest() => clearField(24);
  @$pb.TagNumber(24)
  ProfileSteamBindRequest ensureProfileSteamBindRequest() => $_ensure(18);

  @$pb.TagNumber(25)
  EnterRequest get enterRequest => $_getN(19);
  @$pb.TagNumber(25)
  set enterRequest(EnterRequest v) { setField(25, v); }
  @$pb.TagNumber(25)
  $core.bool hasEnterRequest() => $_has(19);
  @$pb.TagNumber(25)
  void clearEnterRequest() => clearField(25);
  @$pb.TagNumber(25)
  EnterRequest ensureEnterRequest() => $_ensure(19);

  /// 服务端 -> 客户端
  @$pb.TagNumber(50)
  LoginSuccessResponse get loginSuccessResponse => $_getN(20);
  @$pb.TagNumber(50)
  set loginSuccessResponse(LoginSuccessResponse v) { setField(50, v); }
  @$pb.TagNumber(50)
  $core.bool hasLoginSuccessResponse() => $_has(20);
  @$pb.TagNumber(50)
  void clearLoginSuccessResponse() => clearField(50);
  @$pb.TagNumber(50)
  LoginSuccessResponse ensureLoginSuccessResponse() => $_ensure(20);

  @$pb.TagNumber(51)
  LoginFailedResponse get loginFailedResponse => $_getN(21);
  @$pb.TagNumber(51)
  set loginFailedResponse(LoginFailedResponse v) { setField(51, v); }
  @$pb.TagNumber(51)
  $core.bool hasLoginFailedResponse() => $_has(21);
  @$pb.TagNumber(51)
  void clearLoginFailedResponse() => clearField(51);
  @$pb.TagNumber(51)
  LoginFailedResponse ensureLoginFailedResponse() => $_ensure(21);

  @$pb.TagNumber(52)
  LogoutSuccessResponse get logoutSuccessResponse => $_getN(22);
  @$pb.TagNumber(52)
  set logoutSuccessResponse(LogoutSuccessResponse v) { setField(52, v); }
  @$pb.TagNumber(52)
  $core.bool hasLogoutSuccessResponse() => $_has(22);
  @$pb.TagNumber(52)
  void clearLogoutSuccessResponse() => clearField(52);
  @$pb.TagNumber(52)
  LogoutSuccessResponse ensureLogoutSuccessResponse() => $_ensure(22);

  @$pb.TagNumber(53)
  JoinSuccessResponse get joinSuccessResponse => $_getN(23);
  @$pb.TagNumber(53)
  set joinSuccessResponse(JoinSuccessResponse v) { setField(53, v); }
  @$pb.TagNumber(53)
  $core.bool hasJoinSuccessResponse() => $_has(23);
  @$pb.TagNumber(53)
  void clearJoinSuccessResponse() => clearField(53);
  @$pb.TagNumber(53)
  JoinSuccessResponse ensureJoinSuccessResponse() => $_ensure(23);

  @$pb.TagNumber(54)
  SnapshotResponse get snapshotResponse => $_getN(24);
  @$pb.TagNumber(54)
  set snapshotResponse(SnapshotResponse v) { setField(54, v); }
  @$pb.TagNumber(54)
  $core.bool hasSnapshotResponse() => $_has(24);
  @$pb.TagNumber(54)
  void clearSnapshotResponse() => clearField(54);
  @$pb.TagNumber(54)
  SnapshotResponse ensureSnapshotResponse() => $_ensure(24);

  @$pb.TagNumber(55)
  PresenceJoinResponse get presenceJoinResponse => $_getN(25);
  @$pb.TagNumber(55)
  set presenceJoinResponse(PresenceJoinResponse v) { setField(55, v); }
  @$pb.TagNumber(55)
  $core.bool hasPresenceJoinResponse() => $_has(25);
  @$pb.TagNumber(55)
  void clearPresenceJoinResponse() => clearField(55);
  @$pb.TagNumber(55)
  PresenceJoinResponse ensurePresenceJoinResponse() => $_ensure(25);

  @$pb.TagNumber(56)
  PresenceLeaveResponse get presenceLeaveResponse => $_getN(26);
  @$pb.TagNumber(56)
  set presenceLeaveResponse(PresenceLeaveResponse v) { setField(56, v); }
  @$pb.TagNumber(56)
  $core.bool hasPresenceLeaveResponse() => $_has(26);
  @$pb.TagNumber(56)
  void clearPresenceLeaveResponse() => clearField(56);
  @$pb.TagNumber(56)
  PresenceLeaveResponse ensurePresenceLeaveResponse() => $_ensure(26);

  @$pb.TagNumber(57)
  IdentityChangedResponse get identityChangedResponse => $_getN(27);
  @$pb.TagNumber(57)
  set identityChangedResponse(IdentityChangedResponse v) { setField(57, v); }
  @$pb.TagNumber(57)
  $core.bool hasIdentityChangedResponse() => $_has(27);
  @$pb.TagNumber(57)
  void clearIdentityChangedResponse() => clearField(57);
  @$pb.TagNumber(57)
  IdentityChangedResponse ensureIdentityChangedResponse() => $_ensure(27);

  @$pb.TagNumber(58)
  MoveBroadcastResponse get moveBroadcastResponse => $_getN(28);
  @$pb.TagNumber(58)
  set moveBroadcastResponse(MoveBroadcastResponse v) { setField(58, v); }
  @$pb.TagNumber(58)
  $core.bool hasMoveBroadcastResponse() => $_has(28);
  @$pb.TagNumber(58)
  void clearMoveBroadcastResponse() => clearField(58);
  @$pb.TagNumber(58)
  MoveBroadcastResponse ensureMoveBroadcastResponse() => $_ensure(28);

  @$pb.TagNumber(59)
  MoveRejectResponse get moveRejectResponse => $_getN(29);
  @$pb.TagNumber(59)
  set moveRejectResponse(MoveRejectResponse v) { setField(59, v); }
  @$pb.TagNumber(59)
  $core.bool hasMoveRejectResponse() => $_has(29);
  @$pb.TagNumber(59)
  void clearMoveRejectResponse() => clearField(59);
  @$pb.TagNumber(59)
  MoveRejectResponse ensureMoveRejectResponse() => $_ensure(29);

  @$pb.TagNumber(60)
  ChatMessageResponse get chatMessageResponse => $_getN(30);
  @$pb.TagNumber(60)
  set chatMessageResponse(ChatMessageResponse v) { setField(60, v); }
  @$pb.TagNumber(60)
  $core.bool hasChatMessageResponse() => $_has(30);
  @$pb.TagNumber(60)
  void clearChatMessageResponse() => clearField(60);
  @$pb.TagNumber(60)
  ChatMessageResponse ensureChatMessageResponse() => $_ensure(30);

  @$pb.TagNumber(61)
  ChatRejectResponse get chatRejectResponse => $_getN(31);
  @$pb.TagNumber(61)
  set chatRejectResponse(ChatRejectResponse v) { setField(61, v); }
  @$pb.TagNumber(61)
  $core.bool hasChatRejectResponse() => $_has(31);
  @$pb.TagNumber(61)
  void clearChatRejectResponse() => clearField(61);
  @$pb.TagNumber(61)
  ChatRejectResponse ensureChatRejectResponse() => $_ensure(31);

  @$pb.TagNumber(62)
  AnonymousChangedResponse get anonymousChangedResponse => $_getN(32);
  @$pb.TagNumber(62)
  set anonymousChangedResponse(AnonymousChangedResponse v) { setField(62, v); }
  @$pb.TagNumber(62)
  $core.bool hasAnonymousChangedResponse() => $_has(32);
  @$pb.TagNumber(62)
  void clearAnonymousChangedResponse() => clearField(62);
  @$pb.TagNumber(62)
  AnonymousChangedResponse ensureAnonymousChangedResponse() => $_ensure(32);

  @$pb.TagNumber(63)
  SpriteChangedResponse get spriteChangedResponse => $_getN(33);
  @$pb.TagNumber(63)
  set spriteChangedResponse(SpriteChangedResponse v) { setField(63, v); }
  @$pb.TagNumber(63)
  $core.bool hasSpriteChangedResponse() => $_has(33);
  @$pb.TagNumber(63)
  void clearSpriteChangedResponse() => clearField(63);
  @$pb.TagNumber(63)
  SpriteChangedResponse ensureSpriteChangedResponse() => $_ensure(33);

  @$pb.TagNumber(64)
  SpriteChangeRejectResponse get spriteChangeRejectResponse => $_getN(34);
  @$pb.TagNumber(64)
  set spriteChangeRejectResponse(SpriteChangeRejectResponse v) { setField(64, v); }
  @$pb.TagNumber(64)
  $core.bool hasSpriteChangeRejectResponse() => $_has(34);
  @$pb.TagNumber(64)
  void clearSpriteChangeRejectResponse() => clearField(64);
  @$pb.TagNumber(64)
  SpriteChangeRejectResponse ensureSpriteChangeRejectResponse() => $_ensure(34);

  @$pb.TagNumber(65)
  StatusTextBroadcastResponse get statusTextBroadcastResponse => $_getN(35);
  @$pb.TagNumber(65)
  set statusTextBroadcastResponse(StatusTextBroadcastResponse v) { setField(65, v); }
  @$pb.TagNumber(65)
  $core.bool hasStatusTextBroadcastResponse() => $_has(35);
  @$pb.TagNumber(65)
  void clearStatusTextBroadcastResponse() => clearField(65);
  @$pb.TagNumber(65)
  StatusTextBroadcastResponse ensureStatusTextBroadcastResponse() => $_ensure(35);

  @$pb.TagNumber(66)
  DisplayNameChangedResponse get displayNameChangedResponse => $_getN(36);
  @$pb.TagNumber(66)
  set displayNameChangedResponse(DisplayNameChangedResponse v) { setField(66, v); }
  @$pb.TagNumber(66)
  $core.bool hasDisplayNameChangedResponse() => $_has(36);
  @$pb.TagNumber(66)
  void clearDisplayNameChangedResponse() => clearField(66);
  @$pb.TagNumber(66)
  DisplayNameChangedResponse ensureDisplayNameChangedResponse() => $_ensure(36);

  @$pb.TagNumber(67)
  AssetsResponse get assetsResponse => $_getN(37);
  @$pb.TagNumber(67)
  set assetsResponse(AssetsResponse v) { setField(67, v); }
  @$pb.TagNumber(67)
  $core.bool hasAssetsResponse() => $_has(37);
  @$pb.TagNumber(67)
  void clearAssetsResponse() => clearField(67);
  @$pb.TagNumber(67)
  AssetsResponse ensureAssetsResponse() => $_ensure(37);

  @$pb.TagNumber(68)
  AssetsUpdatedResponse get assetsUpdatedResponse => $_getN(38);
  @$pb.TagNumber(68)
  set assetsUpdatedResponse(AssetsUpdatedResponse v) { setField(68, v); }
  @$pb.TagNumber(68)
  $core.bool hasAssetsUpdatedResponse() => $_has(38);
  @$pb.TagNumber(68)
  void clearAssetsUpdatedResponse() => clearField(68);
  @$pb.TagNumber(68)
  AssetsUpdatedResponse ensureAssetsUpdatedResponse() => $_ensure(38);

  @$pb.TagNumber(69)
  PortalTeleportResponse get portalTeleportResponse => $_getN(39);
  @$pb.TagNumber(69)
  set portalTeleportResponse(PortalTeleportResponse v) { setField(69, v); }
  @$pb.TagNumber(69)
  $core.bool hasPortalTeleportResponse() => $_has(39);
  @$pb.TagNumber(69)
  void clearPortalTeleportResponse() => clearField(69);
  @$pb.TagNumber(69)
  PortalTeleportResponse ensurePortalTeleportResponse() => $_ensure(39);

  @$pb.TagNumber(70)
  PortalUseRejectResponse get portalUseRejectResponse => $_getN(40);
  @$pb.TagNumber(70)
  set portalUseRejectResponse(PortalUseRejectResponse v) { setField(70, v); }
  @$pb.TagNumber(70)
  $core.bool hasPortalUseRejectResponse() => $_has(40);
  @$pb.TagNumber(70)
  void clearPortalUseRejectResponse() => clearField(70);
  @$pb.TagNumber(70)
  PortalUseRejectResponse ensurePortalUseRejectResponse() => $_ensure(40);

  @$pb.TagNumber(71)
  BroadcastMessageResponse get broadcastMessageResponse => $_getN(41);
  @$pb.TagNumber(71)
  set broadcastMessageResponse(BroadcastMessageResponse v) { setField(71, v); }
  @$pb.TagNumber(71)
  $core.bool hasBroadcastMessageResponse() => $_has(41);
  @$pb.TagNumber(71)
  void clearBroadcastMessageResponse() => clearField(71);
  @$pb.TagNumber(71)
  BroadcastMessageResponse ensureBroadcastMessageResponse() => $_ensure(41);

  @$pb.TagNumber(72)
  BroadcastRejectResponse get broadcastRejectResponse => $_getN(42);
  @$pb.TagNumber(72)
  set broadcastRejectResponse(BroadcastRejectResponse v) { setField(72, v); }
  @$pb.TagNumber(72)
  $core.bool hasBroadcastRejectResponse() => $_has(42);
  @$pb.TagNumber(72)
  void clearBroadcastRejectResponse() => clearField(72);
  @$pb.TagNumber(72)
  BroadcastRejectResponse ensureBroadcastRejectResponse() => $_ensure(42);

  @$pb.TagNumber(73)
  BroadcastCDResponse get broadcastCdResponse => $_getN(43);
  @$pb.TagNumber(73)
  set broadcastCdResponse(BroadcastCDResponse v) { setField(73, v); }
  @$pb.TagNumber(73)
  $core.bool hasBroadcastCdResponse() => $_has(43);
  @$pb.TagNumber(73)
  void clearBroadcastCdResponse() => clearField(73);
  @$pb.TagNumber(73)
  BroadcastCDResponse ensureBroadcastCdResponse() => $_ensure(43);

  @$pb.TagNumber(74)
  OnlineStatsResponse get onlineStatsResponse => $_getN(44);
  @$pb.TagNumber(74)
  set onlineStatsResponse(OnlineStatsResponse v) { setField(74, v); }
  @$pb.TagNumber(74)
  $core.bool hasOnlineStatsResponse() => $_has(44);
  @$pb.TagNumber(74)
  void clearOnlineStatsResponse() => clearField(74);
  @$pb.TagNumber(74)
  OnlineStatsResponse ensureOnlineStatsResponse() => $_ensure(44);

  @$pb.TagNumber(75)
  SystemErrorResponse get systemErrorResponse => $_getN(45);
  @$pb.TagNumber(75)
  set systemErrorResponse(SystemErrorResponse v) { setField(75, v); }
  @$pb.TagNumber(75)
  $core.bool hasSystemErrorResponse() => $_has(45);
  @$pb.TagNumber(75)
  void clearSystemErrorResponse() => clearField(75);
  @$pb.TagNumber(75)
  SystemErrorResponse ensureSystemErrorResponse() => $_ensure(45);

  @$pb.TagNumber(76)
  SystemNoticeResponse get systemNoticeResponse => $_getN(46);
  @$pb.TagNumber(76)
  set systemNoticeResponse(SystemNoticeResponse v) { setField(76, v); }
  @$pb.TagNumber(76)
  $core.bool hasSystemNoticeResponse() => $_has(46);
  @$pb.TagNumber(76)
  void clearSystemNoticeResponse() => clearField(76);
  @$pb.TagNumber(76)
  SystemNoticeResponse ensureSystemNoticeResponse() => $_ensure(46);

  @$pb.TagNumber(77)
  SystemKickedResponse get systemKickedResponse => $_getN(47);
  @$pb.TagNumber(77)
  set systemKickedResponse(SystemKickedResponse v) { setField(77, v); }
  @$pb.TagNumber(77)
  $core.bool hasSystemKickedResponse() => $_has(47);
  @$pb.TagNumber(77)
  void clearSystemKickedResponse() => clearField(77);
  @$pb.TagNumber(77)
  SystemKickedResponse ensureSystemKickedResponse() => $_ensure(47);

  @$pb.TagNumber(78)
  SteamBindSuccessResponse get steamBindSuccessResponse => $_getN(48);
  @$pb.TagNumber(78)
  set steamBindSuccessResponse(SteamBindSuccessResponse v) { setField(78, v); }
  @$pb.TagNumber(78)
  $core.bool hasSteamBindSuccessResponse() => $_has(48);
  @$pb.TagNumber(78)
  void clearSteamBindSuccessResponse() => clearField(78);
  @$pb.TagNumber(78)
  SteamBindSuccessResponse ensureSteamBindSuccessResponse() => $_ensure(48);

  @$pb.TagNumber(79)
  SpriteChangeSuccessResponse get spriteChangeSuccessResponse => $_getN(49);
  @$pb.TagNumber(79)
  set spriteChangeSuccessResponse(SpriteChangeSuccessResponse v) { setField(79, v); }
  @$pb.TagNumber(79)
  $core.bool hasSpriteChangeSuccessResponse() => $_has(49);
  @$pb.TagNumber(79)
  void clearSpriteChangeSuccessResponse() => clearField(79);
  @$pb.TagNumber(79)
  SpriteChangeSuccessResponse ensureSpriteChangeSuccessResponse() => $_ensure(49);

  @$pb.TagNumber(80)
  PresenceDeltaResponse get presenceDeltaResponse => $_getN(50);
  @$pb.TagNumber(80)
  set presenceDeltaResponse(PresenceDeltaResponse v) { setField(80, v); }
  @$pb.TagNumber(80)
  $core.bool hasPresenceDeltaResponse() => $_has(50);
  @$pb.TagNumber(80)
  void clearPresenceDeltaResponse() => clearField(80);
  @$pb.TagNumber(80)
  PresenceDeltaResponse ensurePresenceDeltaResponse() => $_ensure(50);
}

/// LobbyUser 用户信息
class LobbyUser extends $pb.GeneratedMessage {
  factory LobbyUser({
    $core.String? userId,
    $core.String? nickname,
    $core.String? steamName,
    $core.String? spriteId,
    $core.String? avatarUrl,
    $core.double? x,
    $core.double? y,
    $core.String? facing,
    $core.bool? isOnline,
    $core.bool? isAnonymous,
    $core.String? statusText,
    $core.String? lastMessage,
    $core.String? steamId,
    $core.String? businessUserId,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    if (steamName != null) {
      $result.steamName = steamName;
    }
    if (spriteId != null) {
      $result.spriteId = spriteId;
    }
    if (avatarUrl != null) {
      $result.avatarUrl = avatarUrl;
    }
    if (x != null) {
      $result.x = x;
    }
    if (y != null) {
      $result.y = y;
    }
    if (facing != null) {
      $result.facing = facing;
    }
    if (isOnline != null) {
      $result.isOnline = isOnline;
    }
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    if (statusText != null) {
      $result.statusText = statusText;
    }
    if (lastMessage != null) {
      $result.lastMessage = lastMessage;
    }
    if (steamId != null) {
      $result.steamId = steamId;
    }
    if (businessUserId != null) {
      $result.businessUserId = businessUserId;
    }
    return $result;
  }
  LobbyUser._() : super();
  factory LobbyUser.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyUser.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyUser', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..aOS(3, _omitFieldNames ? '' : 'steamName')
    ..aOS(4, _omitFieldNames ? '' : 'spriteId')
    ..aOS(5, _omitFieldNames ? '' : 'avatarUrl')
    ..a<$core.double>(6, _omitFieldNames ? '' : 'x', $pb.PbFieldType.OD)
    ..a<$core.double>(7, _omitFieldNames ? '' : 'y', $pb.PbFieldType.OD)
    ..aOS(8, _omitFieldNames ? '' : 'facing')
    ..aOB(9, _omitFieldNames ? '' : 'isOnline')
    ..aOB(10, _omitFieldNames ? '' : 'isAnonymous')
    ..aOS(11, _omitFieldNames ? '' : 'statusText')
    ..aOS(12, _omitFieldNames ? '' : 'lastMessage')
    ..aOS(13, _omitFieldNames ? '' : 'steamId')
    ..aOS(14, _omitFieldNames ? '' : 'businessUserId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyUser clone() => LobbyUser()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyUser copyWith(void Function(LobbyUser) updates) => super.copyWith((message) => updates(message as LobbyUser)) as LobbyUser;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyUser create() => LobbyUser._();
  LobbyUser createEmptyInstance() => create();
  static $pb.PbList<LobbyUser> createRepeated() => $pb.PbList<LobbyUser>();
  @$core.pragma('dart2js:noInline')
  static LobbyUser getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyUser>(create);
  static LobbyUser? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get steamName => $_getSZ(2);
  @$pb.TagNumber(3)
  set steamName($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSteamName() => $_has(2);
  @$pb.TagNumber(3)
  void clearSteamName() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get spriteId => $_getSZ(3);
  @$pb.TagNumber(4)
  set spriteId($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSpriteId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpriteId() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get avatarUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set avatarUrl($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasAvatarUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvatarUrl() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get x => $_getN(5);
  @$pb.TagNumber(6)
  set x($core.double v) { $_setDouble(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasX() => $_has(5);
  @$pb.TagNumber(6)
  void clearX() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get y => $_getN(6);
  @$pb.TagNumber(7)
  set y($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasY() => $_has(6);
  @$pb.TagNumber(7)
  void clearY() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get facing => $_getSZ(7);
  @$pb.TagNumber(8)
  set facing($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasFacing() => $_has(7);
  @$pb.TagNumber(8)
  void clearFacing() => clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isOnline => $_getBF(8);
  @$pb.TagNumber(9)
  set isOnline($core.bool v) { $_setBool(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasIsOnline() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsOnline() => clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isAnonymous => $_getBF(9);
  @$pb.TagNumber(10)
  set isAnonymous($core.bool v) { $_setBool(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasIsAnonymous() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsAnonymous() => clearField(10);

  @$pb.TagNumber(11)
  $core.String get statusText => $_getSZ(10);
  @$pb.TagNumber(11)
  set statusText($core.String v) { $_setString(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasStatusText() => $_has(10);
  @$pb.TagNumber(11)
  void clearStatusText() => clearField(11);

  @$pb.TagNumber(12)
  $core.String get lastMessage => $_getSZ(11);
  @$pb.TagNumber(12)
  set lastMessage($core.String v) { $_setString(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasLastMessage() => $_has(11);
  @$pb.TagNumber(12)
  void clearLastMessage() => clearField(12);

  @$pb.TagNumber(13)
  $core.String get steamId => $_getSZ(12);
  @$pb.TagNumber(13)
  set steamId($core.String v) { $_setString(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasSteamId() => $_has(12);
  @$pb.TagNumber(13)
  void clearSteamId() => clearField(13);

  @$pb.TagNumber(14)
  $core.String get businessUserId => $_getSZ(13);
  @$pb.TagNumber(14)
  set businessUserId($core.String v) { $_setString(13, v); }
  @$pb.TagNumber(14)
  $core.bool hasBusinessUserId() => $_has(13);
  @$pb.TagNumber(14)
  void clearBusinessUserId() => clearField(14);
}

/// LobbyMessage 聊天消息
class LobbyMessage extends $pb.GeneratedMessage {
  factory LobbyMessage({
    $core.String? messageId,
    $core.String? userId,
    $core.String? nickname,
    $core.String? content,
    $core.String? type,
    $core.bool? isAnonymous,
    $fixnum.Int64? timestamp,
  }) {
    final $result = create();
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    if (content != null) {
      $result.content = content;
    }
    if (type != null) {
      $result.type = type;
    }
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  LobbyMessage._() : super();
  factory LobbyMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyMessage', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'nickname')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aOS(5, _omitFieldNames ? '' : 'type')
    ..aOB(6, _omitFieldNames ? '' : 'isAnonymous')
    ..aInt64(7, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyMessage clone() => LobbyMessage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyMessage copyWith(void Function(LobbyMessage) updates) => super.copyWith((message) => updates(message as LobbyMessage)) as LobbyMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyMessage create() => LobbyMessage._();
  LobbyMessage createEmptyInstance() => create();
  static $pb.PbList<LobbyMessage> createRepeated() => $pb.PbList<LobbyMessage>();
  @$core.pragma('dart2js:noInline')
  static LobbyMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyMessage>(create);
  static LobbyMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get nickname => $_getSZ(2);
  @$pb.TagNumber(3)
  set nickname($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNickname() => $_has(2);
  @$pb.TagNumber(3)
  void clearNickname() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get type => $_getSZ(4);
  @$pb.TagNumber(5)
  set type($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasType() => $_has(4);
  @$pb.TagNumber(5)
  void clearType() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isAnonymous => $_getBF(5);
  @$pb.TagNumber(6)
  set isAnonymous($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsAnonymous() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsAnonymous() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get timestamp => $_getI64(6);
  @$pb.TagNumber(7)
  set timestamp($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasTimestamp() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestamp() => clearField(7);
}

/// LobbyBroadcastMessage 全服广播消息
class LobbyBroadcastMessage extends $pb.GeneratedMessage {
  factory LobbyBroadcastMessage({
    $core.String? messageId,
    $core.String? userId,
    $core.String? nickname,
    $core.String? content,
    $fixnum.Int64? timestamp,
    $core.String? avatarUrl,
  }) {
    final $result = create();
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    if (content != null) {
      $result.content = content;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (avatarUrl != null) {
      $result.avatarUrl = avatarUrl;
    }
    return $result;
  }
  LobbyBroadcastMessage._() : super();
  factory LobbyBroadcastMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyBroadcastMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyBroadcastMessage', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'nickname')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aInt64(5, _omitFieldNames ? '' : 'timestamp')
    ..aOS(6, _omitFieldNames ? '' : 'avatarUrl')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyBroadcastMessage clone() => LobbyBroadcastMessage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyBroadcastMessage copyWith(void Function(LobbyBroadcastMessage) updates) => super.copyWith((message) => updates(message as LobbyBroadcastMessage)) as LobbyBroadcastMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyBroadcastMessage create() => LobbyBroadcastMessage._();
  LobbyBroadcastMessage createEmptyInstance() => create();
  static $pb.PbList<LobbyBroadcastMessage> createRepeated() => $pb.PbList<LobbyBroadcastMessage>();
  @$core.pragma('dart2js:noInline')
  static LobbyBroadcastMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyBroadcastMessage>(create);
  static LobbyBroadcastMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get nickname => $_getSZ(2);
  @$pb.TagNumber(3)
  set nickname($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNickname() => $_has(2);
  @$pb.TagNumber(3)
  void clearNickname() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestamp => $_getI64(4);
  @$pb.TagNumber(5)
  set timestamp($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTimestamp() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestamp() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get avatarUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set avatarUrl($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasAvatarUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearAvatarUrl() => clearField(6);
}

/// LobbyMapConfig 地图配置
class LobbyMapConfig extends $pb.GeneratedMessage {
  factory LobbyMapConfig({
    $core.String? mapId,
    $core.String? label,
    $core.String? backgroundUrl,
    $core.double? width,
    $core.double? height,
    $core.Iterable<LobbyWalkableArea>? walkableAreas,
    $core.Iterable<LobbyPortal>? portals,
    $core.bool? isDefault,
  }) {
    final $result = create();
    if (mapId != null) {
      $result.mapId = mapId;
    }
    if (label != null) {
      $result.label = label;
    }
    if (backgroundUrl != null) {
      $result.backgroundUrl = backgroundUrl;
    }
    if (width != null) {
      $result.width = width;
    }
    if (height != null) {
      $result.height = height;
    }
    if (walkableAreas != null) {
      $result.walkableAreas.addAll(walkableAreas);
    }
    if (portals != null) {
      $result.portals.addAll(portals);
    }
    if (isDefault != null) {
      $result.isDefault = isDefault;
    }
    return $result;
  }
  LobbyMapConfig._() : super();
  factory LobbyMapConfig.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyMapConfig.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyMapConfig', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mapId')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'backgroundUrl')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'width', $pb.PbFieldType.OD)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'height', $pb.PbFieldType.OD)
    ..pc<LobbyWalkableArea>(6, _omitFieldNames ? '' : 'walkableAreas', $pb.PbFieldType.PM, subBuilder: LobbyWalkableArea.create)
    ..pc<LobbyPortal>(7, _omitFieldNames ? '' : 'portals', $pb.PbFieldType.PM, subBuilder: LobbyPortal.create)
    ..aOB(8, _omitFieldNames ? '' : 'isDefault')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyMapConfig clone() => LobbyMapConfig()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyMapConfig copyWith(void Function(LobbyMapConfig) updates) => super.copyWith((message) => updates(message as LobbyMapConfig)) as LobbyMapConfig;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyMapConfig create() => LobbyMapConfig._();
  LobbyMapConfig createEmptyInstance() => create();
  static $pb.PbList<LobbyMapConfig> createRepeated() => $pb.PbList<LobbyMapConfig>();
  @$core.pragma('dart2js:noInline')
  static LobbyMapConfig getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyMapConfig>(create);
  static LobbyMapConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mapId => $_getSZ(0);
  @$pb.TagNumber(1)
  set mapId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMapId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMapId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get backgroundUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set backgroundUrl($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasBackgroundUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearBackgroundUrl() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get width => $_getN(3);
  @$pb.TagNumber(4)
  set width($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasWidth() => $_has(3);
  @$pb.TagNumber(4)
  void clearWidth() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get height => $_getN(4);
  @$pb.TagNumber(5)
  set height($core.double v) { $_setDouble(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasHeight() => $_has(4);
  @$pb.TagNumber(5)
  void clearHeight() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<LobbyWalkableArea> get walkableAreas => $_getList(5);

  @$pb.TagNumber(7)
  $core.List<LobbyPortal> get portals => $_getList(6);

  @$pb.TagNumber(8)
  $core.bool get isDefault => $_getBF(7);
  @$pb.TagNumber(8)
  set isDefault($core.bool v) { $_setBool(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasIsDefault() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsDefault() => clearField(8);
}

/// LobbyWalkableArea 可行走区域
class LobbyWalkableArea extends $pb.GeneratedMessage {
  factory LobbyWalkableArea({
    $core.double? left,
    $core.double? top,
    $core.double? right,
    $core.double? bottom,
  }) {
    final $result = create();
    if (left != null) {
      $result.left = left;
    }
    if (top != null) {
      $result.top = top;
    }
    if (right != null) {
      $result.right = right;
    }
    if (bottom != null) {
      $result.bottom = bottom;
    }
    return $result;
  }
  LobbyWalkableArea._() : super();
  factory LobbyWalkableArea.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyWalkableArea.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyWalkableArea', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.double>(1, _omitFieldNames ? '' : 'left', $pb.PbFieldType.OD)
    ..a<$core.double>(2, _omitFieldNames ? '' : 'top', $pb.PbFieldType.OD)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'right', $pb.PbFieldType.OD)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'bottom', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyWalkableArea clone() => LobbyWalkableArea()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyWalkableArea copyWith(void Function(LobbyWalkableArea) updates) => super.copyWith((message) => updates(message as LobbyWalkableArea)) as LobbyWalkableArea;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyWalkableArea create() => LobbyWalkableArea._();
  LobbyWalkableArea createEmptyInstance() => create();
  static $pb.PbList<LobbyWalkableArea> createRepeated() => $pb.PbList<LobbyWalkableArea>();
  @$core.pragma('dart2js:noInline')
  static LobbyWalkableArea getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyWalkableArea>(create);
  static LobbyWalkableArea? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get left => $_getN(0);
  @$pb.TagNumber(1)
  set left($core.double v) { $_setDouble(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLeft() => $_has(0);
  @$pb.TagNumber(1)
  void clearLeft() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get top => $_getN(1);
  @$pb.TagNumber(2)
  set top($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTop() => $_has(1);
  @$pb.TagNumber(2)
  void clearTop() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get right => $_getN(2);
  @$pb.TagNumber(3)
  set right($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRight() => $_has(2);
  @$pb.TagNumber(3)
  void clearRight() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get bottom => $_getN(3);
  @$pb.TagNumber(4)
  set bottom($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasBottom() => $_has(3);
  @$pb.TagNumber(4)
  void clearBottom() => clearField(4);
}

/// LobbyPortal 传送门
class LobbyPortal extends $pb.GeneratedMessage {
  factory LobbyPortal({
    $core.String? key,
    $core.String? label,
    $core.double? x,
    $core.double? y,
    $core.String? targetMapId,
    $core.double? targetX,
    $core.double? targetY,
  }) {
    final $result = create();
    if (key != null) {
      $result.key = key;
    }
    if (label != null) {
      $result.label = label;
    }
    if (x != null) {
      $result.x = x;
    }
    if (y != null) {
      $result.y = y;
    }
    if (targetMapId != null) {
      $result.targetMapId = targetMapId;
    }
    if (targetX != null) {
      $result.targetX = targetX;
    }
    if (targetY != null) {
      $result.targetY = targetY;
    }
    return $result;
  }
  LobbyPortal._() : super();
  factory LobbyPortal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyPortal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyPortal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..a<$core.double>(3, _omitFieldNames ? '' : 'x', $pb.PbFieldType.OD)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'y', $pb.PbFieldType.OD)
    ..aOS(5, _omitFieldNames ? '' : 'targetMapId')
    ..a<$core.double>(6, _omitFieldNames ? '' : 'targetX', $pb.PbFieldType.OD)
    ..a<$core.double>(7, _omitFieldNames ? '' : 'targetY', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyPortal clone() => LobbyPortal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyPortal copyWith(void Function(LobbyPortal) updates) => super.copyWith((message) => updates(message as LobbyPortal)) as LobbyPortal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyPortal create() => LobbyPortal._();
  LobbyPortal createEmptyInstance() => create();
  static $pb.PbList<LobbyPortal> createRepeated() => $pb.PbList<LobbyPortal>();
  @$core.pragma('dart2js:noInline')
  static LobbyPortal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyPortal>(create);
  static LobbyPortal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get x => $_getN(2);
  @$pb.TagNumber(3)
  set x($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasX() => $_has(2);
  @$pb.TagNumber(3)
  void clearX() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get y => $_getN(3);
  @$pb.TagNumber(4)
  set y($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasY() => $_has(3);
  @$pb.TagNumber(4)
  void clearY() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get targetMapId => $_getSZ(4);
  @$pb.TagNumber(5)
  set targetMapId($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTargetMapId() => $_has(4);
  @$pb.TagNumber(5)
  void clearTargetMapId() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get targetX => $_getN(5);
  @$pb.TagNumber(6)
  set targetX($core.double v) { $_setDouble(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTargetX() => $_has(5);
  @$pb.TagNumber(6)
  void clearTargetX() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get targetY => $_getN(6);
  @$pb.TagNumber(7)
  set targetY($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasTargetY() => $_has(6);
  @$pb.TagNumber(7)
  void clearTargetY() => clearField(7);
}

/// LobbySpriteConfig 角色外观配置
class LobbySpriteConfig extends $pb.GeneratedMessage {
  factory LobbySpriteConfig({
    $core.String? id,
    $core.String? label,
    $core.String? accentColor,
    $core.String? spriteUrl,
    $core.String? previewUrl,
    $core.bool? isDefault,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (label != null) {
      $result.label = label;
    }
    if (accentColor != null) {
      $result.accentColor = accentColor;
    }
    if (spriteUrl != null) {
      $result.spriteUrl = spriteUrl;
    }
    if (previewUrl != null) {
      $result.previewUrl = previewUrl;
    }
    if (isDefault != null) {
      $result.isDefault = isDefault;
    }
    return $result;
  }
  LobbySpriteConfig._() : super();
  factory LobbySpriteConfig.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbySpriteConfig.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbySpriteConfig', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'accentColor')
    ..aOS(4, _omitFieldNames ? '' : 'spriteUrl')
    ..aOS(5, _omitFieldNames ? '' : 'previewUrl')
    ..aOB(6, _omitFieldNames ? '' : 'isDefault')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbySpriteConfig clone() => LobbySpriteConfig()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbySpriteConfig copyWith(void Function(LobbySpriteConfig) updates) => super.copyWith((message) => updates(message as LobbySpriteConfig)) as LobbySpriteConfig;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbySpriteConfig create() => LobbySpriteConfig._();
  LobbySpriteConfig createEmptyInstance() => create();
  static $pb.PbList<LobbySpriteConfig> createRepeated() => $pb.PbList<LobbySpriteConfig>();
  @$core.pragma('dart2js:noInline')
  static LobbySpriteConfig getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbySpriteConfig>(create);
  static LobbySpriteConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get accentColor => $_getSZ(2);
  @$pb.TagNumber(3)
  set accentColor($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAccentColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccentColor() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get spriteUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set spriteUrl($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSpriteUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpriteUrl() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get previewUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set previewUrl($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPreviewUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearPreviewUrl() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isDefault => $_getBF(5);
  @$pb.TagNumber(6)
  set isDefault($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsDefault() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsDefault() => clearField(6);
}

/// PageInfo 分页信息
class PageInfo extends $pb.GeneratedMessage {
  factory PageInfo({
    $core.int? currentPage,
    $core.int? totalPages,
    $core.int? pageSize,
    $core.int? totalUsers,
  }) {
    final $result = create();
    if (currentPage != null) {
      $result.currentPage = currentPage;
    }
    if (totalPages != null) {
      $result.totalPages = totalPages;
    }
    if (pageSize != null) {
      $result.pageSize = pageSize;
    }
    if (totalUsers != null) {
      $result.totalUsers = totalUsers;
    }
    return $result;
  }
  PageInfo._() : super();
  factory PageInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PageInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PageInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'currentPage', $pb.PbFieldType.O3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'totalPages', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'pageSize', $pb.PbFieldType.O3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'totalUsers', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PageInfo clone() => PageInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PageInfo copyWith(void Function(PageInfo) updates) => super.copyWith((message) => updates(message as PageInfo)) as PageInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PageInfo create() => PageInfo._();
  PageInfo createEmptyInstance() => create();
  static $pb.PbList<PageInfo> createRepeated() => $pb.PbList<PageInfo>();
  @$core.pragma('dart2js:noInline')
  static PageInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PageInfo>(create);
  static PageInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get currentPage => $_getIZ(0);
  @$pb.TagNumber(1)
  set currentPage($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCurrentPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrentPage() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalPages => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalPages($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTotalPages() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalPages() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get pageSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set pageSize($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPageSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageSize() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get totalUsers => $_getIZ(3);
  @$pb.TagNumber(4)
  set totalUsers($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTotalUsers() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalUsers() => clearField(4);
}

class LoginRequest extends $pb.GeneratedMessage {
  factory LoginRequest({
    $core.String? token,
    $core.String? deviceType,
    $core.bool? isAnonymous,
  }) {
    final $result = create();
    if (token != null) {
      $result.token = token;
    }
    if (deviceType != null) {
      $result.deviceType = deviceType;
    }
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    return $result;
  }
  LoginRequest._() : super();
  factory LoginRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoginRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoginRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'deviceType')
    ..aOB(3, _omitFieldNames ? '' : 'isAnonymous')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoginRequest clone() => LoginRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoginRequest copyWith(void Function(LoginRequest) updates) => super.copyWith((message) => updates(message as LoginRequest)) as LoginRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginRequest create() => LoginRequest._();
  LoginRequest createEmptyInstance() => create();
  static $pb.PbList<LoginRequest> createRepeated() => $pb.PbList<LoginRequest>();
  @$core.pragma('dart2js:noInline')
  static LoginRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoginRequest>(create);
  static LoginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceType => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceType($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDeviceType() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceType() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isAnonymous => $_getBF(2);
  @$pb.TagNumber(3)
  set isAnonymous($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIsAnonymous() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsAnonymous() => clearField(3);
}

/// EnterRequest 客户端完成身份确认后，主动宣告进入大厅（两阶段进入协议第二阶段）
/// 客户端流程：joinMatch() → [可选 login] → enter → 服务端广播 presence.join
class EnterRequest extends $pb.GeneratedMessage {
  factory EnterRequest({
    $core.int? protocolFeatures,
  }) {
    final $result = create();
    if (protocolFeatures != null) {
      $result.protocolFeatures = protocolFeatures;
    }
    return $result;
  }
  EnterRequest._() : super();
  factory EnterRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EnterRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EnterRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'protocolFeatures', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EnterRequest clone() => EnterRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EnterRequest copyWith(void Function(EnterRequest) updates) => super.copyWith((message) => updates(message as EnterRequest)) as EnterRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnterRequest create() => EnterRequest._();
  EnterRequest createEmptyInstance() => create();
  static $pb.PbList<EnterRequest> createRepeated() => $pb.PbList<EnterRequest>();
  @$core.pragma('dart2js:noInline')
  static EnterRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EnterRequest>(create);
  static EnterRequest? _defaultInstance;

  /// 无额外参数，服务端从 stagingMap 取当前身份
  @$pb.TagNumber(1)
  $core.int get protocolFeatures => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolFeatures($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasProtocolFeatures() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolFeatures() => clearField(1);
}

class LogoutRequest extends $pb.GeneratedMessage {
  factory LogoutRequest({
    $core.bool? force,
  }) {
    final $result = create();
    if (force != null) {
      $result.force = force;
    }
    return $result;
  }
  LogoutRequest._() : super();
  factory LogoutRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LogoutRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LogoutRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'force')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LogoutRequest clone() => LogoutRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LogoutRequest copyWith(void Function(LogoutRequest) updates) => super.copyWith((message) => updates(message as LogoutRequest)) as LogoutRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogoutRequest create() => LogoutRequest._();
  LogoutRequest createEmptyInstance() => create();
  static $pb.PbList<LogoutRequest> createRepeated() => $pb.PbList<LogoutRequest>();
  @$core.pragma('dart2js:noInline')
  static LogoutRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogoutRequest>(create);
  static LogoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get force => $_getBF(0);
  @$pb.TagNumber(1)
  set force($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasForce() => $_has(0);
  @$pb.TagNumber(1)
  void clearForce() => clearField(1);
}

class MoveRequest extends $pb.GeneratedMessage {
  factory MoveRequest({
    $core.double? targetX,
    $core.double? targetY,
  }) {
    final $result = create();
    if (targetX != null) {
      $result.targetX = targetX;
    }
    if (targetY != null) {
      $result.targetY = targetY;
    }
    return $result;
  }
  MoveRequest._() : super();
  factory MoveRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MoveRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MoveRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.double>(1, _omitFieldNames ? '' : 'targetX', $pb.PbFieldType.OD)
    ..a<$core.double>(2, _omitFieldNames ? '' : 'targetY', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MoveRequest clone() => MoveRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MoveRequest copyWith(void Function(MoveRequest) updates) => super.copyWith((message) => updates(message as MoveRequest)) as MoveRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MoveRequest create() => MoveRequest._();
  MoveRequest createEmptyInstance() => create();
  static $pb.PbList<MoveRequest> createRepeated() => $pb.PbList<MoveRequest>();
  @$core.pragma('dart2js:noInline')
  static MoveRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MoveRequest>(create);
  static MoveRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get targetX => $_getN(0);
  @$pb.TagNumber(1)
  set targetX($core.double v) { $_setDouble(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTargetX() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetX() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get targetY => $_getN(1);
  @$pb.TagNumber(2)
  set targetY($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetY() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetY() => clearField(2);
}

class ChatSendRequest extends $pb.GeneratedMessage {
  factory ChatSendRequest({
    $core.String? content,
  }) {
    final $result = create();
    if (content != null) {
      $result.content = content;
    }
    return $result;
  }
  ChatSendRequest._() : super();
  factory ChatSendRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ChatSendRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ChatSendRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'content')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ChatSendRequest clone() => ChatSendRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ChatSendRequest copyWith(void Function(ChatSendRequest) updates) => super.copyWith((message) => updates(message as ChatSendRequest)) as ChatSendRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatSendRequest create() => ChatSendRequest._();
  ChatSendRequest createEmptyInstance() => create();
  static $pb.PbList<ChatSendRequest> createRepeated() => $pb.PbList<ChatSendRequest>();
  @$core.pragma('dart2js:noInline')
  static ChatSendRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatSendRequest>(create);
  static ChatSendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get content => $_getSZ(0);
  @$pb.TagNumber(1)
  set content($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => clearField(1);
}

class ProfileAnonymousChangeRequest extends $pb.GeneratedMessage {
  factory ProfileAnonymousChangeRequest({
    $core.bool? isAnonymous,
  }) {
    final $result = create();
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    return $result;
  }
  ProfileAnonymousChangeRequest._() : super();
  factory ProfileAnonymousChangeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProfileAnonymousChangeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProfileAnonymousChangeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isAnonymous')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProfileAnonymousChangeRequest clone() => ProfileAnonymousChangeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProfileAnonymousChangeRequest copyWith(void Function(ProfileAnonymousChangeRequest) updates) => super.copyWith((message) => updates(message as ProfileAnonymousChangeRequest)) as ProfileAnonymousChangeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileAnonymousChangeRequest create() => ProfileAnonymousChangeRequest._();
  ProfileAnonymousChangeRequest createEmptyInstance() => create();
  static $pb.PbList<ProfileAnonymousChangeRequest> createRepeated() => $pb.PbList<ProfileAnonymousChangeRequest>();
  @$core.pragma('dart2js:noInline')
  static ProfileAnonymousChangeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProfileAnonymousChangeRequest>(create);
  static ProfileAnonymousChangeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isAnonymous => $_getBF(0);
  @$pb.TagNumber(1)
  set isAnonymous($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIsAnonymous() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsAnonymous() => clearField(1);
}

class ProfileSpriteChangeRequest extends $pb.GeneratedMessage {
  factory ProfileSpriteChangeRequest({
    $core.String? spriteId,
  }) {
    final $result = create();
    if (spriteId != null) {
      $result.spriteId = spriteId;
    }
    return $result;
  }
  ProfileSpriteChangeRequest._() : super();
  factory ProfileSpriteChangeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProfileSpriteChangeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProfileSpriteChangeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'spriteId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProfileSpriteChangeRequest clone() => ProfileSpriteChangeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProfileSpriteChangeRequest copyWith(void Function(ProfileSpriteChangeRequest) updates) => super.copyWith((message) => updates(message as ProfileSpriteChangeRequest)) as ProfileSpriteChangeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileSpriteChangeRequest create() => ProfileSpriteChangeRequest._();
  ProfileSpriteChangeRequest createEmptyInstance() => create();
  static $pb.PbList<ProfileSpriteChangeRequest> createRepeated() => $pb.PbList<ProfileSpriteChangeRequest>();
  @$core.pragma('dart2js:noInline')
  static ProfileSpriteChangeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProfileSpriteChangeRequest>(create);
  static ProfileSpriteChangeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get spriteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set spriteId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSpriteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSpriteId() => clearField(1);
}

class ProfileStatusTextUpdateRequest extends $pb.GeneratedMessage {
  factory ProfileStatusTextUpdateRequest({
    $core.String? statusText,
  }) {
    final $result = create();
    if (statusText != null) {
      $result.statusText = statusText;
    }
    return $result;
  }
  ProfileStatusTextUpdateRequest._() : super();
  factory ProfileStatusTextUpdateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProfileStatusTextUpdateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProfileStatusTextUpdateRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'statusText')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProfileStatusTextUpdateRequest clone() => ProfileStatusTextUpdateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProfileStatusTextUpdateRequest copyWith(void Function(ProfileStatusTextUpdateRequest) updates) => super.copyWith((message) => updates(message as ProfileStatusTextUpdateRequest)) as ProfileStatusTextUpdateRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileStatusTextUpdateRequest create() => ProfileStatusTextUpdateRequest._();
  ProfileStatusTextUpdateRequest createEmptyInstance() => create();
  static $pb.PbList<ProfileStatusTextUpdateRequest> createRepeated() => $pb.PbList<ProfileStatusTextUpdateRequest>();
  @$core.pragma('dart2js:noInline')
  static ProfileStatusTextUpdateRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProfileStatusTextUpdateRequest>(create);
  static ProfileStatusTextUpdateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get statusText => $_getSZ(0);
  @$pb.TagNumber(1)
  set statusText($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasStatusText() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatusText() => clearField(1);
}

class ProfileDisplayNameUpdateRequest extends $pb.GeneratedMessage {
  factory ProfileDisplayNameUpdateRequest({
    $core.String? customName,
    $core.String? steamName,
  }) {
    final $result = create();
    if (customName != null) {
      $result.customName = customName;
    }
    if (steamName != null) {
      $result.steamName = steamName;
    }
    return $result;
  }
  ProfileDisplayNameUpdateRequest._() : super();
  factory ProfileDisplayNameUpdateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProfileDisplayNameUpdateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProfileDisplayNameUpdateRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'customName')
    ..aOS(2, _omitFieldNames ? '' : 'steamName')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProfileDisplayNameUpdateRequest clone() => ProfileDisplayNameUpdateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProfileDisplayNameUpdateRequest copyWith(void Function(ProfileDisplayNameUpdateRequest) updates) => super.copyWith((message) => updates(message as ProfileDisplayNameUpdateRequest)) as ProfileDisplayNameUpdateRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileDisplayNameUpdateRequest create() => ProfileDisplayNameUpdateRequest._();
  ProfileDisplayNameUpdateRequest createEmptyInstance() => create();
  static $pb.PbList<ProfileDisplayNameUpdateRequest> createRepeated() => $pb.PbList<ProfileDisplayNameUpdateRequest>();
  @$core.pragma('dart2js:noInline')
  static ProfileDisplayNameUpdateRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProfileDisplayNameUpdateRequest>(create);
  static ProfileDisplayNameUpdateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get customName => $_getSZ(0);
  @$pb.TagNumber(1)
  set customName($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCustomName() => $_has(0);
  @$pb.TagNumber(1)
  void clearCustomName() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get steamName => $_getSZ(1);
  @$pb.TagNumber(2)
  set steamName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSteamName() => $_has(1);
  @$pb.TagNumber(2)
  void clearSteamName() => clearField(2);
}

class ProfileSteamBindRequest extends $pb.GeneratedMessage {
  factory ProfileSteamBindRequest({
    $core.String? steamId,
    $core.String? steamName,
  }) {
    final $result = create();
    if (steamId != null) {
      $result.steamId = steamId;
    }
    if (steamName != null) {
      $result.steamName = steamName;
    }
    return $result;
  }
  ProfileSteamBindRequest._() : super();
  factory ProfileSteamBindRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProfileSteamBindRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProfileSteamBindRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'steamId')
    ..aOS(2, _omitFieldNames ? '' : 'steamName')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProfileSteamBindRequest clone() => ProfileSteamBindRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProfileSteamBindRequest copyWith(void Function(ProfileSteamBindRequest) updates) => super.copyWith((message) => updates(message as ProfileSteamBindRequest)) as ProfileSteamBindRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileSteamBindRequest create() => ProfileSteamBindRequest._();
  ProfileSteamBindRequest createEmptyInstance() => create();
  static $pb.PbList<ProfileSteamBindRequest> createRepeated() => $pb.PbList<ProfileSteamBindRequest>();
  @$core.pragma('dart2js:noInline')
  static ProfileSteamBindRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProfileSteamBindRequest>(create);
  static ProfileSteamBindRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get steamId => $_getSZ(0);
  @$pb.TagNumber(1)
  set steamId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSteamId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSteamId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get steamName => $_getSZ(1);
  @$pb.TagNumber(2)
  set steamName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSteamName() => $_has(1);
  @$pb.TagNumber(2)
  void clearSteamName() => clearField(2);
}

class SnapshotRequest extends $pb.GeneratedMessage {
  factory SnapshotRequest() => create();
  SnapshotRequest._() : super();
  factory SnapshotRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SnapshotRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SnapshotRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SnapshotRequest clone() => SnapshotRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SnapshotRequest copyWith(void Function(SnapshotRequest) updates) => super.copyWith((message) => updates(message as SnapshotRequest)) as SnapshotRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SnapshotRequest create() => SnapshotRequest._();
  SnapshotRequest createEmptyInstance() => create();
  static $pb.PbList<SnapshotRequest> createRepeated() => $pb.PbList<SnapshotRequest>();
  @$core.pragma('dart2js:noInline')
  static SnapshotRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SnapshotRequest>(create);
  static SnapshotRequest? _defaultInstance;
}

class AssetsRequest extends $pb.GeneratedMessage {
  factory AssetsRequest() => create();
  AssetsRequest._() : super();
  factory AssetsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AssetsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AssetsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AssetsRequest clone() => AssetsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AssetsRequest copyWith(void Function(AssetsRequest) updates) => super.copyWith((message) => updates(message as AssetsRequest)) as AssetsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssetsRequest create() => AssetsRequest._();
  AssetsRequest createEmptyInstance() => create();
  static $pb.PbList<AssetsRequest> createRepeated() => $pb.PbList<AssetsRequest>();
  @$core.pragma('dart2js:noInline')
  static AssetsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AssetsRequest>(create);
  static AssetsRequest? _defaultInstance;
}

class BroadcastSendRequest extends $pb.GeneratedMessage {
  factory BroadcastSendRequest({
    $core.String? content,
  }) {
    final $result = create();
    if (content != null) {
      $result.content = content;
    }
    return $result;
  }
  BroadcastSendRequest._() : super();
  factory BroadcastSendRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastSendRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BroadcastSendRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'content')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastSendRequest clone() => BroadcastSendRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastSendRequest copyWith(void Function(BroadcastSendRequest) updates) => super.copyWith((message) => updates(message as BroadcastSendRequest)) as BroadcastSendRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastSendRequest create() => BroadcastSendRequest._();
  BroadcastSendRequest createEmptyInstance() => create();
  static $pb.PbList<BroadcastSendRequest> createRepeated() => $pb.PbList<BroadcastSendRequest>();
  @$core.pragma('dart2js:noInline')
  static BroadcastSendRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BroadcastSendRequest>(create);
  static BroadcastSendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get content => $_getSZ(0);
  @$pb.TagNumber(1)
  set content($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => clearField(1);
}

class BroadcastCDRequest extends $pb.GeneratedMessage {
  factory BroadcastCDRequest() => create();
  BroadcastCDRequest._() : super();
  factory BroadcastCDRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastCDRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BroadcastCDRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastCDRequest clone() => BroadcastCDRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastCDRequest copyWith(void Function(BroadcastCDRequest) updates) => super.copyWith((message) => updates(message as BroadcastCDRequest)) as BroadcastCDRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastCDRequest create() => BroadcastCDRequest._();
  BroadcastCDRequest createEmptyInstance() => create();
  static $pb.PbList<BroadcastCDRequest> createRepeated() => $pb.PbList<BroadcastCDRequest>();
  @$core.pragma('dart2js:noInline')
  static BroadcastCDRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BroadcastCDRequest>(create);
  static BroadcastCDRequest? _defaultInstance;
}

class PortalUseRequest extends $pb.GeneratedMessage {
  factory PortalUseRequest({
    $core.String? portalKey,
  }) {
    final $result = create();
    if (portalKey != null) {
      $result.portalKey = portalKey;
    }
    return $result;
  }
  PortalUseRequest._() : super();
  factory PortalUseRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PortalUseRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PortalUseRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'portalKey')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PortalUseRequest clone() => PortalUseRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PortalUseRequest copyWith(void Function(PortalUseRequest) updates) => super.copyWith((message) => updates(message as PortalUseRequest)) as PortalUseRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PortalUseRequest create() => PortalUseRequest._();
  PortalUseRequest createEmptyInstance() => create();
  static $pb.PbList<PortalUseRequest> createRepeated() => $pb.PbList<PortalUseRequest>();
  @$core.pragma('dart2js:noInline')
  static PortalUseRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PortalUseRequest>(create);
  static PortalUseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get portalKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set portalKey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPortalKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPortalKey() => clearField(1);
}

class OnlineStatsRequest extends $pb.GeneratedMessage {
  factory OnlineStatsRequest({
    $core.bool? includeUsers,
  }) {
    final $result = create();
    if (includeUsers != null) {
      $result.includeUsers = includeUsers;
    }
    return $result;
  }
  OnlineStatsRequest._() : super();
  factory OnlineStatsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory OnlineStatsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'OnlineStatsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'includeUsers')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  OnlineStatsRequest clone() => OnlineStatsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  OnlineStatsRequest copyWith(void Function(OnlineStatsRequest) updates) => super.copyWith((message) => updates(message as OnlineStatsRequest)) as OnlineStatsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OnlineStatsRequest create() => OnlineStatsRequest._();
  OnlineStatsRequest createEmptyInstance() => create();
  static $pb.PbList<OnlineStatsRequest> createRepeated() => $pb.PbList<OnlineStatsRequest>();
  @$core.pragma('dart2js:noInline')
  static OnlineStatsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OnlineStatsRequest>(create);
  static OnlineStatsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get includeUsers => $_getBF(0);
  @$pb.TagNumber(1)
  set includeUsers($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIncludeUsers() => $_has(0);
  @$pb.TagNumber(1)
  void clearIncludeUsers() => clearField(1);
}

class LoginSuccessResponse extends $pb.GeneratedMessage {
  factory LoginSuccessResponse({
    $core.String? userId,
    $core.String? nickname,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    return $result;
  }
  LoginSuccessResponse._() : super();
  factory LoginSuccessResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoginSuccessResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoginSuccessResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoginSuccessResponse clone() => LoginSuccessResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoginSuccessResponse copyWith(void Function(LoginSuccessResponse) updates) => super.copyWith((message) => updates(message as LoginSuccessResponse)) as LoginSuccessResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginSuccessResponse create() => LoginSuccessResponse._();
  LoginSuccessResponse createEmptyInstance() => create();
  static $pb.PbList<LoginSuccessResponse> createRepeated() => $pb.PbList<LoginSuccessResponse>();
  @$core.pragma('dart2js:noInline')
  static LoginSuccessResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoginSuccessResponse>(create);
  static LoginSuccessResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => clearField(2);
}

class LoginFailedResponse extends $pb.GeneratedMessage {
  factory LoginFailedResponse({
    $core.int? code,
    $core.String? reason,
  }) {
    final $result = create();
    if (code != null) {
      $result.code = code;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  LoginFailedResponse._() : super();
  factory LoginFailedResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoginFailedResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoginFailedResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'code', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoginFailedResponse clone() => LoginFailedResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoginFailedResponse copyWith(void Function(LoginFailedResponse) updates) => super.copyWith((message) => updates(message as LoginFailedResponse)) as LoginFailedResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginFailedResponse create() => LoginFailedResponse._();
  LoginFailedResponse createEmptyInstance() => create();
  static $pb.PbList<LoginFailedResponse> createRepeated() => $pb.PbList<LoginFailedResponse>();
  @$core.pragma('dart2js:noInline')
  static LoginFailedResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoginFailedResponse>(create);
  static LoginFailedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get code => $_getIZ(0);
  @$pb.TagNumber(1)
  set code($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => clearField(2);
}

class LogoutSuccessResponse extends $pb.GeneratedMessage {
  factory LogoutSuccessResponse({
    $core.bool? kick,
  }) {
    final $result = create();
    if (kick != null) {
      $result.kick = kick;
    }
    return $result;
  }
  LogoutSuccessResponse._() : super();
  factory LogoutSuccessResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LogoutSuccessResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LogoutSuccessResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'kick')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LogoutSuccessResponse clone() => LogoutSuccessResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LogoutSuccessResponse copyWith(void Function(LogoutSuccessResponse) updates) => super.copyWith((message) => updates(message as LogoutSuccessResponse)) as LogoutSuccessResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogoutSuccessResponse create() => LogoutSuccessResponse._();
  LogoutSuccessResponse createEmptyInstance() => create();
  static $pb.PbList<LogoutSuccessResponse> createRepeated() => $pb.PbList<LogoutSuccessResponse>();
  @$core.pragma('dart2js:noInline')
  static LogoutSuccessResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogoutSuccessResponse>(create);
  static LogoutSuccessResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get kick => $_getBF(0);
  @$pb.TagNumber(1)
  set kick($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasKick() => $_has(0);
  @$pb.TagNumber(1)
  void clearKick() => clearField(1);
}

class JoinSuccessResponse extends $pb.GeneratedMessage {
  factory JoinSuccessResponse({
    $core.String? mapId,
    LobbyUser? user,
    $core.int? onlineCount,
  }) {
    final $result = create();
    if (mapId != null) {
      $result.mapId = mapId;
    }
    if (user != null) {
      $result.user = user;
    }
    if (onlineCount != null) {
      $result.onlineCount = onlineCount;
    }
    return $result;
  }
  JoinSuccessResponse._() : super();
  factory JoinSuccessResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory JoinSuccessResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'JoinSuccessResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mapId')
    ..aOM<LobbyUser>(2, _omitFieldNames ? '' : 'user', subBuilder: LobbyUser.create)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'onlineCount', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  JoinSuccessResponse clone() => JoinSuccessResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  JoinSuccessResponse copyWith(void Function(JoinSuccessResponse) updates) => super.copyWith((message) => updates(message as JoinSuccessResponse)) as JoinSuccessResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinSuccessResponse create() => JoinSuccessResponse._();
  JoinSuccessResponse createEmptyInstance() => create();
  static $pb.PbList<JoinSuccessResponse> createRepeated() => $pb.PbList<JoinSuccessResponse>();
  @$core.pragma('dart2js:noInline')
  static JoinSuccessResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JoinSuccessResponse>(create);
  static JoinSuccessResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mapId => $_getSZ(0);
  @$pb.TagNumber(1)
  set mapId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMapId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMapId() => clearField(1);

  @$pb.TagNumber(2)
  LobbyUser get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(LobbyUser v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => clearField(2);
  @$pb.TagNumber(2)
  LobbyUser ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.int get onlineCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set onlineCount($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasOnlineCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearOnlineCount() => clearField(3);
}

class SnapshotResponse extends $pb.GeneratedMessage {
  factory SnapshotResponse({
    LobbyMapConfig? mapConfig,
    LobbyUser? self,
    $core.Iterable<LobbyUser>? users,
    $core.Iterable<LobbyMessage>? recentMessages,
    PageInfo? pageInfo,
  }) {
    final $result = create();
    if (mapConfig != null) {
      $result.mapConfig = mapConfig;
    }
    if (self != null) {
      $result.self = self;
    }
    if (users != null) {
      $result.users.addAll(users);
    }
    if (recentMessages != null) {
      $result.recentMessages.addAll(recentMessages);
    }
    if (pageInfo != null) {
      $result.pageInfo = pageInfo;
    }
    return $result;
  }
  SnapshotResponse._() : super();
  factory SnapshotResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SnapshotResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SnapshotResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOM<LobbyMapConfig>(1, _omitFieldNames ? '' : 'mapConfig', subBuilder: LobbyMapConfig.create)
    ..aOM<LobbyUser>(2, _omitFieldNames ? '' : 'self', subBuilder: LobbyUser.create)
    ..pc<LobbyUser>(3, _omitFieldNames ? '' : 'users', $pb.PbFieldType.PM, subBuilder: LobbyUser.create)
    ..pc<LobbyMessage>(4, _omitFieldNames ? '' : 'recentMessages', $pb.PbFieldType.PM, subBuilder: LobbyMessage.create)
    ..aOM<PageInfo>(5, _omitFieldNames ? '' : 'pageInfo', subBuilder: PageInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SnapshotResponse clone() => SnapshotResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SnapshotResponse copyWith(void Function(SnapshotResponse) updates) => super.copyWith((message) => updates(message as SnapshotResponse)) as SnapshotResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SnapshotResponse create() => SnapshotResponse._();
  SnapshotResponse createEmptyInstance() => create();
  static $pb.PbList<SnapshotResponse> createRepeated() => $pb.PbList<SnapshotResponse>();
  @$core.pragma('dart2js:noInline')
  static SnapshotResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SnapshotResponse>(create);
  static SnapshotResponse? _defaultInstance;

  @$pb.TagNumber(1)
  LobbyMapConfig get mapConfig => $_getN(0);
  @$pb.TagNumber(1)
  set mapConfig(LobbyMapConfig v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasMapConfig() => $_has(0);
  @$pb.TagNumber(1)
  void clearMapConfig() => clearField(1);
  @$pb.TagNumber(1)
  LobbyMapConfig ensureMapConfig() => $_ensure(0);

  @$pb.TagNumber(2)
  LobbyUser get self => $_getN(1);
  @$pb.TagNumber(2)
  set self(LobbyUser v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasSelf() => $_has(1);
  @$pb.TagNumber(2)
  void clearSelf() => clearField(2);
  @$pb.TagNumber(2)
  LobbyUser ensureSelf() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.List<LobbyUser> get users => $_getList(2);

  @$pb.TagNumber(4)
  $core.List<LobbyMessage> get recentMessages => $_getList(3);

  @$pb.TagNumber(5)
  PageInfo get pageInfo => $_getN(4);
  @$pb.TagNumber(5)
  set pageInfo(PageInfo v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasPageInfo() => $_has(4);
  @$pb.TagNumber(5)
  void clearPageInfo() => clearField(5);
  @$pb.TagNumber(5)
  PageInfo ensurePageInfo() => $_ensure(4);
}

class PresenceJoinResponse extends $pb.GeneratedMessage {
  factory PresenceJoinResponse({
    LobbyUser? user,
    $core.String? sourceMapId,
    $core.bool? isCrossMapNotification,
  }) {
    final $result = create();
    if (user != null) {
      $result.user = user;
    }
    if (sourceMapId != null) {
      $result.sourceMapId = sourceMapId;
    }
    if (isCrossMapNotification != null) {
      $result.isCrossMapNotification = isCrossMapNotification;
    }
    return $result;
  }
  PresenceJoinResponse._() : super();
  factory PresenceJoinResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PresenceJoinResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PresenceJoinResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOM<LobbyUser>(1, _omitFieldNames ? '' : 'user', subBuilder: LobbyUser.create)
    ..aOS(2, _omitFieldNames ? '' : 'sourceMapId')
    ..aOB(3, _omitFieldNames ? '' : 'isCrossMapNotification')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PresenceJoinResponse clone() => PresenceJoinResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PresenceJoinResponse copyWith(void Function(PresenceJoinResponse) updates) => super.copyWith((message) => updates(message as PresenceJoinResponse)) as PresenceJoinResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PresenceJoinResponse create() => PresenceJoinResponse._();
  PresenceJoinResponse createEmptyInstance() => create();
  static $pb.PbList<PresenceJoinResponse> createRepeated() => $pb.PbList<PresenceJoinResponse>();
  @$core.pragma('dart2js:noInline')
  static PresenceJoinResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PresenceJoinResponse>(create);
  static PresenceJoinResponse? _defaultInstance;

  @$pb.TagNumber(1)
  LobbyUser get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(LobbyUser v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => clearField(1);
  @$pb.TagNumber(1)
  LobbyUser ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get sourceMapId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sourceMapId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSourceMapId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceMapId() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isCrossMapNotification => $_getBF(2);
  @$pb.TagNumber(3)
  set isCrossMapNotification($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIsCrossMapNotification() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsCrossMapNotification() => clearField(3);
}

class PresenceLeaveResponse extends $pb.GeneratedMessage {
  factory PresenceLeaveResponse({
    $core.String? userId,
    $core.String? targetMapId,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (targetMapId != null) {
      $result.targetMapId = targetMapId;
    }
    return $result;
  }
  PresenceLeaveResponse._() : super();
  factory PresenceLeaveResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PresenceLeaveResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PresenceLeaveResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'targetMapId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PresenceLeaveResponse clone() => PresenceLeaveResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PresenceLeaveResponse copyWith(void Function(PresenceLeaveResponse) updates) => super.copyWith((message) => updates(message as PresenceLeaveResponse)) as PresenceLeaveResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PresenceLeaveResponse create() => PresenceLeaveResponse._();
  PresenceLeaveResponse createEmptyInstance() => create();
  static $pb.PbList<PresenceLeaveResponse> createRepeated() => $pb.PbList<PresenceLeaveResponse>();
  @$core.pragma('dart2js:noInline')
  static PresenceLeaveResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PresenceLeaveResponse>(create);
  static PresenceLeaveResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetMapId => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetMapId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetMapId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetMapId() => clearField(2);
}

class IdentityChangedResponse extends $pb.GeneratedMessage {
  factory IdentityChangedResponse({
    $core.String? sessionKey,
    $core.String? oldUserId,
    $core.String? newUserId,
    $core.String? nickname,
    $core.String? avatarUrl,
    $core.String? spriteId,
    $core.bool? isAnonymous,
    $core.String? businessUserId,
  }) {
    final $result = create();
    if (sessionKey != null) {
      $result.sessionKey = sessionKey;
    }
    if (oldUserId != null) {
      $result.oldUserId = oldUserId;
    }
    if (newUserId != null) {
      $result.newUserId = newUserId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    if (avatarUrl != null) {
      $result.avatarUrl = avatarUrl;
    }
    if (spriteId != null) {
      $result.spriteId = spriteId;
    }
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    if (businessUserId != null) {
      $result.businessUserId = businessUserId;
    }
    return $result;
  }
  IdentityChangedResponse._() : super();
  factory IdentityChangedResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory IdentityChangedResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'IdentityChangedResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionKey')
    ..aOS(2, _omitFieldNames ? '' : 'oldUserId')
    ..aOS(3, _omitFieldNames ? '' : 'newUserId')
    ..aOS(4, _omitFieldNames ? '' : 'nickname')
    ..aOS(5, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(6, _omitFieldNames ? '' : 'spriteId')
    ..aOB(7, _omitFieldNames ? '' : 'isAnonymous')
    ..aOS(8, _omitFieldNames ? '' : 'businessUserId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  IdentityChangedResponse clone() => IdentityChangedResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  IdentityChangedResponse copyWith(void Function(IdentityChangedResponse) updates) => super.copyWith((message) => updates(message as IdentityChangedResponse)) as IdentityChangedResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IdentityChangedResponse create() => IdentityChangedResponse._();
  IdentityChangedResponse createEmptyInstance() => create();
  static $pb.PbList<IdentityChangedResponse> createRepeated() => $pb.PbList<IdentityChangedResponse>();
  @$core.pragma('dart2js:noInline')
  static IdentityChangedResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IdentityChangedResponse>(create);
  static IdentityChangedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionKey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSessionKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get oldUserId => $_getSZ(1);
  @$pb.TagNumber(2)
  set oldUserId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOldUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get newUserId => $_getSZ(2);
  @$pb.TagNumber(3)
  set newUserId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNewUserId() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewUserId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get nickname => $_getSZ(3);
  @$pb.TagNumber(4)
  set nickname($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasNickname() => $_has(3);
  @$pb.TagNumber(4)
  void clearNickname() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get avatarUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set avatarUrl($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasAvatarUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvatarUrl() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get spriteId => $_getSZ(5);
  @$pb.TagNumber(6)
  set spriteId($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSpriteId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSpriteId() => clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isAnonymous => $_getBF(6);
  @$pb.TagNumber(7)
  set isAnonymous($core.bool v) { $_setBool(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasIsAnonymous() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsAnonymous() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get businessUserId => $_getSZ(7);
  @$pb.TagNumber(8)
  set businessUserId($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasBusinessUserId() => $_has(7);
  @$pb.TagNumber(8)
  void clearBusinessUserId() => clearField(8);
}

class MoveBroadcastResponse extends $pb.GeneratedMessage {
  factory MoveBroadcastResponse({
    $core.String? userId,
    $core.double? targetX,
    $core.double? targetY,
    $core.String? facing,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (targetX != null) {
      $result.targetX = targetX;
    }
    if (targetY != null) {
      $result.targetY = targetY;
    }
    if (facing != null) {
      $result.facing = facing;
    }
    return $result;
  }
  MoveBroadcastResponse._() : super();
  factory MoveBroadcastResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MoveBroadcastResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MoveBroadcastResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'targetX', $pb.PbFieldType.OD)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'targetY', $pb.PbFieldType.OD)
    ..aOS(4, _omitFieldNames ? '' : 'facing')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MoveBroadcastResponse clone() => MoveBroadcastResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MoveBroadcastResponse copyWith(void Function(MoveBroadcastResponse) updates) => super.copyWith((message) => updates(message as MoveBroadcastResponse)) as MoveBroadcastResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MoveBroadcastResponse create() => MoveBroadcastResponse._();
  MoveBroadcastResponse createEmptyInstance() => create();
  static $pb.PbList<MoveBroadcastResponse> createRepeated() => $pb.PbList<MoveBroadcastResponse>();
  @$core.pragma('dart2js:noInline')
  static MoveBroadcastResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MoveBroadcastResponse>(create);
  static MoveBroadcastResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get targetX => $_getN(1);
  @$pb.TagNumber(2)
  set targetX($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetX() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetX() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get targetY => $_getN(2);
  @$pb.TagNumber(3)
  set targetY($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTargetY() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetY() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get facing => $_getSZ(3);
  @$pb.TagNumber(4)
  set facing($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasFacing() => $_has(3);
  @$pb.TagNumber(4)
  void clearFacing() => clearField(4);
}

class MoveRejectResponse extends $pb.GeneratedMessage {
  factory MoveRejectResponse({
    $core.String? reason,
    $core.double? correctionX,
    $core.double? correctionY,
  }) {
    final $result = create();
    if (reason != null) {
      $result.reason = reason;
    }
    if (correctionX != null) {
      $result.correctionX = correctionX;
    }
    if (correctionY != null) {
      $result.correctionY = correctionY;
    }
    return $result;
  }
  MoveRejectResponse._() : super();
  factory MoveRejectResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MoveRejectResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MoveRejectResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'correctionX', $pb.PbFieldType.OD)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'correctionY', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MoveRejectResponse clone() => MoveRejectResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MoveRejectResponse copyWith(void Function(MoveRejectResponse) updates) => super.copyWith((message) => updates(message as MoveRejectResponse)) as MoveRejectResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MoveRejectResponse create() => MoveRejectResponse._();
  MoveRejectResponse createEmptyInstance() => create();
  static $pb.PbList<MoveRejectResponse> createRepeated() => $pb.PbList<MoveRejectResponse>();
  @$core.pragma('dart2js:noInline')
  static MoveRejectResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MoveRejectResponse>(create);
  static MoveRejectResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get correctionX => $_getN(1);
  @$pb.TagNumber(2)
  set correctionX($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCorrectionX() => $_has(1);
  @$pb.TagNumber(2)
  void clearCorrectionX() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get correctionY => $_getN(2);
  @$pb.TagNumber(3)
  set correctionY($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCorrectionY() => $_has(2);
  @$pb.TagNumber(3)
  void clearCorrectionY() => clearField(3);
}

class ChatMessageResponse extends $pb.GeneratedMessage {
  factory ChatMessageResponse({
    LobbyMessage? message,
  }) {
    final $result = create();
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  ChatMessageResponse._() : super();
  factory ChatMessageResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ChatMessageResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ChatMessageResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOM<LobbyMessage>(1, _omitFieldNames ? '' : 'message', subBuilder: LobbyMessage.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ChatMessageResponse clone() => ChatMessageResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ChatMessageResponse copyWith(void Function(ChatMessageResponse) updates) => super.copyWith((message) => updates(message as ChatMessageResponse)) as ChatMessageResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatMessageResponse create() => ChatMessageResponse._();
  ChatMessageResponse createEmptyInstance() => create();
  static $pb.PbList<ChatMessageResponse> createRepeated() => $pb.PbList<ChatMessageResponse>();
  @$core.pragma('dart2js:noInline')
  static ChatMessageResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatMessageResponse>(create);
  static ChatMessageResponse? _defaultInstance;

  @$pb.TagNumber(1)
  LobbyMessage get message => $_getN(0);
  @$pb.TagNumber(1)
  set message(LobbyMessage v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);
  @$pb.TagNumber(1)
  LobbyMessage ensureMessage() => $_ensure(0);
}

class ChatRejectResponse extends $pb.GeneratedMessage {
  factory ChatRejectResponse({
    $core.String? reason,
  }) {
    final $result = create();
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  ChatRejectResponse._() : super();
  factory ChatRejectResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ChatRejectResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ChatRejectResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ChatRejectResponse clone() => ChatRejectResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ChatRejectResponse copyWith(void Function(ChatRejectResponse) updates) => super.copyWith((message) => updates(message as ChatRejectResponse)) as ChatRejectResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatRejectResponse create() => ChatRejectResponse._();
  ChatRejectResponse createEmptyInstance() => create();
  static $pb.PbList<ChatRejectResponse> createRepeated() => $pb.PbList<ChatRejectResponse>();
  @$core.pragma('dart2js:noInline')
  static ChatRejectResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatRejectResponse>(create);
  static ChatRejectResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => clearField(1);
}

class AnonymousChangedResponse extends $pb.GeneratedMessage {
  factory AnonymousChangedResponse({
    $core.String? userId,
    $core.bool? isAnonymous,
    $core.String? displayNickname,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    if (displayNickname != null) {
      $result.displayNickname = displayNickname;
    }
    return $result;
  }
  AnonymousChangedResponse._() : super();
  factory AnonymousChangedResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AnonymousChangedResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AnonymousChangedResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOB(2, _omitFieldNames ? '' : 'isAnonymous')
    ..aOS(3, _omitFieldNames ? '' : 'displayNickname')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AnonymousChangedResponse clone() => AnonymousChangedResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AnonymousChangedResponse copyWith(void Function(AnonymousChangedResponse) updates) => super.copyWith((message) => updates(message as AnonymousChangedResponse)) as AnonymousChangedResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnonymousChangedResponse create() => AnonymousChangedResponse._();
  AnonymousChangedResponse createEmptyInstance() => create();
  static $pb.PbList<AnonymousChangedResponse> createRepeated() => $pb.PbList<AnonymousChangedResponse>();
  @$core.pragma('dart2js:noInline')
  static AnonymousChangedResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AnonymousChangedResponse>(create);
  static AnonymousChangedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isAnonymous => $_getBF(1);
  @$pb.TagNumber(2)
  set isAnonymous($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIsAnonymous() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsAnonymous() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayNickname => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayNickname($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDisplayNickname() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayNickname() => clearField(3);
}

class SpriteChangedResponse extends $pb.GeneratedMessage {
  factory SpriteChangedResponse({
    $core.String? userId,
    $core.String? spriteId,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (spriteId != null) {
      $result.spriteId = spriteId;
    }
    return $result;
  }
  SpriteChangedResponse._() : super();
  factory SpriteChangedResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpriteChangedResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpriteChangedResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'spriteId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpriteChangedResponse clone() => SpriteChangedResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpriteChangedResponse copyWith(void Function(SpriteChangedResponse) updates) => super.copyWith((message) => updates(message as SpriteChangedResponse)) as SpriteChangedResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpriteChangedResponse create() => SpriteChangedResponse._();
  SpriteChangedResponse createEmptyInstance() => create();
  static $pb.PbList<SpriteChangedResponse> createRepeated() => $pb.PbList<SpriteChangedResponse>();
  @$core.pragma('dart2js:noInline')
  static SpriteChangedResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpriteChangedResponse>(create);
  static SpriteChangedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get spriteId => $_getSZ(1);
  @$pb.TagNumber(2)
  set spriteId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSpriteId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSpriteId() => clearField(2);
}

class SpriteChangeSuccessResponse extends $pb.GeneratedMessage {
  factory SpriteChangeSuccessResponse({
    $core.String? spriteId,
  }) {
    final $result = create();
    if (spriteId != null) {
      $result.spriteId = spriteId;
    }
    return $result;
  }
  SpriteChangeSuccessResponse._() : super();
  factory SpriteChangeSuccessResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpriteChangeSuccessResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpriteChangeSuccessResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'spriteId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpriteChangeSuccessResponse clone() => SpriteChangeSuccessResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpriteChangeSuccessResponse copyWith(void Function(SpriteChangeSuccessResponse) updates) => super.copyWith((message) => updates(message as SpriteChangeSuccessResponse)) as SpriteChangeSuccessResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpriteChangeSuccessResponse create() => SpriteChangeSuccessResponse._();
  SpriteChangeSuccessResponse createEmptyInstance() => create();
  static $pb.PbList<SpriteChangeSuccessResponse> createRepeated() => $pb.PbList<SpriteChangeSuccessResponse>();
  @$core.pragma('dart2js:noInline')
  static SpriteChangeSuccessResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpriteChangeSuccessResponse>(create);
  static SpriteChangeSuccessResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get spriteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set spriteId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSpriteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSpriteId() => clearField(1);
}

class SpriteChangeRejectResponse extends $pb.GeneratedMessage {
  factory SpriteChangeRejectResponse({
    $core.String? reason,
  }) {
    final $result = create();
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  SpriteChangeRejectResponse._() : super();
  factory SpriteChangeRejectResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpriteChangeRejectResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpriteChangeRejectResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpriteChangeRejectResponse clone() => SpriteChangeRejectResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpriteChangeRejectResponse copyWith(void Function(SpriteChangeRejectResponse) updates) => super.copyWith((message) => updates(message as SpriteChangeRejectResponse)) as SpriteChangeRejectResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpriteChangeRejectResponse create() => SpriteChangeRejectResponse._();
  SpriteChangeRejectResponse createEmptyInstance() => create();
  static $pb.PbList<SpriteChangeRejectResponse> createRepeated() => $pb.PbList<SpriteChangeRejectResponse>();
  @$core.pragma('dart2js:noInline')
  static SpriteChangeRejectResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpriteChangeRejectResponse>(create);
  static SpriteChangeRejectResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => clearField(1);
}

class StatusTextBroadcastResponse extends $pb.GeneratedMessage {
  factory StatusTextBroadcastResponse({
    $core.String? userId,
    $core.String? statusText,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (statusText != null) {
      $result.statusText = statusText;
    }
    return $result;
  }
  StatusTextBroadcastResponse._() : super();
  factory StatusTextBroadcastResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory StatusTextBroadcastResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'StatusTextBroadcastResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'statusText')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  StatusTextBroadcastResponse clone() => StatusTextBroadcastResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  StatusTextBroadcastResponse copyWith(void Function(StatusTextBroadcastResponse) updates) => super.copyWith((message) => updates(message as StatusTextBroadcastResponse)) as StatusTextBroadcastResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StatusTextBroadcastResponse create() => StatusTextBroadcastResponse._();
  StatusTextBroadcastResponse createEmptyInstance() => create();
  static $pb.PbList<StatusTextBroadcastResponse> createRepeated() => $pb.PbList<StatusTextBroadcastResponse>();
  @$core.pragma('dart2js:noInline')
  static StatusTextBroadcastResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StatusTextBroadcastResponse>(create);
  static StatusTextBroadcastResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get statusText => $_getSZ(1);
  @$pb.TagNumber(2)
  set statusText($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasStatusText() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatusText() => clearField(2);
}

class DisplayNameChangedResponse extends $pb.GeneratedMessage {
  factory DisplayNameChangedResponse({
    $core.String? userId,
    $core.String? nickname,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    return $result;
  }
  DisplayNameChangedResponse._() : super();
  factory DisplayNameChangedResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DisplayNameChangedResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DisplayNameChangedResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DisplayNameChangedResponse clone() => DisplayNameChangedResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DisplayNameChangedResponse copyWith(void Function(DisplayNameChangedResponse) updates) => super.copyWith((message) => updates(message as DisplayNameChangedResponse)) as DisplayNameChangedResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DisplayNameChangedResponse create() => DisplayNameChangedResponse._();
  DisplayNameChangedResponse createEmptyInstance() => create();
  static $pb.PbList<DisplayNameChangedResponse> createRepeated() => $pb.PbList<DisplayNameChangedResponse>();
  @$core.pragma('dart2js:noInline')
  static DisplayNameChangedResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DisplayNameChangedResponse>(create);
  static DisplayNameChangedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => clearField(2);
}

class AssetsResponse extends $pb.GeneratedMessage {
  factory AssetsResponse({
    $core.Iterable<LobbyMapConfig>? maps,
    $core.Iterable<LobbySpriteConfig>? sprites,
  }) {
    final $result = create();
    if (maps != null) {
      $result.maps.addAll(maps);
    }
    if (sprites != null) {
      $result.sprites.addAll(sprites);
    }
    return $result;
  }
  AssetsResponse._() : super();
  factory AssetsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AssetsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AssetsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..pc<LobbyMapConfig>(1, _omitFieldNames ? '' : 'maps', $pb.PbFieldType.PM, subBuilder: LobbyMapConfig.create)
    ..pc<LobbySpriteConfig>(2, _omitFieldNames ? '' : 'sprites', $pb.PbFieldType.PM, subBuilder: LobbySpriteConfig.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AssetsResponse clone() => AssetsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AssetsResponse copyWith(void Function(AssetsResponse) updates) => super.copyWith((message) => updates(message as AssetsResponse)) as AssetsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssetsResponse create() => AssetsResponse._();
  AssetsResponse createEmptyInstance() => create();
  static $pb.PbList<AssetsResponse> createRepeated() => $pb.PbList<AssetsResponse>();
  @$core.pragma('dart2js:noInline')
  static AssetsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AssetsResponse>(create);
  static AssetsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<LobbyMapConfig> get maps => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<LobbySpriteConfig> get sprites => $_getList(1);
}

class AssetsUpdatedResponse extends $pb.GeneratedMessage {
  factory AssetsUpdatedResponse({
    $core.String? updateType,
    $core.String? message,
  }) {
    final $result = create();
    if (updateType != null) {
      $result.updateType = updateType;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  AssetsUpdatedResponse._() : super();
  factory AssetsUpdatedResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AssetsUpdatedResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AssetsUpdatedResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'updateType')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AssetsUpdatedResponse clone() => AssetsUpdatedResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AssetsUpdatedResponse copyWith(void Function(AssetsUpdatedResponse) updates) => super.copyWith((message) => updates(message as AssetsUpdatedResponse)) as AssetsUpdatedResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssetsUpdatedResponse create() => AssetsUpdatedResponse._();
  AssetsUpdatedResponse createEmptyInstance() => create();
  static $pb.PbList<AssetsUpdatedResponse> createRepeated() => $pb.PbList<AssetsUpdatedResponse>();
  @$core.pragma('dart2js:noInline')
  static AssetsUpdatedResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AssetsUpdatedResponse>(create);
  static AssetsUpdatedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get updateType => $_getSZ(0);
  @$pb.TagNumber(1)
  set updateType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUpdateType() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpdateType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class PortalTeleportResponse extends $pb.GeneratedMessage {
  factory PortalTeleportResponse({
    $core.String? portalKey,
    $core.String? label,
    $core.String? sourceMapId,
    $core.String? targetMapId,
    $core.double? targetX,
    $core.double? targetY,
    $core.String? targetMatchId,
  }) {
    final $result = create();
    if (portalKey != null) {
      $result.portalKey = portalKey;
    }
    if (label != null) {
      $result.label = label;
    }
    if (sourceMapId != null) {
      $result.sourceMapId = sourceMapId;
    }
    if (targetMapId != null) {
      $result.targetMapId = targetMapId;
    }
    if (targetX != null) {
      $result.targetX = targetX;
    }
    if (targetY != null) {
      $result.targetY = targetY;
    }
    if (targetMatchId != null) {
      $result.targetMatchId = targetMatchId;
    }
    return $result;
  }
  PortalTeleportResponse._() : super();
  factory PortalTeleportResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PortalTeleportResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PortalTeleportResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'portalKey')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'sourceMapId')
    ..aOS(4, _omitFieldNames ? '' : 'targetMapId')
    ..a<$core.double>(5, _omitFieldNames ? '' : 'targetX', $pb.PbFieldType.OD)
    ..a<$core.double>(6, _omitFieldNames ? '' : 'targetY', $pb.PbFieldType.OD)
    ..aOS(7, _omitFieldNames ? '' : 'targetMatchId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PortalTeleportResponse clone() => PortalTeleportResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PortalTeleportResponse copyWith(void Function(PortalTeleportResponse) updates) => super.copyWith((message) => updates(message as PortalTeleportResponse)) as PortalTeleportResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PortalTeleportResponse create() => PortalTeleportResponse._();
  PortalTeleportResponse createEmptyInstance() => create();
  static $pb.PbList<PortalTeleportResponse> createRepeated() => $pb.PbList<PortalTeleportResponse>();
  @$core.pragma('dart2js:noInline')
  static PortalTeleportResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PortalTeleportResponse>(create);
  static PortalTeleportResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get portalKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set portalKey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPortalKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPortalKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get sourceMapId => $_getSZ(2);
  @$pb.TagNumber(3)
  set sourceMapId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSourceMapId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSourceMapId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get targetMapId => $_getSZ(3);
  @$pb.TagNumber(4)
  set targetMapId($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTargetMapId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTargetMapId() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get targetX => $_getN(4);
  @$pb.TagNumber(5)
  set targetX($core.double v) { $_setDouble(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTargetX() => $_has(4);
  @$pb.TagNumber(5)
  void clearTargetX() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get targetY => $_getN(5);
  @$pb.TagNumber(6)
  set targetY($core.double v) { $_setDouble(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTargetY() => $_has(5);
  @$pb.TagNumber(6)
  void clearTargetY() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get targetMatchId => $_getSZ(6);
  @$pb.TagNumber(7)
  set targetMatchId($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasTargetMatchId() => $_has(6);
  @$pb.TagNumber(7)
  void clearTargetMatchId() => clearField(7);
}

class PortalUseRejectResponse extends $pb.GeneratedMessage {
  factory PortalUseRejectResponse({
    $core.String? reason,
  }) {
    final $result = create();
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  PortalUseRejectResponse._() : super();
  factory PortalUseRejectResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PortalUseRejectResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PortalUseRejectResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PortalUseRejectResponse clone() => PortalUseRejectResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PortalUseRejectResponse copyWith(void Function(PortalUseRejectResponse) updates) => super.copyWith((message) => updates(message as PortalUseRejectResponse)) as PortalUseRejectResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PortalUseRejectResponse create() => PortalUseRejectResponse._();
  PortalUseRejectResponse createEmptyInstance() => create();
  static $pb.PbList<PortalUseRejectResponse> createRepeated() => $pb.PbList<PortalUseRejectResponse>();
  @$core.pragma('dart2js:noInline')
  static PortalUseRejectResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PortalUseRejectResponse>(create);
  static PortalUseRejectResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => clearField(1);
}

class BroadcastMessageResponse extends $pb.GeneratedMessage {
  factory BroadcastMessageResponse({
    LobbyBroadcastMessage? message,
  }) {
    final $result = create();
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  BroadcastMessageResponse._() : super();
  factory BroadcastMessageResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastMessageResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BroadcastMessageResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOM<LobbyBroadcastMessage>(1, _omitFieldNames ? '' : 'message', subBuilder: LobbyBroadcastMessage.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastMessageResponse clone() => BroadcastMessageResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastMessageResponse copyWith(void Function(BroadcastMessageResponse) updates) => super.copyWith((message) => updates(message as BroadcastMessageResponse)) as BroadcastMessageResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastMessageResponse create() => BroadcastMessageResponse._();
  BroadcastMessageResponse createEmptyInstance() => create();
  static $pb.PbList<BroadcastMessageResponse> createRepeated() => $pb.PbList<BroadcastMessageResponse>();
  @$core.pragma('dart2js:noInline')
  static BroadcastMessageResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BroadcastMessageResponse>(create);
  static BroadcastMessageResponse? _defaultInstance;

  @$pb.TagNumber(1)
  LobbyBroadcastMessage get message => $_getN(0);
  @$pb.TagNumber(1)
  set message(LobbyBroadcastMessage v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);
  @$pb.TagNumber(1)
  LobbyBroadcastMessage ensureMessage() => $_ensure(0);
}

class BroadcastRejectResponse extends $pb.GeneratedMessage {
  factory BroadcastRejectResponse({
    $core.String? reason,
  }) {
    final $result = create();
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  BroadcastRejectResponse._() : super();
  factory BroadcastRejectResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastRejectResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BroadcastRejectResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastRejectResponse clone() => BroadcastRejectResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastRejectResponse copyWith(void Function(BroadcastRejectResponse) updates) => super.copyWith((message) => updates(message as BroadcastRejectResponse)) as BroadcastRejectResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastRejectResponse create() => BroadcastRejectResponse._();
  BroadcastRejectResponse createEmptyInstance() => create();
  static $pb.PbList<BroadcastRejectResponse> createRepeated() => $pb.PbList<BroadcastRejectResponse>();
  @$core.pragma('dart2js:noInline')
  static BroadcastRejectResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BroadcastRejectResponse>(create);
  static BroadcastRejectResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => clearField(1);
}

class BroadcastCDResponse extends $pb.GeneratedMessage {
  factory BroadcastCDResponse({
    $core.bool? inCooldown,
    $fixnum.Int64? remainingMs,
    $fixnum.Int64? nextBroadcastAt,
  }) {
    final $result = create();
    if (inCooldown != null) {
      $result.inCooldown = inCooldown;
    }
    if (remainingMs != null) {
      $result.remainingMs = remainingMs;
    }
    if (nextBroadcastAt != null) {
      $result.nextBroadcastAt = nextBroadcastAt;
    }
    return $result;
  }
  BroadcastCDResponse._() : super();
  factory BroadcastCDResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastCDResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BroadcastCDResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'inCooldown')
    ..aInt64(2, _omitFieldNames ? '' : 'remainingMs')
    ..aInt64(3, _omitFieldNames ? '' : 'nextBroadcastAt')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastCDResponse clone() => BroadcastCDResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastCDResponse copyWith(void Function(BroadcastCDResponse) updates) => super.copyWith((message) => updates(message as BroadcastCDResponse)) as BroadcastCDResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastCDResponse create() => BroadcastCDResponse._();
  BroadcastCDResponse createEmptyInstance() => create();
  static $pb.PbList<BroadcastCDResponse> createRepeated() => $pb.PbList<BroadcastCDResponse>();
  @$core.pragma('dart2js:noInline')
  static BroadcastCDResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BroadcastCDResponse>(create);
  static BroadcastCDResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get inCooldown => $_getBF(0);
  @$pb.TagNumber(1)
  set inCooldown($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInCooldown() => $_has(0);
  @$pb.TagNumber(1)
  void clearInCooldown() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get remainingMs => $_getI64(1);
  @$pb.TagNumber(2)
  set remainingMs($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRemainingMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearRemainingMs() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get nextBroadcastAt => $_getI64(2);
  @$pb.TagNumber(3)
  set nextBroadcastAt($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNextBroadcastAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearNextBroadcastAt() => clearField(3);
}

class OnlineStatsResponse extends $pb.GeneratedMessage {
  factory OnlineStatsResponse({
    $core.int? total,
    $core.Map<$core.String, $core.int>? byMap,
    $core.Iterable<LobbyUser>? users,
  }) {
    final $result = create();
    if (total != null) {
      $result.total = total;
    }
    if (byMap != null) {
      $result.byMap.addAll(byMap);
    }
    if (users != null) {
      $result.users.addAll(users);
    }
    return $result;
  }
  OnlineStatsResponse._() : super();
  factory OnlineStatsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory OnlineStatsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'OnlineStatsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'total', $pb.PbFieldType.O3)
    ..m<$core.String, $core.int>(2, _omitFieldNames ? '' : 'byMap', entryClassName: 'OnlineStatsResponse.ByMapEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.O3, packageName: const $pb.PackageName('lobby'))
    ..pc<LobbyUser>(3, _omitFieldNames ? '' : 'users', $pb.PbFieldType.PM, subBuilder: LobbyUser.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  OnlineStatsResponse clone() => OnlineStatsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  OnlineStatsResponse copyWith(void Function(OnlineStatsResponse) updates) => super.copyWith((message) => updates(message as OnlineStatsResponse)) as OnlineStatsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OnlineStatsResponse create() => OnlineStatsResponse._();
  OnlineStatsResponse createEmptyInstance() => create();
  static $pb.PbList<OnlineStatsResponse> createRepeated() => $pb.PbList<OnlineStatsResponse>();
  @$core.pragma('dart2js:noInline')
  static OnlineStatsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OnlineStatsResponse>(create);
  static OnlineStatsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get total => $_getIZ(0);
  @$pb.TagNumber(1)
  set total($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTotal() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotal() => clearField(1);

  @$pb.TagNumber(2)
  $core.Map<$core.String, $core.int> get byMap => $_getMap(1);

  @$pb.TagNumber(3)
  $core.List<LobbyUser> get users => $_getList(2);
}

class SystemErrorResponse extends $pb.GeneratedMessage {
  factory SystemErrorResponse({
    $core.int? code,
    $core.String? message,
  }) {
    final $result = create();
    if (code != null) {
      $result.code = code;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SystemErrorResponse._() : super();
  factory SystemErrorResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SystemErrorResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SystemErrorResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'code', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SystemErrorResponse clone() => SystemErrorResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SystemErrorResponse copyWith(void Function(SystemErrorResponse) updates) => super.copyWith((message) => updates(message as SystemErrorResponse)) as SystemErrorResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SystemErrorResponse create() => SystemErrorResponse._();
  SystemErrorResponse createEmptyInstance() => create();
  static $pb.PbList<SystemErrorResponse> createRepeated() => $pb.PbList<SystemErrorResponse>();
  @$core.pragma('dart2js:noInline')
  static SystemErrorResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SystemErrorResponse>(create);
  static SystemErrorResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get code => $_getIZ(0);
  @$pb.TagNumber(1)
  set code($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class SystemNoticeResponse extends $pb.GeneratedMessage {
  factory SystemNoticeResponse({
    $core.String? message,
  }) {
    final $result = create();
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SystemNoticeResponse._() : super();
  factory SystemNoticeResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SystemNoticeResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SystemNoticeResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SystemNoticeResponse clone() => SystemNoticeResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SystemNoticeResponse copyWith(void Function(SystemNoticeResponse) updates) => super.copyWith((message) => updates(message as SystemNoticeResponse)) as SystemNoticeResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SystemNoticeResponse create() => SystemNoticeResponse._();
  SystemNoticeResponse createEmptyInstance() => create();
  static $pb.PbList<SystemNoticeResponse> createRepeated() => $pb.PbList<SystemNoticeResponse>();
  @$core.pragma('dart2js:noInline')
  static SystemNoticeResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SystemNoticeResponse>(create);
  static SystemNoticeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);
}

class SystemKickedResponse extends $pb.GeneratedMessage {
  factory SystemKickedResponse({
    $core.String? reason,
    $core.String? message,
  }) {
    final $result = create();
    if (reason != null) {
      $result.reason = reason;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SystemKickedResponse._() : super();
  factory SystemKickedResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SystemKickedResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SystemKickedResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SystemKickedResponse clone() => SystemKickedResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SystemKickedResponse copyWith(void Function(SystemKickedResponse) updates) => super.copyWith((message) => updates(message as SystemKickedResponse)) as SystemKickedResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SystemKickedResponse create() => SystemKickedResponse._();
  SystemKickedResponse createEmptyInstance() => create();
  static $pb.PbList<SystemKickedResponse> createRepeated() => $pb.PbList<SystemKickedResponse>();
  @$core.pragma('dart2js:noInline')
  static SystemKickedResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SystemKickedResponse>(create);
  static SystemKickedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class SteamBindSuccessResponse extends $pb.GeneratedMessage {
  factory SteamBindSuccessResponse({
    $core.String? steamId,
    $core.String? steamName,
    $core.String? displayNickname,
  }) {
    final $result = create();
    if (steamId != null) {
      $result.steamId = steamId;
    }
    if (steamName != null) {
      $result.steamName = steamName;
    }
    if (displayNickname != null) {
      $result.displayNickname = displayNickname;
    }
    return $result;
  }
  SteamBindSuccessResponse._() : super();
  factory SteamBindSuccessResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SteamBindSuccessResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SteamBindSuccessResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'steamId')
    ..aOS(2, _omitFieldNames ? '' : 'steamName')
    ..aOS(3, _omitFieldNames ? '' : 'displayNickname')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SteamBindSuccessResponse clone() => SteamBindSuccessResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SteamBindSuccessResponse copyWith(void Function(SteamBindSuccessResponse) updates) => super.copyWith((message) => updates(message as SteamBindSuccessResponse)) as SteamBindSuccessResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SteamBindSuccessResponse create() => SteamBindSuccessResponse._();
  SteamBindSuccessResponse createEmptyInstance() => create();
  static $pb.PbList<SteamBindSuccessResponse> createRepeated() => $pb.PbList<SteamBindSuccessResponse>();
  @$core.pragma('dart2js:noInline')
  static SteamBindSuccessResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SteamBindSuccessResponse>(create);
  static SteamBindSuccessResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get steamId => $_getSZ(0);
  @$pb.TagNumber(1)
  set steamId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSteamId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSteamId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get steamName => $_getSZ(1);
  @$pb.TagNumber(2)
  set steamName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSteamName() => $_has(1);
  @$pb.TagNumber(2)
  void clearSteamName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayNickname => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayNickname($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDisplayNickname() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayNickname() => clearField(3);
}

/// LobbyJoinRequest 加入大厅请求
class LobbyJoinRequest extends $pb.GeneratedMessage {
  factory LobbyJoinRequest({
    $core.String? deviceType,
    $core.int? protocolFeatures,
  }) {
    final $result = create();
    if (deviceType != null) {
      $result.deviceType = deviceType;
    }
    if (protocolFeatures != null) {
      $result.protocolFeatures = protocolFeatures;
    }
    return $result;
  }
  LobbyJoinRequest._() : super();
  factory LobbyJoinRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyJoinRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyJoinRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceType')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'protocolFeatures', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyJoinRequest clone() => LobbyJoinRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyJoinRequest copyWith(void Function(LobbyJoinRequest) updates) => super.copyWith((message) => updates(message as LobbyJoinRequest)) as LobbyJoinRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyJoinRequest create() => LobbyJoinRequest._();
  LobbyJoinRequest createEmptyInstance() => create();
  static $pb.PbList<LobbyJoinRequest> createRepeated() => $pb.PbList<LobbyJoinRequest>();
  @$core.pragma('dart2js:noInline')
  static LobbyJoinRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyJoinRequest>(create);
  static LobbyJoinRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceType => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDeviceType() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceType() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get protocolFeatures => $_getIZ(1);
  @$pb.TagNumber(2)
  set protocolFeatures($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasProtocolFeatures() => $_has(1);
  @$pb.TagNumber(2)
  void clearProtocolFeatures() => clearField(2);
}

/// LobbyJoinResponse 加入大厅响应
class LobbyJoinResponse extends $pb.GeneratedMessage {
  factory LobbyJoinResponse({
    $core.String? matchId,
    $core.String? mapId,
    $core.String? ticket,
    $core.int? position,
    $core.int? queueTotal,
    $core.int? etaSeconds,
    $core.int? pollIntervalMs,
  }) {
    final $result = create();
    if (matchId != null) {
      $result.matchId = matchId;
    }
    if (mapId != null) {
      $result.mapId = mapId;
    }
    if (ticket != null) {
      $result.ticket = ticket;
    }
    if (position != null) {
      $result.position = position;
    }
    if (queueTotal != null) {
      $result.queueTotal = queueTotal;
    }
    if (etaSeconds != null) {
      $result.etaSeconds = etaSeconds;
    }
    if (pollIntervalMs != null) {
      $result.pollIntervalMs = pollIntervalMs;
    }
    return $result;
  }
  LobbyJoinResponse._() : super();
  factory LobbyJoinResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LobbyJoinResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LobbyJoinResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'matchId')
    ..aOS(2, _omitFieldNames ? '' : 'mapId')
    ..aOS(3, _omitFieldNames ? '' : 'ticket')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'position', $pb.PbFieldType.O3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'queueTotal', $pb.PbFieldType.O3)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'etaSeconds', $pb.PbFieldType.O3)
    ..a<$core.int>(7, _omitFieldNames ? '' : 'pollIntervalMs', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LobbyJoinResponse clone() => LobbyJoinResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LobbyJoinResponse copyWith(void Function(LobbyJoinResponse) updates) => super.copyWith((message) => updates(message as LobbyJoinResponse)) as LobbyJoinResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LobbyJoinResponse create() => LobbyJoinResponse._();
  LobbyJoinResponse createEmptyInstance() => create();
  static $pb.PbList<LobbyJoinResponse> createRepeated() => $pb.PbList<LobbyJoinResponse>();
  @$core.pragma('dart2js:noInline')
  static LobbyJoinResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LobbyJoinResponse>(create);
  static LobbyJoinResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get matchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set matchId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMatchId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get mapId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mapId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMapId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMapId() => clearField(2);

  /// 排队相关（match_id 为空时有效）
  @$pb.TagNumber(3)
  $core.String get ticket => $_getSZ(2);
  @$pb.TagNumber(3)
  set ticket($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTicket() => $_has(2);
  @$pb.TagNumber(3)
  void clearTicket() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get position => $_getIZ(3);
  @$pb.TagNumber(4)
  set position($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPosition() => $_has(3);
  @$pb.TagNumber(4)
  void clearPosition() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get queueTotal => $_getIZ(4);
  @$pb.TagNumber(5)
  set queueTotal($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasQueueTotal() => $_has(4);
  @$pb.TagNumber(5)
  void clearQueueTotal() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get etaSeconds => $_getIZ(5);
  @$pb.TagNumber(6)
  set etaSeconds($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasEtaSeconds() => $_has(5);
  @$pb.TagNumber(6)
  void clearEtaSeconds() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get pollIntervalMs => $_getIZ(6);
  @$pb.TagNumber(7)
  set pollIntervalMs($core.int v) { $_setSignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasPollIntervalMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearPollIntervalMs() => clearField(7);
}

/// SteamUserInfoRequest 查询 Steam 用户信息请求
class SteamUserInfoRequest extends $pb.GeneratedMessage {
  factory SteamUserInfoRequest({
    $core.String? userId,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    return $result;
  }
  SteamUserInfoRequest._() : super();
  factory SteamUserInfoRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SteamUserInfoRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SteamUserInfoRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SteamUserInfoRequest clone() => SteamUserInfoRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SteamUserInfoRequest copyWith(void Function(SteamUserInfoRequest) updates) => super.copyWith((message) => updates(message as SteamUserInfoRequest)) as SteamUserInfoRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SteamUserInfoRequest create() => SteamUserInfoRequest._();
  SteamUserInfoRequest createEmptyInstance() => create();
  static $pb.PbList<SteamUserInfoRequest> createRepeated() => $pb.PbList<SteamUserInfoRequest>();
  @$core.pragma('dart2js:noInline')
  static SteamUserInfoRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SteamUserInfoRequest>(create);
  static SteamUserInfoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);
}

/// SteamUserInfoResponse 查询 Steam 用户信息响应
class SteamUserInfoResponse extends $pb.GeneratedMessage {
  factory SteamUserInfoResponse({
    $core.int? code,
    $core.String? message,
    $fixnum.Int64? forumUid,
    $core.String? forumUsername,
    $core.String? forumAvatarUrl,
    $core.String? steamId,
    $core.String? steamId64,
    $core.String? avatarUrl,
    $core.String? steamName,
    $core.String? inGameName,
    $core.String? joinDate,
    $core.int? vipLevel,
    $core.String? vipDate,
    $core.String? vipEnd,
    $fixnum.Int64? csgoGold,
    $fixnum.Int64? onlineTimeTotal,
    $fixnum.Int64? onlineTimeDay,
    $fixnum.Int64? cs2Gold,
    $fixnum.Int64? cs2Point,
    $fixnum.Int64? cs2SpentPoint,
    $fixnum.Int64? mgPts,
    $fixnum.Int64? mgPtsRank,
    $fixnum.Int64? mgPtsTotal,
    $fixnum.Int64? surfPts,
    $fixnum.Int64? surfPtsRank,
    $fixnum.Int64? surfPtsTotal,
    $fixnum.Int64? bhopPts,
    $fixnum.Int64? bhopPtsRank,
    $fixnum.Int64? bhopPtsTotal,
    $fixnum.Int64? kzPts,
    $fixnum.Int64? kzPtsRank,
    $fixnum.Int64? kzPtsTotal,
    $fixnum.Int64? csgoOnlineTime,
    $fixnum.Int64? csgoZombiePts,
    $fixnum.Int64? csgoZombieKill,
    $fixnum.Int64? csgoZombieKnife,
    $fixnum.Int64? csgoZombieKickAss,
    $fixnum.Int64? csgoZombieLostAss,
    $fixnum.Int64? csgoZombieProLevel,
    $fixnum.Int64? csgoMgPts,
    $fixnum.Int64? csgoSurfPts,
    $fixnum.Int64? csgoBhopPts,
    $fixnum.Int64? csgoKzPts,
    $fixnum.Int64? csgoTttInnocentPts,
    $fixnum.Int64? csgoTttDetectivePts,
    $fixnum.Int64? csgoTttTraitorPts,
    $fixnum.Int64? cssZombiePts,
    $fixnum.Int64? cssZombieKill,
    $fixnum.Int64? cssZombieKnife,
    $fixnum.Int64? cssZombieKickAss,
    $fixnum.Int64? cssZombieProLevel,
    $fixnum.Int64? cssTitanPts,
    $fixnum.Int64? cssTitanKills,
    $fixnum.Int64? cssTitanSpecialKills,
    $fixnum.Int64? cssTitanHumanKills,
    $fixnum.Int64? cssTitanAssists,
    $fixnum.Int64? cssTttPts,
    $fixnum.Int64? cssTttWrongKill,
    $fixnum.Int64? cssTttKarma,
    $core.int? donatorLevel,
    $core.String? donateDate,
    $core.String? donateEnd,
    $core.bool? donatorSignToday,
    $core.String? currentDate,
  }) {
    final $result = create();
    if (code != null) {
      $result.code = code;
    }
    if (message != null) {
      $result.message = message;
    }
    if (forumUid != null) {
      $result.forumUid = forumUid;
    }
    if (forumUsername != null) {
      $result.forumUsername = forumUsername;
    }
    if (forumAvatarUrl != null) {
      $result.forumAvatarUrl = forumAvatarUrl;
    }
    if (steamId != null) {
      $result.steamId = steamId;
    }
    if (steamId64 != null) {
      $result.steamId64 = steamId64;
    }
    if (avatarUrl != null) {
      $result.avatarUrl = avatarUrl;
    }
    if (steamName != null) {
      $result.steamName = steamName;
    }
    if (inGameName != null) {
      $result.inGameName = inGameName;
    }
    if (joinDate != null) {
      $result.joinDate = joinDate;
    }
    if (vipLevel != null) {
      $result.vipLevel = vipLevel;
    }
    if (vipDate != null) {
      $result.vipDate = vipDate;
    }
    if (vipEnd != null) {
      $result.vipEnd = vipEnd;
    }
    if (csgoGold != null) {
      $result.csgoGold = csgoGold;
    }
    if (onlineTimeTotal != null) {
      $result.onlineTimeTotal = onlineTimeTotal;
    }
    if (onlineTimeDay != null) {
      $result.onlineTimeDay = onlineTimeDay;
    }
    if (cs2Gold != null) {
      $result.cs2Gold = cs2Gold;
    }
    if (cs2Point != null) {
      $result.cs2Point = cs2Point;
    }
    if (cs2SpentPoint != null) {
      $result.cs2SpentPoint = cs2SpentPoint;
    }
    if (mgPts != null) {
      $result.mgPts = mgPts;
    }
    if (mgPtsRank != null) {
      $result.mgPtsRank = mgPtsRank;
    }
    if (mgPtsTotal != null) {
      $result.mgPtsTotal = mgPtsTotal;
    }
    if (surfPts != null) {
      $result.surfPts = surfPts;
    }
    if (surfPtsRank != null) {
      $result.surfPtsRank = surfPtsRank;
    }
    if (surfPtsTotal != null) {
      $result.surfPtsTotal = surfPtsTotal;
    }
    if (bhopPts != null) {
      $result.bhopPts = bhopPts;
    }
    if (bhopPtsRank != null) {
      $result.bhopPtsRank = bhopPtsRank;
    }
    if (bhopPtsTotal != null) {
      $result.bhopPtsTotal = bhopPtsTotal;
    }
    if (kzPts != null) {
      $result.kzPts = kzPts;
    }
    if (kzPtsRank != null) {
      $result.kzPtsRank = kzPtsRank;
    }
    if (kzPtsTotal != null) {
      $result.kzPtsTotal = kzPtsTotal;
    }
    if (csgoOnlineTime != null) {
      $result.csgoOnlineTime = csgoOnlineTime;
    }
    if (csgoZombiePts != null) {
      $result.csgoZombiePts = csgoZombiePts;
    }
    if (csgoZombieKill != null) {
      $result.csgoZombieKill = csgoZombieKill;
    }
    if (csgoZombieKnife != null) {
      $result.csgoZombieKnife = csgoZombieKnife;
    }
    if (csgoZombieKickAss != null) {
      $result.csgoZombieKickAss = csgoZombieKickAss;
    }
    if (csgoZombieLostAss != null) {
      $result.csgoZombieLostAss = csgoZombieLostAss;
    }
    if (csgoZombieProLevel != null) {
      $result.csgoZombieProLevel = csgoZombieProLevel;
    }
    if (csgoMgPts != null) {
      $result.csgoMgPts = csgoMgPts;
    }
    if (csgoSurfPts != null) {
      $result.csgoSurfPts = csgoSurfPts;
    }
    if (csgoBhopPts != null) {
      $result.csgoBhopPts = csgoBhopPts;
    }
    if (csgoKzPts != null) {
      $result.csgoKzPts = csgoKzPts;
    }
    if (csgoTttInnocentPts != null) {
      $result.csgoTttInnocentPts = csgoTttInnocentPts;
    }
    if (csgoTttDetectivePts != null) {
      $result.csgoTttDetectivePts = csgoTttDetectivePts;
    }
    if (csgoTttTraitorPts != null) {
      $result.csgoTttTraitorPts = csgoTttTraitorPts;
    }
    if (cssZombiePts != null) {
      $result.cssZombiePts = cssZombiePts;
    }
    if (cssZombieKill != null) {
      $result.cssZombieKill = cssZombieKill;
    }
    if (cssZombieKnife != null) {
      $result.cssZombieKnife = cssZombieKnife;
    }
    if (cssZombieKickAss != null) {
      $result.cssZombieKickAss = cssZombieKickAss;
    }
    if (cssZombieProLevel != null) {
      $result.cssZombieProLevel = cssZombieProLevel;
    }
    if (cssTitanPts != null) {
      $result.cssTitanPts = cssTitanPts;
    }
    if (cssTitanKills != null) {
      $result.cssTitanKills = cssTitanKills;
    }
    if (cssTitanSpecialKills != null) {
      $result.cssTitanSpecialKills = cssTitanSpecialKills;
    }
    if (cssTitanHumanKills != null) {
      $result.cssTitanHumanKills = cssTitanHumanKills;
    }
    if (cssTitanAssists != null) {
      $result.cssTitanAssists = cssTitanAssists;
    }
    if (cssTttPts != null) {
      $result.cssTttPts = cssTttPts;
    }
    if (cssTttWrongKill != null) {
      $result.cssTttWrongKill = cssTttWrongKill;
    }
    if (cssTttKarma != null) {
      $result.cssTttKarma = cssTttKarma;
    }
    if (donatorLevel != null) {
      $result.donatorLevel = donatorLevel;
    }
    if (donateDate != null) {
      $result.donateDate = donateDate;
    }
    if (donateEnd != null) {
      $result.donateEnd = donateEnd;
    }
    if (donatorSignToday != null) {
      $result.donatorSignToday = donatorSignToday;
    }
    if (currentDate != null) {
      $result.currentDate = currentDate;
    }
    return $result;
  }
  SteamUserInfoResponse._() : super();
  factory SteamUserInfoResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SteamUserInfoResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SteamUserInfoResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'code', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aInt64(3, _omitFieldNames ? '' : 'forumUid')
    ..aOS(4, _omitFieldNames ? '' : 'forumUsername')
    ..aOS(5, _omitFieldNames ? '' : 'forumAvatarUrl')
    ..aOS(6, _omitFieldNames ? '' : 'steamId')
    ..aOS(7, _omitFieldNames ? '' : 'steamId64')
    ..aOS(8, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(9, _omitFieldNames ? '' : 'steamName')
    ..aOS(10, _omitFieldNames ? '' : 'inGameName')
    ..aOS(11, _omitFieldNames ? '' : 'joinDate')
    ..a<$core.int>(12, _omitFieldNames ? '' : 'vipLevel', $pb.PbFieldType.O3)
    ..aOS(13, _omitFieldNames ? '' : 'vipDate')
    ..aOS(14, _omitFieldNames ? '' : 'vipEnd')
    ..aInt64(15, _omitFieldNames ? '' : 'csgoGold')
    ..aInt64(16, _omitFieldNames ? '' : 'onlineTimeTotal')
    ..aInt64(17, _omitFieldNames ? '' : 'onlineTimeDay')
    ..aInt64(18, _omitFieldNames ? '' : 'cs2Gold')
    ..aInt64(19, _omitFieldNames ? '' : 'cs2Point')
    ..aInt64(20, _omitFieldNames ? '' : 'cs2SpentPoint')
    ..aInt64(21, _omitFieldNames ? '' : 'mgPts')
    ..aInt64(22, _omitFieldNames ? '' : 'mgPtsRank')
    ..aInt64(23, _omitFieldNames ? '' : 'mgPtsTotal')
    ..aInt64(24, _omitFieldNames ? '' : 'surfPts')
    ..aInt64(25, _omitFieldNames ? '' : 'surfPtsRank')
    ..aInt64(26, _omitFieldNames ? '' : 'surfPtsTotal')
    ..aInt64(27, _omitFieldNames ? '' : 'bhopPts')
    ..aInt64(28, _omitFieldNames ? '' : 'bhopPtsRank')
    ..aInt64(29, _omitFieldNames ? '' : 'bhopPtsTotal')
    ..aInt64(30, _omitFieldNames ? '' : 'kzPts')
    ..aInt64(31, _omitFieldNames ? '' : 'kzPtsRank')
    ..aInt64(32, _omitFieldNames ? '' : 'kzPtsTotal')
    ..aInt64(33, _omitFieldNames ? '' : 'csgoOnlineTime')
    ..aInt64(34, _omitFieldNames ? '' : 'csgoZombiePts')
    ..aInt64(35, _omitFieldNames ? '' : 'csgoZombieKill')
    ..aInt64(36, _omitFieldNames ? '' : 'csgoZombieKnife')
    ..aInt64(37, _omitFieldNames ? '' : 'csgoZombieKickAss')
    ..aInt64(38, _omitFieldNames ? '' : 'csgoZombieLostAss')
    ..aInt64(39, _omitFieldNames ? '' : 'csgoZombieProLevel')
    ..aInt64(40, _omitFieldNames ? '' : 'csgoMgPts')
    ..aInt64(41, _omitFieldNames ? '' : 'csgoSurfPts')
    ..aInt64(42, _omitFieldNames ? '' : 'csgoBhopPts')
    ..aInt64(43, _omitFieldNames ? '' : 'csgoKzPts')
    ..aInt64(44, _omitFieldNames ? '' : 'csgoTttInnocentPts')
    ..aInt64(45, _omitFieldNames ? '' : 'csgoTttDetectivePts')
    ..aInt64(46, _omitFieldNames ? '' : 'csgoTttTraitorPts')
    ..aInt64(47, _omitFieldNames ? '' : 'cssZombiePts')
    ..aInt64(48, _omitFieldNames ? '' : 'cssZombieKill')
    ..aInt64(49, _omitFieldNames ? '' : 'cssZombieKnife')
    ..aInt64(50, _omitFieldNames ? '' : 'cssZombieKickAss')
    ..aInt64(51, _omitFieldNames ? '' : 'cssZombieProLevel')
    ..aInt64(52, _omitFieldNames ? '' : 'cssTitanPts')
    ..aInt64(53, _omitFieldNames ? '' : 'cssTitanKills')
    ..aInt64(54, _omitFieldNames ? '' : 'cssTitanSpecialKills')
    ..aInt64(55, _omitFieldNames ? '' : 'cssTitanHumanKills')
    ..aInt64(56, _omitFieldNames ? '' : 'cssTitanAssists')
    ..aInt64(57, _omitFieldNames ? '' : 'cssTttPts')
    ..aInt64(58, _omitFieldNames ? '' : 'cssTttWrongKill')
    ..aInt64(59, _omitFieldNames ? '' : 'cssTttKarma')
    ..a<$core.int>(60, _omitFieldNames ? '' : 'donatorLevel', $pb.PbFieldType.O3)
    ..aOS(61, _omitFieldNames ? '' : 'donateDate')
    ..aOS(62, _omitFieldNames ? '' : 'donateEnd')
    ..aOB(63, _omitFieldNames ? '' : 'donatorSignToday')
    ..aOS(64, _omitFieldNames ? '' : 'currentDate')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SteamUserInfoResponse clone() => SteamUserInfoResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SteamUserInfoResponse copyWith(void Function(SteamUserInfoResponse) updates) => super.copyWith((message) => updates(message as SteamUserInfoResponse)) as SteamUserInfoResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SteamUserInfoResponse create() => SteamUserInfoResponse._();
  SteamUserInfoResponse createEmptyInstance() => create();
  static $pb.PbList<SteamUserInfoResponse> createRepeated() => $pb.PbList<SteamUserInfoResponse>();
  @$core.pragma('dart2js:noInline')
  static SteamUserInfoResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SteamUserInfoResponse>(create);
  static SteamUserInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get code => $_getIZ(0);
  @$pb.TagNumber(1)
  set code($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  /// 以下字段仅 code=0 时有效
  @$pb.TagNumber(3)
  $fixnum.Int64 get forumUid => $_getI64(2);
  @$pb.TagNumber(3)
  set forumUid($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasForumUid() => $_has(2);
  @$pb.TagNumber(3)
  void clearForumUid() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get forumUsername => $_getSZ(3);
  @$pb.TagNumber(4)
  set forumUsername($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasForumUsername() => $_has(3);
  @$pb.TagNumber(4)
  void clearForumUsername() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get forumAvatarUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set forumAvatarUrl($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasForumAvatarUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearForumAvatarUrl() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get steamId => $_getSZ(5);
  @$pb.TagNumber(6)
  set steamId($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSteamId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSteamId() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get steamId64 => $_getSZ(6);
  @$pb.TagNumber(7)
  set steamId64($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasSteamId64() => $_has(6);
  @$pb.TagNumber(7)
  void clearSteamId64() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get avatarUrl => $_getSZ(7);
  @$pb.TagNumber(8)
  set avatarUrl($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasAvatarUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearAvatarUrl() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get steamName => $_getSZ(8);
  @$pb.TagNumber(9)
  set steamName($core.String v) { $_setString(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasSteamName() => $_has(8);
  @$pb.TagNumber(9)
  void clearSteamName() => clearField(9);

  @$pb.TagNumber(10)
  $core.String get inGameName => $_getSZ(9);
  @$pb.TagNumber(10)
  set inGameName($core.String v) { $_setString(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasInGameName() => $_has(9);
  @$pb.TagNumber(10)
  void clearInGameName() => clearField(10);

  @$pb.TagNumber(11)
  $core.String get joinDate => $_getSZ(10);
  @$pb.TagNumber(11)
  set joinDate($core.String v) { $_setString(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasJoinDate() => $_has(10);
  @$pb.TagNumber(11)
  void clearJoinDate() => clearField(11);

  @$pb.TagNumber(12)
  $core.int get vipLevel => $_getIZ(11);
  @$pb.TagNumber(12)
  set vipLevel($core.int v) { $_setSignedInt32(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasVipLevel() => $_has(11);
  @$pb.TagNumber(12)
  void clearVipLevel() => clearField(12);

  @$pb.TagNumber(13)
  $core.String get vipDate => $_getSZ(12);
  @$pb.TagNumber(13)
  set vipDate($core.String v) { $_setString(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasVipDate() => $_has(12);
  @$pb.TagNumber(13)
  void clearVipDate() => clearField(13);

  @$pb.TagNumber(14)
  $core.String get vipEnd => $_getSZ(13);
  @$pb.TagNumber(14)
  set vipEnd($core.String v) { $_setString(13, v); }
  @$pb.TagNumber(14)
  $core.bool hasVipEnd() => $_has(13);
  @$pb.TagNumber(14)
  void clearVipEnd() => clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get csgoGold => $_getI64(14);
  @$pb.TagNumber(15)
  set csgoGold($fixnum.Int64 v) { $_setInt64(14, v); }
  @$pb.TagNumber(15)
  $core.bool hasCsgoGold() => $_has(14);
  @$pb.TagNumber(15)
  void clearCsgoGold() => clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get onlineTimeTotal => $_getI64(15);
  @$pb.TagNumber(16)
  set onlineTimeTotal($fixnum.Int64 v) { $_setInt64(15, v); }
  @$pb.TagNumber(16)
  $core.bool hasOnlineTimeTotal() => $_has(15);
  @$pb.TagNumber(16)
  void clearOnlineTimeTotal() => clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get onlineTimeDay => $_getI64(16);
  @$pb.TagNumber(17)
  set onlineTimeDay($fixnum.Int64 v) { $_setInt64(16, v); }
  @$pb.TagNumber(17)
  $core.bool hasOnlineTimeDay() => $_has(16);
  @$pb.TagNumber(17)
  void clearOnlineTimeDay() => clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get cs2Gold => $_getI64(17);
  @$pb.TagNumber(18)
  set cs2Gold($fixnum.Int64 v) { $_setInt64(17, v); }
  @$pb.TagNumber(18)
  $core.bool hasCs2Gold() => $_has(17);
  @$pb.TagNumber(18)
  void clearCs2Gold() => clearField(18);

  @$pb.TagNumber(19)
  $fixnum.Int64 get cs2Point => $_getI64(18);
  @$pb.TagNumber(19)
  set cs2Point($fixnum.Int64 v) { $_setInt64(18, v); }
  @$pb.TagNumber(19)
  $core.bool hasCs2Point() => $_has(18);
  @$pb.TagNumber(19)
  void clearCs2Point() => clearField(19);

  @$pb.TagNumber(20)
  $fixnum.Int64 get cs2SpentPoint => $_getI64(19);
  @$pb.TagNumber(20)
  set cs2SpentPoint($fixnum.Int64 v) { $_setInt64(19, v); }
  @$pb.TagNumber(20)
  $core.bool hasCs2SpentPoint() => $_has(19);
  @$pb.TagNumber(20)
  void clearCs2SpentPoint() => clearField(20);

  /// 各模式当前积分（null 时为 0）
  @$pb.TagNumber(21)
  $fixnum.Int64 get mgPts => $_getI64(20);
  @$pb.TagNumber(21)
  set mgPts($fixnum.Int64 v) { $_setInt64(20, v); }
  @$pb.TagNumber(21)
  $core.bool hasMgPts() => $_has(20);
  @$pb.TagNumber(21)
  void clearMgPts() => clearField(21);

  @$pb.TagNumber(22)
  $fixnum.Int64 get mgPtsRank => $_getI64(21);
  @$pb.TagNumber(22)
  set mgPtsRank($fixnum.Int64 v) { $_setInt64(21, v); }
  @$pb.TagNumber(22)
  $core.bool hasMgPtsRank() => $_has(21);
  @$pb.TagNumber(22)
  void clearMgPtsRank() => clearField(22);

  @$pb.TagNumber(23)
  $fixnum.Int64 get mgPtsTotal => $_getI64(22);
  @$pb.TagNumber(23)
  set mgPtsTotal($fixnum.Int64 v) { $_setInt64(22, v); }
  @$pb.TagNumber(23)
  $core.bool hasMgPtsTotal() => $_has(22);
  @$pb.TagNumber(23)
  void clearMgPtsTotal() => clearField(23);

  @$pb.TagNumber(24)
  $fixnum.Int64 get surfPts => $_getI64(23);
  @$pb.TagNumber(24)
  set surfPts($fixnum.Int64 v) { $_setInt64(23, v); }
  @$pb.TagNumber(24)
  $core.bool hasSurfPts() => $_has(23);
  @$pb.TagNumber(24)
  void clearSurfPts() => clearField(24);

  @$pb.TagNumber(25)
  $fixnum.Int64 get surfPtsRank => $_getI64(24);
  @$pb.TagNumber(25)
  set surfPtsRank($fixnum.Int64 v) { $_setInt64(24, v); }
  @$pb.TagNumber(25)
  $core.bool hasSurfPtsRank() => $_has(24);
  @$pb.TagNumber(25)
  void clearSurfPtsRank() => clearField(25);

  @$pb.TagNumber(26)
  $fixnum.Int64 get surfPtsTotal => $_getI64(25);
  @$pb.TagNumber(26)
  set surfPtsTotal($fixnum.Int64 v) { $_setInt64(25, v); }
  @$pb.TagNumber(26)
  $core.bool hasSurfPtsTotal() => $_has(25);
  @$pb.TagNumber(26)
  void clearSurfPtsTotal() => clearField(26);

  @$pb.TagNumber(27)
  $fixnum.Int64 get bhopPts => $_getI64(26);
  @$pb.TagNumber(27)
  set bhopPts($fixnum.Int64 v) { $_setInt64(26, v); }
  @$pb.TagNumber(27)
  $core.bool hasBhopPts() => $_has(26);
  @$pb.TagNumber(27)
  void clearBhopPts() => clearField(27);

  @$pb.TagNumber(28)
  $fixnum.Int64 get bhopPtsRank => $_getI64(27);
  @$pb.TagNumber(28)
  set bhopPtsRank($fixnum.Int64 v) { $_setInt64(27, v); }
  @$pb.TagNumber(28)
  $core.bool hasBhopPtsRank() => $_has(27);
  @$pb.TagNumber(28)
  void clearBhopPtsRank() => clearField(28);

  @$pb.TagNumber(29)
  $fixnum.Int64 get bhopPtsTotal => $_getI64(28);
  @$pb.TagNumber(29)
  set bhopPtsTotal($fixnum.Int64 v) { $_setInt64(28, v); }
  @$pb.TagNumber(29)
  $core.bool hasBhopPtsTotal() => $_has(28);
  @$pb.TagNumber(29)
  void clearBhopPtsTotal() => clearField(29);

  @$pb.TagNumber(30)
  $fixnum.Int64 get kzPts => $_getI64(29);
  @$pb.TagNumber(30)
  set kzPts($fixnum.Int64 v) { $_setInt64(29, v); }
  @$pb.TagNumber(30)
  $core.bool hasKzPts() => $_has(29);
  @$pb.TagNumber(30)
  void clearKzPts() => clearField(30);

  @$pb.TagNumber(31)
  $fixnum.Int64 get kzPtsRank => $_getI64(30);
  @$pb.TagNumber(31)
  set kzPtsRank($fixnum.Int64 v) { $_setInt64(30, v); }
  @$pb.TagNumber(31)
  $core.bool hasKzPtsRank() => $_has(30);
  @$pb.TagNumber(31)
  void clearKzPtsRank() => clearField(31);

  @$pb.TagNumber(32)
  $fixnum.Int64 get kzPtsTotal => $_getI64(31);
  @$pb.TagNumber(32)
  set kzPtsTotal($fixnum.Int64 v) { $_setInt64(31, v); }
  @$pb.TagNumber(32)
  $core.bool hasKzPtsTotal() => $_has(31);
  @$pb.TagNumber(32)
  void clearKzPtsTotal() => clearField(32);

  /// CSGO 数据
  @$pb.TagNumber(33)
  $fixnum.Int64 get csgoOnlineTime => $_getI64(32);
  @$pb.TagNumber(33)
  set csgoOnlineTime($fixnum.Int64 v) { $_setInt64(32, v); }
  @$pb.TagNumber(33)
  $core.bool hasCsgoOnlineTime() => $_has(32);
  @$pb.TagNumber(33)
  void clearCsgoOnlineTime() => clearField(33);

  @$pb.TagNumber(34)
  $fixnum.Int64 get csgoZombiePts => $_getI64(33);
  @$pb.TagNumber(34)
  set csgoZombiePts($fixnum.Int64 v) { $_setInt64(33, v); }
  @$pb.TagNumber(34)
  $core.bool hasCsgoZombiePts() => $_has(33);
  @$pb.TagNumber(34)
  void clearCsgoZombiePts() => clearField(34);

  @$pb.TagNumber(35)
  $fixnum.Int64 get csgoZombieKill => $_getI64(34);
  @$pb.TagNumber(35)
  set csgoZombieKill($fixnum.Int64 v) { $_setInt64(34, v); }
  @$pb.TagNumber(35)
  $core.bool hasCsgoZombieKill() => $_has(34);
  @$pb.TagNumber(35)
  void clearCsgoZombieKill() => clearField(35);

  @$pb.TagNumber(36)
  $fixnum.Int64 get csgoZombieKnife => $_getI64(35);
  @$pb.TagNumber(36)
  set csgoZombieKnife($fixnum.Int64 v) { $_setInt64(35, v); }
  @$pb.TagNumber(36)
  $core.bool hasCsgoZombieKnife() => $_has(35);
  @$pb.TagNumber(36)
  void clearCsgoZombieKnife() => clearField(36);

  @$pb.TagNumber(37)
  $fixnum.Int64 get csgoZombieKickAss => $_getI64(36);
  @$pb.TagNumber(37)
  set csgoZombieKickAss($fixnum.Int64 v) { $_setInt64(36, v); }
  @$pb.TagNumber(37)
  $core.bool hasCsgoZombieKickAss() => $_has(36);
  @$pb.TagNumber(37)
  void clearCsgoZombieKickAss() => clearField(37);

  @$pb.TagNumber(38)
  $fixnum.Int64 get csgoZombieLostAss => $_getI64(37);
  @$pb.TagNumber(38)
  set csgoZombieLostAss($fixnum.Int64 v) { $_setInt64(37, v); }
  @$pb.TagNumber(38)
  $core.bool hasCsgoZombieLostAss() => $_has(37);
  @$pb.TagNumber(38)
  void clearCsgoZombieLostAss() => clearField(38);

  @$pb.TagNumber(39)
  $fixnum.Int64 get csgoZombieProLevel => $_getI64(38);
  @$pb.TagNumber(39)
  set csgoZombieProLevel($fixnum.Int64 v) { $_setInt64(38, v); }
  @$pb.TagNumber(39)
  $core.bool hasCsgoZombieProLevel() => $_has(38);
  @$pb.TagNumber(39)
  void clearCsgoZombieProLevel() => clearField(39);

  @$pb.TagNumber(40)
  $fixnum.Int64 get csgoMgPts => $_getI64(39);
  @$pb.TagNumber(40)
  set csgoMgPts($fixnum.Int64 v) { $_setInt64(39, v); }
  @$pb.TagNumber(40)
  $core.bool hasCsgoMgPts() => $_has(39);
  @$pb.TagNumber(40)
  void clearCsgoMgPts() => clearField(40);

  @$pb.TagNumber(41)
  $fixnum.Int64 get csgoSurfPts => $_getI64(40);
  @$pb.TagNumber(41)
  set csgoSurfPts($fixnum.Int64 v) { $_setInt64(40, v); }
  @$pb.TagNumber(41)
  $core.bool hasCsgoSurfPts() => $_has(40);
  @$pb.TagNumber(41)
  void clearCsgoSurfPts() => clearField(41);

  @$pb.TagNumber(42)
  $fixnum.Int64 get csgoBhopPts => $_getI64(41);
  @$pb.TagNumber(42)
  set csgoBhopPts($fixnum.Int64 v) { $_setInt64(41, v); }
  @$pb.TagNumber(42)
  $core.bool hasCsgoBhopPts() => $_has(41);
  @$pb.TagNumber(42)
  void clearCsgoBhopPts() => clearField(42);

  @$pb.TagNumber(43)
  $fixnum.Int64 get csgoKzPts => $_getI64(42);
  @$pb.TagNumber(43)
  set csgoKzPts($fixnum.Int64 v) { $_setInt64(42, v); }
  @$pb.TagNumber(43)
  $core.bool hasCsgoKzPts() => $_has(42);
  @$pb.TagNumber(43)
  void clearCsgoKzPts() => clearField(43);

  @$pb.TagNumber(44)
  $fixnum.Int64 get csgoTttInnocentPts => $_getI64(43);
  @$pb.TagNumber(44)
  set csgoTttInnocentPts($fixnum.Int64 v) { $_setInt64(43, v); }
  @$pb.TagNumber(44)
  $core.bool hasCsgoTttInnocentPts() => $_has(43);
  @$pb.TagNumber(44)
  void clearCsgoTttInnocentPts() => clearField(44);

  @$pb.TagNumber(45)
  $fixnum.Int64 get csgoTttDetectivePts => $_getI64(44);
  @$pb.TagNumber(45)
  set csgoTttDetectivePts($fixnum.Int64 v) { $_setInt64(44, v); }
  @$pb.TagNumber(45)
  $core.bool hasCsgoTttDetectivePts() => $_has(44);
  @$pb.TagNumber(45)
  void clearCsgoTttDetectivePts() => clearField(45);

  @$pb.TagNumber(46)
  $fixnum.Int64 get csgoTttTraitorPts => $_getI64(45);
  @$pb.TagNumber(46)
  set csgoTttTraitorPts($fixnum.Int64 v) { $_setInt64(45, v); }
  @$pb.TagNumber(46)
  $core.bool hasCsgoTttTraitorPts() => $_has(45);
  @$pb.TagNumber(46)
  void clearCsgoTttTraitorPts() => clearField(46);

  /// CSS 数据
  @$pb.TagNumber(47)
  $fixnum.Int64 get cssZombiePts => $_getI64(46);
  @$pb.TagNumber(47)
  set cssZombiePts($fixnum.Int64 v) { $_setInt64(46, v); }
  @$pb.TagNumber(47)
  $core.bool hasCssZombiePts() => $_has(46);
  @$pb.TagNumber(47)
  void clearCssZombiePts() => clearField(47);

  @$pb.TagNumber(48)
  $fixnum.Int64 get cssZombieKill => $_getI64(47);
  @$pb.TagNumber(48)
  set cssZombieKill($fixnum.Int64 v) { $_setInt64(47, v); }
  @$pb.TagNumber(48)
  $core.bool hasCssZombieKill() => $_has(47);
  @$pb.TagNumber(48)
  void clearCssZombieKill() => clearField(48);

  @$pb.TagNumber(49)
  $fixnum.Int64 get cssZombieKnife => $_getI64(48);
  @$pb.TagNumber(49)
  set cssZombieKnife($fixnum.Int64 v) { $_setInt64(48, v); }
  @$pb.TagNumber(49)
  $core.bool hasCssZombieKnife() => $_has(48);
  @$pb.TagNumber(49)
  void clearCssZombieKnife() => clearField(49);

  @$pb.TagNumber(50)
  $fixnum.Int64 get cssZombieKickAss => $_getI64(49);
  @$pb.TagNumber(50)
  set cssZombieKickAss($fixnum.Int64 v) { $_setInt64(49, v); }
  @$pb.TagNumber(50)
  $core.bool hasCssZombieKickAss() => $_has(49);
  @$pb.TagNumber(50)
  void clearCssZombieKickAss() => clearField(50);

  @$pb.TagNumber(51)
  $fixnum.Int64 get cssZombieProLevel => $_getI64(50);
  @$pb.TagNumber(51)
  set cssZombieProLevel($fixnum.Int64 v) { $_setInt64(50, v); }
  @$pb.TagNumber(51)
  $core.bool hasCssZombieProLevel() => $_has(50);
  @$pb.TagNumber(51)
  void clearCssZombieProLevel() => clearField(51);

  @$pb.TagNumber(52)
  $fixnum.Int64 get cssTitanPts => $_getI64(51);
  @$pb.TagNumber(52)
  set cssTitanPts($fixnum.Int64 v) { $_setInt64(51, v); }
  @$pb.TagNumber(52)
  $core.bool hasCssTitanPts() => $_has(51);
  @$pb.TagNumber(52)
  void clearCssTitanPts() => clearField(52);

  @$pb.TagNumber(53)
  $fixnum.Int64 get cssTitanKills => $_getI64(52);
  @$pb.TagNumber(53)
  set cssTitanKills($fixnum.Int64 v) { $_setInt64(52, v); }
  @$pb.TagNumber(53)
  $core.bool hasCssTitanKills() => $_has(52);
  @$pb.TagNumber(53)
  void clearCssTitanKills() => clearField(53);

  @$pb.TagNumber(54)
  $fixnum.Int64 get cssTitanSpecialKills => $_getI64(53);
  @$pb.TagNumber(54)
  set cssTitanSpecialKills($fixnum.Int64 v) { $_setInt64(53, v); }
  @$pb.TagNumber(54)
  $core.bool hasCssTitanSpecialKills() => $_has(53);
  @$pb.TagNumber(54)
  void clearCssTitanSpecialKills() => clearField(54);

  @$pb.TagNumber(55)
  $fixnum.Int64 get cssTitanHumanKills => $_getI64(54);
  @$pb.TagNumber(55)
  set cssTitanHumanKills($fixnum.Int64 v) { $_setInt64(54, v); }
  @$pb.TagNumber(55)
  $core.bool hasCssTitanHumanKills() => $_has(54);
  @$pb.TagNumber(55)
  void clearCssTitanHumanKills() => clearField(55);

  @$pb.TagNumber(56)
  $fixnum.Int64 get cssTitanAssists => $_getI64(55);
  @$pb.TagNumber(56)
  set cssTitanAssists($fixnum.Int64 v) { $_setInt64(55, v); }
  @$pb.TagNumber(56)
  $core.bool hasCssTitanAssists() => $_has(55);
  @$pb.TagNumber(56)
  void clearCssTitanAssists() => clearField(56);

  @$pb.TagNumber(57)
  $fixnum.Int64 get cssTttPts => $_getI64(56);
  @$pb.TagNumber(57)
  set cssTttPts($fixnum.Int64 v) { $_setInt64(56, v); }
  @$pb.TagNumber(57)
  $core.bool hasCssTttPts() => $_has(56);
  @$pb.TagNumber(57)
  void clearCssTttPts() => clearField(57);

  @$pb.TagNumber(58)
  $fixnum.Int64 get cssTttWrongKill => $_getI64(57);
  @$pb.TagNumber(58)
  set cssTttWrongKill($fixnum.Int64 v) { $_setInt64(57, v); }
  @$pb.TagNumber(58)
  $core.bool hasCssTttWrongKill() => $_has(57);
  @$pb.TagNumber(58)
  void clearCssTttWrongKill() => clearField(58);

  @$pb.TagNumber(59)
  $fixnum.Int64 get cssTttKarma => $_getI64(58);
  @$pb.TagNumber(59)
  set cssTttKarma($fixnum.Int64 v) { $_setInt64(58, v); }
  @$pb.TagNumber(59)
  $core.bool hasCssTttKarma() => $_has(58);
  @$pb.TagNumber(59)
  void clearCssTttKarma() => clearField(59);

  /// 新捐助者字段（API 更新后 vip_* 字段已被 donator_* 替代）
  /// 旧字段 vip_level/vip_date/vip_end 保持兼容（自动从 donator 字段回填）
  @$pb.TagNumber(60)
  $core.int get donatorLevel => $_getIZ(59);
  @$pb.TagNumber(60)
  set donatorLevel($core.int v) { $_setSignedInt32(59, v); }
  @$pb.TagNumber(60)
  $core.bool hasDonatorLevel() => $_has(59);
  @$pb.TagNumber(60)
  void clearDonatorLevel() => clearField(60);

  @$pb.TagNumber(61)
  $core.String get donateDate => $_getSZ(60);
  @$pb.TagNumber(61)
  set donateDate($core.String v) { $_setString(60, v); }
  @$pb.TagNumber(61)
  $core.bool hasDonateDate() => $_has(60);
  @$pb.TagNumber(61)
  void clearDonateDate() => clearField(61);

  @$pb.TagNumber(62)
  $core.String get donateEnd => $_getSZ(61);
  @$pb.TagNumber(62)
  set donateEnd($core.String v) { $_setString(61, v); }
  @$pb.TagNumber(62)
  $core.bool hasDonateEnd() => $_has(61);
  @$pb.TagNumber(62)
  void clearDonateEnd() => clearField(62);

  @$pb.TagNumber(63)
  $core.bool get donatorSignToday => $_getBF(62);
  @$pb.TagNumber(63)
  set donatorSignToday($core.bool v) { $_setBool(62, v); }
  @$pb.TagNumber(63)
  $core.bool hasDonatorSignToday() => $_has(62);
  @$pb.TagNumber(63)
  void clearDonatorSignToday() => clearField(63);

  @$pb.TagNumber(64)
  $core.String get currentDate => $_getSZ(63);
  @$pb.TagNumber(64)
  set currentDate($core.String v) { $_setString(63, v); }
  @$pb.TagNumber(64)
  $core.bool hasCurrentDate() => $_has(63);
  @$pb.TagNumber(64)
  void clearCurrentDate() => clearField(64);
}

/// InventoryStatsRequest 查询玩家库存统计请求
class InventoryStatsRequest extends $pb.GeneratedMessage {
  factory InventoryStatsRequest({
    $core.String? userId,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    return $result;
  }
  InventoryStatsRequest._() : super();
  factory InventoryStatsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory InventoryStatsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'InventoryStatsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  InventoryStatsRequest clone() => InventoryStatsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  InventoryStatsRequest copyWith(void Function(InventoryStatsRequest) updates) => super.copyWith((message) => updates(message as InventoryStatsRequest)) as InventoryStatsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InventoryStatsRequest create() => InventoryStatsRequest._();
  InventoryStatsRequest createEmptyInstance() => create();
  static $pb.PbList<InventoryStatsRequest> createRepeated() => $pb.PbList<InventoryStatsRequest>();
  @$core.pragma('dart2js:noInline')
  static InventoryStatsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<InventoryStatsRequest>(create);
  static InventoryStatsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);
}

/// InventoryStatsResponse 查询玩家库存统计响应
class InventoryStatsResponse extends $pb.GeneratedMessage {
  factory InventoryStatsResponse({
    $core.int? code,
    $core.String? message,
    $core.int? skinCount,
    $core.int? spellCount,
    $core.int? danmakuCount,
    $core.int? skillCount,
    $core.int? knifeCount,
    $core.int? weaponCount,
    $core.int? cheerCount,
    $core.int? skinmenuCount,
    $fixnum.Int64? totalGoldValue,
    $fixnum.Int64? totalPointValue,
  }) {
    final $result = create();
    if (code != null) {
      $result.code = code;
    }
    if (message != null) {
      $result.message = message;
    }
    if (skinCount != null) {
      $result.skinCount = skinCount;
    }
    if (spellCount != null) {
      $result.spellCount = spellCount;
    }
    if (danmakuCount != null) {
      $result.danmakuCount = danmakuCount;
    }
    if (skillCount != null) {
      $result.skillCount = skillCount;
    }
    if (knifeCount != null) {
      $result.knifeCount = knifeCount;
    }
    if (weaponCount != null) {
      $result.weaponCount = weaponCount;
    }
    if (cheerCount != null) {
      $result.cheerCount = cheerCount;
    }
    if (skinmenuCount != null) {
      $result.skinmenuCount = skinmenuCount;
    }
    if (totalGoldValue != null) {
      $result.totalGoldValue = totalGoldValue;
    }
    if (totalPointValue != null) {
      $result.totalPointValue = totalPointValue;
    }
    return $result;
  }
  InventoryStatsResponse._() : super();
  factory InventoryStatsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory InventoryStatsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'InventoryStatsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'code', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'skinCount', $pb.PbFieldType.O3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'spellCount', $pb.PbFieldType.O3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'danmakuCount', $pb.PbFieldType.O3)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'skillCount', $pb.PbFieldType.O3)
    ..a<$core.int>(7, _omitFieldNames ? '' : 'knifeCount', $pb.PbFieldType.O3)
    ..a<$core.int>(8, _omitFieldNames ? '' : 'weaponCount', $pb.PbFieldType.O3)
    ..a<$core.int>(9, _omitFieldNames ? '' : 'cheerCount', $pb.PbFieldType.O3)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'skinmenuCount', $pb.PbFieldType.O3)
    ..aInt64(11, _omitFieldNames ? '' : 'totalGoldValue')
    ..aInt64(12, _omitFieldNames ? '' : 'totalPointValue')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  InventoryStatsResponse clone() => InventoryStatsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  InventoryStatsResponse copyWith(void Function(InventoryStatsResponse) updates) => super.copyWith((message) => updates(message as InventoryStatsResponse)) as InventoryStatsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InventoryStatsResponse create() => InventoryStatsResponse._();
  InventoryStatsResponse createEmptyInstance() => create();
  static $pb.PbList<InventoryStatsResponse> createRepeated() => $pb.PbList<InventoryStatsResponse>();
  @$core.pragma('dart2js:noInline')
  static InventoryStatsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<InventoryStatsResponse>(create);
  static InventoryStatsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get code => $_getIZ(0);
  @$pb.TagNumber(1)
  set code($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  /// 以下字段仅 code=0 时有效
  @$pb.TagNumber(3)
  $core.int get skinCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set skinCount($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSkinCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearSkinCount() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get spellCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set spellCount($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSpellCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpellCount() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get danmakuCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set danmakuCount($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasDanmakuCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearDanmakuCount() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get skillCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set skillCount($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSkillCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearSkillCount() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get knifeCount => $_getIZ(6);
  @$pb.TagNumber(7)
  set knifeCount($core.int v) { $_setSignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasKnifeCount() => $_has(6);
  @$pb.TagNumber(7)
  void clearKnifeCount() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get weaponCount => $_getIZ(7);
  @$pb.TagNumber(8)
  set weaponCount($core.int v) { $_setSignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasWeaponCount() => $_has(7);
  @$pb.TagNumber(8)
  void clearWeaponCount() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get cheerCount => $_getIZ(8);
  @$pb.TagNumber(9)
  set cheerCount($core.int v) { $_setSignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasCheerCount() => $_has(8);
  @$pb.TagNumber(9)
  void clearCheerCount() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get skinmenuCount => $_getIZ(9);
  @$pb.TagNumber(10)
  set skinmenuCount($core.int v) { $_setSignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasSkinmenuCount() => $_has(9);
  @$pb.TagNumber(10)
  void clearSkinmenuCount() => clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get totalGoldValue => $_getI64(10);
  @$pb.TagNumber(11)
  set totalGoldValue($fixnum.Int64 v) { $_setInt64(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasTotalGoldValue() => $_has(10);
  @$pb.TagNumber(11)
  void clearTotalGoldValue() => clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get totalPointValue => $_getI64(11);
  @$pb.TagNumber(12)
  set totalPointValue($fixnum.Int64 v) { $_setInt64(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasTotalPointValue() => $_has(11);
  @$pb.TagNumber(12)
  void clearTotalPointValue() => clearField(12);
}

/// PresenceDeltaResponse 增量 presence 帧（替代逐条 presence.join/leave）
/// 服务端每 tick 末尾合并本 tick 内所有 enter/leave 变化，一次性推送。
/// 客户端收到后批量更新本地用户列表，减少渲染抖动。
/// seq 为单调递增序列号，客户端检测到 seq 不连续时应主动请求 snapshot 进行全量同步。
class PresenceDeltaResponse extends $pb.GeneratedMessage {
  factory PresenceDeltaResponse({
    $core.Iterable<LobbyUser>? joined,
    $core.Iterable<$core.String>? leftUserIds,
    $core.Iterable<CrossMapPresenceEvent>? crossMapEvents,
    $fixnum.Int64? seq,
  }) {
    final $result = create();
    if (joined != null) {
      $result.joined.addAll(joined);
    }
    if (leftUserIds != null) {
      $result.leftUserIds.addAll(leftUserIds);
    }
    if (crossMapEvents != null) {
      $result.crossMapEvents.addAll(crossMapEvents);
    }
    if (seq != null) {
      $result.seq = seq;
    }
    return $result;
  }
  PresenceDeltaResponse._() : super();
  factory PresenceDeltaResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PresenceDeltaResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PresenceDeltaResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..pc<LobbyUser>(1, _omitFieldNames ? '' : 'joined', $pb.PbFieldType.PM, subBuilder: LobbyUser.create)
    ..pPS(2, _omitFieldNames ? '' : 'leftUserIds')
    ..pc<CrossMapPresenceEvent>(3, _omitFieldNames ? '' : 'crossMapEvents', $pb.PbFieldType.PM, subBuilder: CrossMapPresenceEvent.create)
    ..aInt64(10, _omitFieldNames ? '' : 'seq')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PresenceDeltaResponse clone() => PresenceDeltaResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PresenceDeltaResponse copyWith(void Function(PresenceDeltaResponse) updates) => super.copyWith((message) => updates(message as PresenceDeltaResponse)) as PresenceDeltaResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PresenceDeltaResponse create() => PresenceDeltaResponse._();
  PresenceDeltaResponse createEmptyInstance() => create();
  static $pb.PbList<PresenceDeltaResponse> createRepeated() => $pb.PbList<PresenceDeltaResponse>();
  @$core.pragma('dart2js:noInline')
  static PresenceDeltaResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PresenceDeltaResponse>(create);
  static PresenceDeltaResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<LobbyUser> get joined => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<$core.String> get leftUserIds => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<CrossMapPresenceEvent> get crossMapEvents => $_getList(2);

  @$pb.TagNumber(10)
  $fixnum.Int64 get seq => $_getI64(3);
  @$pb.TagNumber(10)
  set seq($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(10)
  $core.bool hasSeq() => $_has(3);
  @$pb.TagNumber(10)
  void clearSeq() => clearField(10);
}

/// CrossMapPresenceEvent 跨地图 presence 事件（弱通知，不渲染角色，仅 UI 提示）
class CrossMapPresenceEvent extends $pb.GeneratedMessage {
  factory CrossMapPresenceEvent({
    $core.String? userId,
    $core.String? nickname,
    $core.String? avatarUrl,
    $core.bool? isAnonymous,
    $core.String? mapId,
    $core.String? eventType,
    $core.String? targetMapId,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    if (avatarUrl != null) {
      $result.avatarUrl = avatarUrl;
    }
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    if (mapId != null) {
      $result.mapId = mapId;
    }
    if (eventType != null) {
      $result.eventType = eventType;
    }
    if (targetMapId != null) {
      $result.targetMapId = targetMapId;
    }
    return $result;
  }
  CrossMapPresenceEvent._() : super();
  factory CrossMapPresenceEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CrossMapPresenceEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CrossMapPresenceEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..aOS(3, _omitFieldNames ? '' : 'avatarUrl')
    ..aOB(4, _omitFieldNames ? '' : 'isAnonymous')
    ..aOS(5, _omitFieldNames ? '' : 'mapId')
    ..aOS(6, _omitFieldNames ? '' : 'eventType')
    ..aOS(7, _omitFieldNames ? '' : 'targetMapId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CrossMapPresenceEvent clone() => CrossMapPresenceEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CrossMapPresenceEvent copyWith(void Function(CrossMapPresenceEvent) updates) => super.copyWith((message) => updates(message as CrossMapPresenceEvent)) as CrossMapPresenceEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CrossMapPresenceEvent create() => CrossMapPresenceEvent._();
  CrossMapPresenceEvent createEmptyInstance() => create();
  static $pb.PbList<CrossMapPresenceEvent> createRepeated() => $pb.PbList<CrossMapPresenceEvent>();
  @$core.pragma('dart2js:noInline')
  static CrossMapPresenceEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CrossMapPresenceEvent>(create);
  static CrossMapPresenceEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get avatarUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set avatarUrl($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAvatarUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatarUrl() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isAnonymous => $_getBF(3);
  @$pb.TagNumber(4)
  set isAnonymous($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIsAnonymous() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsAnonymous() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get mapId => $_getSZ(4);
  @$pb.TagNumber(5)
  set mapId($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasMapId() => $_has(4);
  @$pb.TagNumber(5)
  void clearMapId() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get eventType => $_getSZ(5);
  @$pb.TagNumber(6)
  set eventType($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasEventType() => $_has(5);
  @$pb.TagNumber(6)
  void clearEventType() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get targetMapId => $_getSZ(6);
  @$pb.TagNumber(7)
  set targetMapId($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasTargetMapId() => $_has(6);
  @$pb.TagNumber(7)
  void clearTargetMapId() => clearField(7);
}

/// QueueStatusRequest 查询排队状态
class QueueStatusRequest extends $pb.GeneratedMessage {
  factory QueueStatusRequest({
    $core.String? ticket,
  }) {
    final $result = create();
    if (ticket != null) {
      $result.ticket = ticket;
    }
    return $result;
  }
  QueueStatusRequest._() : super();
  factory QueueStatusRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory QueueStatusRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'QueueStatusRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'ticket')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  QueueStatusRequest clone() => QueueStatusRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  QueueStatusRequest copyWith(void Function(QueueStatusRequest) updates) => super.copyWith((message) => updates(message as QueueStatusRequest)) as QueueStatusRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueueStatusRequest create() => QueueStatusRequest._();
  QueueStatusRequest createEmptyInstance() => create();
  static $pb.PbList<QueueStatusRequest> createRepeated() => $pb.PbList<QueueStatusRequest>();
  @$core.pragma('dart2js:noInline')
  static QueueStatusRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QueueStatusRequest>(create);
  static QueueStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get ticket => $_getSZ(0);
  @$pb.TagNumber(1)
  set ticket($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTicket() => $_has(0);
  @$pb.TagNumber(1)
  void clearTicket() => clearField(1);
}

/// QueueStatusResponse 排队状态响应
class QueueStatusResponse extends $pb.GeneratedMessage {
  factory QueueStatusResponse({
    $core.bool? ready,
    $core.String? matchId,
    $core.String? mapId,
    $core.int? position,
    $core.int? queueTotal,
    $core.int? etaSeconds,
    $core.int? pollIntervalMs,
    $core.bool? expired,
    $core.String? expireReason,
  }) {
    final $result = create();
    if (ready != null) {
      $result.ready = ready;
    }
    if (matchId != null) {
      $result.matchId = matchId;
    }
    if (mapId != null) {
      $result.mapId = mapId;
    }
    if (position != null) {
      $result.position = position;
    }
    if (queueTotal != null) {
      $result.queueTotal = queueTotal;
    }
    if (etaSeconds != null) {
      $result.etaSeconds = etaSeconds;
    }
    if (pollIntervalMs != null) {
      $result.pollIntervalMs = pollIntervalMs;
    }
    if (expired != null) {
      $result.expired = expired;
    }
    if (expireReason != null) {
      $result.expireReason = expireReason;
    }
    return $result;
  }
  QueueStatusResponse._() : super();
  factory QueueStatusResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory QueueStatusResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'QueueStatusResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ready')
    ..aOS(2, _omitFieldNames ? '' : 'matchId')
    ..aOS(3, _omitFieldNames ? '' : 'mapId')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'position', $pb.PbFieldType.O3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'queueTotal', $pb.PbFieldType.O3)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'etaSeconds', $pb.PbFieldType.O3)
    ..a<$core.int>(7, _omitFieldNames ? '' : 'pollIntervalMs', $pb.PbFieldType.O3)
    ..aOB(8, _omitFieldNames ? '' : 'expired')
    ..aOS(9, _omitFieldNames ? '' : 'expireReason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  QueueStatusResponse clone() => QueueStatusResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  QueueStatusResponse copyWith(void Function(QueueStatusResponse) updates) => super.copyWith((message) => updates(message as QueueStatusResponse)) as QueueStatusResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueueStatusResponse create() => QueueStatusResponse._();
  QueueStatusResponse createEmptyInstance() => create();
  static $pb.PbList<QueueStatusResponse> createRepeated() => $pb.PbList<QueueStatusResponse>();
  @$core.pragma('dart2js:noInline')
  static QueueStatusResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QueueStatusResponse>(create);
  static QueueStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ready => $_getBF(0);
  @$pb.TagNumber(1)
  set ready($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasReady() => $_has(0);
  @$pb.TagNumber(1)
  void clearReady() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get matchId => $_getSZ(1);
  @$pb.TagNumber(2)
  set matchId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMatchId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMatchId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get mapId => $_getSZ(2);
  @$pb.TagNumber(3)
  set mapId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMapId() => $_has(2);
  @$pb.TagNumber(3)
  void clearMapId() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get position => $_getIZ(3);
  @$pb.TagNumber(4)
  set position($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPosition() => $_has(3);
  @$pb.TagNumber(4)
  void clearPosition() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get queueTotal => $_getIZ(4);
  @$pb.TagNumber(5)
  set queueTotal($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasQueueTotal() => $_has(4);
  @$pb.TagNumber(5)
  void clearQueueTotal() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get etaSeconds => $_getIZ(5);
  @$pb.TagNumber(6)
  set etaSeconds($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasEtaSeconds() => $_has(5);
  @$pb.TagNumber(6)
  void clearEtaSeconds() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get pollIntervalMs => $_getIZ(6);
  @$pb.TagNumber(7)
  set pollIntervalMs($core.int v) { $_setSignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasPollIntervalMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearPollIntervalMs() => clearField(7);

  @$pb.TagNumber(8)
  $core.bool get expired => $_getBF(7);
  @$pb.TagNumber(8)
  set expired($core.bool v) { $_setBool(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasExpired() => $_has(7);
  @$pb.TagNumber(8)
  void clearExpired() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get expireReason => $_getSZ(8);
  @$pb.TagNumber(9)
  set expireReason($core.String v) { $_setString(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasExpireReason() => $_has(8);
  @$pb.TagNumber(9)
  void clearExpireReason() => clearField(9);
}

/// QueueCancelRequest 取消排队
class QueueCancelRequest extends $pb.GeneratedMessage {
  factory QueueCancelRequest({
    $core.String? ticket,
  }) {
    final $result = create();
    if (ticket != null) {
      $result.ticket = ticket;
    }
    return $result;
  }
  QueueCancelRequest._() : super();
  factory QueueCancelRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory QueueCancelRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'QueueCancelRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'ticket')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  QueueCancelRequest clone() => QueueCancelRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  QueueCancelRequest copyWith(void Function(QueueCancelRequest) updates) => super.copyWith((message) => updates(message as QueueCancelRequest)) as QueueCancelRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueueCancelRequest create() => QueueCancelRequest._();
  QueueCancelRequest createEmptyInstance() => create();
  static $pb.PbList<QueueCancelRequest> createRepeated() => $pb.PbList<QueueCancelRequest>();
  @$core.pragma('dart2js:noInline')
  static QueueCancelRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QueueCancelRequest>(create);
  static QueueCancelRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get ticket => $_getSZ(0);
  @$pb.TagNumber(1)
  set ticket($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTicket() => $_has(0);
  @$pb.TagNumber(1)
  void clearTicket() => clearField(1);
}

/// QueueCancelResponse 取消排队响应
class QueueCancelResponse extends $pb.GeneratedMessage {
  factory QueueCancelResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  QueueCancelResponse._() : super();
  factory QueueCancelResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory QueueCancelResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'QueueCancelResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  QueueCancelResponse clone() => QueueCancelResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  QueueCancelResponse copyWith(void Function(QueueCancelResponse) updates) => super.copyWith((message) => updates(message as QueueCancelResponse)) as QueueCancelResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueueCancelResponse create() => QueueCancelResponse._();
  QueueCancelResponse createEmptyInstance() => create();
  static $pb.PbList<QueueCancelResponse> createRepeated() => $pb.PbList<QueueCancelResponse>();
  @$core.pragma('dart2js:noInline')
  static QueueCancelResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QueueCancelResponse>(create);
  static QueueCancelResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}

/// BatchPresenceJoinSignal 批量跨地图 presence.join 信号
class BatchPresenceJoinSignal extends $pb.GeneratedMessage {
  factory BatchPresenceJoinSignal({
    $core.Iterable<PresenceJoinSignal>? joins,
  }) {
    final $result = create();
    if (joins != null) {
      $result.joins.addAll(joins);
    }
    return $result;
  }
  BatchPresenceJoinSignal._() : super();
  factory BatchPresenceJoinSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BatchPresenceJoinSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BatchPresenceJoinSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..pc<PresenceJoinSignal>(1, _omitFieldNames ? '' : 'joins', $pb.PbFieldType.PM, subBuilder: PresenceJoinSignal.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BatchPresenceJoinSignal clone() => BatchPresenceJoinSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BatchPresenceJoinSignal copyWith(void Function(BatchPresenceJoinSignal) updates) => super.copyWith((message) => updates(message as BatchPresenceJoinSignal)) as BatchPresenceJoinSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchPresenceJoinSignal create() => BatchPresenceJoinSignal._();
  BatchPresenceJoinSignal createEmptyInstance() => create();
  static $pb.PbList<BatchPresenceJoinSignal> createRepeated() => $pb.PbList<BatchPresenceJoinSignal>();
  @$core.pragma('dart2js:noInline')
  static BatchPresenceJoinSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BatchPresenceJoinSignal>(create);
  static BatchPresenceJoinSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<PresenceJoinSignal> get joins => $_getList(0);
}

/// BatchPresenceLeaveSignal 批量跨地图 presence.leave 信号
class BatchPresenceLeaveSignal extends $pb.GeneratedMessage {
  factory BatchPresenceLeaveSignal({
    $core.Iterable<PresenceLeaveSignal>? leaves,
  }) {
    final $result = create();
    if (leaves != null) {
      $result.leaves.addAll(leaves);
    }
    return $result;
  }
  BatchPresenceLeaveSignal._() : super();
  factory BatchPresenceLeaveSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BatchPresenceLeaveSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BatchPresenceLeaveSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..pc<PresenceLeaveSignal>(1, _omitFieldNames ? '' : 'leaves', $pb.PbFieldType.PM, subBuilder: PresenceLeaveSignal.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BatchPresenceLeaveSignal clone() => BatchPresenceLeaveSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BatchPresenceLeaveSignal copyWith(void Function(BatchPresenceLeaveSignal) updates) => super.copyWith((message) => updates(message as BatchPresenceLeaveSignal)) as BatchPresenceLeaveSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchPresenceLeaveSignal create() => BatchPresenceLeaveSignal._();
  BatchPresenceLeaveSignal createEmptyInstance() => create();
  static $pb.PbList<BatchPresenceLeaveSignal> createRepeated() => $pb.PbList<BatchPresenceLeaveSignal>();
  @$core.pragma('dart2js:noInline')
  static BatchPresenceLeaveSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BatchPresenceLeaveSignal>(create);
  static BatchPresenceLeaveSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<PresenceLeaveSignal> get leaves => $_getList(0);
}

enum MatchSignal_Payload {
  kick, 
  assetsUpdated, 
  broadcastMessage, 
  teleportArrival, 
  chatMessage, 
  onlineCountChanged, 
  presenceJoin, 
  presenceLeave, 
  batchPresenceJoin, 
  batchPresenceLeave, 
  notSet
}

/// MatchSignal 管理后台发送的信号
class MatchSignal extends $pb.GeneratedMessage {
  factory MatchSignal({
    $core.String? action,
    KickSignal? kick,
    AssetsUpdatedSignal? assetsUpdated,
    BroadcastMessageSignal? broadcastMessage,
    TeleportArrivalSignal? teleportArrival,
    ChatMessageSignal? chatMessage,
    OnlineCountChangedSignal? onlineCountChanged,
    PresenceJoinSignal? presenceJoin,
    PresenceLeaveSignal? presenceLeave,
    BatchPresenceJoinSignal? batchPresenceJoin,
    BatchPresenceLeaveSignal? batchPresenceLeave,
  }) {
    final $result = create();
    if (action != null) {
      $result.action = action;
    }
    if (kick != null) {
      $result.kick = kick;
    }
    if (assetsUpdated != null) {
      $result.assetsUpdated = assetsUpdated;
    }
    if (broadcastMessage != null) {
      $result.broadcastMessage = broadcastMessage;
    }
    if (teleportArrival != null) {
      $result.teleportArrival = teleportArrival;
    }
    if (chatMessage != null) {
      $result.chatMessage = chatMessage;
    }
    if (onlineCountChanged != null) {
      $result.onlineCountChanged = onlineCountChanged;
    }
    if (presenceJoin != null) {
      $result.presenceJoin = presenceJoin;
    }
    if (presenceLeave != null) {
      $result.presenceLeave = presenceLeave;
    }
    if (batchPresenceJoin != null) {
      $result.batchPresenceJoin = batchPresenceJoin;
    }
    if (batchPresenceLeave != null) {
      $result.batchPresenceLeave = batchPresenceLeave;
    }
    return $result;
  }
  MatchSignal._() : super();
  factory MatchSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, MatchSignal_Payload> _MatchSignal_PayloadByTag = {
    10 : MatchSignal_Payload.kick,
    11 : MatchSignal_Payload.assetsUpdated,
    12 : MatchSignal_Payload.broadcastMessage,
    13 : MatchSignal_Payload.teleportArrival,
    14 : MatchSignal_Payload.chatMessage,
    18 : MatchSignal_Payload.onlineCountChanged,
    19 : MatchSignal_Payload.presenceJoin,
    20 : MatchSignal_Payload.presenceLeave,
    21 : MatchSignal_Payload.batchPresenceJoin,
    22 : MatchSignal_Payload.batchPresenceLeave,
    0 : MatchSignal_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 18, 19, 20, 21, 22])
    ..aOS(1, _omitFieldNames ? '' : 'action')
    ..aOM<KickSignal>(10, _omitFieldNames ? '' : 'kick', subBuilder: KickSignal.create)
    ..aOM<AssetsUpdatedSignal>(11, _omitFieldNames ? '' : 'assetsUpdated', subBuilder: AssetsUpdatedSignal.create)
    ..aOM<BroadcastMessageSignal>(12, _omitFieldNames ? '' : 'broadcastMessage', subBuilder: BroadcastMessageSignal.create)
    ..aOM<TeleportArrivalSignal>(13, _omitFieldNames ? '' : 'teleportArrival', subBuilder: TeleportArrivalSignal.create)
    ..aOM<ChatMessageSignal>(14, _omitFieldNames ? '' : 'chatMessage', subBuilder: ChatMessageSignal.create)
    ..aOM<OnlineCountChangedSignal>(18, _omitFieldNames ? '' : 'onlineCountChanged', subBuilder: OnlineCountChangedSignal.create)
    ..aOM<PresenceJoinSignal>(19, _omitFieldNames ? '' : 'presenceJoin', subBuilder: PresenceJoinSignal.create)
    ..aOM<PresenceLeaveSignal>(20, _omitFieldNames ? '' : 'presenceLeave', subBuilder: PresenceLeaveSignal.create)
    ..aOM<BatchPresenceJoinSignal>(21, _omitFieldNames ? '' : 'batchPresenceJoin', subBuilder: BatchPresenceJoinSignal.create)
    ..aOM<BatchPresenceLeaveSignal>(22, _omitFieldNames ? '' : 'batchPresenceLeave', subBuilder: BatchPresenceLeaveSignal.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchSignal clone() => MatchSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchSignal copyWith(void Function(MatchSignal) updates) => super.copyWith((message) => updates(message as MatchSignal)) as MatchSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchSignal create() => MatchSignal._();
  MatchSignal createEmptyInstance() => create();
  static $pb.PbList<MatchSignal> createRepeated() => $pb.PbList<MatchSignal>();
  @$core.pragma('dart2js:noInline')
  static MatchSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchSignal>(create);
  static MatchSignal? _defaultInstance;

  MatchSignal_Payload whichPayload() => _MatchSignal_PayloadByTag[$_whichOneof(0)]!;
  void clearPayload() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get action => $_getSZ(0);
  @$pb.TagNumber(1)
  set action($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAction() => $_has(0);
  @$pb.TagNumber(1)
  void clearAction() => clearField(1);

  @$pb.TagNumber(10)
  KickSignal get kick => $_getN(1);
  @$pb.TagNumber(10)
  set kick(KickSignal v) { setField(10, v); }
  @$pb.TagNumber(10)
  $core.bool hasKick() => $_has(1);
  @$pb.TagNumber(10)
  void clearKick() => clearField(10);
  @$pb.TagNumber(10)
  KickSignal ensureKick() => $_ensure(1);

  @$pb.TagNumber(11)
  AssetsUpdatedSignal get assetsUpdated => $_getN(2);
  @$pb.TagNumber(11)
  set assetsUpdated(AssetsUpdatedSignal v) { setField(11, v); }
  @$pb.TagNumber(11)
  $core.bool hasAssetsUpdated() => $_has(2);
  @$pb.TagNumber(11)
  void clearAssetsUpdated() => clearField(11);
  @$pb.TagNumber(11)
  AssetsUpdatedSignal ensureAssetsUpdated() => $_ensure(2);

  @$pb.TagNumber(12)
  BroadcastMessageSignal get broadcastMessage => $_getN(3);
  @$pb.TagNumber(12)
  set broadcastMessage(BroadcastMessageSignal v) { setField(12, v); }
  @$pb.TagNumber(12)
  $core.bool hasBroadcastMessage() => $_has(3);
  @$pb.TagNumber(12)
  void clearBroadcastMessage() => clearField(12);
  @$pb.TagNumber(12)
  BroadcastMessageSignal ensureBroadcastMessage() => $_ensure(3);

  @$pb.TagNumber(13)
  TeleportArrivalSignal get teleportArrival => $_getN(4);
  @$pb.TagNumber(13)
  set teleportArrival(TeleportArrivalSignal v) { setField(13, v); }
  @$pb.TagNumber(13)
  $core.bool hasTeleportArrival() => $_has(4);
  @$pb.TagNumber(13)
  void clearTeleportArrival() => clearField(13);
  @$pb.TagNumber(13)
  TeleportArrivalSignal ensureTeleportArrival() => $_ensure(4);

  @$pb.TagNumber(14)
  ChatMessageSignal get chatMessage => $_getN(5);
  @$pb.TagNumber(14)
  set chatMessage(ChatMessageSignal v) { setField(14, v); }
  @$pb.TagNumber(14)
  $core.bool hasChatMessage() => $_has(5);
  @$pb.TagNumber(14)
  void clearChatMessage() => clearField(14);
  @$pb.TagNumber(14)
  ChatMessageSignal ensureChatMessage() => $_ensure(5);

  @$pb.TagNumber(18)
  OnlineCountChangedSignal get onlineCountChanged => $_getN(6);
  @$pb.TagNumber(18)
  set onlineCountChanged(OnlineCountChangedSignal v) { setField(18, v); }
  @$pb.TagNumber(18)
  $core.bool hasOnlineCountChanged() => $_has(6);
  @$pb.TagNumber(18)
  void clearOnlineCountChanged() => clearField(18);
  @$pb.TagNumber(18)
  OnlineCountChangedSignal ensureOnlineCountChanged() => $_ensure(6);

  @$pb.TagNumber(19)
  PresenceJoinSignal get presenceJoin => $_getN(7);
  @$pb.TagNumber(19)
  set presenceJoin(PresenceJoinSignal v) { setField(19, v); }
  @$pb.TagNumber(19)
  $core.bool hasPresenceJoin() => $_has(7);
  @$pb.TagNumber(19)
  void clearPresenceJoin() => clearField(19);
  @$pb.TagNumber(19)
  PresenceJoinSignal ensurePresenceJoin() => $_ensure(7);

  @$pb.TagNumber(20)
  PresenceLeaveSignal get presenceLeave => $_getN(8);
  @$pb.TagNumber(20)
  set presenceLeave(PresenceLeaveSignal v) { setField(20, v); }
  @$pb.TagNumber(20)
  $core.bool hasPresenceLeave() => $_has(8);
  @$pb.TagNumber(20)
  void clearPresenceLeave() => clearField(20);
  @$pb.TagNumber(20)
  PresenceLeaveSignal ensurePresenceLeave() => $_ensure(8);

  @$pb.TagNumber(21)
  BatchPresenceJoinSignal get batchPresenceJoin => $_getN(9);
  @$pb.TagNumber(21)
  set batchPresenceJoin(BatchPresenceJoinSignal v) { setField(21, v); }
  @$pb.TagNumber(21)
  $core.bool hasBatchPresenceJoin() => $_has(9);
  @$pb.TagNumber(21)
  void clearBatchPresenceJoin() => clearField(21);
  @$pb.TagNumber(21)
  BatchPresenceJoinSignal ensureBatchPresenceJoin() => $_ensure(9);

  @$pb.TagNumber(22)
  BatchPresenceLeaveSignal get batchPresenceLeave => $_getN(10);
  @$pb.TagNumber(22)
  set batchPresenceLeave(BatchPresenceLeaveSignal v) { setField(22, v); }
  @$pb.TagNumber(22)
  $core.bool hasBatchPresenceLeave() => $_has(10);
  @$pb.TagNumber(22)
  void clearBatchPresenceLeave() => clearField(22);
  @$pb.TagNumber(22)
  BatchPresenceLeaveSignal ensureBatchPresenceLeave() => $_ensure(10);
}

/// PresenceJoinSignal 跨 Match 用户进入通知信号（仅通知，不含坐标，不渲染）
class PresenceJoinSignal extends $pb.GeneratedMessage {
  factory PresenceJoinSignal({
    $core.String? userId,
    $core.String? nickname,
    $core.String? avatarUrl,
    $core.bool? isAnonymous,
    $core.String? mapId,
    $core.String? businessUserId,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    if (avatarUrl != null) {
      $result.avatarUrl = avatarUrl;
    }
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    if (mapId != null) {
      $result.mapId = mapId;
    }
    if (businessUserId != null) {
      $result.businessUserId = businessUserId;
    }
    return $result;
  }
  PresenceJoinSignal._() : super();
  factory PresenceJoinSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PresenceJoinSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PresenceJoinSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..aOS(3, _omitFieldNames ? '' : 'avatarUrl')
    ..aOB(4, _omitFieldNames ? '' : 'isAnonymous')
    ..aOS(5, _omitFieldNames ? '' : 'mapId')
    ..aOS(6, _omitFieldNames ? '' : 'businessUserId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PresenceJoinSignal clone() => PresenceJoinSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PresenceJoinSignal copyWith(void Function(PresenceJoinSignal) updates) => super.copyWith((message) => updates(message as PresenceJoinSignal)) as PresenceJoinSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PresenceJoinSignal create() => PresenceJoinSignal._();
  PresenceJoinSignal createEmptyInstance() => create();
  static $pb.PbList<PresenceJoinSignal> createRepeated() => $pb.PbList<PresenceJoinSignal>();
  @$core.pragma('dart2js:noInline')
  static PresenceJoinSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PresenceJoinSignal>(create);
  static PresenceJoinSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get avatarUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set avatarUrl($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAvatarUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatarUrl() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isAnonymous => $_getBF(3);
  @$pb.TagNumber(4)
  set isAnonymous($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIsAnonymous() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsAnonymous() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get mapId => $_getSZ(4);
  @$pb.TagNumber(5)
  set mapId($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasMapId() => $_has(4);
  @$pb.TagNumber(5)
  void clearMapId() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get businessUserId => $_getSZ(5);
  @$pb.TagNumber(6)
  set businessUserId($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasBusinessUserId() => $_has(5);
  @$pb.TagNumber(6)
  void clearBusinessUserId() => clearField(6);
}

/// PresenceLeaveSignal 跨 Match 用户离开通知信号
class PresenceLeaveSignal extends $pb.GeneratedMessage {
  factory PresenceLeaveSignal({
    $core.String? userId,
    $core.String? mapId,
    $core.String? targetMapId,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (mapId != null) {
      $result.mapId = mapId;
    }
    if (targetMapId != null) {
      $result.targetMapId = targetMapId;
    }
    return $result;
  }
  PresenceLeaveSignal._() : super();
  factory PresenceLeaveSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PresenceLeaveSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PresenceLeaveSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'mapId')
    ..aOS(3, _omitFieldNames ? '' : 'targetMapId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PresenceLeaveSignal clone() => PresenceLeaveSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PresenceLeaveSignal copyWith(void Function(PresenceLeaveSignal) updates) => super.copyWith((message) => updates(message as PresenceLeaveSignal)) as PresenceLeaveSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PresenceLeaveSignal create() => PresenceLeaveSignal._();
  PresenceLeaveSignal createEmptyInstance() => create();
  static $pb.PbList<PresenceLeaveSignal> createRepeated() => $pb.PbList<PresenceLeaveSignal>();
  @$core.pragma('dart2js:noInline')
  static PresenceLeaveSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PresenceLeaveSignal>(create);
  static PresenceLeaveSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get mapId => $_getSZ(1);
  @$pb.TagNumber(2)
  set mapId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMapId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMapId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get targetMapId => $_getSZ(2);
  @$pb.TagNumber(3)
  set targetMapId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTargetMapId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetMapId() => clearField(3);
}

/// KickSignal 踢人信号
class KickSignal extends $pb.GeneratedMessage {
  factory KickSignal({
    $core.String? userId,
    $core.String? reason,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  KickSignal._() : super();
  factory KickSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory KickSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'KickSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  KickSignal clone() => KickSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  KickSignal copyWith(void Function(KickSignal) updates) => super.copyWith((message) => updates(message as KickSignal)) as KickSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KickSignal create() => KickSignal._();
  KickSignal createEmptyInstance() => create();
  static $pb.PbList<KickSignal> createRepeated() => $pb.PbList<KickSignal>();
  @$core.pragma('dart2js:noInline')
  static KickSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KickSignal>(create);
  static KickSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => clearField(2);
}

/// AssetsUpdatedSignal 素材更新信号
class AssetsUpdatedSignal extends $pb.GeneratedMessage {
  factory AssetsUpdatedSignal({
    $core.String? updateType,
    $core.String? message,
  }) {
    final $result = create();
    if (updateType != null) {
      $result.updateType = updateType;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  AssetsUpdatedSignal._() : super();
  factory AssetsUpdatedSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AssetsUpdatedSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AssetsUpdatedSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'updateType')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AssetsUpdatedSignal clone() => AssetsUpdatedSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AssetsUpdatedSignal copyWith(void Function(AssetsUpdatedSignal) updates) => super.copyWith((message) => updates(message as AssetsUpdatedSignal)) as AssetsUpdatedSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssetsUpdatedSignal create() => AssetsUpdatedSignal._();
  AssetsUpdatedSignal createEmptyInstance() => create();
  static $pb.PbList<AssetsUpdatedSignal> createRepeated() => $pb.PbList<AssetsUpdatedSignal>();
  @$core.pragma('dart2js:noInline')
  static AssetsUpdatedSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AssetsUpdatedSignal>(create);
  static AssetsUpdatedSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get updateType => $_getSZ(0);
  @$pb.TagNumber(1)
  set updateType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUpdateType() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpdateType() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

/// BroadcastMessageSignal 跨 Match 全服广播信号
class BroadcastMessageSignal extends $pb.GeneratedMessage {
  factory BroadcastMessageSignal({
    $core.String? messageId,
    $core.String? userId,
    $core.String? nickname,
    $core.String? avatarUrl,
    $core.String? content,
    $fixnum.Int64? timestamp,
  }) {
    final $result = create();
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    if (avatarUrl != null) {
      $result.avatarUrl = avatarUrl;
    }
    if (content != null) {
      $result.content = content;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  BroadcastMessageSignal._() : super();
  factory BroadcastMessageSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastMessageSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BroadcastMessageSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'nickname')
    ..aOS(4, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(5, _omitFieldNames ? '' : 'content')
    ..aInt64(6, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastMessageSignal clone() => BroadcastMessageSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastMessageSignal copyWith(void Function(BroadcastMessageSignal) updates) => super.copyWith((message) => updates(message as BroadcastMessageSignal)) as BroadcastMessageSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastMessageSignal create() => BroadcastMessageSignal._();
  BroadcastMessageSignal createEmptyInstance() => create();
  static $pb.PbList<BroadcastMessageSignal> createRepeated() => $pb.PbList<BroadcastMessageSignal>();
  @$core.pragma('dart2js:noInline')
  static BroadcastMessageSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BroadcastMessageSignal>(create);
  static BroadcastMessageSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get nickname => $_getSZ(2);
  @$pb.TagNumber(3)
  set nickname($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNickname() => $_has(2);
  @$pb.TagNumber(3)
  void clearNickname() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get avatarUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set avatarUrl($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAvatarUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvatarUrl() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get content => $_getSZ(4);
  @$pb.TagNumber(5)
  set content($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasContent() => $_has(4);
  @$pb.TagNumber(5)
  void clearContent() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get timestamp => $_getI64(5);
  @$pb.TagNumber(6)
  set timestamp($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTimestamp() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestamp() => clearField(6);
}

/// TeleportArrivalSignal 传送到达信号（源地图 → 目标地图）
/// 由源地图的 handlePortalUse 通过 MatchSignal 发送给目标地图，
/// 目标地图在 MatchSignal 回调中缓存到 pendingTeleports，
/// MatchJoin 时从本地内存读取，彻底消除 Storage 竞态。
class TeleportArrivalSignal extends $pb.GeneratedMessage {
  factory TeleportArrivalSignal({
    $core.String? userId,
    $core.String? sourceMapId,
    $core.double? targetX,
    $core.double? targetY,
    $fixnum.Int64? issuedAt,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (sourceMapId != null) {
      $result.sourceMapId = sourceMapId;
    }
    if (targetX != null) {
      $result.targetX = targetX;
    }
    if (targetY != null) {
      $result.targetY = targetY;
    }
    if (issuedAt != null) {
      $result.issuedAt = issuedAt;
    }
    return $result;
  }
  TeleportArrivalSignal._() : super();
  factory TeleportArrivalSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TeleportArrivalSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TeleportArrivalSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'sourceMapId')
    ..a<$core.double>(3, _omitFieldNames ? '' : 'targetX', $pb.PbFieldType.OD)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'targetY', $pb.PbFieldType.OD)
    ..aInt64(5, _omitFieldNames ? '' : 'issuedAt')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TeleportArrivalSignal clone() => TeleportArrivalSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TeleportArrivalSignal copyWith(void Function(TeleportArrivalSignal) updates) => super.copyWith((message) => updates(message as TeleportArrivalSignal)) as TeleportArrivalSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TeleportArrivalSignal create() => TeleportArrivalSignal._();
  TeleportArrivalSignal createEmptyInstance() => create();
  static $pb.PbList<TeleportArrivalSignal> createRepeated() => $pb.PbList<TeleportArrivalSignal>();
  @$core.pragma('dart2js:noInline')
  static TeleportArrivalSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TeleportArrivalSignal>(create);
  static TeleportArrivalSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get sourceMapId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sourceMapId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSourceMapId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceMapId() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get targetX => $_getN(2);
  @$pb.TagNumber(3)
  set targetX($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTargetX() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetX() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get targetY => $_getN(3);
  @$pb.TagNumber(4)
  set targetY($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTargetY() => $_has(3);
  @$pb.TagNumber(4)
  void clearTargetY() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get issuedAt => $_getI64(4);
  @$pb.TagNumber(5)
  set issuedAt($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasIssuedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearIssuedAt() => clearField(5);
}

/// ChatMessageSignal 跨 Match 聊天消息信号
class ChatMessageSignal extends $pb.GeneratedMessage {
  factory ChatMessageSignal({
    $core.String? messageId,
    $core.String? userId,
    $core.String? nickname,
    $core.String? content,
    $core.String? messageType,
    $core.bool? isAnonymous,
    $fixnum.Int64? timestamp,
  }) {
    final $result = create();
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (nickname != null) {
      $result.nickname = nickname;
    }
    if (content != null) {
      $result.content = content;
    }
    if (messageType != null) {
      $result.messageType = messageType;
    }
    if (isAnonymous != null) {
      $result.isAnonymous = isAnonymous;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  ChatMessageSignal._() : super();
  factory ChatMessageSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ChatMessageSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ChatMessageSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'nickname')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aOS(5, _omitFieldNames ? '' : 'messageType')
    ..aOB(6, _omitFieldNames ? '' : 'isAnonymous')
    ..aInt64(7, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ChatMessageSignal clone() => ChatMessageSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ChatMessageSignal copyWith(void Function(ChatMessageSignal) updates) => super.copyWith((message) => updates(message as ChatMessageSignal)) as ChatMessageSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatMessageSignal create() => ChatMessageSignal._();
  ChatMessageSignal createEmptyInstance() => create();
  static $pb.PbList<ChatMessageSignal> createRepeated() => $pb.PbList<ChatMessageSignal>();
  @$core.pragma('dart2js:noInline')
  static ChatMessageSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatMessageSignal>(create);
  static ChatMessageSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get nickname => $_getSZ(2);
  @$pb.TagNumber(3)
  set nickname($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNickname() => $_has(2);
  @$pb.TagNumber(3)
  void clearNickname() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get messageType => $_getSZ(4);
  @$pb.TagNumber(5)
  set messageType($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasMessageType() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageType() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isAnonymous => $_getBF(5);
  @$pb.TagNumber(6)
  set isAnonymous($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsAnonymous() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsAnonymous() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get timestamp => $_getI64(6);
  @$pb.TagNumber(7)
  set timestamp($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasTimestamp() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestamp() => clearField(7);
}

/// OnlineCountChangedSignal 全服在线人数变更信号
class OnlineCountChangedSignal extends $pb.GeneratedMessage {
  factory OnlineCountChangedSignal({
    $core.int? total,
    $core.Map<$core.String, $core.int>? byMap,
  }) {
    final $result = create();
    if (total != null) {
      $result.total = total;
    }
    if (byMap != null) {
      $result.byMap.addAll(byMap);
    }
    return $result;
  }
  OnlineCountChangedSignal._() : super();
  factory OnlineCountChangedSignal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory OnlineCountChangedSignal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'OnlineCountChangedSignal', package: const $pb.PackageName(_omitMessageNames ? '' : 'lobby'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'total', $pb.PbFieldType.O3)
    ..m<$core.String, $core.int>(2, _omitFieldNames ? '' : 'byMap', entryClassName: 'OnlineCountChangedSignal.ByMapEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.O3, packageName: const $pb.PackageName('lobby'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  OnlineCountChangedSignal clone() => OnlineCountChangedSignal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  OnlineCountChangedSignal copyWith(void Function(OnlineCountChangedSignal) updates) => super.copyWith((message) => updates(message as OnlineCountChangedSignal)) as OnlineCountChangedSignal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OnlineCountChangedSignal create() => OnlineCountChangedSignal._();
  OnlineCountChangedSignal createEmptyInstance() => create();
  static $pb.PbList<OnlineCountChangedSignal> createRepeated() => $pb.PbList<OnlineCountChangedSignal>();
  @$core.pragma('dart2js:noInline')
  static OnlineCountChangedSignal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OnlineCountChangedSignal>(create);
  static OnlineCountChangedSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get total => $_getIZ(0);
  @$pb.TagNumber(1)
  set total($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTotal() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotal() => clearField(1);

  @$pb.TagNumber(2)
  $core.Map<$core.String, $core.int> get byMap => $_getMap(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
