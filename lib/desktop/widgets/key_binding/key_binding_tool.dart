import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../../core/bloc/key_binding/key_binding_event.dart';
import '../../../core/bloc/key_binding/key_binding_state.dart';
import '../../../core/utils/toast_utils.dart';
import 'views/left_panel.dart';
import 'views/right_panel.dart';

/// 按键绑定工具 - 现代化两栏布局（重构版）
class KeyBindingTool extends StatefulWidget {
  const KeyBindingTool({super.key});

  @override
  State<KeyBindingTool> createState() => _KeyBindingToolState();
}

class _KeyBindingToolState extends State<KeyBindingTool> {
  final _searchCtrl = TextEditingController();

  // 右侧面板模式: 0=配置详情, 1=autoexec, 2=发布, 3=编辑
  int _rightMode = 0;

  // 正在编辑的配置（模式3时使用）
  dynamic _editingConfig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<KeyBindingBloc>();
      bloc.add(KeyBindingLoadConfigs());
      bloc.add(KeyBindingLoadCategories());
      bloc.add(KeyBindingLoadAutoexecContent());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<KeyBindingBloc, KeyBindingState>(
      listenWhen: (previous, current) {
        final successChanged =
            previous.successMessage != current.successMessage &&
            current.successMessage?.isNotEmpty == true;
        final errorChanged =
            previous.error != current.error &&
            current.error?.isNotEmpty == true;
        return successChanged || errorChanged;
      },
      listener: (context, state) {
        if (state.successMessage?.isNotEmpty == true) {
          ToastUtils.showSuccess(context, state.successMessage!);
          if (_rightMode == 3 && state.successMessage!.contains('更新')) {
            setState(() {
              _rightMode = 0;
              _editingConfig = null;
            });
          }
        }
        if (state.error?.isNotEmpty == true) {
          ToastUtils.showError(context, state.error!);
        }
        context.read<KeyBindingBloc>().add(KeyBindingClearMessages());
      },
      child: Container(
        margin: const EdgeInsets.all(0),
        child: Row(
          children: [
            // 左侧：配置列表 + 顶部工具栏
            Expanded(
              flex: 3,
              child: LeftPanel(
                searchCtrl: _searchCtrl,
                rightMode: _rightMode,
                onModeChanged: (m) => setState(() {
                  _rightMode = m;
                  if (m != 3) _editingConfig = null;
                }),
                onConfigTap: () => setState(() {
                  _rightMode = 0;
                  _editingConfig = null;
                }),
              ),
            ),
            const SizedBox(width: 16),
            // 右侧：动态内容区
            Expanded(
              flex: 5,
              child: RightPanel(
                mode: _rightMode,
                editingConfig: _editingConfig,
                onEditComplete: () => setState(() {
                  _rightMode = 0;
                  _editingConfig = null;
                }),
                onEditConfig: (config) => setState(() {
                  _rightMode = 3;
                  _editingConfig = config;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
