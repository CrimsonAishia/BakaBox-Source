import 'lobby_models.dart';
import 'proto/lobby.pb.dart' as pb;

/// 消息信封解析工具类
///
/// 仅用于接收方向：将 Protobuf 字节数组反序列化为 [LobbyServerEvent]。
/// 发送方向直接使用 [pb.LobbyEnvelope]。
class LobbyEnvelopeParser {
  LobbyEnvelopeParser._();

  /// 从 Protobuf 字节数组反序列化为 [LobbyServerEvent]。
  ///
  /// 对畸形数据返回 null，不抛出异常。
  static LobbyServerEvent? fromBytes(List<int> bytes) {
    try {
      final envelope = pb.LobbyEnvelope.fromBuffer(bytes);
      if (envelope.type.isEmpty) return null;

      return LobbyServerEvent(
        type: envelope.type,
        timestamp: DateTime.fromMillisecondsSinceEpoch(envelope.ts.toInt()),
        traceId: envelope.traceId.isEmpty ? '' : envelope.traceId,
        envelope: envelope,
      );
    } catch (e) {
      return null;
    }
  }
}
