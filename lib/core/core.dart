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
export 'api/server_api.dart';
export 'api/update_api.dart';
export 'api/update_log_api.dart';
export 'api/issue_api.dart';

// Models
export 'models/announcement_models.dart';
export 'models/server_models.dart';
export 'models/update_models.dart';
export 'models/update_log_models.dart';
export 'models/user_info.dart';
export 'models/issue_models.dart';

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
export 'services/game_launcher_service.dart';
export 'services/floating_window_service.dart';
export 'services/custom_server_service.dart';
export 'services/image_url_service.dart';

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

// Constants
export 'constants/api_constants.dart';
export 'constants/app_constants.dart';
export 'constants/fallback_data.dart';

// Widgets
export 'widgets/exit_dialog.dart';
export 'widgets/page_view_with_listener.dart';
export 'widgets/navigation/app_navigation.dart';
export 'widgets/update_dialog.dart';
export 'widgets/rich_text_editor.dart';
export 'widgets/image_viewer_dialog.dart';
export 'widgets/clickable_image.dart';
export 'widgets/map_background.dart';
export 'widgets/rich_text_viewer.dart';
