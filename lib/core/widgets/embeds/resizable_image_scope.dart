import 'package:flutter/widgets.dart';

import 'resizable_image_controller.dart';

/// 通过 InheritedWidget 向 embed builder 下发 [ResizableImageController]
///
/// flutter_quill 的 EmbedBuilder.build 只能拿到 BuildContext，
/// 因此用 InheritedWidget 在编辑器子树中提供选中协调器。
class ResizableImageScope extends InheritedWidget {
  final ResizableImageController controller;

  /// 是否只读（详情页渲染时为 true，禁用所有交互）
  final bool readOnly;

  /// 图片宽度上限比例（默认 1.0）
  final double maxWidthFactor;

  const ResizableImageScope({
    super.key,
    required this.controller,
    required this.readOnly,
    this.maxWidthFactor = 1.0,
    required super.child,
  });

  static ResizableImageScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ResizableImageScope>();
  }

  @override
  bool updateShouldNotify(ResizableImageScope oldWidget) {
    return controller != oldWidget.controller ||
        readOnly != oldWidget.readOnly ||
        maxWidthFactor != oldWidget.maxWidthFactor;
  }
}
