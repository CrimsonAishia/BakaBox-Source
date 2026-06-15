//
//  Generated code. Do not modify.
//  source: proto/lobby.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use lobbyEnvelopeDescriptor instead')
const LobbyEnvelope$json = {
  '1': 'LobbyEnvelope',
  '2': [
    {'1': 'v', '3': 1, '4': 1, '5': 5, '10': 'v'},
    {'1': 'type', '3': 2, '4': 1, '5': 9, '10': 'type'},
    {'1': 'ts', '3': 3, '4': 1, '5': 3, '10': 'ts'},
    {'1': 'trace_id', '3': 4, '4': 1, '5': 9, '10': 'traceId'},
    {'1': 'login_request', '3': 10, '4': 1, '5': 11, '6': '.lobby.LoginRequest', '9': 0, '10': 'loginRequest'},
    {'1': 'logout_request', '3': 11, '4': 1, '5': 11, '6': '.lobby.LogoutRequest', '9': 0, '10': 'logoutRequest'},
    {'1': 'move_request', '3': 12, '4': 1, '5': 11, '6': '.lobby.MoveRequest', '9': 0, '10': 'moveRequest'},
    {'1': 'chat_send_request', '3': 13, '4': 1, '5': 11, '6': '.lobby.ChatSendRequest', '9': 0, '10': 'chatSendRequest'},
    {'1': 'profile_anonymous_change_request', '3': 14, '4': 1, '5': 11, '6': '.lobby.ProfileAnonymousChangeRequest', '9': 0, '10': 'profileAnonymousChangeRequest'},
    {'1': 'profile_sprite_change_request', '3': 15, '4': 1, '5': 11, '6': '.lobby.ProfileSpriteChangeRequest', '9': 0, '10': 'profileSpriteChangeRequest'},
    {'1': 'profile_status_text_update_request', '3': 16, '4': 1, '5': 11, '6': '.lobby.ProfileStatusTextUpdateRequest', '9': 0, '10': 'profileStatusTextUpdateRequest'},
    {'1': 'profile_display_name_update_request', '3': 17, '4': 1, '5': 11, '6': '.lobby.ProfileDisplayNameUpdateRequest', '9': 0, '10': 'profileDisplayNameUpdateRequest'},
    {'1': 'snapshot_request', '3': 18, '4': 1, '5': 11, '6': '.lobby.SnapshotRequest', '9': 0, '10': 'snapshotRequest'},
    {'1': 'assets_request', '3': 19, '4': 1, '5': 11, '6': '.lobby.AssetsRequest', '9': 0, '10': 'assetsRequest'},
    {'1': 'broadcast_send_request', '3': 20, '4': 1, '5': 11, '6': '.lobby.BroadcastSendRequest', '9': 0, '10': 'broadcastSendRequest'},
    {'1': 'broadcast_cd_request', '3': 21, '4': 1, '5': 11, '6': '.lobby.BroadcastCDRequest', '9': 0, '10': 'broadcastCdRequest'},
    {'1': 'portal_use_request', '3': 22, '4': 1, '5': 11, '6': '.lobby.PortalUseRequest', '9': 0, '10': 'portalUseRequest'},
    {'1': 'online_stats_request', '3': 23, '4': 1, '5': 11, '6': '.lobby.OnlineStatsRequest', '9': 0, '10': 'onlineStatsRequest'},
    {'1': 'profile_steam_bind_request', '3': 24, '4': 1, '5': 11, '6': '.lobby.ProfileSteamBindRequest', '9': 0, '10': 'profileSteamBindRequest'},
    {'1': 'enter_request', '3': 25, '4': 1, '5': 11, '6': '.lobby.EnterRequest', '9': 0, '10': 'enterRequest'},
    {'1': 'mode_change_request', '3': 26, '4': 1, '5': 11, '6': '.lobby.ModeChangeRequest', '9': 0, '10': 'modeChangeRequest'},
    {'1': 'login_success_response', '3': 50, '4': 1, '5': 11, '6': '.lobby.LoginSuccessResponse', '9': 0, '10': 'loginSuccessResponse'},
    {'1': 'login_failed_response', '3': 51, '4': 1, '5': 11, '6': '.lobby.LoginFailedResponse', '9': 0, '10': 'loginFailedResponse'},
    {'1': 'logout_success_response', '3': 52, '4': 1, '5': 11, '6': '.lobby.LogoutSuccessResponse', '9': 0, '10': 'logoutSuccessResponse'},
    {'1': 'join_success_response', '3': 53, '4': 1, '5': 11, '6': '.lobby.JoinSuccessResponse', '9': 0, '10': 'joinSuccessResponse'},
    {'1': 'snapshot_response', '3': 54, '4': 1, '5': 11, '6': '.lobby.SnapshotResponse', '9': 0, '10': 'snapshotResponse'},
    {'1': 'presence_join_response', '3': 55, '4': 1, '5': 11, '6': '.lobby.PresenceJoinResponse', '9': 0, '10': 'presenceJoinResponse'},
    {'1': 'presence_leave_response', '3': 56, '4': 1, '5': 11, '6': '.lobby.PresenceLeaveResponse', '9': 0, '10': 'presenceLeaveResponse'},
    {'1': 'identity_changed_response', '3': 57, '4': 1, '5': 11, '6': '.lobby.IdentityChangedResponse', '9': 0, '10': 'identityChangedResponse'},
    {'1': 'move_broadcast_response', '3': 58, '4': 1, '5': 11, '6': '.lobby.MoveBroadcastResponse', '9': 0, '10': 'moveBroadcastResponse'},
    {'1': 'move_reject_response', '3': 59, '4': 1, '5': 11, '6': '.lobby.MoveRejectResponse', '9': 0, '10': 'moveRejectResponse'},
    {'1': 'chat_message_response', '3': 60, '4': 1, '5': 11, '6': '.lobby.ChatMessageResponse', '9': 0, '10': 'chatMessageResponse'},
    {'1': 'chat_reject_response', '3': 61, '4': 1, '5': 11, '6': '.lobby.ChatRejectResponse', '9': 0, '10': 'chatRejectResponse'},
    {'1': 'anonymous_changed_response', '3': 62, '4': 1, '5': 11, '6': '.lobby.AnonymousChangedResponse', '9': 0, '10': 'anonymousChangedResponse'},
    {'1': 'sprite_changed_response', '3': 63, '4': 1, '5': 11, '6': '.lobby.SpriteChangedResponse', '9': 0, '10': 'spriteChangedResponse'},
    {'1': 'sprite_change_reject_response', '3': 64, '4': 1, '5': 11, '6': '.lobby.SpriteChangeRejectResponse', '9': 0, '10': 'spriteChangeRejectResponse'},
    {'1': 'status_text_broadcast_response', '3': 65, '4': 1, '5': 11, '6': '.lobby.StatusTextBroadcastResponse', '9': 0, '10': 'statusTextBroadcastResponse'},
    {'1': 'display_name_changed_response', '3': 66, '4': 1, '5': 11, '6': '.lobby.DisplayNameChangedResponse', '9': 0, '10': 'displayNameChangedResponse'},
    {'1': 'assets_response', '3': 67, '4': 1, '5': 11, '6': '.lobby.AssetsResponse', '9': 0, '10': 'assetsResponse'},
    {'1': 'assets_updated_response', '3': 68, '4': 1, '5': 11, '6': '.lobby.AssetsUpdatedResponse', '9': 0, '10': 'assetsUpdatedResponse'},
    {'1': 'portal_teleport_response', '3': 69, '4': 1, '5': 11, '6': '.lobby.PortalTeleportResponse', '9': 0, '10': 'portalTeleportResponse'},
    {'1': 'portal_use_reject_response', '3': 70, '4': 1, '5': 11, '6': '.lobby.PortalUseRejectResponse', '9': 0, '10': 'portalUseRejectResponse'},
    {'1': 'broadcast_message_response', '3': 71, '4': 1, '5': 11, '6': '.lobby.BroadcastMessageResponse', '9': 0, '10': 'broadcastMessageResponse'},
    {'1': 'broadcast_reject_response', '3': 72, '4': 1, '5': 11, '6': '.lobby.BroadcastRejectResponse', '9': 0, '10': 'broadcastRejectResponse'},
    {'1': 'broadcast_cd_response', '3': 73, '4': 1, '5': 11, '6': '.lobby.BroadcastCDResponse', '9': 0, '10': 'broadcastCdResponse'},
    {'1': 'online_stats_response', '3': 74, '4': 1, '5': 11, '6': '.lobby.OnlineStatsResponse', '9': 0, '10': 'onlineStatsResponse'},
    {'1': 'system_error_response', '3': 75, '4': 1, '5': 11, '6': '.lobby.SystemErrorResponse', '9': 0, '10': 'systemErrorResponse'},
    {'1': 'system_notice_response', '3': 76, '4': 1, '5': 11, '6': '.lobby.SystemNoticeResponse', '9': 0, '10': 'systemNoticeResponse'},
    {'1': 'system_kicked_response', '3': 77, '4': 1, '5': 11, '6': '.lobby.SystemKickedResponse', '9': 0, '10': 'systemKickedResponse'},
    {'1': 'steam_bind_success_response', '3': 78, '4': 1, '5': 11, '6': '.lobby.SteamBindSuccessResponse', '9': 0, '10': 'steamBindSuccessResponse'},
    {'1': 'sprite_change_success_response', '3': 79, '4': 1, '5': 11, '6': '.lobby.SpriteChangeSuccessResponse', '9': 0, '10': 'spriteChangeSuccessResponse'},
    {'1': 'presence_delta_response', '3': 80, '4': 1, '5': 11, '6': '.lobby.PresenceDeltaResponse', '9': 0, '10': 'presenceDeltaResponse'},
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `LobbyEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyEnvelopeDescriptor = $convert.base64Decode(
    'Cg1Mb2JieUVudmVsb3BlEgwKAXYYASABKAVSAXYSEgoEdHlwZRgCIAEoCVIEdHlwZRIOCgJ0cx'
    'gDIAEoA1ICdHMSGQoIdHJhY2VfaWQYBCABKAlSB3RyYWNlSWQSOgoNbG9naW5fcmVxdWVzdBgK'
    'IAEoCzITLmxvYmJ5LkxvZ2luUmVxdWVzdEgAUgxsb2dpblJlcXVlc3QSPQoObG9nb3V0X3JlcX'
    'Vlc3QYCyABKAsyFC5sb2JieS5Mb2dvdXRSZXF1ZXN0SABSDWxvZ291dFJlcXVlc3QSNwoMbW92'
    'ZV9yZXF1ZXN0GAwgASgLMhIubG9iYnkuTW92ZVJlcXVlc3RIAFILbW92ZVJlcXVlc3QSRAoRY2'
    'hhdF9zZW5kX3JlcXVlc3QYDSABKAsyFi5sb2JieS5DaGF0U2VuZFJlcXVlc3RIAFIPY2hhdFNl'
    'bmRSZXF1ZXN0Em8KIHByb2ZpbGVfYW5vbnltb3VzX2NoYW5nZV9yZXF1ZXN0GA4gASgLMiQubG'
    '9iYnkuUHJvZmlsZUFub255bW91c0NoYW5nZVJlcXVlc3RIAFIdcHJvZmlsZUFub255bW91c0No'
    'YW5nZVJlcXVlc3QSZgodcHJvZmlsZV9zcHJpdGVfY2hhbmdlX3JlcXVlc3QYDyABKAsyIS5sb2'
    'JieS5Qcm9maWxlU3ByaXRlQ2hhbmdlUmVxdWVzdEgAUhpwcm9maWxlU3ByaXRlQ2hhbmdlUmVx'
    'dWVzdBJzCiJwcm9maWxlX3N0YXR1c190ZXh0X3VwZGF0ZV9yZXF1ZXN0GBAgASgLMiUubG9iYn'
    'kuUHJvZmlsZVN0YXR1c1RleHRVcGRhdGVSZXF1ZXN0SABSHnByb2ZpbGVTdGF0dXNUZXh0VXBk'
    'YXRlUmVxdWVzdBJ2CiNwcm9maWxlX2Rpc3BsYXlfbmFtZV91cGRhdGVfcmVxdWVzdBgRIAEoCz'
    'ImLmxvYmJ5LlByb2ZpbGVEaXNwbGF5TmFtZVVwZGF0ZVJlcXVlc3RIAFIfcHJvZmlsZURpc3Bs'
    'YXlOYW1lVXBkYXRlUmVxdWVzdBJDChBzbmFwc2hvdF9yZXF1ZXN0GBIgASgLMhYubG9iYnkuU2'
    '5hcHNob3RSZXF1ZXN0SABSD3NuYXBzaG90UmVxdWVzdBI9Cg5hc3NldHNfcmVxdWVzdBgTIAEo'
    'CzIULmxvYmJ5LkFzc2V0c1JlcXVlc3RIAFINYXNzZXRzUmVxdWVzdBJTChZicm9hZGNhc3Rfc2'
    'VuZF9yZXF1ZXN0GBQgASgLMhsubG9iYnkuQnJvYWRjYXN0U2VuZFJlcXVlc3RIAFIUYnJvYWRj'
    'YXN0U2VuZFJlcXVlc3QSTQoUYnJvYWRjYXN0X2NkX3JlcXVlc3QYFSABKAsyGS5sb2JieS5Ccm'
    '9hZGNhc3RDRFJlcXVlc3RIAFISYnJvYWRjYXN0Q2RSZXF1ZXN0EkcKEnBvcnRhbF91c2VfcmVx'
    'dWVzdBgWIAEoCzIXLmxvYmJ5LlBvcnRhbFVzZVJlcXVlc3RIAFIQcG9ydGFsVXNlUmVxdWVzdB'
    'JNChRvbmxpbmVfc3RhdHNfcmVxdWVzdBgXIAEoCzIZLmxvYmJ5Lk9ubGluZVN0YXRzUmVxdWVz'
    'dEgAUhJvbmxpbmVTdGF0c1JlcXVlc3QSXQoacHJvZmlsZV9zdGVhbV9iaW5kX3JlcXVlc3QYGC'
    'ABKAsyHi5sb2JieS5Qcm9maWxlU3RlYW1CaW5kUmVxdWVzdEgAUhdwcm9maWxlU3RlYW1CaW5k'
    'UmVxdWVzdBI6Cg1lbnRlcl9yZXF1ZXN0GBkgASgLMhMubG9iYnkuRW50ZXJSZXF1ZXN0SABSDG'
    'VudGVyUmVxdWVzdBJKChNtb2RlX2NoYW5nZV9yZXF1ZXN0GBogASgLMhgubG9iYnkuTW9kZUNo'
    'YW5nZVJlcXVlc3RIAFIRbW9kZUNoYW5nZVJlcXVlc3QSUwoWbG9naW5fc3VjY2Vzc19yZXNwb2'
    '5zZRgyIAEoCzIbLmxvYmJ5LkxvZ2luU3VjY2Vzc1Jlc3BvbnNlSABSFGxvZ2luU3VjY2Vzc1Jl'
    'c3BvbnNlElAKFWxvZ2luX2ZhaWxlZF9yZXNwb25zZRgzIAEoCzIaLmxvYmJ5LkxvZ2luRmFpbG'
    'VkUmVzcG9uc2VIAFITbG9naW5GYWlsZWRSZXNwb25zZRJWChdsb2dvdXRfc3VjY2Vzc19yZXNw'
    'b25zZRg0IAEoCzIcLmxvYmJ5LkxvZ291dFN1Y2Nlc3NSZXNwb25zZUgAUhVsb2dvdXRTdWNjZX'
    'NzUmVzcG9uc2USUAoVam9pbl9zdWNjZXNzX3Jlc3BvbnNlGDUgASgLMhoubG9iYnkuSm9pblN1'
    'Y2Nlc3NSZXNwb25zZUgAUhNqb2luU3VjY2Vzc1Jlc3BvbnNlEkYKEXNuYXBzaG90X3Jlc3Bvbn'
    'NlGDYgASgLMhcubG9iYnkuU25hcHNob3RSZXNwb25zZUgAUhBzbmFwc2hvdFJlc3BvbnNlElMK'
    'FnByZXNlbmNlX2pvaW5fcmVzcG9uc2UYNyABKAsyGy5sb2JieS5QcmVzZW5jZUpvaW5SZXNwb2'
    '5zZUgAUhRwcmVzZW5jZUpvaW5SZXNwb25zZRJWChdwcmVzZW5jZV9sZWF2ZV9yZXNwb25zZRg4'
    'IAEoCzIcLmxvYmJ5LlByZXNlbmNlTGVhdmVSZXNwb25zZUgAUhVwcmVzZW5jZUxlYXZlUmVzcG'
    '9uc2USXAoZaWRlbnRpdHlfY2hhbmdlZF9yZXNwb25zZRg5IAEoCzIeLmxvYmJ5LklkZW50aXR5'
    'Q2hhbmdlZFJlc3BvbnNlSABSF2lkZW50aXR5Q2hhbmdlZFJlc3BvbnNlElYKF21vdmVfYnJvYW'
    'RjYXN0X3Jlc3BvbnNlGDogASgLMhwubG9iYnkuTW92ZUJyb2FkY2FzdFJlc3BvbnNlSABSFW1v'
    'dmVCcm9hZGNhc3RSZXNwb25zZRJNChRtb3ZlX3JlamVjdF9yZXNwb25zZRg7IAEoCzIZLmxvYm'
    'J5Lk1vdmVSZWplY3RSZXNwb25zZUgAUhJtb3ZlUmVqZWN0UmVzcG9uc2USUAoVY2hhdF9tZXNz'
    'YWdlX3Jlc3BvbnNlGDwgASgLMhoubG9iYnkuQ2hhdE1lc3NhZ2VSZXNwb25zZUgAUhNjaGF0TW'
    'Vzc2FnZVJlc3BvbnNlEk0KFGNoYXRfcmVqZWN0X3Jlc3BvbnNlGD0gASgLMhkubG9iYnkuQ2hh'
    'dFJlamVjdFJlc3BvbnNlSABSEmNoYXRSZWplY3RSZXNwb25zZRJfChphbm9ueW1vdXNfY2hhbm'
    'dlZF9yZXNwb25zZRg+IAEoCzIfLmxvYmJ5LkFub255bW91c0NoYW5nZWRSZXNwb25zZUgAUhhh'
    'bm9ueW1vdXNDaGFuZ2VkUmVzcG9uc2USVgoXc3ByaXRlX2NoYW5nZWRfcmVzcG9uc2UYPyABKA'
    'syHC5sb2JieS5TcHJpdGVDaGFuZ2VkUmVzcG9uc2VIAFIVc3ByaXRlQ2hhbmdlZFJlc3BvbnNl'
    'EmYKHXNwcml0ZV9jaGFuZ2VfcmVqZWN0X3Jlc3BvbnNlGEAgASgLMiEubG9iYnkuU3ByaXRlQ2'
    'hhbmdlUmVqZWN0UmVzcG9uc2VIAFIac3ByaXRlQ2hhbmdlUmVqZWN0UmVzcG9uc2USaQoec3Rh'
    'dHVzX3RleHRfYnJvYWRjYXN0X3Jlc3BvbnNlGEEgASgLMiIubG9iYnkuU3RhdHVzVGV4dEJyb2'
    'FkY2FzdFJlc3BvbnNlSABSG3N0YXR1c1RleHRCcm9hZGNhc3RSZXNwb25zZRJmCh1kaXNwbGF5'
    'X25hbWVfY2hhbmdlZF9yZXNwb25zZRhCIAEoCzIhLmxvYmJ5LkRpc3BsYXlOYW1lQ2hhbmdlZF'
    'Jlc3BvbnNlSABSGmRpc3BsYXlOYW1lQ2hhbmdlZFJlc3BvbnNlEkAKD2Fzc2V0c19yZXNwb25z'
    'ZRhDIAEoCzIVLmxvYmJ5LkFzc2V0c1Jlc3BvbnNlSABSDmFzc2V0c1Jlc3BvbnNlElYKF2Fzc2'
    'V0c191cGRhdGVkX3Jlc3BvbnNlGEQgASgLMhwubG9iYnkuQXNzZXRzVXBkYXRlZFJlc3BvbnNl'
    'SABSFWFzc2V0c1VwZGF0ZWRSZXNwb25zZRJZChhwb3J0YWxfdGVsZXBvcnRfcmVzcG9uc2UYRS'
    'ABKAsyHS5sb2JieS5Qb3J0YWxUZWxlcG9ydFJlc3BvbnNlSABSFnBvcnRhbFRlbGVwb3J0UmVz'
    'cG9uc2USXQoacG9ydGFsX3VzZV9yZWplY3RfcmVzcG9uc2UYRiABKAsyHi5sb2JieS5Qb3J0YW'
    'xVc2VSZWplY3RSZXNwb25zZUgAUhdwb3J0YWxVc2VSZWplY3RSZXNwb25zZRJfChpicm9hZGNh'
    'c3RfbWVzc2FnZV9yZXNwb25zZRhHIAEoCzIfLmxvYmJ5LkJyb2FkY2FzdE1lc3NhZ2VSZXNwb2'
    '5zZUgAUhhicm9hZGNhc3RNZXNzYWdlUmVzcG9uc2USXAoZYnJvYWRjYXN0X3JlamVjdF9yZXNw'
    'b25zZRhIIAEoCzIeLmxvYmJ5LkJyb2FkY2FzdFJlamVjdFJlc3BvbnNlSABSF2Jyb2FkY2FzdF'
    'JlamVjdFJlc3BvbnNlElAKFWJyb2FkY2FzdF9jZF9yZXNwb25zZRhJIAEoCzIaLmxvYmJ5LkJy'
    'b2FkY2FzdENEUmVzcG9uc2VIAFITYnJvYWRjYXN0Q2RSZXNwb25zZRJQChVvbmxpbmVfc3RhdH'
    'NfcmVzcG9uc2UYSiABKAsyGi5sb2JieS5PbmxpbmVTdGF0c1Jlc3BvbnNlSABSE29ubGluZVN0'
    'YXRzUmVzcG9uc2USUAoVc3lzdGVtX2Vycm9yX3Jlc3BvbnNlGEsgASgLMhoubG9iYnkuU3lzdG'
    'VtRXJyb3JSZXNwb25zZUgAUhNzeXN0ZW1FcnJvclJlc3BvbnNlElMKFnN5c3RlbV9ub3RpY2Vf'
    'cmVzcG9uc2UYTCABKAsyGy5sb2JieS5TeXN0ZW1Ob3RpY2VSZXNwb25zZUgAUhRzeXN0ZW1Ob3'
    'RpY2VSZXNwb25zZRJTChZzeXN0ZW1fa2lja2VkX3Jlc3BvbnNlGE0gASgLMhsubG9iYnkuU3lz'
    'dGVtS2lja2VkUmVzcG9uc2VIAFIUc3lzdGVtS2lja2VkUmVzcG9uc2USYAobc3RlYW1fYmluZF'
    '9zdWNjZXNzX3Jlc3BvbnNlGE4gASgLMh8ubG9iYnkuU3RlYW1CaW5kU3VjY2Vzc1Jlc3BvbnNl'
    'SABSGHN0ZWFtQmluZFN1Y2Nlc3NSZXNwb25zZRJpCh5zcHJpdGVfY2hhbmdlX3N1Y2Nlc3Nfcm'
    'VzcG9uc2UYTyABKAsyIi5sb2JieS5TcHJpdGVDaGFuZ2VTdWNjZXNzUmVzcG9uc2VIAFIbc3By'
    'aXRlQ2hhbmdlU3VjY2Vzc1Jlc3BvbnNlElYKF3ByZXNlbmNlX2RlbHRhX3Jlc3BvbnNlGFAgAS'
    'gLMhwubG9iYnkuUHJlc2VuY2VEZWx0YVJlc3BvbnNlSABSFXByZXNlbmNlRGVsdGFSZXNwb25z'
    'ZUIJCgdwYXlsb2Fk');

@$core.Deprecated('Use lobbyUserDescriptor instead')
const LobbyUser$json = {
  '1': 'LobbyUser',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'steam_name', '3': 3, '4': 1, '5': 9, '10': 'steamName'},
    {'1': 'sprite_id', '3': 4, '4': 1, '5': 9, '10': 'spriteId'},
    {'1': 'avatar_url', '3': 5, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'x', '3': 6, '4': 1, '5': 1, '10': 'x'},
    {'1': 'y', '3': 7, '4': 1, '5': 1, '10': 'y'},
    {'1': 'facing', '3': 8, '4': 1, '5': 9, '10': 'facing'},
    {'1': 'is_online', '3': 9, '4': 1, '5': 8, '10': 'isOnline'},
    {'1': 'is_anonymous', '3': 10, '4': 1, '5': 8, '10': 'isAnonymous'},
    {'1': 'status_text', '3': 11, '4': 1, '5': 9, '10': 'statusText'},
    {'1': 'last_message', '3': 12, '4': 1, '5': 9, '10': 'lastMessage'},
    {'1': 'steam_id', '3': 13, '4': 1, '5': 9, '10': 'steamId'},
    {'1': 'business_user_id', '3': 14, '4': 1, '5': 9, '10': 'businessUserId'},
    {'1': 'map_id', '3': 15, '4': 1, '5': 9, '10': 'mapId'},
  ],
};

/// Descriptor for `LobbyUser`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyUserDescriptor = $convert.base64Decode(
    'CglMb2JieVVzZXISFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCG5pY2tuYW1lGAIgASgJUg'
    'huaWNrbmFtZRIdCgpzdGVhbV9uYW1lGAMgASgJUglzdGVhbU5hbWUSGwoJc3ByaXRlX2lkGAQg'
    'ASgJUghzcHJpdGVJZBIdCgphdmF0YXJfdXJsGAUgASgJUglhdmF0YXJVcmwSDAoBeBgGIAEoAV'
    'IBeBIMCgF5GAcgASgBUgF5EhYKBmZhY2luZxgIIAEoCVIGZmFjaW5nEhsKCWlzX29ubGluZRgJ'
    'IAEoCFIIaXNPbmxpbmUSIQoMaXNfYW5vbnltb3VzGAogASgIUgtpc0Fub255bW91cxIfCgtzdG'
    'F0dXNfdGV4dBgLIAEoCVIKc3RhdHVzVGV4dBIhCgxsYXN0X21lc3NhZ2UYDCABKAlSC2xhc3RN'
    'ZXNzYWdlEhkKCHN0ZWFtX2lkGA0gASgJUgdzdGVhbUlkEigKEGJ1c2luZXNzX3VzZXJfaWQYDi'
    'ABKAlSDmJ1c2luZXNzVXNlcklkEhUKBm1hcF9pZBgPIAEoCVIFbWFwSWQ=');

@$core.Deprecated('Use lobbyMessageDescriptor instead')
const LobbyMessage$json = {
  '1': 'LobbyMessage',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 3, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'type', '3': 5, '4': 1, '5': 9, '10': 'type'},
    {'1': 'is_anonymous', '3': 6, '4': 1, '5': 8, '10': 'isAnonymous'},
    {'1': 'timestamp', '3': 7, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `LobbyMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyMessageDescriptor = $convert.base64Decode(
    'CgxMb2JieU1lc3NhZ2USHQoKbWVzc2FnZV9pZBgBIAEoCVIJbWVzc2FnZUlkEhcKB3VzZXJfaW'
    'QYAiABKAlSBnVzZXJJZBIaCghuaWNrbmFtZRgDIAEoCVIIbmlja25hbWUSGAoHY29udGVudBgE'
    'IAEoCVIHY29udGVudBISCgR0eXBlGAUgASgJUgR0eXBlEiEKDGlzX2Fub255bW91cxgGIAEoCF'
    'ILaXNBbm9ueW1vdXMSHAoJdGltZXN0YW1wGAcgASgDUgl0aW1lc3RhbXA=');

@$core.Deprecated('Use lobbyBroadcastMessageDescriptor instead')
const LobbyBroadcastMessage$json = {
  '1': 'LobbyBroadcastMessage',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 3, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'avatar_url', '3': 6, '4': 1, '5': 9, '10': 'avatarUrl'},
  ],
};

/// Descriptor for `LobbyBroadcastMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyBroadcastMessageDescriptor = $convert.base64Decode(
    'ChVMb2JieUJyb2FkY2FzdE1lc3NhZ2USHQoKbWVzc2FnZV9pZBgBIAEoCVIJbWVzc2FnZUlkEh'
    'cKB3VzZXJfaWQYAiABKAlSBnVzZXJJZBIaCghuaWNrbmFtZRgDIAEoCVIIbmlja25hbWUSGAoH'
    'Y29udGVudBgEIAEoCVIHY29udGVudBIcCgl0aW1lc3RhbXAYBSABKANSCXRpbWVzdGFtcBIdCg'
    'phdmF0YXJfdXJsGAYgASgJUglhdmF0YXJVcmw=');

@$core.Deprecated('Use lobbyMapConfigDescriptor instead')
const LobbyMapConfig$json = {
  '1': 'LobbyMapConfig',
  '2': [
    {'1': 'map_id', '3': 1, '4': 1, '5': 9, '10': 'mapId'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'background_url', '3': 3, '4': 1, '5': 9, '10': 'backgroundUrl'},
    {'1': 'width', '3': 4, '4': 1, '5': 1, '10': 'width'},
    {'1': 'height', '3': 5, '4': 1, '5': 1, '10': 'height'},
    {'1': 'walkable_areas', '3': 6, '4': 3, '5': 11, '6': '.lobby.LobbyWalkableArea', '10': 'walkableAreas'},
    {'1': 'portals', '3': 7, '4': 3, '5': 11, '6': '.lobby.LobbyPortal', '10': 'portals'},
    {'1': 'is_default', '3': 8, '4': 1, '5': 8, '10': 'isDefault'},
  ],
};

/// Descriptor for `LobbyMapConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyMapConfigDescriptor = $convert.base64Decode(
    'Cg5Mb2JieU1hcENvbmZpZxIVCgZtYXBfaWQYASABKAlSBW1hcElkEhQKBWxhYmVsGAIgASgJUg'
    'VsYWJlbBIlCg5iYWNrZ3JvdW5kX3VybBgDIAEoCVINYmFja2dyb3VuZFVybBIUCgV3aWR0aBgE'
    'IAEoAVIFd2lkdGgSFgoGaGVpZ2h0GAUgASgBUgZoZWlnaHQSPwoOd2Fsa2FibGVfYXJlYXMYBi'
    'ADKAsyGC5sb2JieS5Mb2JieVdhbGthYmxlQXJlYVINd2Fsa2FibGVBcmVhcxIsCgdwb3J0YWxz'
    'GAcgAygLMhIubG9iYnkuTG9iYnlQb3J0YWxSB3BvcnRhbHMSHQoKaXNfZGVmYXVsdBgIIAEoCF'
    'IJaXNEZWZhdWx0');

@$core.Deprecated('Use lobbyWalkableAreaDescriptor instead')
const LobbyWalkableArea$json = {
  '1': 'LobbyWalkableArea',
  '2': [
    {'1': 'left', '3': 1, '4': 1, '5': 1, '10': 'left'},
    {'1': 'top', '3': 2, '4': 1, '5': 1, '10': 'top'},
    {'1': 'right', '3': 3, '4': 1, '5': 1, '10': 'right'},
    {'1': 'bottom', '3': 4, '4': 1, '5': 1, '10': 'bottom'},
  ],
};

/// Descriptor for `LobbyWalkableArea`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyWalkableAreaDescriptor = $convert.base64Decode(
    'ChFMb2JieVdhbGthYmxlQXJlYRISCgRsZWZ0GAEgASgBUgRsZWZ0EhAKA3RvcBgCIAEoAVIDdG'
    '9wEhQKBXJpZ2h0GAMgASgBUgVyaWdodBIWCgZib3R0b20YBCABKAFSBmJvdHRvbQ==');

@$core.Deprecated('Use lobbyPortalDescriptor instead')
const LobbyPortal$json = {
  '1': 'LobbyPortal',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'x', '3': 3, '4': 1, '5': 1, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 1, '10': 'y'},
    {'1': 'target_map_id', '3': 5, '4': 1, '5': 9, '10': 'targetMapId'},
    {'1': 'target_x', '3': 6, '4': 1, '5': 1, '10': 'targetX'},
    {'1': 'target_y', '3': 7, '4': 1, '5': 1, '10': 'targetY'},
  ],
};

/// Descriptor for `LobbyPortal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyPortalDescriptor = $convert.base64Decode(
    'CgtMb2JieVBvcnRhbBIQCgNrZXkYASABKAlSA2tleRIUCgVsYWJlbBgCIAEoCVIFbGFiZWwSDA'
    'oBeBgDIAEoAVIBeBIMCgF5GAQgASgBUgF5EiIKDXRhcmdldF9tYXBfaWQYBSABKAlSC3Rhcmdl'
    'dE1hcElkEhkKCHRhcmdldF94GAYgASgBUgd0YXJnZXRYEhkKCHRhcmdldF95GAcgASgBUgd0YX'
    'JnZXRZ');

@$core.Deprecated('Use lobbySpriteConfigDescriptor instead')
const LobbySpriteConfig$json = {
  '1': 'LobbySpriteConfig',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'accent_color', '3': 3, '4': 1, '5': 9, '10': 'accentColor'},
    {'1': 'sprite_url', '3': 4, '4': 1, '5': 9, '10': 'spriteUrl'},
    {'1': 'preview_url', '3': 5, '4': 1, '5': 9, '10': 'previewUrl'},
    {'1': 'is_default', '3': 6, '4': 1, '5': 8, '10': 'isDefault'},
  ],
};

/// Descriptor for `LobbySpriteConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbySpriteConfigDescriptor = $convert.base64Decode(
    'ChFMb2JieVNwcml0ZUNvbmZpZxIOCgJpZBgBIAEoCVICaWQSFAoFbGFiZWwYAiABKAlSBWxhYm'
    'VsEiEKDGFjY2VudF9jb2xvchgDIAEoCVILYWNjZW50Q29sb3ISHQoKc3ByaXRlX3VybBgEIAEo'
    'CVIJc3ByaXRlVXJsEh8KC3ByZXZpZXdfdXJsGAUgASgJUgpwcmV2aWV3VXJsEh0KCmlzX2RlZm'
    'F1bHQYBiABKAhSCWlzRGVmYXVsdA==');

@$core.Deprecated('Use pageInfoDescriptor instead')
const PageInfo$json = {
  '1': 'PageInfo',
  '2': [
    {'1': 'current_page', '3': 1, '4': 1, '5': 5, '10': 'currentPage'},
    {'1': 'total_pages', '3': 2, '4': 1, '5': 5, '10': 'totalPages'},
    {'1': 'page_size', '3': 3, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'total_users', '3': 4, '4': 1, '5': 5, '10': 'totalUsers'},
  ],
};

/// Descriptor for `PageInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageInfoDescriptor = $convert.base64Decode(
    'CghQYWdlSW5mbxIhCgxjdXJyZW50X3BhZ2UYASABKAVSC2N1cnJlbnRQYWdlEh8KC3RvdGFsX3'
    'BhZ2VzGAIgASgFUgp0b3RhbFBhZ2VzEhsKCXBhZ2Vfc2l6ZRgDIAEoBVIIcGFnZVNpemUSHwoL'
    'dG90YWxfdXNlcnMYBCABKAVSCnRvdGFsVXNlcnM=');

@$core.Deprecated('Use loginRequestDescriptor instead')
const LoginRequest$json = {
  '1': 'LoginRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'device_type', '3': 2, '4': 1, '5': 9, '10': 'deviceType'},
    {'1': 'is_anonymous', '3': 3, '4': 1, '5': 8, '10': 'isAnonymous'},
  ],
};

/// Descriptor for `LoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginRequestDescriptor = $convert.base64Decode(
    'CgxMb2dpblJlcXVlc3QSFAoFdG9rZW4YASABKAlSBXRva2VuEh8KC2RldmljZV90eXBlGAIgAS'
    'gJUgpkZXZpY2VUeXBlEiEKDGlzX2Fub255bW91cxgDIAEoCFILaXNBbm9ueW1vdXM=');

@$core.Deprecated('Use enterRequestDescriptor instead')
const EnterRequest$json = {
  '1': 'EnterRequest',
  '2': [
    {'1': 'protocol_features', '3': 1, '4': 1, '5': 5, '10': 'protocolFeatures'},
    {'1': 'low_bandwidth', '3': 2, '4': 1, '5': 8, '10': 'lowBandwidth'},
  ],
};

/// Descriptor for `EnterRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enterRequestDescriptor = $convert.base64Decode(
    'CgxFbnRlclJlcXVlc3QSKwoRcHJvdG9jb2xfZmVhdHVyZXMYASABKAVSEHByb3RvY29sRmVhdH'
    'VyZXMSIwoNbG93X2JhbmR3aWR0aBgCIAEoCFIMbG93QmFuZHdpZHRo');

@$core.Deprecated('Use modeChangeRequestDescriptor instead')
const ModeChangeRequest$json = {
  '1': 'ModeChangeRequest',
  '2': [
    {'1': 'low_bandwidth', '3': 1, '4': 1, '5': 8, '10': 'lowBandwidth'},
  ],
};

/// Descriptor for `ModeChangeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modeChangeRequestDescriptor = $convert.base64Decode(
    'ChFNb2RlQ2hhbmdlUmVxdWVzdBIjCg1sb3dfYmFuZHdpZHRoGAEgASgIUgxsb3dCYW5kd2lkdG'
    'g=');

@$core.Deprecated('Use logoutRequestDescriptor instead')
const LogoutRequest$json = {
  '1': 'LogoutRequest',
  '2': [
    {'1': 'force', '3': 1, '4': 1, '5': 8, '10': 'force'},
  ],
};

/// Descriptor for `LogoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutRequestDescriptor = $convert.base64Decode(
    'Cg1Mb2dvdXRSZXF1ZXN0EhQKBWZvcmNlGAEgASgIUgVmb3JjZQ==');

@$core.Deprecated('Use moveRequestDescriptor instead')
const MoveRequest$json = {
  '1': 'MoveRequest',
  '2': [
    {'1': 'target_x', '3': 1, '4': 1, '5': 1, '10': 'targetX'},
    {'1': 'target_y', '3': 2, '4': 1, '5': 1, '10': 'targetY'},
  ],
};

/// Descriptor for `MoveRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveRequestDescriptor = $convert.base64Decode(
    'CgtNb3ZlUmVxdWVzdBIZCgh0YXJnZXRfeBgBIAEoAVIHdGFyZ2V0WBIZCgh0YXJnZXRfeRgCIA'
    'EoAVIHdGFyZ2V0WQ==');

@$core.Deprecated('Use chatSendRequestDescriptor instead')
const ChatSendRequest$json = {
  '1': 'ChatSendRequest',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 9, '10': 'content'},
  ],
};

/// Descriptor for `ChatSendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatSendRequestDescriptor = $convert.base64Decode(
    'Cg9DaGF0U2VuZFJlcXVlc3QSGAoHY29udGVudBgBIAEoCVIHY29udGVudA==');

@$core.Deprecated('Use profileAnonymousChangeRequestDescriptor instead')
const ProfileAnonymousChangeRequest$json = {
  '1': 'ProfileAnonymousChangeRequest',
  '2': [
    {'1': 'is_anonymous', '3': 1, '4': 1, '5': 8, '10': 'isAnonymous'},
  ],
};

/// Descriptor for `ProfileAnonymousChangeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileAnonymousChangeRequestDescriptor = $convert.base64Decode(
    'Ch1Qcm9maWxlQW5vbnltb3VzQ2hhbmdlUmVxdWVzdBIhCgxpc19hbm9ueW1vdXMYASABKAhSC2'
    'lzQW5vbnltb3Vz');

@$core.Deprecated('Use profileSpriteChangeRequestDescriptor instead')
const ProfileSpriteChangeRequest$json = {
  '1': 'ProfileSpriteChangeRequest',
  '2': [
    {'1': 'sprite_id', '3': 1, '4': 1, '5': 9, '10': 'spriteId'},
  ],
};

/// Descriptor for `ProfileSpriteChangeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileSpriteChangeRequestDescriptor = $convert.base64Decode(
    'ChpQcm9maWxlU3ByaXRlQ2hhbmdlUmVxdWVzdBIbCglzcHJpdGVfaWQYASABKAlSCHNwcml0ZU'
    'lk');

@$core.Deprecated('Use profileStatusTextUpdateRequestDescriptor instead')
const ProfileStatusTextUpdateRequest$json = {
  '1': 'ProfileStatusTextUpdateRequest',
  '2': [
    {'1': 'status_text', '3': 1, '4': 1, '5': 9, '10': 'statusText'},
  ],
};

/// Descriptor for `ProfileStatusTextUpdateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileStatusTextUpdateRequestDescriptor = $convert.base64Decode(
    'Ch5Qcm9maWxlU3RhdHVzVGV4dFVwZGF0ZVJlcXVlc3QSHwoLc3RhdHVzX3RleHQYASABKAlSCn'
    'N0YXR1c1RleHQ=');

@$core.Deprecated('Use profileDisplayNameUpdateRequestDescriptor instead')
const ProfileDisplayNameUpdateRequest$json = {
  '1': 'ProfileDisplayNameUpdateRequest',
  '2': [
    {'1': 'custom_name', '3': 1, '4': 1, '5': 9, '10': 'customName'},
    {'1': 'steam_name', '3': 2, '4': 1, '5': 9, '10': 'steamName'},
  ],
};

/// Descriptor for `ProfileDisplayNameUpdateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileDisplayNameUpdateRequestDescriptor = $convert.base64Decode(
    'Ch9Qcm9maWxlRGlzcGxheU5hbWVVcGRhdGVSZXF1ZXN0Eh8KC2N1c3RvbV9uYW1lGAEgASgJUg'
    'pjdXN0b21OYW1lEh0KCnN0ZWFtX25hbWUYAiABKAlSCXN0ZWFtTmFtZQ==');

@$core.Deprecated('Use profileSteamBindRequestDescriptor instead')
const ProfileSteamBindRequest$json = {
  '1': 'ProfileSteamBindRequest',
  '2': [
    {'1': 'steam_id', '3': 1, '4': 1, '5': 9, '10': 'steamId'},
    {'1': 'steam_name', '3': 2, '4': 1, '5': 9, '10': 'steamName'},
  ],
};

/// Descriptor for `ProfileSteamBindRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileSteamBindRequestDescriptor = $convert.base64Decode(
    'ChdQcm9maWxlU3RlYW1CaW5kUmVxdWVzdBIZCghzdGVhbV9pZBgBIAEoCVIHc3RlYW1JZBIdCg'
    'pzdGVhbV9uYW1lGAIgASgJUglzdGVhbU5hbWU=');

@$core.Deprecated('Use snapshotRequestDescriptor instead')
const SnapshotRequest$json = {
  '1': 'SnapshotRequest',
  '2': [
    {'1': 'last_delta_seq', '3': 1, '4': 1, '5': 3, '10': 'lastDeltaSeq'},
  ],
};

/// Descriptor for `SnapshotRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotRequestDescriptor = $convert.base64Decode(
    'Cg9TbmFwc2hvdFJlcXVlc3QSJAoObGFzdF9kZWx0YV9zZXEYASABKANSDGxhc3REZWx0YVNlcQ'
    '==');

@$core.Deprecated('Use assetsRequestDescriptor instead')
const AssetsRequest$json = {
  '1': 'AssetsRequest',
};

/// Descriptor for `AssetsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetsRequestDescriptor = $convert.base64Decode(
    'Cg1Bc3NldHNSZXF1ZXN0');

@$core.Deprecated('Use broadcastSendRequestDescriptor instead')
const BroadcastSendRequest$json = {
  '1': 'BroadcastSendRequest',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 9, '10': 'content'},
  ],
};

/// Descriptor for `BroadcastSendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastSendRequestDescriptor = $convert.base64Decode(
    'ChRCcm9hZGNhc3RTZW5kUmVxdWVzdBIYCgdjb250ZW50GAEgASgJUgdjb250ZW50');

@$core.Deprecated('Use broadcastCDRequestDescriptor instead')
const BroadcastCDRequest$json = {
  '1': 'BroadcastCDRequest',
};

/// Descriptor for `BroadcastCDRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastCDRequestDescriptor = $convert.base64Decode(
    'ChJCcm9hZGNhc3RDRFJlcXVlc3Q=');

@$core.Deprecated('Use portalUseRequestDescriptor instead')
const PortalUseRequest$json = {
  '1': 'PortalUseRequest',
  '2': [
    {'1': 'portal_key', '3': 1, '4': 1, '5': 9, '10': 'portalKey'},
  ],
};

/// Descriptor for `PortalUseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List portalUseRequestDescriptor = $convert.base64Decode(
    'ChBQb3J0YWxVc2VSZXF1ZXN0Eh0KCnBvcnRhbF9rZXkYASABKAlSCXBvcnRhbEtleQ==');

@$core.Deprecated('Use onlineStatsRequestDescriptor instead')
const OnlineStatsRequest$json = {
  '1': 'OnlineStatsRequest',
  '2': [
    {'1': 'include_users', '3': 1, '4': 1, '5': 8, '10': 'includeUsers'},
  ],
};

/// Descriptor for `OnlineStatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List onlineStatsRequestDescriptor = $convert.base64Decode(
    'ChJPbmxpbmVTdGF0c1JlcXVlc3QSIwoNaW5jbHVkZV91c2VycxgBIAEoCFIMaW5jbHVkZVVzZX'
    'Jz');

@$core.Deprecated('Use loginSuccessResponseDescriptor instead')
const LoginSuccessResponse$json = {
  '1': 'LoginSuccessResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
  ],
};

/// Descriptor for `LoginSuccessResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginSuccessResponseDescriptor = $convert.base64Decode(
    'ChRMb2dpblN1Y2Nlc3NSZXNwb25zZRIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSGgoIbmlja2'
    '5hbWUYAiABKAlSCG5pY2tuYW1l');

@$core.Deprecated('Use loginFailedResponseDescriptor instead')
const LoginFailedResponse$json = {
  '1': 'LoginFailedResponse',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 5, '10': 'code'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `LoginFailedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginFailedResponseDescriptor = $convert.base64Decode(
    'ChNMb2dpbkZhaWxlZFJlc3BvbnNlEhIKBGNvZGUYASABKAVSBGNvZGUSFgoGcmVhc29uGAIgAS'
    'gJUgZyZWFzb24=');

@$core.Deprecated('Use logoutSuccessResponseDescriptor instead')
const LogoutSuccessResponse$json = {
  '1': 'LogoutSuccessResponse',
  '2': [
    {'1': 'kick', '3': 1, '4': 1, '5': 8, '10': 'kick'},
  ],
};

/// Descriptor for `LogoutSuccessResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutSuccessResponseDescriptor = $convert.base64Decode(
    'ChVMb2dvdXRTdWNjZXNzUmVzcG9uc2USEgoEa2ljaxgBIAEoCFIEa2ljaw==');

@$core.Deprecated('Use joinSuccessResponseDescriptor instead')
const JoinSuccessResponse$json = {
  '1': 'JoinSuccessResponse',
  '2': [
    {'1': 'map_id', '3': 1, '4': 1, '5': 9, '10': 'mapId'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.lobby.LobbyUser', '10': 'user'},
    {'1': 'online_count', '3': 3, '4': 1, '5': 5, '10': 'onlineCount'},
  ],
};

/// Descriptor for `JoinSuccessResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinSuccessResponseDescriptor = $convert.base64Decode(
    'ChNKb2luU3VjY2Vzc1Jlc3BvbnNlEhUKBm1hcF9pZBgBIAEoCVIFbWFwSWQSJAoEdXNlchgCIA'
    'EoCzIQLmxvYmJ5LkxvYmJ5VXNlclIEdXNlchIhCgxvbmxpbmVfY291bnQYAyABKAVSC29ubGlu'
    'ZUNvdW50');

@$core.Deprecated('Use snapshotResponseDescriptor instead')
const SnapshotResponse$json = {
  '1': 'SnapshotResponse',
  '2': [
    {'1': 'map_config', '3': 1, '4': 1, '5': 11, '6': '.lobby.LobbyMapConfig', '10': 'mapConfig'},
    {'1': 'self', '3': 2, '4': 1, '5': 11, '6': '.lobby.LobbyUser', '10': 'self'},
    {'1': 'users', '3': 3, '4': 3, '5': 11, '6': '.lobby.LobbyUser', '10': 'users'},
    {'1': 'recent_messages', '3': 4, '4': 3, '5': 11, '6': '.lobby.LobbyMessage', '10': 'recentMessages'},
    {'1': 'page_info', '3': 5, '4': 1, '5': 11, '6': '.lobby.PageInfo', '10': 'pageInfo'},
    {'1': 'is_resume', '3': 6, '4': 1, '5': 8, '10': 'isResume'},
    {'1': 'left_user_ids', '3': 7, '4': 3, '5': 9, '10': 'leftUserIds'},
    {'1': 'delta_seq', '3': 8, '4': 1, '5': 3, '10': 'deltaSeq'},
  ],
};

/// Descriptor for `SnapshotResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotResponseDescriptor = $convert.base64Decode(
    'ChBTbmFwc2hvdFJlc3BvbnNlEjQKCm1hcF9jb25maWcYASABKAsyFS5sb2JieS5Mb2JieU1hcE'
    'NvbmZpZ1IJbWFwQ29uZmlnEiQKBHNlbGYYAiABKAsyEC5sb2JieS5Mb2JieVVzZXJSBHNlbGYS'
    'JgoFdXNlcnMYAyADKAsyEC5sb2JieS5Mb2JieVVzZXJSBXVzZXJzEjwKD3JlY2VudF9tZXNzYW'
    'dlcxgEIAMoCzITLmxvYmJ5LkxvYmJ5TWVzc2FnZVIOcmVjZW50TWVzc2FnZXMSLAoJcGFnZV9p'
    'bmZvGAUgASgLMg8ubG9iYnkuUGFnZUluZm9SCHBhZ2VJbmZvEhsKCWlzX3Jlc3VtZRgGIAEoCF'
    'IIaXNSZXN1bWUSIgoNbGVmdF91c2VyX2lkcxgHIAMoCVILbGVmdFVzZXJJZHMSGwoJZGVsdGFf'
    'c2VxGAggASgDUghkZWx0YVNlcQ==');

@$core.Deprecated('Use presenceJoinResponseDescriptor instead')
const PresenceJoinResponse$json = {
  '1': 'PresenceJoinResponse',
  '2': [
    {'1': 'user', '3': 1, '4': 1, '5': 11, '6': '.lobby.LobbyUser', '10': 'user'},
    {'1': 'source_map_id', '3': 2, '4': 1, '5': 9, '10': 'sourceMapId'},
    {'1': 'is_cross_map_notification', '3': 3, '4': 1, '5': 8, '10': 'isCrossMapNotification'},
  ],
};

/// Descriptor for `PresenceJoinResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List presenceJoinResponseDescriptor = $convert.base64Decode(
    'ChRQcmVzZW5jZUpvaW5SZXNwb25zZRIkCgR1c2VyGAEgASgLMhAubG9iYnkuTG9iYnlVc2VyUg'
    'R1c2VyEiIKDXNvdXJjZV9tYXBfaWQYAiABKAlSC3NvdXJjZU1hcElkEjkKGWlzX2Nyb3NzX21h'
    'cF9ub3RpZmljYXRpb24YAyABKAhSFmlzQ3Jvc3NNYXBOb3RpZmljYXRpb24=');

@$core.Deprecated('Use presenceLeaveResponseDescriptor instead')
const PresenceLeaveResponse$json = {
  '1': 'PresenceLeaveResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'target_map_id', '3': 2, '4': 1, '5': 9, '10': 'targetMapId'},
  ],
};

/// Descriptor for `PresenceLeaveResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List presenceLeaveResponseDescriptor = $convert.base64Decode(
    'ChVQcmVzZW5jZUxlYXZlUmVzcG9uc2USFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEiIKDXRhcm'
    'dldF9tYXBfaWQYAiABKAlSC3RhcmdldE1hcElk');

@$core.Deprecated('Use identityChangedResponseDescriptor instead')
const IdentityChangedResponse$json = {
  '1': 'IdentityChangedResponse',
  '2': [
    {'1': 'session_key', '3': 1, '4': 1, '5': 9, '10': 'sessionKey'},
    {'1': 'old_user_id', '3': 2, '4': 1, '5': 9, '10': 'oldUserId'},
    {'1': 'new_user_id', '3': 3, '4': 1, '5': 9, '10': 'newUserId'},
    {'1': 'nickname', '3': 4, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'avatar_url', '3': 5, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'sprite_id', '3': 6, '4': 1, '5': 9, '10': 'spriteId'},
    {'1': 'is_anonymous', '3': 7, '4': 1, '5': 8, '10': 'isAnonymous'},
    {'1': 'business_user_id', '3': 8, '4': 1, '5': 9, '10': 'businessUserId'},
  ],
};

/// Descriptor for `IdentityChangedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List identityChangedResponseDescriptor = $convert.base64Decode(
    'ChdJZGVudGl0eUNoYW5nZWRSZXNwb25zZRIfCgtzZXNzaW9uX2tleRgBIAEoCVIKc2Vzc2lvbk'
    'tleRIeCgtvbGRfdXNlcl9pZBgCIAEoCVIJb2xkVXNlcklkEh4KC25ld191c2VyX2lkGAMgASgJ'
    'UgluZXdVc2VySWQSGgoIbmlja25hbWUYBCABKAlSCG5pY2tuYW1lEh0KCmF2YXRhcl91cmwYBS'
    'ABKAlSCWF2YXRhclVybBIbCglzcHJpdGVfaWQYBiABKAlSCHNwcml0ZUlkEiEKDGlzX2Fub255'
    'bW91cxgHIAEoCFILaXNBbm9ueW1vdXMSKAoQYnVzaW5lc3NfdXNlcl9pZBgIIAEoCVIOYnVzaW'
    '5lc3NVc2VySWQ=');

@$core.Deprecated('Use moveBroadcastResponseDescriptor instead')
const MoveBroadcastResponse$json = {
  '1': 'MoveBroadcastResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'target_x', '3': 2, '4': 1, '5': 1, '10': 'targetX'},
    {'1': 'target_y', '3': 3, '4': 1, '5': 1, '10': 'targetY'},
    {'1': 'facing', '3': 4, '4': 1, '5': 9, '10': 'facing'},
  ],
};

/// Descriptor for `MoveBroadcastResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveBroadcastResponseDescriptor = $convert.base64Decode(
    'ChVNb3ZlQnJvYWRjYXN0UmVzcG9uc2USFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhkKCHRhcm'
    'dldF94GAIgASgBUgd0YXJnZXRYEhkKCHRhcmdldF95GAMgASgBUgd0YXJnZXRZEhYKBmZhY2lu'
    'ZxgEIAEoCVIGZmFjaW5n');

@$core.Deprecated('Use moveRejectResponseDescriptor instead')
const MoveRejectResponse$json = {
  '1': 'MoveRejectResponse',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'correction_x', '3': 2, '4': 1, '5': 1, '10': 'correctionX'},
    {'1': 'correction_y', '3': 3, '4': 1, '5': 1, '10': 'correctionY'},
  ],
};

/// Descriptor for `MoveRejectResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveRejectResponseDescriptor = $convert.base64Decode(
    'ChJNb3ZlUmVqZWN0UmVzcG9uc2USFgoGcmVhc29uGAEgASgJUgZyZWFzb24SIQoMY29ycmVjdG'
    'lvbl94GAIgASgBUgtjb3JyZWN0aW9uWBIhCgxjb3JyZWN0aW9uX3kYAyABKAFSC2NvcnJlY3Rp'
    'b25Z');

@$core.Deprecated('Use chatMessageResponseDescriptor instead')
const ChatMessageResponse$json = {
  '1': 'ChatMessageResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 11, '6': '.lobby.LobbyMessage', '10': 'message'},
  ],
};

/// Descriptor for `ChatMessageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageResponseDescriptor = $convert.base64Decode(
    'ChNDaGF0TWVzc2FnZVJlc3BvbnNlEi0KB21lc3NhZ2UYASABKAsyEy5sb2JieS5Mb2JieU1lc3'
    'NhZ2VSB21lc3NhZ2U=');

@$core.Deprecated('Use chatRejectResponseDescriptor instead')
const ChatRejectResponse$json = {
  '1': 'ChatRejectResponse',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `ChatRejectResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatRejectResponseDescriptor = $convert.base64Decode(
    'ChJDaGF0UmVqZWN0UmVzcG9uc2USFgoGcmVhc29uGAEgASgJUgZyZWFzb24=');

@$core.Deprecated('Use anonymousChangedResponseDescriptor instead')
const AnonymousChangedResponse$json = {
  '1': 'AnonymousChangedResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'is_anonymous', '3': 2, '4': 1, '5': 8, '10': 'isAnonymous'},
    {'1': 'display_nickname', '3': 3, '4': 1, '5': 9, '10': 'displayNickname'},
  ],
};

/// Descriptor for `AnonymousChangedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List anonymousChangedResponseDescriptor = $convert.base64Decode(
    'ChhBbm9ueW1vdXNDaGFuZ2VkUmVzcG9uc2USFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEiEKDG'
    'lzX2Fub255bW91cxgCIAEoCFILaXNBbm9ueW1vdXMSKQoQZGlzcGxheV9uaWNrbmFtZRgDIAEo'
    'CVIPZGlzcGxheU5pY2tuYW1l');

@$core.Deprecated('Use spriteChangedResponseDescriptor instead')
const SpriteChangedResponse$json = {
  '1': 'SpriteChangedResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'sprite_id', '3': 2, '4': 1, '5': 9, '10': 'spriteId'},
  ],
};

/// Descriptor for `SpriteChangedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List spriteChangedResponseDescriptor = $convert.base64Decode(
    'ChVTcHJpdGVDaGFuZ2VkUmVzcG9uc2USFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhsKCXNwcm'
    'l0ZV9pZBgCIAEoCVIIc3ByaXRlSWQ=');

@$core.Deprecated('Use spriteChangeSuccessResponseDescriptor instead')
const SpriteChangeSuccessResponse$json = {
  '1': 'SpriteChangeSuccessResponse',
  '2': [
    {'1': 'sprite_id', '3': 1, '4': 1, '5': 9, '10': 'spriteId'},
  ],
};

/// Descriptor for `SpriteChangeSuccessResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List spriteChangeSuccessResponseDescriptor = $convert.base64Decode(
    'ChtTcHJpdGVDaGFuZ2VTdWNjZXNzUmVzcG9uc2USGwoJc3ByaXRlX2lkGAEgASgJUghzcHJpdG'
    'VJZA==');

@$core.Deprecated('Use spriteChangeRejectResponseDescriptor instead')
const SpriteChangeRejectResponse$json = {
  '1': 'SpriteChangeRejectResponse',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `SpriteChangeRejectResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List spriteChangeRejectResponseDescriptor = $convert.base64Decode(
    'ChpTcHJpdGVDaGFuZ2VSZWplY3RSZXNwb25zZRIWCgZyZWFzb24YASABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use statusTextBroadcastResponseDescriptor instead')
const StatusTextBroadcastResponse$json = {
  '1': 'StatusTextBroadcastResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'status_text', '3': 2, '4': 1, '5': 9, '10': 'statusText'},
  ],
};

/// Descriptor for `StatusTextBroadcastResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusTextBroadcastResponseDescriptor = $convert.base64Decode(
    'ChtTdGF0dXNUZXh0QnJvYWRjYXN0UmVzcG9uc2USFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEh'
    '8KC3N0YXR1c190ZXh0GAIgASgJUgpzdGF0dXNUZXh0');

@$core.Deprecated('Use displayNameChangedResponseDescriptor instead')
const DisplayNameChangedResponse$json = {
  '1': 'DisplayNameChangedResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
  ],
};

/// Descriptor for `DisplayNameChangedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List displayNameChangedResponseDescriptor = $convert.base64Decode(
    'ChpEaXNwbGF5TmFtZUNoYW5nZWRSZXNwb25zZRIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSGg'
    'oIbmlja25hbWUYAiABKAlSCG5pY2tuYW1l');

@$core.Deprecated('Use assetsResponseDescriptor instead')
const AssetsResponse$json = {
  '1': 'AssetsResponse',
  '2': [
    {'1': 'maps', '3': 1, '4': 3, '5': 11, '6': '.lobby.LobbyMapConfig', '10': 'maps'},
    {'1': 'sprites', '3': 2, '4': 3, '5': 11, '6': '.lobby.LobbySpriteConfig', '10': 'sprites'},
  ],
};

/// Descriptor for `AssetsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetsResponseDescriptor = $convert.base64Decode(
    'Cg5Bc3NldHNSZXNwb25zZRIpCgRtYXBzGAEgAygLMhUubG9iYnkuTG9iYnlNYXBDb25maWdSBG'
    '1hcHMSMgoHc3ByaXRlcxgCIAMoCzIYLmxvYmJ5LkxvYmJ5U3ByaXRlQ29uZmlnUgdzcHJpdGVz');

@$core.Deprecated('Use assetsUpdatedResponseDescriptor instead')
const AssetsUpdatedResponse$json = {
  '1': 'AssetsUpdatedResponse',
  '2': [
    {'1': 'update_type', '3': 1, '4': 1, '5': 9, '10': 'updateType'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `AssetsUpdatedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetsUpdatedResponseDescriptor = $convert.base64Decode(
    'ChVBc3NldHNVcGRhdGVkUmVzcG9uc2USHwoLdXBkYXRlX3R5cGUYASABKAlSCnVwZGF0ZVR5cG'
    'USGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use portalTeleportResponseDescriptor instead')
const PortalTeleportResponse$json = {
  '1': 'PortalTeleportResponse',
  '2': [
    {'1': 'portal_key', '3': 1, '4': 1, '5': 9, '10': 'portalKey'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'source_map_id', '3': 3, '4': 1, '5': 9, '10': 'sourceMapId'},
    {'1': 'target_map_id', '3': 4, '4': 1, '5': 9, '10': 'targetMapId'},
    {'1': 'target_x', '3': 5, '4': 1, '5': 1, '10': 'targetX'},
    {'1': 'target_y', '3': 6, '4': 1, '5': 1, '10': 'targetY'},
    {'1': 'target_match_id', '3': 7, '4': 1, '5': 9, '10': 'targetMatchId'},
  ],
};

/// Descriptor for `PortalTeleportResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List portalTeleportResponseDescriptor = $convert.base64Decode(
    'ChZQb3J0YWxUZWxlcG9ydFJlc3BvbnNlEh0KCnBvcnRhbF9rZXkYASABKAlSCXBvcnRhbEtleR'
    'IUCgVsYWJlbBgCIAEoCVIFbGFiZWwSIgoNc291cmNlX21hcF9pZBgDIAEoCVILc291cmNlTWFw'
    'SWQSIgoNdGFyZ2V0X21hcF9pZBgEIAEoCVILdGFyZ2V0TWFwSWQSGQoIdGFyZ2V0X3gYBSABKA'
    'FSB3RhcmdldFgSGQoIdGFyZ2V0X3kYBiABKAFSB3RhcmdldFkSJgoPdGFyZ2V0X21hdGNoX2lk'
    'GAcgASgJUg10YXJnZXRNYXRjaElk');

@$core.Deprecated('Use portalUseRejectResponseDescriptor instead')
const PortalUseRejectResponse$json = {
  '1': 'PortalUseRejectResponse',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `PortalUseRejectResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List portalUseRejectResponseDescriptor = $convert.base64Decode(
    'ChdQb3J0YWxVc2VSZWplY3RSZXNwb25zZRIWCgZyZWFzb24YASABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use broadcastMessageResponseDescriptor instead')
const BroadcastMessageResponse$json = {
  '1': 'BroadcastMessageResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 11, '6': '.lobby.LobbyBroadcastMessage', '10': 'message'},
  ],
};

/// Descriptor for `BroadcastMessageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastMessageResponseDescriptor = $convert.base64Decode(
    'ChhCcm9hZGNhc3RNZXNzYWdlUmVzcG9uc2USNgoHbWVzc2FnZRgBIAEoCzIcLmxvYmJ5LkxvYm'
    'J5QnJvYWRjYXN0TWVzc2FnZVIHbWVzc2FnZQ==');

@$core.Deprecated('Use broadcastRejectResponseDescriptor instead')
const BroadcastRejectResponse$json = {
  '1': 'BroadcastRejectResponse',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `BroadcastRejectResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastRejectResponseDescriptor = $convert.base64Decode(
    'ChdCcm9hZGNhc3RSZWplY3RSZXNwb25zZRIWCgZyZWFzb24YASABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use broadcastCDResponseDescriptor instead')
const BroadcastCDResponse$json = {
  '1': 'BroadcastCDResponse',
  '2': [
    {'1': 'in_cooldown', '3': 1, '4': 1, '5': 8, '10': 'inCooldown'},
    {'1': 'remaining_ms', '3': 2, '4': 1, '5': 3, '10': 'remainingMs'},
    {'1': 'next_broadcast_at', '3': 3, '4': 1, '5': 3, '10': 'nextBroadcastAt'},
  ],
};

/// Descriptor for `BroadcastCDResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastCDResponseDescriptor = $convert.base64Decode(
    'ChNCcm9hZGNhc3RDRFJlc3BvbnNlEh8KC2luX2Nvb2xkb3duGAEgASgIUgppbkNvb2xkb3duEi'
    'EKDHJlbWFpbmluZ19tcxgCIAEoA1ILcmVtYWluaW5nTXMSKgoRbmV4dF9icm9hZGNhc3RfYXQY'
    'AyABKANSD25leHRCcm9hZGNhc3RBdA==');

@$core.Deprecated('Use onlineStatsResponseDescriptor instead')
const OnlineStatsResponse$json = {
  '1': 'OnlineStatsResponse',
  '2': [
    {'1': 'total', '3': 1, '4': 1, '5': 5, '10': 'total'},
    {'1': 'by_map', '3': 2, '4': 3, '5': 11, '6': '.lobby.OnlineStatsResponse.ByMapEntry', '10': 'byMap'},
    {'1': 'users', '3': 3, '4': 3, '5': 11, '6': '.lobby.LobbyUser', '10': 'users'},
  ],
  '3': [OnlineStatsResponse_ByMapEntry$json],
};

@$core.Deprecated('Use onlineStatsResponseDescriptor instead')
const OnlineStatsResponse_ByMapEntry$json = {
  '1': 'ByMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 5, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `OnlineStatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List onlineStatsResponseDescriptor = $convert.base64Decode(
    'ChNPbmxpbmVTdGF0c1Jlc3BvbnNlEhQKBXRvdGFsGAEgASgFUgV0b3RhbBI8CgZieV9tYXAYAi'
    'ADKAsyJS5sb2JieS5PbmxpbmVTdGF0c1Jlc3BvbnNlLkJ5TWFwRW50cnlSBWJ5TWFwEiYKBXVz'
    'ZXJzGAMgAygLMhAubG9iYnkuTG9iYnlVc2VyUgV1c2Vycxo4CgpCeU1hcEVudHJ5EhAKA2tleR'
    'gBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgFUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use systemErrorResponseDescriptor instead')
const SystemErrorResponse$json = {
  '1': 'SystemErrorResponse',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 5, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SystemErrorResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List systemErrorResponseDescriptor = $convert.base64Decode(
    'ChNTeXN0ZW1FcnJvclJlc3BvbnNlEhIKBGNvZGUYASABKAVSBGNvZGUSGAoHbWVzc2FnZRgCIA'
    'EoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use systemNoticeResponseDescriptor instead')
const SystemNoticeResponse$json = {
  '1': 'SystemNoticeResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SystemNoticeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List systemNoticeResponseDescriptor = $convert.base64Decode(
    'ChRTeXN0ZW1Ob3RpY2VSZXNwb25zZRIYCgdtZXNzYWdlGAEgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use systemKickedResponseDescriptor instead')
const SystemKickedResponse$json = {
  '1': 'SystemKickedResponse',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SystemKickedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List systemKickedResponseDescriptor = $convert.base64Decode(
    'ChRTeXN0ZW1LaWNrZWRSZXNwb25zZRIWCgZyZWFzb24YASABKAlSBnJlYXNvbhIYCgdtZXNzYW'
    'dlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use steamBindSuccessResponseDescriptor instead')
const SteamBindSuccessResponse$json = {
  '1': 'SteamBindSuccessResponse',
  '2': [
    {'1': 'steam_id', '3': 1, '4': 1, '5': 9, '10': 'steamId'},
    {'1': 'steam_name', '3': 2, '4': 1, '5': 9, '10': 'steamName'},
    {'1': 'display_nickname', '3': 3, '4': 1, '5': 9, '10': 'displayNickname'},
  ],
};

/// Descriptor for `SteamBindSuccessResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List steamBindSuccessResponseDescriptor = $convert.base64Decode(
    'ChhTdGVhbUJpbmRTdWNjZXNzUmVzcG9uc2USGQoIc3RlYW1faWQYASABKAlSB3N0ZWFtSWQSHQ'
    'oKc3RlYW1fbmFtZRgCIAEoCVIJc3RlYW1OYW1lEikKEGRpc3BsYXlfbmlja25hbWUYAyABKAlS'
    'D2Rpc3BsYXlOaWNrbmFtZQ==');

@$core.Deprecated('Use lobbyJoinRequestDescriptor instead')
const LobbyJoinRequest$json = {
  '1': 'LobbyJoinRequest',
  '2': [
    {'1': 'device_type', '3': 1, '4': 1, '5': 9, '10': 'deviceType'},
    {'1': 'protocol_features', '3': 2, '4': 1, '5': 5, '10': 'protocolFeatures'},
    {'1': 'token', '3': 3, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `LobbyJoinRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyJoinRequestDescriptor = $convert.base64Decode(
    'ChBMb2JieUpvaW5SZXF1ZXN0Eh8KC2RldmljZV90eXBlGAEgASgJUgpkZXZpY2VUeXBlEisKEX'
    'Byb3RvY29sX2ZlYXR1cmVzGAIgASgFUhBwcm90b2NvbEZlYXR1cmVzEhQKBXRva2VuGAMgASgJ'
    'UgV0b2tlbg==');

@$core.Deprecated('Use lobbyJoinResponseDescriptor instead')
const LobbyJoinResponse$json = {
  '1': 'LobbyJoinResponse',
  '2': [
    {'1': 'match_id', '3': 1, '4': 1, '5': 9, '10': 'matchId'},
    {'1': 'map_id', '3': 2, '4': 1, '5': 9, '10': 'mapId'},
    {'1': 'ticket', '3': 3, '4': 1, '5': 9, '10': 'ticket'},
    {'1': 'position', '3': 4, '4': 1, '5': 5, '10': 'position'},
    {'1': 'queue_total', '3': 5, '4': 1, '5': 5, '10': 'queueTotal'},
    {'1': 'eta_seconds', '3': 6, '4': 1, '5': 5, '10': 'etaSeconds'},
    {'1': 'poll_interval_ms', '3': 7, '4': 1, '5': 5, '10': 'pollIntervalMs'},
  ],
};

/// Descriptor for `LobbyJoinResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lobbyJoinResponseDescriptor = $convert.base64Decode(
    'ChFMb2JieUpvaW5SZXNwb25zZRIZCghtYXRjaF9pZBgBIAEoCVIHbWF0Y2hJZBIVCgZtYXBfaW'
    'QYAiABKAlSBW1hcElkEhYKBnRpY2tldBgDIAEoCVIGdGlja2V0EhoKCHBvc2l0aW9uGAQgASgF'
    'Ughwb3NpdGlvbhIfCgtxdWV1ZV90b3RhbBgFIAEoBVIKcXVldWVUb3RhbBIfCgtldGFfc2Vjb2'
    '5kcxgGIAEoBVIKZXRhU2Vjb25kcxIoChBwb2xsX2ludGVydmFsX21zGAcgASgFUg5wb2xsSW50'
    'ZXJ2YWxNcw==');

@$core.Deprecated('Use steamUserInfoRequestDescriptor instead')
const SteamUserInfoRequest$json = {
  '1': 'SteamUserInfoRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `SteamUserInfoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List steamUserInfoRequestDescriptor = $convert.base64Decode(
    'ChRTdGVhbVVzZXJJbmZvUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQ=');

@$core.Deprecated('Use steamUserInfoResponseDescriptor instead')
const SteamUserInfoResponse$json = {
  '1': 'SteamUserInfoResponse',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 5, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'forum_uid', '3': 3, '4': 1, '5': 3, '10': 'forumUid'},
    {'1': 'forum_username', '3': 4, '4': 1, '5': 9, '10': 'forumUsername'},
    {'1': 'forum_avatar_url', '3': 5, '4': 1, '5': 9, '10': 'forumAvatarUrl'},
    {'1': 'steam_id', '3': 6, '4': 1, '5': 9, '10': 'steamId'},
    {'1': 'steam_id64', '3': 7, '4': 1, '5': 9, '10': 'steamId64'},
    {'1': 'avatar_url', '3': 8, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'steam_name', '3': 9, '4': 1, '5': 9, '10': 'steamName'},
    {'1': 'in_game_name', '3': 10, '4': 1, '5': 9, '10': 'inGameName'},
    {'1': 'join_date', '3': 11, '4': 1, '5': 9, '10': 'joinDate'},
    {'1': 'vip_level', '3': 12, '4': 1, '5': 5, '10': 'vipLevel'},
    {'1': 'vip_date', '3': 13, '4': 1, '5': 9, '10': 'vipDate'},
    {'1': 'vip_end', '3': 14, '4': 1, '5': 9, '10': 'vipEnd'},
    {'1': 'csgo_gold', '3': 15, '4': 1, '5': 3, '10': 'csgoGold'},
    {'1': 'online_time_total', '3': 16, '4': 1, '5': 3, '10': 'onlineTimeTotal'},
    {'1': 'online_time_day', '3': 17, '4': 1, '5': 3, '10': 'onlineTimeDay'},
    {'1': 'cs2_gold', '3': 18, '4': 1, '5': 3, '10': 'cs2Gold'},
    {'1': 'cs2_point', '3': 19, '4': 1, '5': 3, '10': 'cs2Point'},
    {'1': 'cs2_spent_point', '3': 20, '4': 1, '5': 3, '10': 'cs2SpentPoint'},
    {'1': 'mg_pts', '3': 21, '4': 1, '5': 3, '10': 'mgPts'},
    {'1': 'mg_pts_rank', '3': 22, '4': 1, '5': 3, '10': 'mgPtsRank'},
    {'1': 'mg_pts_total', '3': 23, '4': 1, '5': 3, '10': 'mgPtsTotal'},
    {'1': 'surf_pts', '3': 24, '4': 1, '5': 3, '10': 'surfPts'},
    {'1': 'surf_pts_rank', '3': 25, '4': 1, '5': 3, '10': 'surfPtsRank'},
    {'1': 'surf_pts_total', '3': 26, '4': 1, '5': 3, '10': 'surfPtsTotal'},
    {'1': 'bhop_pts', '3': 27, '4': 1, '5': 3, '10': 'bhopPts'},
    {'1': 'bhop_pts_rank', '3': 28, '4': 1, '5': 3, '10': 'bhopPtsRank'},
    {'1': 'bhop_pts_total', '3': 29, '4': 1, '5': 3, '10': 'bhopPtsTotal'},
    {'1': 'kz_pts', '3': 30, '4': 1, '5': 3, '10': 'kzPts'},
    {'1': 'kz_pts_rank', '3': 31, '4': 1, '5': 3, '10': 'kzPtsRank'},
    {'1': 'kz_pts_total', '3': 32, '4': 1, '5': 3, '10': 'kzPtsTotal'},
    {'1': 'csgo_online_time', '3': 33, '4': 1, '5': 3, '10': 'csgoOnlineTime'},
    {'1': 'csgo_zombie_pts', '3': 34, '4': 1, '5': 3, '10': 'csgoZombiePts'},
    {'1': 'csgo_zombie_kill', '3': 35, '4': 1, '5': 3, '10': 'csgoZombieKill'},
    {'1': 'csgo_zombie_knife', '3': 36, '4': 1, '5': 3, '10': 'csgoZombieKnife'},
    {'1': 'csgo_zombie_kick_ass', '3': 37, '4': 1, '5': 3, '10': 'csgoZombieKickAss'},
    {'1': 'csgo_zombie_lost_ass', '3': 38, '4': 1, '5': 3, '10': 'csgoZombieLostAss'},
    {'1': 'csgo_zombie_pro_level', '3': 39, '4': 1, '5': 3, '10': 'csgoZombieProLevel'},
    {'1': 'csgo_mg_pts', '3': 40, '4': 1, '5': 3, '10': 'csgoMgPts'},
    {'1': 'csgo_surf_pts', '3': 41, '4': 1, '5': 3, '10': 'csgoSurfPts'},
    {'1': 'csgo_bhop_pts', '3': 42, '4': 1, '5': 3, '10': 'csgoBhopPts'},
    {'1': 'csgo_kz_pts', '3': 43, '4': 1, '5': 3, '10': 'csgoKzPts'},
    {'1': 'csgo_ttt_innocent_pts', '3': 44, '4': 1, '5': 3, '10': 'csgoTttInnocentPts'},
    {'1': 'csgo_ttt_detective_pts', '3': 45, '4': 1, '5': 3, '10': 'csgoTttDetectivePts'},
    {'1': 'csgo_ttt_traitor_pts', '3': 46, '4': 1, '5': 3, '10': 'csgoTttTraitorPts'},
    {'1': 'css_zombie_pts', '3': 47, '4': 1, '5': 3, '10': 'cssZombiePts'},
    {'1': 'css_zombie_kill', '3': 48, '4': 1, '5': 3, '10': 'cssZombieKill'},
    {'1': 'css_zombie_knife', '3': 49, '4': 1, '5': 3, '10': 'cssZombieKnife'},
    {'1': 'css_zombie_kick_ass', '3': 50, '4': 1, '5': 3, '10': 'cssZombieKickAss'},
    {'1': 'css_zombie_pro_level', '3': 51, '4': 1, '5': 3, '10': 'cssZombieProLevel'},
    {'1': 'css_titan_pts', '3': 52, '4': 1, '5': 3, '10': 'cssTitanPts'},
    {'1': 'css_titan_kills', '3': 53, '4': 1, '5': 3, '10': 'cssTitanKills'},
    {'1': 'css_titan_special_kills', '3': 54, '4': 1, '5': 3, '10': 'cssTitanSpecialKills'},
    {'1': 'css_titan_human_kills', '3': 55, '4': 1, '5': 3, '10': 'cssTitanHumanKills'},
    {'1': 'css_titan_assists', '3': 56, '4': 1, '5': 3, '10': 'cssTitanAssists'},
    {'1': 'css_ttt_pts', '3': 57, '4': 1, '5': 3, '10': 'cssTttPts'},
    {'1': 'css_ttt_wrong_kill', '3': 58, '4': 1, '5': 3, '10': 'cssTttWrongKill'},
    {'1': 'css_ttt_karma', '3': 59, '4': 1, '5': 3, '10': 'cssTttKarma'},
    {'1': 'donator_level', '3': 60, '4': 1, '5': 5, '10': 'donatorLevel'},
    {'1': 'donate_date', '3': 61, '4': 1, '5': 9, '10': 'donateDate'},
    {'1': 'donate_end', '3': 62, '4': 1, '5': 9, '10': 'donateEnd'},
    {'1': 'donator_sign_today', '3': 63, '4': 1, '5': 8, '10': 'donatorSignToday'},
    {'1': 'current_date', '3': 64, '4': 1, '5': 9, '10': 'currentDate'},
  ],
};

/// Descriptor for `SteamUserInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List steamUserInfoResponseDescriptor = $convert.base64Decode(
    'ChVTdGVhbVVzZXJJbmZvUmVzcG9uc2USEgoEY29kZRgBIAEoBVIEY29kZRIYCgdtZXNzYWdlGA'
    'IgASgJUgdtZXNzYWdlEhsKCWZvcnVtX3VpZBgDIAEoA1IIZm9ydW1VaWQSJQoOZm9ydW1fdXNl'
    'cm5hbWUYBCABKAlSDWZvcnVtVXNlcm5hbWUSKAoQZm9ydW1fYXZhdGFyX3VybBgFIAEoCVIOZm'
    '9ydW1BdmF0YXJVcmwSGQoIc3RlYW1faWQYBiABKAlSB3N0ZWFtSWQSHQoKc3RlYW1faWQ2NBgH'
    'IAEoCVIJc3RlYW1JZDY0Eh0KCmF2YXRhcl91cmwYCCABKAlSCWF2YXRhclVybBIdCgpzdGVhbV'
    '9uYW1lGAkgASgJUglzdGVhbU5hbWUSIAoMaW5fZ2FtZV9uYW1lGAogASgJUgppbkdhbWVOYW1l'
    'EhsKCWpvaW5fZGF0ZRgLIAEoCVIIam9pbkRhdGUSGwoJdmlwX2xldmVsGAwgASgFUgh2aXBMZX'
    'ZlbBIZCgh2aXBfZGF0ZRgNIAEoCVIHdmlwRGF0ZRIXCgd2aXBfZW5kGA4gASgJUgZ2aXBFbmQS'
    'GwoJY3Nnb19nb2xkGA8gASgDUghjc2dvR29sZBIqChFvbmxpbmVfdGltZV90b3RhbBgQIAEoA1'
    'IPb25saW5lVGltZVRvdGFsEiYKD29ubGluZV90aW1lX2RheRgRIAEoA1INb25saW5lVGltZURh'
    'eRIZCghjczJfZ29sZBgSIAEoA1IHY3MyR29sZBIbCgljczJfcG9pbnQYEyABKANSCGNzMlBvaW'
    '50EiYKD2NzMl9zcGVudF9wb2ludBgUIAEoA1INY3MyU3BlbnRQb2ludBIVCgZtZ19wdHMYFSAB'
    'KANSBW1nUHRzEh4KC21nX3B0c19yYW5rGBYgASgDUgltZ1B0c1JhbmsSIAoMbWdfcHRzX3RvdG'
    'FsGBcgASgDUgptZ1B0c1RvdGFsEhkKCHN1cmZfcHRzGBggASgDUgdzdXJmUHRzEiIKDXN1cmZf'
    'cHRzX3JhbmsYGSABKANSC3N1cmZQdHNSYW5rEiQKDnN1cmZfcHRzX3RvdGFsGBogASgDUgxzdX'
    'JmUHRzVG90YWwSGQoIYmhvcF9wdHMYGyABKANSB2Job3BQdHMSIgoNYmhvcF9wdHNfcmFuaxgc'
    'IAEoA1ILYmhvcFB0c1JhbmsSJAoOYmhvcF9wdHNfdG90YWwYHSABKANSDGJob3BQdHNUb3RhbB'
    'IVCgZrel9wdHMYHiABKANSBWt6UHRzEh4KC2t6X3B0c19yYW5rGB8gASgDUglrelB0c1JhbmsS'
    'IAoMa3pfcHRzX3RvdGFsGCAgASgDUgprelB0c1RvdGFsEigKEGNzZ29fb25saW5lX3RpbWUYIS'
    'ABKANSDmNzZ29PbmxpbmVUaW1lEiYKD2NzZ29fem9tYmllX3B0cxgiIAEoA1INY3Nnb1pvbWJp'
    'ZVB0cxIoChBjc2dvX3pvbWJpZV9raWxsGCMgASgDUg5jc2dvWm9tYmllS2lsbBIqChFjc2dvX3'
    'pvbWJpZV9rbmlmZRgkIAEoA1IPY3Nnb1pvbWJpZUtuaWZlEi8KFGNzZ29fem9tYmllX2tpY2tf'
    'YXNzGCUgASgDUhFjc2dvWm9tYmllS2lja0FzcxIvChRjc2dvX3pvbWJpZV9sb3N0X2FzcxgmIA'
    'EoA1IRY3Nnb1pvbWJpZUxvc3RBc3MSMQoVY3Nnb196b21iaWVfcHJvX2xldmVsGCcgASgDUhJj'
    'c2dvWm9tYmllUHJvTGV2ZWwSHgoLY3Nnb19tZ19wdHMYKCABKANSCWNzZ29NZ1B0cxIiCg1jc2'
    'dvX3N1cmZfcHRzGCkgASgDUgtjc2dvU3VyZlB0cxIiCg1jc2dvX2Job3BfcHRzGCogASgDUgtj'
    'c2dvQmhvcFB0cxIeCgtjc2dvX2t6X3B0cxgrIAEoA1IJY3Nnb0t6UHRzEjEKFWNzZ29fdHR0X2'
    'lubm9jZW50X3B0cxgsIAEoA1ISY3Nnb1R0dElubm9jZW50UHRzEjMKFmNzZ29fdHR0X2RldGVj'
    'dGl2ZV9wdHMYLSABKANSE2NzZ29UdHREZXRlY3RpdmVQdHMSLwoUY3Nnb190dHRfdHJhaXRvcl'
    '9wdHMYLiABKANSEWNzZ29UdHRUcmFpdG9yUHRzEiQKDmNzc196b21iaWVfcHRzGC8gASgDUgxj'
    'c3Nab21iaWVQdHMSJgoPY3NzX3pvbWJpZV9raWxsGDAgASgDUg1jc3Nab21iaWVLaWxsEigKEG'
    'Nzc196b21iaWVfa25pZmUYMSABKANSDmNzc1pvbWJpZUtuaWZlEi0KE2Nzc196b21iaWVfa2lj'
    'a19hc3MYMiABKANSEGNzc1pvbWJpZUtpY2tBc3MSLwoUY3NzX3pvbWJpZV9wcm9fbGV2ZWwYMy'
    'ABKANSEWNzc1pvbWJpZVByb0xldmVsEiIKDWNzc190aXRhbl9wdHMYNCABKANSC2Nzc1RpdGFu'
    'UHRzEiYKD2Nzc190aXRhbl9raWxscxg1IAEoA1INY3NzVGl0YW5LaWxscxI1Chdjc3NfdGl0YW'
    '5fc3BlY2lhbF9raWxscxg2IAEoA1IUY3NzVGl0YW5TcGVjaWFsS2lsbHMSMQoVY3NzX3RpdGFu'
    'X2h1bWFuX2tpbGxzGDcgASgDUhJjc3NUaXRhbkh1bWFuS2lsbHMSKgoRY3NzX3RpdGFuX2Fzc2'
    'lzdHMYOCABKANSD2Nzc1RpdGFuQXNzaXN0cxIeCgtjc3NfdHR0X3B0cxg5IAEoA1IJY3NzVHR0'
    'UHRzEisKEmNzc190dHRfd3Jvbmdfa2lsbBg6IAEoA1IPY3NzVHR0V3JvbmdLaWxsEiIKDWNzc1'
    '90dHRfa2FybWEYOyABKANSC2Nzc1R0dEthcm1hEiMKDWRvbmF0b3JfbGV2ZWwYPCABKAVSDGRv'
    'bmF0b3JMZXZlbBIfCgtkb25hdGVfZGF0ZRg9IAEoCVIKZG9uYXRlRGF0ZRIdCgpkb25hdGVfZW'
    '5kGD4gASgJUglkb25hdGVFbmQSLAoSZG9uYXRvcl9zaWduX3RvZGF5GD8gASgIUhBkb25hdG9y'
    'U2lnblRvZGF5EiEKDGN1cnJlbnRfZGF0ZRhAIAEoCVILY3VycmVudERhdGU=');

@$core.Deprecated('Use inventoryStatsRequestDescriptor instead')
const InventoryStatsRequest$json = {
  '1': 'InventoryStatsRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `InventoryStatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inventoryStatsRequestDescriptor = $convert.base64Decode(
    'ChVJbnZlbnRvcnlTdGF0c1JlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklk');

@$core.Deprecated('Use inventoryStatsResponseDescriptor instead')
const InventoryStatsResponse$json = {
  '1': 'InventoryStatsResponse',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 5, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'skin_count', '3': 3, '4': 1, '5': 5, '10': 'skinCount'},
    {'1': 'spell_count', '3': 4, '4': 1, '5': 5, '10': 'spellCount'},
    {'1': 'danmaku_count', '3': 5, '4': 1, '5': 5, '10': 'danmakuCount'},
    {'1': 'skill_count', '3': 6, '4': 1, '5': 5, '10': 'skillCount'},
    {'1': 'knife_count', '3': 7, '4': 1, '5': 5, '10': 'knifeCount'},
    {'1': 'weapon_count', '3': 8, '4': 1, '5': 5, '10': 'weaponCount'},
    {'1': 'cheer_count', '3': 9, '4': 1, '5': 5, '10': 'cheerCount'},
    {'1': 'skinmenu_count', '3': 10, '4': 1, '5': 5, '10': 'skinmenuCount'},
    {'1': 'total_gold_value', '3': 11, '4': 1, '5': 3, '10': 'totalGoldValue'},
    {'1': 'total_point_value', '3': 12, '4': 1, '5': 3, '10': 'totalPointValue'},
  ],
};

/// Descriptor for `InventoryStatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inventoryStatsResponseDescriptor = $convert.base64Decode(
    'ChZJbnZlbnRvcnlTdGF0c1Jlc3BvbnNlEhIKBGNvZGUYASABKAVSBGNvZGUSGAoHbWVzc2FnZR'
    'gCIAEoCVIHbWVzc2FnZRIdCgpza2luX2NvdW50GAMgASgFUglza2luQ291bnQSHwoLc3BlbGxf'
    'Y291bnQYBCABKAVSCnNwZWxsQ291bnQSIwoNZGFubWFrdV9jb3VudBgFIAEoBVIMZGFubWFrdU'
    'NvdW50Eh8KC3NraWxsX2NvdW50GAYgASgFUgpza2lsbENvdW50Eh8KC2tuaWZlX2NvdW50GAcg'
    'ASgFUgprbmlmZUNvdW50EiEKDHdlYXBvbl9jb3VudBgIIAEoBVILd2VhcG9uQ291bnQSHwoLY2'
    'hlZXJfY291bnQYCSABKAVSCmNoZWVyQ291bnQSJQoOc2tpbm1lbnVfY291bnQYCiABKAVSDXNr'
    'aW5tZW51Q291bnQSKAoQdG90YWxfZ29sZF92YWx1ZRgLIAEoA1IOdG90YWxHb2xkVmFsdWUSKg'
    'oRdG90YWxfcG9pbnRfdmFsdWUYDCABKANSD3RvdGFsUG9pbnRWYWx1ZQ==');

@$core.Deprecated('Use presenceDeltaResponseDescriptor instead')
const PresenceDeltaResponse$json = {
  '1': 'PresenceDeltaResponse',
  '2': [
    {'1': 'joined', '3': 1, '4': 3, '5': 11, '6': '.lobby.LobbyUser', '10': 'joined'},
    {'1': 'left_user_ids', '3': 2, '4': 3, '5': 9, '10': 'leftUserIds'},
    {'1': 'cross_map_events', '3': 3, '4': 3, '5': 11, '6': '.lobby.CrossMapPresenceEvent', '10': 'crossMapEvents'},
    {'1': 'seq', '3': 10, '4': 1, '5': 3, '10': 'seq'},
  ],
};

/// Descriptor for `PresenceDeltaResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List presenceDeltaResponseDescriptor = $convert.base64Decode(
    'ChVQcmVzZW5jZURlbHRhUmVzcG9uc2USKAoGam9pbmVkGAEgAygLMhAubG9iYnkuTG9iYnlVc2'
    'VyUgZqb2luZWQSIgoNbGVmdF91c2VyX2lkcxgCIAMoCVILbGVmdFVzZXJJZHMSRgoQY3Jvc3Nf'
    'bWFwX2V2ZW50cxgDIAMoCzIcLmxvYmJ5LkNyb3NzTWFwUHJlc2VuY2VFdmVudFIOY3Jvc3NNYX'
    'BFdmVudHMSEAoDc2VxGAogASgDUgNzZXE=');

@$core.Deprecated('Use crossMapPresenceEventDescriptor instead')
const CrossMapPresenceEvent$json = {
  '1': 'CrossMapPresenceEvent',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'avatar_url', '3': 3, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'is_anonymous', '3': 4, '4': 1, '5': 8, '10': 'isAnonymous'},
    {'1': 'map_id', '3': 5, '4': 1, '5': 9, '10': 'mapId'},
    {'1': 'event_type', '3': 6, '4': 1, '5': 9, '10': 'eventType'},
    {'1': 'target_map_id', '3': 7, '4': 1, '5': 9, '10': 'targetMapId'},
  ],
};

/// Descriptor for `CrossMapPresenceEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List crossMapPresenceEventDescriptor = $convert.base64Decode(
    'ChVDcm9zc01hcFByZXNlbmNlRXZlbnQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCG5pY2'
    'tuYW1lGAIgASgJUghuaWNrbmFtZRIdCgphdmF0YXJfdXJsGAMgASgJUglhdmF0YXJVcmwSIQoM'
    'aXNfYW5vbnltb3VzGAQgASgIUgtpc0Fub255bW91cxIVCgZtYXBfaWQYBSABKAlSBW1hcElkEh'
    '0KCmV2ZW50X3R5cGUYBiABKAlSCWV2ZW50VHlwZRIiCg10YXJnZXRfbWFwX2lkGAcgASgJUgt0'
    'YXJnZXRNYXBJZA==');

@$core.Deprecated('Use queueStatusRequestDescriptor instead')
const QueueStatusRequest$json = {
  '1': 'QueueStatusRequest',
  '2': [
    {'1': 'ticket', '3': 1, '4': 1, '5': 9, '10': 'ticket'},
  ],
};

/// Descriptor for `QueueStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queueStatusRequestDescriptor = $convert.base64Decode(
    'ChJRdWV1ZVN0YXR1c1JlcXVlc3QSFgoGdGlja2V0GAEgASgJUgZ0aWNrZXQ=');

@$core.Deprecated('Use queueStatusResponseDescriptor instead')
const QueueStatusResponse$json = {
  '1': 'QueueStatusResponse',
  '2': [
    {'1': 'ready', '3': 1, '4': 1, '5': 8, '10': 'ready'},
    {'1': 'match_id', '3': 2, '4': 1, '5': 9, '10': 'matchId'},
    {'1': 'map_id', '3': 3, '4': 1, '5': 9, '10': 'mapId'},
    {'1': 'position', '3': 4, '4': 1, '5': 5, '10': 'position'},
    {'1': 'queue_total', '3': 5, '4': 1, '5': 5, '10': 'queueTotal'},
    {'1': 'eta_seconds', '3': 6, '4': 1, '5': 5, '10': 'etaSeconds'},
    {'1': 'poll_interval_ms', '3': 7, '4': 1, '5': 5, '10': 'pollIntervalMs'},
    {'1': 'expired', '3': 8, '4': 1, '5': 8, '10': 'expired'},
    {'1': 'expire_reason', '3': 9, '4': 1, '5': 9, '10': 'expireReason'},
  ],
};

/// Descriptor for `QueueStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queueStatusResponseDescriptor = $convert.base64Decode(
    'ChNRdWV1ZVN0YXR1c1Jlc3BvbnNlEhQKBXJlYWR5GAEgASgIUgVyZWFkeRIZCghtYXRjaF9pZB'
    'gCIAEoCVIHbWF0Y2hJZBIVCgZtYXBfaWQYAyABKAlSBW1hcElkEhoKCHBvc2l0aW9uGAQgASgF'
    'Ughwb3NpdGlvbhIfCgtxdWV1ZV90b3RhbBgFIAEoBVIKcXVldWVUb3RhbBIfCgtldGFfc2Vjb2'
    '5kcxgGIAEoBVIKZXRhU2Vjb25kcxIoChBwb2xsX2ludGVydmFsX21zGAcgASgFUg5wb2xsSW50'
    'ZXJ2YWxNcxIYCgdleHBpcmVkGAggASgIUgdleHBpcmVkEiMKDWV4cGlyZV9yZWFzb24YCSABKA'
    'lSDGV4cGlyZVJlYXNvbg==');

@$core.Deprecated('Use queueCancelRequestDescriptor instead')
const QueueCancelRequest$json = {
  '1': 'QueueCancelRequest',
  '2': [
    {'1': 'ticket', '3': 1, '4': 1, '5': 9, '10': 'ticket'},
  ],
};

/// Descriptor for `QueueCancelRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queueCancelRequestDescriptor = $convert.base64Decode(
    'ChJRdWV1ZUNhbmNlbFJlcXVlc3QSFgoGdGlja2V0GAEgASgJUgZ0aWNrZXQ=');

@$core.Deprecated('Use queueCancelResponseDescriptor instead')
const QueueCancelResponse$json = {
  '1': 'QueueCancelResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `QueueCancelResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queueCancelResponseDescriptor = $convert.base64Decode(
    'ChNRdWV1ZUNhbmNlbFJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3M=');

@$core.Deprecated('Use batchPresenceJoinSignalDescriptor instead')
const BatchPresenceJoinSignal$json = {
  '1': 'BatchPresenceJoinSignal',
  '2': [
    {'1': 'joins', '3': 1, '4': 3, '5': 11, '6': '.lobby.PresenceJoinSignal', '10': 'joins'},
  ],
};

/// Descriptor for `BatchPresenceJoinSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchPresenceJoinSignalDescriptor = $convert.base64Decode(
    'ChdCYXRjaFByZXNlbmNlSm9pblNpZ25hbBIvCgVqb2lucxgBIAMoCzIZLmxvYmJ5LlByZXNlbm'
    'NlSm9pblNpZ25hbFIFam9pbnM=');

@$core.Deprecated('Use batchPresenceLeaveSignalDescriptor instead')
const BatchPresenceLeaveSignal$json = {
  '1': 'BatchPresenceLeaveSignal',
  '2': [
    {'1': 'leaves', '3': 1, '4': 3, '5': 11, '6': '.lobby.PresenceLeaveSignal', '10': 'leaves'},
  ],
};

/// Descriptor for `BatchPresenceLeaveSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchPresenceLeaveSignalDescriptor = $convert.base64Decode(
    'ChhCYXRjaFByZXNlbmNlTGVhdmVTaWduYWwSMgoGbGVhdmVzGAEgAygLMhoubG9iYnkuUHJlc2'
    'VuY2VMZWF2ZVNpZ25hbFIGbGVhdmVz');

@$core.Deprecated('Use matchSignalDescriptor instead')
const MatchSignal$json = {
  '1': 'MatchSignal',
  '2': [
    {'1': 'action', '3': 1, '4': 1, '5': 9, '10': 'action'},
    {'1': 'kick', '3': 10, '4': 1, '5': 11, '6': '.lobby.KickSignal', '9': 0, '10': 'kick'},
    {'1': 'assets_updated', '3': 11, '4': 1, '5': 11, '6': '.lobby.AssetsUpdatedSignal', '9': 0, '10': 'assetsUpdated'},
    {'1': 'broadcast_message', '3': 12, '4': 1, '5': 11, '6': '.lobby.BroadcastMessageSignal', '9': 0, '10': 'broadcastMessage'},
    {'1': 'teleport_arrival', '3': 13, '4': 1, '5': 11, '6': '.lobby.TeleportArrivalSignal', '9': 0, '10': 'teleportArrival'},
    {'1': 'chat_message', '3': 14, '4': 1, '5': 11, '6': '.lobby.ChatMessageSignal', '9': 0, '10': 'chatMessage'},
    {'1': 'online_count_changed', '3': 18, '4': 1, '5': 11, '6': '.lobby.OnlineCountChangedSignal', '9': 0, '10': 'onlineCountChanged'},
    {'1': 'presence_join', '3': 19, '4': 1, '5': 11, '6': '.lobby.PresenceJoinSignal', '9': 0, '10': 'presenceJoin'},
    {'1': 'presence_leave', '3': 20, '4': 1, '5': 11, '6': '.lobby.PresenceLeaveSignal', '9': 0, '10': 'presenceLeave'},
    {'1': 'batch_presence_join', '3': 21, '4': 1, '5': 11, '6': '.lobby.BatchPresenceJoinSignal', '9': 0, '10': 'batchPresenceJoin'},
    {'1': 'batch_presence_leave', '3': 22, '4': 1, '5': 11, '6': '.lobby.BatchPresenceLeaveSignal', '9': 0, '10': 'batchPresenceLeave'},
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `MatchSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchSignalDescriptor = $convert.base64Decode(
    'CgtNYXRjaFNpZ25hbBIWCgZhY3Rpb24YASABKAlSBmFjdGlvbhInCgRraWNrGAogASgLMhEubG'
    '9iYnkuS2lja1NpZ25hbEgAUgRraWNrEkMKDmFzc2V0c191cGRhdGVkGAsgASgLMhoubG9iYnku'
    'QXNzZXRzVXBkYXRlZFNpZ25hbEgAUg1hc3NldHNVcGRhdGVkEkwKEWJyb2FkY2FzdF9tZXNzYW'
    'dlGAwgASgLMh0ubG9iYnkuQnJvYWRjYXN0TWVzc2FnZVNpZ25hbEgAUhBicm9hZGNhc3RNZXNz'
    'YWdlEkkKEHRlbGVwb3J0X2Fycml2YWwYDSABKAsyHC5sb2JieS5UZWxlcG9ydEFycml2YWxTaW'
    'duYWxIAFIPdGVsZXBvcnRBcnJpdmFsEj0KDGNoYXRfbWVzc2FnZRgOIAEoCzIYLmxvYmJ5LkNo'
    'YXRNZXNzYWdlU2lnbmFsSABSC2NoYXRNZXNzYWdlElMKFG9ubGluZV9jb3VudF9jaGFuZ2VkGB'
    'IgASgLMh8ubG9iYnkuT25saW5lQ291bnRDaGFuZ2VkU2lnbmFsSABSEm9ubGluZUNvdW50Q2hh'
    'bmdlZBJACg1wcmVzZW5jZV9qb2luGBMgASgLMhkubG9iYnkuUHJlc2VuY2VKb2luU2lnbmFsSA'
    'BSDHByZXNlbmNlSm9pbhJDCg5wcmVzZW5jZV9sZWF2ZRgUIAEoCzIaLmxvYmJ5LlByZXNlbmNl'
    'TGVhdmVTaWduYWxIAFINcHJlc2VuY2VMZWF2ZRJQChNiYXRjaF9wcmVzZW5jZV9qb2luGBUgAS'
    'gLMh4ubG9iYnkuQmF0Y2hQcmVzZW5jZUpvaW5TaWduYWxIAFIRYmF0Y2hQcmVzZW5jZUpvaW4S'
    'UwoUYmF0Y2hfcHJlc2VuY2VfbGVhdmUYFiABKAsyHy5sb2JieS5CYXRjaFByZXNlbmNlTGVhdm'
    'VTaWduYWxIAFISYmF0Y2hQcmVzZW5jZUxlYXZlQgkKB3BheWxvYWQ=');

@$core.Deprecated('Use presenceJoinSignalDescriptor instead')
const PresenceJoinSignal$json = {
  '1': 'PresenceJoinSignal',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'avatar_url', '3': 3, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'is_anonymous', '3': 4, '4': 1, '5': 8, '10': 'isAnonymous'},
    {'1': 'map_id', '3': 5, '4': 1, '5': 9, '10': 'mapId'},
    {'1': 'business_user_id', '3': 6, '4': 1, '5': 9, '10': 'businessUserId'},
  ],
};

/// Descriptor for `PresenceJoinSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List presenceJoinSignalDescriptor = $convert.base64Decode(
    'ChJQcmVzZW5jZUpvaW5TaWduYWwSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhoKCG5pY2tuYW'
    '1lGAIgASgJUghuaWNrbmFtZRIdCgphdmF0YXJfdXJsGAMgASgJUglhdmF0YXJVcmwSIQoMaXNf'
    'YW5vbnltb3VzGAQgASgIUgtpc0Fub255bW91cxIVCgZtYXBfaWQYBSABKAlSBW1hcElkEigKEG'
    'J1c2luZXNzX3VzZXJfaWQYBiABKAlSDmJ1c2luZXNzVXNlcklk');

@$core.Deprecated('Use presenceLeaveSignalDescriptor instead')
const PresenceLeaveSignal$json = {
  '1': 'PresenceLeaveSignal',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'map_id', '3': 2, '4': 1, '5': 9, '10': 'mapId'},
    {'1': 'target_map_id', '3': 3, '4': 1, '5': 9, '10': 'targetMapId'},
  ],
};

/// Descriptor for `PresenceLeaveSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List presenceLeaveSignalDescriptor = $convert.base64Decode(
    'ChNQcmVzZW5jZUxlYXZlU2lnbmFsEhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIVCgZtYXBfaW'
    'QYAiABKAlSBW1hcElkEiIKDXRhcmdldF9tYXBfaWQYAyABKAlSC3RhcmdldE1hcElk');

@$core.Deprecated('Use kickSignalDescriptor instead')
const KickSignal$json = {
  '1': 'KickSignal',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `KickSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kickSignalDescriptor = $convert.base64Decode(
    'CgpLaWNrU2lnbmFsEhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIWCgZyZWFzb24YAiABKAlSBn'
    'JlYXNvbg==');

@$core.Deprecated('Use assetsUpdatedSignalDescriptor instead')
const AssetsUpdatedSignal$json = {
  '1': 'AssetsUpdatedSignal',
  '2': [
    {'1': 'update_type', '3': 1, '4': 1, '5': 9, '10': 'updateType'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `AssetsUpdatedSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetsUpdatedSignalDescriptor = $convert.base64Decode(
    'ChNBc3NldHNVcGRhdGVkU2lnbmFsEh8KC3VwZGF0ZV90eXBlGAEgASgJUgp1cGRhdGVUeXBlEh'
    'gKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use broadcastMessageSignalDescriptor instead')
const BroadcastMessageSignal$json = {
  '1': 'BroadcastMessageSignal',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 3, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'avatar_url', '3': 4, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'content', '3': 5, '4': 1, '5': 9, '10': 'content'},
    {'1': 'timestamp', '3': 6, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `BroadcastMessageSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastMessageSignalDescriptor = $convert.base64Decode(
    'ChZCcm9hZGNhc3RNZXNzYWdlU2lnbmFsEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZB'
    'IXCgd1c2VyX2lkGAIgASgJUgZ1c2VySWQSGgoIbmlja25hbWUYAyABKAlSCG5pY2tuYW1lEh0K'
    'CmF2YXRhcl91cmwYBCABKAlSCWF2YXRhclVybBIYCgdjb250ZW50GAUgASgJUgdjb250ZW50Eh'
    'wKCXRpbWVzdGFtcBgGIAEoA1IJdGltZXN0YW1w');

@$core.Deprecated('Use teleportArrivalSignalDescriptor instead')
const TeleportArrivalSignal$json = {
  '1': 'TeleportArrivalSignal',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'source_map_id', '3': 2, '4': 1, '5': 9, '10': 'sourceMapId'},
    {'1': 'target_x', '3': 3, '4': 1, '5': 1, '10': 'targetX'},
    {'1': 'target_y', '3': 4, '4': 1, '5': 1, '10': 'targetY'},
    {'1': 'issued_at', '3': 5, '4': 1, '5': 3, '10': 'issuedAt'},
  ],
};

/// Descriptor for `TeleportArrivalSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List teleportArrivalSignalDescriptor = $convert.base64Decode(
    'ChVUZWxlcG9ydEFycml2YWxTaWduYWwSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEiIKDXNvdX'
    'JjZV9tYXBfaWQYAiABKAlSC3NvdXJjZU1hcElkEhkKCHRhcmdldF94GAMgASgBUgd0YXJnZXRY'
    'EhkKCHRhcmdldF95GAQgASgBUgd0YXJnZXRZEhsKCWlzc3VlZF9hdBgFIAEoA1IIaXNzdWVkQX'
    'Q=');

@$core.Deprecated('Use chatMessageSignalDescriptor instead')
const ChatMessageSignal$json = {
  '1': 'ChatMessageSignal',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'nickname', '3': 3, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'message_type', '3': 5, '4': 1, '5': 9, '10': 'messageType'},
    {'1': 'is_anonymous', '3': 6, '4': 1, '5': 8, '10': 'isAnonymous'},
    {'1': 'timestamp', '3': 7, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `ChatMessageSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageSignalDescriptor = $convert.base64Decode(
    'ChFDaGF0TWVzc2FnZVNpZ25hbBIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSFwoHdX'
    'Nlcl9pZBgCIAEoCVIGdXNlcklkEhoKCG5pY2tuYW1lGAMgASgJUghuaWNrbmFtZRIYCgdjb250'
    'ZW50GAQgASgJUgdjb250ZW50EiEKDG1lc3NhZ2VfdHlwZRgFIAEoCVILbWVzc2FnZVR5cGUSIQ'
    'oMaXNfYW5vbnltb3VzGAYgASgIUgtpc0Fub255bW91cxIcCgl0aW1lc3RhbXAYByABKANSCXRp'
    'bWVzdGFtcA==');

@$core.Deprecated('Use onlineCountChangedSignalDescriptor instead')
const OnlineCountChangedSignal$json = {
  '1': 'OnlineCountChangedSignal',
  '2': [
    {'1': 'total', '3': 1, '4': 1, '5': 5, '10': 'total'},
    {'1': 'by_map', '3': 2, '4': 3, '5': 11, '6': '.lobby.OnlineCountChangedSignal.ByMapEntry', '10': 'byMap'},
  ],
  '3': [OnlineCountChangedSignal_ByMapEntry$json],
};

@$core.Deprecated('Use onlineCountChangedSignalDescriptor instead')
const OnlineCountChangedSignal_ByMapEntry$json = {
  '1': 'ByMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 5, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `OnlineCountChangedSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List onlineCountChangedSignalDescriptor = $convert.base64Decode(
    'ChhPbmxpbmVDb3VudENoYW5nZWRTaWduYWwSFAoFdG90YWwYASABKAVSBXRvdGFsEkEKBmJ5X2'
    '1hcBgCIAMoCzIqLmxvYmJ5Lk9ubGluZUNvdW50Q2hhbmdlZFNpZ25hbC5CeU1hcEVudHJ5UgVi'
    'eU1hcBo4CgpCeU1hcEVudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgFUgV2YW'
    'x1ZToCOAE=');

