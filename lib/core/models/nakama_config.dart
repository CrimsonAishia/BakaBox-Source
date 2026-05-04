import '../api/env_config.dart';

/// Nakama 服务器连接配置
class NakamaConfig {
  final String host;
  final int port;
  final int grpcPort;
  final String serverKey;
  final bool ssl;

  const NakamaConfig({
    required this.host,
    required this.port,
    required this.grpcPort,
    required this.serverKey,
    required this.ssl,
  });

  /// 从环境配置（EnvConfig）读取 Nakama 服务器配置
  factory NakamaConfig.fromEnv() => NakamaConfig(
        host: EnvConfig.nakamaHost,
        port: EnvConfig.nakamaPort,
        grpcPort: EnvConfig.nakamaGrpcPort,
        serverKey: EnvConfig.nakamaServerKey,
        ssl: EnvConfig.nakamaSsl,
      );
}
