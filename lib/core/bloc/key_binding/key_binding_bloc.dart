import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/api.dart';
import '../../api/key_config_api.dart';
import '../../models/key_config_models.dart';
import '../../services/autoexec_service.dart';
import '../../utils/error_utils.dart';
import '../../utils/key_placeholder_parser.dart';
import '../../utils/log_service.dart';
import 'key_binding_event.dart';
import 'key_binding_state.dart';

/// 按键绑定 Bloc
///
/// 管理按键配置的加载、应用、发布等功能
class KeyBindingBloc extends Bloc<KeyBindingEvent, KeyBindingState> {
  final KeyConfigApi _api;
  final AutoexecService _autoexecService;

  KeyBindingBloc({KeyConfigApi? api, AutoexecService? autoexecService})
    : _api = api ?? KeyConfigApi(),
      _autoexecService = autoexecService ?? AutoexecService(),
      super(const KeyBindingState()) {
    on<KeyBindingLoadConfigs>(_onLoadConfigs);
    on<KeyBindingLoadCategories>(_onLoadCategories);
    on<KeyBindingSelectConfig>(_onSelectConfig);
    on<KeyBindingClearSelection>(_onClearSelection);
    on<KeyBindingSetKeyBinding>(_onSetKeyBinding);
    on<KeyBindingClearKeyBinding>(_onClearKeyBinding);
    on<KeyBindingClearAllKeyBindings>(_onClearAllKeyBindings);
    on<KeyBindingApplyConfig>(_onApplyConfig);
    on<KeyBindingRemoveAppliedConfig>(_onRemoveAppliedConfig);
    on<KeyBindingLoadAutoexecContent>(_onLoadAutoexecContent);
    on<KeyBindingSaveAutoexecContent>(_onSaveAutoexecContent);
    on<KeyBindingCreateAutoexecFile>(_onCreateAutoexecFile);
    on<KeyBindingPublishConfig>(_onPublishConfig);
    on<KeyBindingDeleteConfig>(_onDeleteConfig);
    on<KeyBindingUpdateConfig>(_onUpdateConfig);
    on<KeyBindingSetCategoryFilter>(_onSetCategoryFilter);
    on<KeyBindingSetSearchKeyword>(_onSetSearchKeyword);
    on<KeyBindingSetShowMyConfigs>(_onSetShowMyConfigs);
    on<KeyBindingOpenInExplorer>(_onOpenInExplorer);
    on<KeyBindingCopyAutoexecContent>(_onCopyAutoexecContent);
    on<KeyBindingClearMessages>(_onClearMessages);
    on<KeyBindingLoadMyConfigs>(_onLoadMyConfigs);
    on<KeyBindingVote>(_onVote);
    on<KeyBindingLoadComments>(_onLoadComments);
    on<KeyBindingAddComment>(_onAddComment);
    on<KeyBindingClearComments>(_onClearComments);
    on<KeyBindingLoadChangeRequests>(_onLoadChangeRequests);
    on<KeyBindingCancelChangeRequest>(_onCancelChangeRequest);
  }

  /// 加载配置列表
  Future<void> _onLoadConfigs(
    KeyBindingLoadConfigs event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      LogService.d('[KeyBindingBloc] 开始加载配置列表');

      final response = await _api.getConfigList(
        categoryId: state.categoryFilter,
        keyword: state.searchKeyword,
        isActive: true,
      );

      if (response != null) {
        emit(
          state.copyWith(
            configs: response.items,
            isLoading: false,
            successMessage: event.showSuccessMessage ? '已刷新配置列表' : null,
          ),
        );
        LogService.d('[KeyBindingBloc] 加载配置列表成功，共 ${response.items.length} 条');
      } else {
        // 用户主动刷新时才显示错误，后台静默刷新不覆盖 successMessage
        if (event.showSuccessMessage) {
          emit(state.copyWith(isLoading: false, error: '加载配置列表失败'));
        } else {
          emit(state.copyWith(isLoading: false));
        }
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 加载配置列表失败', e);
      // 用户主动刷新时才显示错误，后台静默刷新不覆盖 successMessage
      if (event.showSuccessMessage) {
        emit(
          state.copyWith(
            isLoading: false,
            error: ErrorUtils.getErrorMessage(e, defaultMessage: '加载配置列表失败'),
          ),
        );
      } else {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  /// 加载分类列表
  Future<void> _onLoadCategories(
    KeyBindingLoadCategories event,
    Emitter<KeyBindingState> emit,
  ) async {
    try {
      LogService.d('[KeyBindingBloc] 开始加载分类列表');

      final categories = await _api.getCategories();
      emit(state.copyWith(categories: categories));

      LogService.d('[KeyBindingBloc] 加载分类列表成功，共 ${categories.length} 个分类');
    } catch (e) {
      LogService.e('[KeyBindingBloc] 加载分类列表失败', e);
    }
  }

  /// 选择配置
  Future<void> _onSelectConfig(
    KeyBindingSelectConfig event,
    Emitter<KeyBindingState> emit,
  ) async {
    // 解析配置脚本中的占位符，初始化按键绑定映射
    final placeholders = KeyPlaceholderParser.parse(event.config.config);
    final keyBindings = <String, String>{};

    // 为每个占位符创建空的绑定
    for (final placeholder in placeholders) {
      keyBindings[placeholder.label] = '';
    }

    emit(
      state.copyWith(
        selectedConfig: event.config,
        keyBindings: keyBindings,
        clearError: true,
        clearComments: true,
        commentTotal: 0,
      ),
    );

    // 已通过的配置自动加载评论列表
    if (event.config.isApproved) {
      add(KeyBindingLoadComments(configId: event.config.id));
    }

    LogService.d(
      '[KeyBindingBloc] 选择配置: ${event.config.name}，占位符数量: ${placeholders.length}',
    );
  }

  /// 清除选中的配置
  void _onClearSelection(
    KeyBindingClearSelection event,
    Emitter<KeyBindingState> emit,
  ) {
    emit(state.copyWith(clearSelectedConfig: true, keyBindings: const {}));
  }

  /// 设置按键绑定
  void _onSetKeyBinding(
    KeyBindingSetKeyBinding event,
    Emitter<KeyBindingState> emit,
  ) {
    final keyBindings = Map<String, String>.from(state.keyBindings);
    keyBindings[event.label] = event.key;
    emit(state.copyWith(keyBindings: keyBindings));

    LogService.d('[KeyBindingBloc] 设置按键绑定: ${event.label} -> ${event.key}');
  }

  /// 清除按键绑定
  void _onClearKeyBinding(
    KeyBindingClearKeyBinding event,
    Emitter<KeyBindingState> emit,
  ) {
    final keyBindings = Map<String, String>.from(state.keyBindings);
    keyBindings[event.label] = '';
    emit(state.copyWith(keyBindings: keyBindings));
  }

  /// 清除所有按键绑定
  void _onClearAllKeyBindings(
    KeyBindingClearAllKeyBindings event,
    Emitter<KeyBindingState> emit,
  ) {
    final keyBindings = Map<String, String>.from(state.keyBindings);
    for (final key in keyBindings.keys) {
      keyBindings[key] = '';
    }
    emit(state.copyWith(keyBindings: keyBindings));
  }

  /// 应用配置到 autoexec.cfg
  Future<void> _onApplyConfig(
    KeyBindingApplyConfig event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      LogService.d('[KeyBindingBloc] 开始应用配置: ${event.config.name}');

      // 检查游戏路径
      final hasPath = await _autoexecService.hasGamePath();
      if (!hasPath) {
        emit(state.copyWith(isSaving: false, error: '请先在设置中配置游戏路径'));
        return;
      }

      // 验证按键绑定（如果需要）
      if (event.config.needsKeybind) {
        if (!KeyPlaceholderParser.validate(
          event.config.config,
          event.keyBindings,
        )) {
          final missing = KeyPlaceholderParser.getMissingBindings(
            event.config.config,
            event.keyBindings,
          );
          emit(
            state.copyWith(
              isSaving: false,
              error: '请为以下按键选择绑定: ${missing.join(", ")}',
            ),
          );
          return;
        }
      }

      // 读取当前文件内容
      String content = await _autoexecService.readContent() ?? '';

      // 如果文件不存在，先创建
      if (content.isEmpty) {
        final created = await _autoexecService.createFile();
        if (!created) {
          emit(state.copyWith(isSaving: false, error: '创建 autoexec.cfg 文件失败'));
          return;
        }
        content = await _autoexecService.readContent() ?? '';
      }

      // 添加配置块
      content = _autoexecService.addConfigBlock(
        content,
        event.config.configId,
        event.config.config,
        event.keyBindings,
        configName: event.config.name,
      );

      // 保存文件
      final saved = await _autoexecService.saveContent(content);
      if (!saved) {
        emit(state.copyWith(isSaving: false, error: '保存 autoexec.cfg 文件失败'));
        return;
      }

      // 重新解析已应用的配置块
      final appliedConfigs = _autoexecService.parseConfigBlocks(content);

      emit(
        state.copyWith(
          isSaving: false,
          autoexecContent: content,
          appliedConfigs: appliedConfigs,
          successMessage: '配置 "${event.config.name}" 已成功应用，重启游戏生效',
        ),
      );

      // 记录应用次数（异步执行，不阻塞主流程）
      _api.useConfig(event.config.id);

      LogService.d('[KeyBindingBloc] 配置应用成功: ${event.config.name}');
    } catch (e) {
      LogService.e('[KeyBindingBloc] 应用配置失败', e);
      emit(
        state.copyWith(
          isSaving: false,
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '应用配置失败'),
        ),
      );
    }
  }

  /// 移除已应用的配置
  Future<void> _onRemoveAppliedConfig(
    KeyBindingRemoveAppliedConfig event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      LogService.d('[KeyBindingBloc] 开始移除配置: ${event.configId}');

      // 读取当前文件内容
      final content = await _autoexecService.readContent();
      if (content == null) {
        emit(state.copyWith(isSaving: false, error: 'autoexec.cfg 文件不存在'));
        return;
      }

      // 移除配置块
      final newContent = _autoexecService.removeConfigBlock(
        content,
        event.configId,
      );

      // 保存文件
      final saved = await _autoexecService.saveContent(newContent);
      if (!saved) {
        emit(state.copyWith(isSaving: false, error: '保存 autoexec.cfg 文件失败'));
        return;
      }

      // 重新解析已应用的配置块
      final appliedConfigs = _autoexecService.parseConfigBlocks(newContent);

      emit(
        state.copyWith(
          isSaving: false,
          autoexecContent: newContent,
          appliedConfigs: appliedConfigs,
          successMessage: '配置已成功移除，重启游戏生效',
        ),
      );

      LogService.d('[KeyBindingBloc] 配置移除成功: ${event.configId}');
    } catch (e) {
      LogService.e('[KeyBindingBloc] 移除配置失败', e);
      emit(
        state.copyWith(
          isSaving: false,
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '移除配置失败'),
        ),
      );
    }
  }

  /// 加载 autoexec.cfg 内容
  Future<void> _onLoadAutoexecContent(
    KeyBindingLoadAutoexecContent event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(state.copyWith(isLoadingAutoexec: true, clearError: true));

    try {
      LogService.d('[KeyBindingBloc] 开始加载 autoexec.cfg');

      // 检查游戏路径是否已配置
      final hasPath = await _autoexecService.hasGamePath();
      emit(state.copyWith(hasGamePath: hasPath));

      if (!hasPath) {
        emit(
          state.copyWith(isLoadingAutoexec: false, autoexecFileExists: false),
        );
        return;
      }

      // 检查文件是否存在
      final fileExists = await _autoexecService.fileExists();
      emit(state.copyWith(autoexecFileExists: fileExists));

      if (!fileExists) {
        emit(
          state.copyWith(
            isLoadingAutoexec: false,
            clearAutoexecContent: true,
            appliedConfigs: const [],
          ),
        );
        return;
      }

      // 读取文件内容
      final content = await _autoexecService.readContent();

      if (content != null) {
        // 解析已应用的配置块
        final appliedConfigs = _autoexecService.parseConfigBlocks(content);

        emit(
          state.copyWith(
            isLoadingAutoexec: false,
            autoexecContent: content,
            appliedConfigs: appliedConfigs,
          ),
        );

        LogService.d(
          '[KeyBindingBloc] 加载 autoexec.cfg 成功，已应用 ${appliedConfigs.length} 个配置',
        );
      } else {
        emit(
          state.copyWith(
            isLoadingAutoexec: false,
            clearAutoexecContent: true,
            appliedConfigs: const [],
          ),
        );
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 加载 autoexec.cfg 失败', e);
      emit(
        state.copyWith(
          isLoadingAutoexec: false,
          error: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '加载 autoexec.cfg 失败',
          ),
        ),
      );
    }
  }

  /// 保存 autoexec.cfg 内容
  Future<void> _onSaveAutoexecContent(
    KeyBindingSaveAutoexecContent event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      LogService.d('[KeyBindingBloc] 开始保存 autoexec.cfg');

      final saved = await _autoexecService.saveContent(event.content);

      if (saved) {
        // 重新解析已应用的配置块
        final appliedConfigs = _autoexecService.parseConfigBlocks(
          event.content,
        );

        emit(
          state.copyWith(
            isSaving: false,
            autoexecContent: event.content,
            appliedConfigs: appliedConfigs,
            successMessage: 'autoexec.cfg 保存成功，重启游戏生效',
          ),
        );

        LogService.d('[KeyBindingBloc] 保存 autoexec.cfg 成功');
      } else {
        emit(state.copyWith(isSaving: false, error: '保存 autoexec.cfg 失败'));
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 保存 autoexec.cfg 失败', e);
      emit(
        state.copyWith(
          isSaving: false,
          error: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '保存 autoexec.cfg 失败',
          ),
        ),
      );
    }
  }

  /// 创建 autoexec.cfg 文件
  Future<void> _onCreateAutoexecFile(
    KeyBindingCreateAutoexecFile event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      LogService.d('[KeyBindingBloc] 开始创建 autoexec.cfg');

      final created = await _autoexecService.createFile();

      if (created) {
        emit(
          state.copyWith(
            isSaving: false,
            autoexecFileExists: true,
            successMessage: 'autoexec.cfg 创建成功',
          ),
        );

        // 重新加载内容
        add(KeyBindingLoadAutoexecContent());

        LogService.d('[KeyBindingBloc] 创建 autoexec.cfg 成功');
      } else {
        emit(state.copyWith(isSaving: false, error: '创建 autoexec.cfg 失败'));
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 创建 autoexec.cfg 失败', e);
      emit(
        state.copyWith(
          isSaving: false,
          error: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '创建 autoexec.cfg 失败',
          ),
        ),
      );
    }
  }

  /// 发布配置
  Future<void> _onPublishConfig(
    KeyBindingPublishConfig event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isPublishing: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      LogService.d('[KeyBindingBloc] 开始发布配置: ${event.request.name}');

      final config = await _api.createConfig(event.request);

      if (config != null) {
        emit(
          state.copyWith(
            isPublishing: false,
            successMessage: '配置 "${event.request.name}" 发布成功',
          ),
        );

        // 刷新配置列表（不显示成功提示，避免双重提示）
        add(const KeyBindingLoadConfigs(showSuccessMessage: false));
        // 刷新用户配置列表
        add(const KeyBindingLoadMyConfigs(showSuccessMessage: false));

        LogService.d('[KeyBindingBloc] 发布配置成功: ${event.request.name}');
      } else {
        emit(state.copyWith(isPublishing: false, error: '发布配置失败'));
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 发布配置失败', e);
      emit(
        state.copyWith(
          isPublishing: false,
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '发布配置失败'),
        ),
      );
    }
  }

  /// 删除配置
  Future<void> _onDeleteConfig(
    KeyBindingDeleteConfig event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      LogService.d(
        '[KeyBindingBloc] 开始删除配置: id=${event.id}, editReason=${event.editReason}',
      );

      await _api.deleteConfig(event.id, editReason: event.editReason);

      // 判断是否为已通过配置（有 editReason 说明走的是变更申请流程）
      final isChangeRequest =
          event.editReason != null && event.editReason!.isNotEmpty;

      // 如果是直接删除（非变更申请），清除选中状态
      final shouldClearSelection =
          !isChangeRequest && state.selectedConfig?.id == event.id;

      emit(
        state.copyWith(
          isLoading: false,
          successMessage: isChangeRequest ? '删除申请已提交，等待管理员审核' : '配置删除成功',
          clearSelectedConfig: shouldClearSelection,
        ),
      );

      // 刷新配置列表
      add(const KeyBindingLoadConfigs(showSuccessMessage: false));
      add(const KeyBindingLoadMyConfigs(showSuccessMessage: false));
      // 如果是变更申请，刷新变更申请列表
      if (isChangeRequest) {
        add(const KeyBindingLoadChangeRequests());
      }

      LogService.d('[KeyBindingBloc] 删除配置成功: id=${event.id}');
    } catch (e) {
      LogService.e('[KeyBindingBloc] 删除配置失败', e);
      final errorMsg = _getChangeRequestErrorMessage(e) ??
          ErrorUtils.getErrorMessage(e, defaultMessage: '删除配置失败');
      emit(state.copyWith(isLoading: false, error: errorMsg));
    }
  }

  /// 更新配置
  Future<void> _onUpdateConfig(
    KeyBindingUpdateConfig event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      LogService.d(
        '[KeyBindingBloc] 开始更新配置: id=${event.id}, name=${event.request.name}, editReason=${event.editReason}',
      );

      final config = await _api.updateConfig(
        event.id,
        event.request,
        editReason: event.editReason,
      );

      if (config != null) {
        // 判断是否为变更申请（已通过配置编辑）
        final isChangeRequest =
            event.editReason != null && event.editReason!.isNotEmpty;

        emit(
          state.copyWith(
            isSaving: false,
            successMessage: isChangeRequest
                ? '编辑申请已提交，等待管理员审核'
                : '配置 "${event.request.name}" 更新成功',
            selectedConfig: config,
          ),
        );

        add(const KeyBindingLoadConfigs(showSuccessMessage: false));
        add(const KeyBindingLoadMyConfigs(showSuccessMessage: false));
        if (isChangeRequest) {
          add(const KeyBindingLoadChangeRequests());
        }

        LogService.d('[KeyBindingBloc] 更新配置成功: id=${event.id}');
      } else {
        emit(state.copyWith(isSaving: false, error: '更新配置失败'));
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 更新配置失败', e);
      final errorMsg = _getChangeRequestErrorMessage(e) ??
          ErrorUtils.getErrorMessage(e, defaultMessage: '更新配置失败');
      emit(state.copyWith(isSaving: false, error: errorMsg));
    }
  }

  /// 设置分类筛选
  Future<void> _onSetCategoryFilter(
    KeyBindingSetCategoryFilter event,
    Emitter<KeyBindingState> emit,
  ) async {
    // 使用事件中的 categoryId，而不是 state 中的值
    final categoryId = event.categoryId;

    if (categoryId == null) {
      emit(
        state.copyWith(
          clearCategoryFilter: true,
          isLoading: true,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          categoryFilter: categoryId,
          isLoading: true,
          clearError: true,
        ),
      );
    }

    // 直接加载配置，使用事件中的 categoryId
    try {
      final response = await _api.getConfigList(
        categoryId: categoryId,
        keyword: state.searchKeyword,
        isActive: true,
      );

      if (response != null) {
        emit(state.copyWith(configs: response.items, isLoading: false));
      } else {
        emit(state.copyWith(isLoading: false, error: '加载配置列表失败'));
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 加载配置列表失败', e);
      emit(
        state.copyWith(
          isLoading: false,
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '加载配置列表失败'),
        ),
      );
    }
  }

  /// 设置搜索关键词
  Future<void> _onSetSearchKeyword(
    KeyBindingSetSearchKeyword event,
    Emitter<KeyBindingState> emit,
  ) async {
    if (event.keyword == null || event.keyword!.isEmpty) {
      emit(state.copyWith(clearSearchKeyword: true));
    } else {
      emit(state.copyWith(searchKeyword: event.keyword));
    }

    // 根据当前模式加载对应的配置列表
    if (state.showMyConfigs) {
      add(const KeyBindingLoadMyConfigs());
    } else {
      add(const KeyBindingLoadConfigs());
    }
  }

  /// 设置是否显示用户自己的配置
  Future<void> _onSetShowMyConfigs(
    KeyBindingSetShowMyConfigs event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        showMyConfigs: event.showMyConfigs,
        clearCategoryFilter: true,
      ),
    );

    if (event.showMyConfigs) {
      // 加载用户配置
      add(const KeyBindingLoadMyConfigs());
    } else {
      // 加载公开配置
      add(const KeyBindingLoadConfigs());
    }
  }

  /// 在文件管理器中打开
  Future<void> _onOpenInExplorer(
    KeyBindingOpenInExplorer event,
    Emitter<KeyBindingState> emit,
  ) async {
    try {
      await _autoexecService.openInExplorer();
    } catch (e) {
      LogService.e('[KeyBindingBloc] 打开文件管理器失败', e);
      emit(state.copyWith(error: '打开文件管理器失败'));
    }
  }

  /// 复制 autoexec.cfg 内容到剪贴板
  Future<void> _onCopyAutoexecContent(
    KeyBindingCopyAutoexecContent event,
    Emitter<KeyBindingState> emit,
  ) async {
    if (state.autoexecContent != null && state.autoexecContent!.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: state.autoexecContent!));
      emit(state.copyWith(successMessage: '已复制到剪贴板'));
    }
  }

  /// 清除消息
  void _onClearMessages(
    KeyBindingClearMessages event,
    Emitter<KeyBindingState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccessMessage: true));
  }

  /// 加载用户自己的配置列表
  Future<void> _onLoadMyConfigs(
    KeyBindingLoadMyConfigs event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(state.copyWith(isLoadingMyConfigs: true, clearError: true));

    try {
      LogService.d('[KeyBindingBloc] 开始加载用户配置列表');

      final response = await _api.getMyConfigList(keyword: state.searchKeyword);

      if (response != null) {
        emit(
          state.copyWith(
            myConfigs: response.items,
            isLoadingMyConfigs: false,
            successMessage: event.showSuccessMessage ? '已刷新我的配置列表' : null,
          ),
        );
        LogService.d(
          '[KeyBindingBloc] 加载用户配置列表成功，共 ${response.items.length} 条',
        );
      } else {
        // 用户主动刷新时才显示错误，后台静默刷新不覆盖 successMessage
        if (event.showSuccessMessage) {
          emit(state.copyWith(isLoadingMyConfigs: false, error: '加载我的配置列表失败'));
        } else {
          emit(state.copyWith(isLoadingMyConfigs: false));
        }
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 加载用户配置列表失败', e);
      // 用户主动刷新时才显示错误，后台静默刷新不覆盖 successMessage
      if (event.showSuccessMessage) {
        emit(
          state.copyWith(
            isLoadingMyConfigs: false,
            error: ErrorUtils.getErrorMessage(e, defaultMessage: '加载我的配置列表失败'),
          ),
        );
      } else {
        emit(state.copyWith(isLoadingMyConfigs: false));
      }
    }
  }

  /// 投票
  Future<void> _onVote(
    KeyBindingVote event,
    Emitter<KeyBindingState> emit,
  ) async {
    try {
      LogService.d(
        '[KeyBindingBloc] 开始投票: configId=${event.configId}, voteType=${event.voteType}',
      );

      final response = await _api.vote(event.configId, event.voteType);

      if (response != null && response.success) {
        // 更新配置列表中的投票状态
        final updatedConfigs = state.configs.map((config) {
          if (config.id == event.configId) {
            return config.copyWith(
              upCount: response.upCount,
              downCount: response.downCount,
              voteCount: response.voteCount,
              hasVoted: response.hasVoted,
              voteType: response.voteType,
            );
          }
          return config;
        }).toList();

        // 如果当前选中的配置是被投票的配置，也更新它
        KeyConfig? updatedSelectedConfig;
        if (state.selectedConfig?.id == event.configId) {
          updatedSelectedConfig = state.selectedConfig!.copyWith(
            upCount: response.upCount,
            downCount: response.downCount,
            voteCount: response.voteCount,
            hasVoted: response.hasVoted,
            voteType: response.voteType,
          );
        }

        emit(
          state.copyWith(
            configs: updatedConfigs,
            selectedConfig: updatedSelectedConfig ?? state.selectedConfig,
          ),
        );

        LogService.d(
          '[KeyBindingBloc] 投票成功: upCount=${response.upCount}, downCount=${response.downCount}',
        );
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 投票失败', e);
      // 检查是否是"不能对自己的配置投反对票"的错误
      final errorMsg = e.toString();
      if (errorMsg.contains('40003') || errorMsg.contains('不能对自己')) {
        emit(state.copyWith(error: '不能对自己的配置投反对票'));
      } else {
        emit(
          state.copyWith(
            error: ErrorUtils.getErrorMessage(e, defaultMessage: '投票失败'),
          ),
        );
      }
    }
  }

  /// 加载评论列表
  Future<void> _onLoadComments(
    KeyBindingLoadComments event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(state.copyWith(isLoadingComments: true, clearError: true));

    try {
      LogService.d(
        '[KeyBindingBloc] 开始加载评论列表: configId=${event.configId}, page=${event.page}',
      );

      final response = await _api.getComments(event.configId, page: event.page);

      emit(
        state.copyWith(
          comments: response.items,
          commentTotal: response.total,
          isLoadingComments: false,
        ),
      );

      LogService.d('[KeyBindingBloc] 加载评论列表成功，共 ${response.items.length} 条');
    } catch (e) {
      LogService.e('[KeyBindingBloc] 加载评论列表失败', e);
      emit(
        state.copyWith(
          isLoadingComments: false,
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '加载评论列表失败'),
        ),
      );
    }
  }

  /// 发表评论
  Future<void> _onAddComment(
    KeyBindingAddComment event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isSubmittingComment: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      LogService.d('[KeyBindingBloc] 开始发表评论: configId=${event.configId}');

      final response = await _api.addComment(
        event.configId,
        event.content,
        images: event.images,
        replyToId: event.replyToId,
      );

      if (response != null) {
        // 更新选中配置的评论数（如果是当前选中的配置）
        KeyConfig? updatedConfig;
        if (state.selectedConfig?.id == event.configId) {
          updatedConfig = state.selectedConfig!.copyWith(
            commentCount: state.selectedConfig!.commentCount + 1,
          );
        }

        emit(
          state.copyWith(
            isSubmittingComment: false,
            successMessage: '评论发表成功',
            selectedConfig: updatedConfig,
          ),
        );

        // 重新加载评论列表
        add(KeyBindingLoadComments(configId: event.configId));

        LogService.d('[KeyBindingBloc] 发表评论成功');
      } else {
        emit(state.copyWith(isSubmittingComment: false, error: '发表评论失败'));
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 发表评论失败', e);
      emit(
        state.copyWith(
          isSubmittingComment: false,
          error: ErrorUtils.getErrorMessage(e, defaultMessage: '发表评论失败'),
        ),
      );
    }
  }

  /// 清除评论列表
  void _onClearComments(
    KeyBindingClearComments event,
    Emitter<KeyBindingState> emit,
  ) {
    emit(state.copyWith(clearComments: true, commentTotal: 0));
  }

  /// 加载我的变更申请列表
  Future<void> _onLoadChangeRequests(
    KeyBindingLoadChangeRequests event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(state.copyWith(isLoadingChangeRequests: true, clearError: true));

    try {
      LogService.d('[KeyBindingBloc] 开始加载变更申请列表');

      final response = await _api.getMyChangeRequests();

      if (response != null) {
        emit(
          state.copyWith(
            changeRequests: response.items,
            changeRequestTotal: response.total,
            isLoadingChangeRequests: false,
            successMessage: event.showSuccessMessage ? '已刷新变更申请列表' : null,
          ),
        );
        LogService.d(
          '[KeyBindingBloc] 加载变更申请列表成功，共 ${response.items.length} 条',
        );
      } else {
        emit(state.copyWith(isLoadingChangeRequests: false));
      }
    } catch (e) {
      LogService.e('[KeyBindingBloc] 加载变更申请列表失败', e);
      // 仅重置加载状态，不覆盖 successMessage（避免掩盖前序操作的成功提示）
      emit(state.copyWith(isLoadingChangeRequests: false));
    }
  }

  /// 解析变更申请相关的业务错误码
  String? _getChangeRequestErrorMessage(Object e) {
    if (e is ApiException) {
      return switch (e.code) {
        20533 => '该配置已有待审核的变更申请，请等待审核完成后再提交',
        20530 => '已通过的配置操作时需要填写理由',
        _ => null,
      };
    }
    return null;
  }

  /// 撤销变更申请
  Future<void> _onCancelChangeRequest(
    KeyBindingCancelChangeRequest event,
    Emitter<KeyBindingState> emit,
  ) async {
    emit(
      state.copyWith(
        isCancellingChangeRequest: true,
        clearError: true,
        clearSuccessMessage: true,
      ),
    );
    try {
      LogService.d('[KeyBindingBloc] 撤销变更申请: configId=${event.configId}');
      await _api.cancelChangeRequest(event.configId);

      emit(
        state.copyWith(
          isCancellingChangeRequest: false,
          successMessage: '变更申请已撤销',
          // 立即更新 selectedConfig 的 hasPendingChange，详情页 header 即时刷新
          selectedConfig: state.selectedConfig?.id == event.configId
              ? state.selectedConfig!.copyWith(hasPendingChange: false)
              : state.selectedConfig,
        ),
      );

      // 刷新所有相关列表
      add(const KeyBindingLoadChangeRequests());
      add(const KeyBindingLoadMyConfigs(showSuccessMessage: false));
      add(const KeyBindingLoadConfigs(showSuccessMessage: false));

      LogService.d('[KeyBindingBloc] 撤销变更申请成功');
    } catch (e) {
      LogService.e('[KeyBindingBloc] 撤销变更申请失败', e);
      String errorMsg;
      if (e is ApiException && e.code == 20528) {
        errorMsg = '申请已审核，无法撤销';
      } else {
        errorMsg = ErrorUtils.getErrorMessage(e, defaultMessage: '撤销变更申请失败');
      }
      emit(
        state.copyWith(isCancellingChangeRequest: false, error: errorMsg),
      );
    }
  }
}
