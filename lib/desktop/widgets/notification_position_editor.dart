import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/constants/app_colors.dart';

/// 窗口位置枚举
enum WindowPositionType {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// 窗口位置扩展
extension WindowPositionTypeExtension on WindowPositionType {
  String get displayName {
    switch (this) {
      case WindowPositionType.topLeft:
        return '左上角';
      case WindowPositionType.topCenter:
        return '顶部居中';
      case WindowPositionType.topRight:
        return '右上角';
      case WindowPositionType.centerLeft:
        return '左侧居中';
      case WindowPositionType.center:
        return '正中间';
      case WindowPositionType.centerRight:
        return '右侧居中';
      case WindowPositionType.bottomLeft:
        return '左下角';
      case WindowPositionType.bottomCenter:
        return '底部居中';
      case WindowPositionType.bottomRight:
        return '右下角';
    }
  }
}

/// 窗口类型枚举
enum DraggableWindowType { notification, floating }

/// 窗口位置编辑器 - 模拟电脑屏幕，用户可以拖动通知和浮窗位置
class NotificationPositionEditor extends StatefulWidget {
  final WindowPositionType initialNotificationPosition;
  final WindowPositionType initialFloatingPosition;
  final ValueChanged<WindowPositionType> onNotificationPositionChanged;
  final ValueChanged<WindowPositionType> onFloatingPositionChanged;
  final VoidCallback? onNotificationPreview;
  final VoidCallback? onFloatingPreview;
  final bool isNotificationPreviewActive;
  final bool isFloatingPreviewActive;

  const NotificationPositionEditor({
    super.key,
    required this.initialNotificationPosition,
    required this.initialFloatingPosition,
    required this.onNotificationPositionChanged,
    required this.onFloatingPositionChanged,
    this.onNotificationPreview,
    this.onFloatingPreview,
    this.isNotificationPreviewActive = false,
    this.isFloatingPreviewActive = false,
  });

  @override
  State<NotificationPositionEditor> createState() =>
      _NotificationPositionEditorState();
}

class _NotificationPositionEditorState
    extends State<NotificationPositionEditor> {
  late WindowPositionType _notificationPosition;
  late WindowPositionType _floatingPosition;

  DraggableWindowType? _selectedType;

  // 屏幕模拟区域的尺寸
  static const double _screenWidth = 480.0;
  static const double _screenHeight = 300.0;
  static const double _padding = 12.0;
  static const double _taskbarHeight = 28.0;

  // 通知窗口尺寸
  static const double _notificationWidth = 70.0;
  static const double _notificationHeight = 45.0;

  // 浮窗尺寸
  static const double _floatingWidth = 65.0;
  static const double _floatingHeight = 55.0;

  @override
  void initState() {
    super.initState();
    _notificationPosition = widget.initialNotificationPosition;
    _floatingPosition = widget.initialFloatingPosition;
  }

  @override
  void didUpdateWidget(NotificationPositionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialNotificationPosition !=
        widget.initialNotificationPosition) {
      setState(
        () => _notificationPosition = widget.initialNotificationPosition,
      );
    }
    if (oldWidget.initialFloatingPosition != widget.initialFloatingPosition) {
      setState(() => _floatingPosition = widget.initialFloatingPosition);
    }
  }

  Offset _getOffsetForPosition(
    WindowPositionType position,
    double width,
    double height,
  ) {
    final availableHeight = _screenHeight - _taskbarHeight;
    final centerY = (availableHeight - height) / 2;

    switch (position) {
      case WindowPositionType.topLeft:
        return const Offset(_padding, _padding);
      case WindowPositionType.topCenter:
        return Offset((_screenWidth - width) / 2, _padding);
      case WindowPositionType.topRight:
        return Offset(_screenWidth - width - _padding, _padding);
      case WindowPositionType.centerLeft:
        return Offset(_padding, centerY);
      case WindowPositionType.center:
        return Offset((_screenWidth - width) / 2, centerY);
      case WindowPositionType.centerRight:
        return Offset(_screenWidth - width - _padding, centerY);
      case WindowPositionType.bottomLeft:
        return Offset(_padding, availableHeight - height - _padding);
      case WindowPositionType.bottomCenter:
        return Offset(
          (_screenWidth - width) / 2,
          availableHeight - height - _padding,
        );
      case WindowPositionType.bottomRight:
        return Offset(
          _screenWidth - width - _padding,
          availableHeight - height - _padding,
        );
    }
  }

  WindowPositionType _getClosestPosition(
    Offset offset,
    double width,
    double height,
  ) {
    double minDistance = double.infinity;
    WindowPositionType closestPosition = WindowPositionType.topRight;

    for (final position in WindowPositionType.values) {
      final targetOffset = _getOffsetForPosition(position, width, height);
      final distance = (offset - targetOffset).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closestPosition = position;
      }
    }
    return closestPosition;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 屏幕模拟区域
        Container(
          width: _screenWidth,
          height: _screenHeight,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : AppColors.gray200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.slate600 : AppColors.gray300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 桌面背景
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(
                    painter: _DesktopBackgroundPainter(isDark: isDark),
                  ),
                ),
              ),
              // 任务栏
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _taskbarHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.slate800.withValues(alpha: 0.9)
                        : AppColors.gray100.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Icon(
                        MdiIcons.microsoftWindows,
                        size: 16,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      const Spacer(),
                      Text(
                        '12:00',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              // 位置指示点
              ..._buildPositionIndicators(isDark),
              // 可拖动窗口 - 选中的窗口放在最上层
              ..._buildDraggableWindows(isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 图例
        _buildLegendAndStatus(isDark),
      ],
    );
  }

  /// 构建可拖动窗口列表，选中的窗口放在最后（最上层）
  List<Widget> _buildDraggableWindows(bool isDark) {
    final notificationWindow = _buildDraggableWindow(
      type: DraggableWindowType.notification,
      position: _notificationPosition,
      width: _notificationWidth,
      height: _notificationHeight,
      isDark: isDark,
      onPositionChanged: (newPosition) {
        setState(() => _notificationPosition = newPosition);
        widget.onNotificationPositionChanged(newPosition);
      },
    );

    final floatingWindow = _buildDraggableWindow(
      type: DraggableWindowType.floating,
      position: _floatingPosition,
      width: _floatingWidth,
      height: _floatingHeight,
      isDark: isDark,
      onPositionChanged: (newPosition) {
        setState(() => _floatingPosition = newPosition);
        widget.onFloatingPositionChanged(newPosition);
      },
    );

    // 选中的窗口放在最后（最上层）
    if (_selectedType == DraggableWindowType.notification) {
      return [floatingWindow, notificationWindow];
    } else {
      return [notificationWindow, floatingWindow];
    }
  }

  Widget _buildDraggableWindow({
    required DraggableWindowType type,
    required WindowPositionType position,
    required double width,
    required double height,
    required bool isDark,
    required ValueChanged<WindowPositionType> onPositionChanged,
  }) {
    final offset = _getOffsetForPosition(position, width, height);
    final isSelected = _selectedType == type;

    return AnimatedPositioned(
      key: ValueKey(type), // 添加 key 防止切换时位置交换
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onTap: () =>
            setState(() => _selectedType = _selectedType == type ? null : type),
        onPanStart: (_) => setState(() => _selectedType = type),
        onPanUpdate: (details) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            final localPosition = box.globalToLocal(details.globalPosition);
            final newPosition = _getClosestPosition(
              localPosition,
              width,
              height,
            );
            if (newPosition != position) {
              onPositionChanged(newPosition);
            }
          }
        },
        child: _buildWindowCard(type, width, height, isDark, isSelected),
      ),
    );
  }

  Widget _buildWindowCard(
    DraggableWindowType type,
    double width,
    double height,
    bool isDark,
    bool isSelected,
  ) {
    final isNotification = type == DraggableWindowType.notification;
    final color = isNotification
        ? AppColors.primary
        : AppColors.orange;
    final icon = isNotification ? MdiIcons.bellOutline : MdiIcons.gamepad;
    final label = isNotification ? '通知' : '浮窗';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: isSelected ? 2.5 : 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isSelected ? 0.4 : 0.2),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white70 : AppColors.gray500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPositionIndicators(bool isDark) {
    final indicators = <Widget>[];

    for (final position in WindowPositionType.values) {
      final notificationOffset = _getOffsetForPosition(
        position,
        _notificationWidth,
        _notificationHeight,
      );
      final floatingOffset = _getOffsetForPosition(
        position,
        _floatingWidth,
        _floatingHeight,
      );
      final isNotificationSelected = position == _notificationPosition;
      final isFloatingSelected = position == _floatingPosition;

      if (!isNotificationSelected && !isFloatingSelected) {
        indicators.add(
          Positioned(
            left:
                (notificationOffset.dx + floatingOffset.dx) / 2 +
                (_notificationWidth + _floatingWidth) / 4 -
                4,
            top:
                (notificationOffset.dy + floatingOffset.dy) / 2 +
                (_notificationHeight + _floatingHeight) / 4 -
                4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black26,
                  width: 1,
                ),
              ),
            ),
          ),
        );
      }
    }
    return indicators;
  }

  Widget _buildLegendAndStatus(bool isDark) {
    return Row(
      children: [
        _buildLegendItem(
          color: AppColors.primary,
          icon: MdiIcons.bellOutline,
          label: '通知窗口',
          position: _notificationPosition,
          isDark: isDark,
          isSelected: _selectedType == DraggableWindowType.notification,
          onTap: () => setState(() {
            _selectedType = _selectedType == DraggableWindowType.notification
                ? null
                : DraggableWindowType.notification;
          }),
          onPreview: widget.onNotificationPreview,
          isPreviewActive: widget.isNotificationPreviewActive,
        ),
        const SizedBox(width: 20),
        _buildLegendItem(
          color: AppColors.orange,
          icon: MdiIcons.gamepad,
          label: '状态浮窗',
          position: _floatingPosition,
          isDark: isDark,
          isSelected: _selectedType == DraggableWindowType.floating,
          onTap: () => setState(() {
            _selectedType = _selectedType == DraggableWindowType.floating
                ? null
                : DraggableWindowType.floating;
          }),
          onPreview: widget.onFloatingPreview,
          isPreviewActive: widget.isFloatingPreviewActive,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String label,
    required WindowPositionType position,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onPreview,
    bool isPreviewActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.slate600 : AppColors.gray200),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(icon, size: 10, color: color),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.gray700,
                  ),
                ),
                Text(
                  position.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (onPreview != null) ...[
              const SizedBox(width: 8),
              _PreviewEyeButton(
                color: color,
                isActive: isPreviewActive,
                onTap: onPreview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 桌面背景绘制器
class _DesktopBackgroundPainter extends CustomPainter {
  final bool isDark;

  _DesktopBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const gridSize = 20.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final iconPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08);

    final iconPositions = [
      const Offset(20, 20),
      const Offset(20, 70),
      const Offset(20, 120),
    ];
    for (final pos in iconPositions) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pos.dx, pos.dy, 30, 30),
          const Radius.circular(4),
        ),
        iconPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DesktopBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// 预览眼睛按钮
class _PreviewEyeButton extends StatelessWidget {
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _PreviewEyeButton({
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isActive ? '关闭预览' : '屏幕预览',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: color.withValues(alpha: isActive ? 1 : 0.5),
              width: 1,
            ),
          ),
          child: Icon(
            isActive ? MdiIcons.eye : MdiIcons.eyeOutline,
            size: 14,
            color: isActive ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
