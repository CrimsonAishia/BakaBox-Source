/// Core module - 共享业务逻辑层
///
/// 包含所有平台共享的：
/// - API 客户端和接口
/// - 数据模型
/// - 状态管理 (Bloc)
/// - 路由 (GoRouter)
/// - 业务服务
/// - 工具类
/// - 常量配置
/// - 共享组件

library;

// API
export 'api/api_client.dart';
export 'api/announcement_api.dart';
export 'api/score_api.dart';
export 'api/server_api.dart';
export 'api/server_stats_api.dart';
export 'api/update_api.dart';
export 'api/update_log_api.dart';
export 'api/issue_api.dart';
export 'api/feature_status_api.dart';
export 'api/character_api.dart';

// Exceptions
export 'exceptions/app_exception.dart';

// Models
export 'models/announcement_models.dart';
export 'models/server_models.dart';
export 'models/server_score.dart';
export 'models/server_stats_models.dart';
export 'models/update_models.dart';
export 'models/update_log_models.dart';
export 'models/user_info.dart';
export 'models/issue_models.dart';
export 'models/feature_status_models.dart';
export 'models/character_models.dart';
export 'models/map_subscription_models.dart';
export 'models/bilibili_content_models.dart';
export 'models/lobby_models.dart';
export 'models/nakama_config.dart';
export 'models/lobby_envelope.dart';

// Bloc
export 'bloc/bloc.dart';

// Router
export 'router/app_router.dart';

// Services
export 'services/announcement_read_service.dart';
export 'services/auth_service.dart';
export 'services/token_service.dart';
export 'services/source_server_service.dart';
export 'services/update_service.dart';
export 'services/analytics_service.dart';
export 'services/custom_server_service.dart';
export 'services/draft_service.dart';
export 'services/image_url_service.dart';
export 'services/map_subscription_service.dart';
export 'services/bilibili_service.dart';
export 'services/lobby_nakama_service.dart';
export 'services/lobby_asset_cache_service.dart';
export 'services/lobby_image_cache_service.dart';
export 'services/lobby_map_loader_service.dart';
export 'services/broadcast_notification_service.dart';
export 'services/app_permission_service.dart';
export 'services/scheduler_service.dart';

// Desktop-only services（桌面端直接 import，不通过 core.dart 导出）
// - game_launcher_service.dart
// - floating_window_service.dart
// - score_upload_service.dart
// - tts_service.dart

// Utils
export 'utils/announcement_utils.dart';
export 'utils/app_directory_service.dart';
export 'utils/cache_service.dart';
export 'utils/category_utils.dart';
export 'utils/error_utils.dart';
export 'utils/formatters.dart';
export 'utils/log_service.dart';
export 'utils/platform_utils.dart';
export 'utils/server_item_utils.dart';
export 'utils/time_utils.dart';
export 'utils/toast_utils.dart';
export 'utils/screen_wakelock.dart';

// Constants
export 'constants/api_constants.dart';
export 'constants/app_constants.dart';
export 'constants/fallback_data.dart';

// Widgets
export 'services/app_exit_service.dart';
export 'widgets/page_view_with_listener.dart';
export 'widgets/navigation/app_navigation.dart';
export 'widgets/update_dialog.dart';
export 'widgets/rich_text_editor.dart';
export 'widgets/image_viewer_dialog.dart';
export 'widgets/clickable_image.dart';
export 'widgets/map_background.dart';
export 'widgets/rich_text_viewer.dart';
export 'widgets/feature_gate.dart';
export 'widgets/lobby_kicked_overlay.dart';
