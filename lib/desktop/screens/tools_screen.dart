import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../core/bloc/map_contribution/map_contribution_bloc.dart';
import '../widgets/crash_report/crash_report_tool.dart';
import '../widgets/key_binding/key_binding_tool.dart';
import '../widgets/obs_tool/obs_tool.dart';
import '../widgets/page_layout.dart';
import 'map_database_desktop.dart';
import '../../core/constants/app_colors.dart';

/// 工具箱页面
class ToolsScreen extends StatefulWidget {
  /// 外部指定的初始工具 ID（由 DesktopNavigator 跳转时传入）
  final String? initialToolId;

  /// 外部传入的工具参数（例如 {'mapName': 'ze_minecraft'}）
  final Map<String, dynamic>? initialToolArgs;

  /// 参数消费完毕后的回调，通知外部清空 pending 状态
  final VoidCallback? onArgsConsumed;

  const ToolsScreen({
    super.key,
    this.initialToolId,
    this.initialToolArgs,
    this.onArgsConsumed,
  });

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  /// 当前打开的工具ID
  String? _openedToolId;

  @override
  void initState() {
    super.initState();
    if (widget.initialToolId != null) {
      _openedToolId = widget.initialToolId;
      // frame end 后通知外部已消费参数
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onArgsConsumed?.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ToolsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果外部传入了新的 initialToolId，自动打开对应工具
    if (widget.initialToolId != null &&
        widget.initialToolId != oldWidget.initialToolId) {
      setState(() {
        _openedToolId = widget.initialToolId;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onArgsConsumed?.call();
      });
    }
  }

  static final List<_ToolItem> _tools = [
    _ToolItem(
      id: 'key_binding',
      name: '按键绑定',
      description: '管理 CS2 游戏快捷键配置',
      icon: MdiIcons.keyboardOutline,
      isFullScreen: true,
    ),
    _ToolItem(
      id: 'map_database',
      name: '地图数据库',
      description: '查看和管理地图信息贡献',
      icon: MdiIcons.database,
      isFullScreen: true,
    ),
    _ToolItem(
      id: 'obs_overlay',
      name: 'OBS 投屏组件',
      description: '为OBS配置可视化服务器信息展示',
      icon: MdiIcons.televisionGuide,
      isFullScreen: true,
    ),
    _ToolItem(
      id: 'crash_reports',
      name: '崩溃报告',
      description: '查看 CS2 崩溃分析',
      icon: MdiIcons.alertOctagonOutline,
      isFullScreen: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 如果有打开的全屏工具，显示工具页面
    if (_openedToolId != null) {
      return _buildFullScreenTool(context);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 渐变背景
          _buildGradientBackground(),
          // 浮动装饰
          const _FloatingShapes(),
          // 页面内容
          PageLayout(
            title: '工具箱',
            subtitle: 'CS2 游戏工具集合',
            child: _buildToolsGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenTool(BuildContext context) {
    final tool = _tools.firstWhere((t) => t.id == _openedToolId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.slate900
          : AppColors.gray100,
      body: PageLayout(
        title: tool.name,
        subtitle: tool.description,
        headerActions: _buildBackButton(),
        child: _buildToolContent(),
      ),
    );
  }

  Widget _buildBackButton() {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _openedToolId = null;
        });
      },
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('返回工具箱'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gray500,
        side: const BorderSide(color: AppColors.gray200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  Widget _buildToolContent() {
    switch (_openedToolId) {
      case 'key_binding':
        return BlocProvider(
          create: (context) => KeyBindingBloc(),
          child: const KeyBindingTool(),
        );
      case 'map_database':
        final initialMapName = widget.initialToolArgs?['mapName'] as String?;
        return BlocProvider(
          create: (context) => MapContributionBloc(),
          child: MapDatabaseDesktop(initialMapName: initialMapName),
        );
      case 'obs_overlay':
        return const ObsTool();
      case 'crash_reports':
        return const CrashReportTool();
      default:
        return const Center(child: Text('工具未找到'));
    }
  }

  Widget _buildGradientBackground() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.slate900,
                  AppColors.slate800,
                  const Color(0xFF1A1A2E),
                ]
              : [
                  const Color(0xFFE3F2FD),
                  const Color(0xFFE0F7FA),
                  const Color(0xFFEDE7F6),
                  const Color(0xFFFFF3E0),
                ],
          stops: isDark ? [0.0, 0.5, 1.0] : [0.0, 0.35, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 固定3列
        const columnCount = 3;
        final cardWidth =
            (constraints.maxWidth - 48 - (columnCount - 1) * 20) / columnCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: _tools
                .map(
                  (tool) => SizedBox(
                    width: cardWidth,
                    child: _ToolCard(
                      tool: tool,
                      onOpenFullScreen: tool.isFullScreen
                          ? () {
                              setState(() {
                                _openedToolId = tool.id;
                              });
                            }
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

/// 浮动工具图标组件
class _FloatingShapes extends StatelessWidget {
  const _FloatingShapes();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _FloatingToolIcon(
          icon: MdiIcons.wrench,
          size: 40,
          top: 0.12,
          left: 0.06,
          delay: 0,
        ),
        _FloatingToolIcon(
          icon: MdiIcons.cog,
          size: 36,
          top: 0.28,
          right: 0.10,
          delay: 800,
        ),
        _FloatingToolIcon(
          icon: MdiIcons.hammer,
          size: 32,
          bottom: 0.38,
          left: 0.12,
          delay: 1600,
        ),
        _FloatingToolIcon(
          icon: MdiIcons.keyboardOutline,
          size: 38,
          top: 0.55,
          right: 0.06,
          delay: 2400,
        ),
        _FloatingToolIcon(
          icon: MdiIcons.screwdriver,
          size: 30,
          bottom: 0.22,
          right: 0.18,
          delay: 1200,
        ),
        _FloatingToolIcon(
          icon: MdiIcons.toolboxOutline,
          size: 34,
          top: 0.40,
          left: 0.08,
          delay: 2000,
        ),
      ],
    );
  }
}

/// 单个浮动工具图标
class _FloatingToolIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final int delay;

  const _FloatingToolIcon({
    required this.icon,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.delay,
  });

  @override
  State<_FloatingToolIcon> createState() => _FloatingToolIconState();
}

class _FloatingToolIconState extends State<_FloatingToolIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _floatAnimation = Tween<double>(
      begin: 0,
      end: 15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotateAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: widget.top != null ? screenSize.height * widget.top! : null,
      bottom: widget.bottom != null ? screenSize.height * widget.bottom! : null,
      left: widget.left != null ? screenSize.width * widget.left! : null,
      right: widget.right != null ? screenSize.width * widget.right! : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_floatAnimation.value),
            child: Transform.rotate(
              angle: _rotateAnimation.value * math.pi,
              child: child,
            ),
          );
        },
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.blue500.withValues(alpha: 0.4),
              AppColors.violet500.withValues(alpha: 0.4),
            ],
          ).createShader(bounds),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 工具卡片
class _ToolCard extends StatefulWidget {
  final _ToolItem tool;
  final VoidCallback? onOpenFullScreen;

  const _ToolCard({required this.tool, this.onOpenFullScreen});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCard(context, isDark, true);
  }

  Widget _buildCard(BuildContext context, bool isDark, bool isEnabled) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: isEnabled ? _handleTap : null,
        child: AnimatedScale(
          scale: _isHovered && isEnabled ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: Offset(0, _isHovered && isEnabled ? -0.04 : 0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.6,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.slate800.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: !isEnabled
                        ? (isDark
                              ? AppColors.slate600
                              : AppColors.gray300)
                        : _isHovered
                        ? AppColors.green500.withValues(alpha: 0.4)
                        : (isDark
                              ? AppColors.slate700
                              : AppColors.green500.withValues(alpha: 0.2)),
                  ),
                  boxShadow: _isHovered && isEnabled
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: isDark ? 0.2 : 0.15),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // 卡片背景装饰
                      if (isEnabled) _buildBgDecoration(),
                      // 顶部渐变条
                      if (isEnabled) _buildTopBar(),
                      // 状态指示器
                      _buildStatusIndicator(isEnabled),
                      // 内容
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _buildContent(isDark, isEnabled),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBgDecoration() {
    return Positioned.fill(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _isHovered ? 1.0 : 0.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.6),
              radius: 1.0,
              colors: [
                AppColors.blue500.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 400),
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 400),
          widthFactor: _isHovered ? 1.0 : 0.0,
          child: Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.blue500,
                  AppColors.violet500,
                  Color(0xFFEC4899),
                  AppColors.amber500,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isEnabled) {
    return Positioned(
      top: 20,
      right: 20,
      child: isEnabled ? _PulsingDot() : _DisabledIndicator(),
    );
  }

  Widget _buildContent(bool isDark, bool isEnabled) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标容器
          _buildIconContainer(isDark, isEnabled),
          const SizedBox(height: 16),
          // 标题
          Text(
            widget.tool.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.gray800,
            ),
          ),
          const SizedBox(height: 8),
          // 描述
          Text(
            widget.tool.description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : AppColors.gray500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer(bool isDark, bool isEnabled) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 光晕效果
        AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: _isHovered && isEnabled ? 1.0 : 0.0,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.blue500.withValues(alpha: isDark ? 0.4 : 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 图标
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 64,
          height: 64,
          transform: _isHovered && isEnabled
              ? (Matrix4.identity()
                  ..setEntry(0, 0, 1.1)
                  ..setEntry(1, 1, 1.1)
                  ..setEntry(2, 2, 1.1)
                  ..rotateZ(0.087)) // 约5度
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (isEnabled ? AppColors.blue500 : AppColors.gray500)
                    .withValues(alpha: _isHovered && isEnabled ? 0.25 : 0.15),
                (isEnabled ? const Color(0xFF9333EA) : AppColors.gray500)
                    .withValues(alpha: _isHovered && isEnabled ? 0.25 : 0.15),
              ],
            ),
          ),
          child: Icon(
            isEnabled ? widget.tool.icon : MdiIcons.lockOutline,
            size: 32,
            color: isEnabled
                ? (_isHovered
                      ? (isDark
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF1D4ED8))
                      : (isDark
                            ? const Color(0xFF60A5FA)
                            : AppColors.blue500))
                : (isDark ? Colors.white38 : AppColors.gray400),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTap() async {
    // 如果是全屏工具
    if (widget.tool.isFullScreen && widget.onOpenFullScreen != null) {
      widget.onOpenFullScreen!();
    }
  }
}

/// 脉冲状态点
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.green500,
            boxShadow: [
              BoxShadow(
                color: AppColors.green500.withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Opacity(
              opacity: 0.5 + _controller.value * 0.5,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 禁用状态指示器
class _DisabledIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.slate600 : AppColors.gray300,
      ),
      child: Center(
        child: Icon(
          MdiIcons.lock,
          size: 8,
          color: isDark ? Colors.white38 : AppColors.gray400,
        ),
      ),
    );
  }
}

class _ToolItem {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool isFullScreen;

  const _ToolItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isFullScreen = false,
  });
}
