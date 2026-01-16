import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/bloc/key_binding/key_binding_bloc.dart';
import '../../core/bloc/feature_status/feature_status_bloc.dart';
import '../../core/bloc/feature_status/feature_status_state.dart';
import '../../core/models/feature_status_models.dart';
import '../../core/widgets/feature_gate.dart';
import '../widgets/key_binding/key_binding_tool.dart';
import '../widgets/page_layout.dart';

/// 工具箱页面
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  /// 当前打开的工具ID
  String? _openedToolId;

  static final List<_ToolItem> _tools = [
    _ToolItem(
      id: 'key_binding',
      name: '按键绑定',
      description: '管理 CS2 游戏快捷键配置',
      icon: MdiIcons.keyboardOutline,
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
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
        foregroundColor: const Color(0xFF6B7280),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  Widget _buildToolContent() {
    switch (_openedToolId) {
      case 'key_binding':
        return FeatureGate(
          feature: FeatureType.keyConfig,
          child: BlocProvider(
            create: (context) => KeyBindingBloc(),
            child: const KeyBindingTool(),
          ),
        );
      default:
        return const Center(
          child: Text('工具未找到'),
        );
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
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF1A1A2E)]
              : [const Color(0xFFE3F2FD), const Color(0xFFE0F7FA), const Color(0xFFEDE7F6), const Color(0xFFFFF3E0)],
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
        final cardWidth = (constraints.maxWidth - 48 - (columnCount - 1) * 20) / columnCount;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: _tools
                .map((tool) => SizedBox(
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
                    ))
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
        _FloatingToolIcon(icon: MdiIcons.wrench, size: 40, top: 0.12, left: 0.06, delay: 0),
        _FloatingToolIcon(icon: MdiIcons.cog, size: 36, top: 0.28, right: 0.10, delay: 800),
        _FloatingToolIcon(icon: MdiIcons.hammer, size: 32, bottom: 0.38, left: 0.12, delay: 1600),
        _FloatingToolIcon(icon: MdiIcons.keyboardOutline, size: 38, top: 0.55, right: 0.06, delay: 2400),
        _FloatingToolIcon(icon: MdiIcons.screwdriver, size: 30, bottom: 0.22, right: 0.18, delay: 1200),
        _FloatingToolIcon(icon: MdiIcons.toolboxOutline, size: 34, top: 0.40, left: 0.08, delay: 2000),
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
    _floatAnimation = Tween<double>(begin: 0, end: 15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
              const Color(0xFF3B82F6).withValues(alpha: 0.4),
              const Color(0xFF8B5CF6).withValues(alpha: 0.4),
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

  const _ToolCard({
    required this.tool,
    this.onOpenFullScreen,
  });

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _isHovered = false;

  /// 获取工具对应的功能类型
  FeatureType? get _featureType {
    switch (widget.tool.id) {
      case 'key_binding':
        return FeatureType.keyConfig;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 如果有对应的功能类型，检查功能状态
    if (_featureType != null) {
      return BlocBuilder<FeatureStatusBloc, FeatureStatusState>(
        builder: (context, state) {
          // 只有明确加载完成且禁用时才显示为禁用
          final isEnabled = state.loadState != FeatureStatusLoadState.loaded ||
              state.status.getStatus(_featureType!).enabled;
          return _buildCard(context, isDark, isEnabled);
        },
      );
    }
    
    return _buildCard(context, isDark, true);
  }

  Widget _buildCard(BuildContext context, bool isDark, bool isEnabled) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
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
                height: 200,
                decoration: BoxDecoration(
                  color: isDark 
                      ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: !isEnabled
                        ? (isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB))
                        : _isHovered
                            ? const Color(0xFF22C55E).withValues(alpha: 0.4)
                            : (isDark 
                                ? const Color(0xFF334155)
                                : const Color(0xFF22C55E).withValues(alpha: 0.2)),
                  ),
                  boxShadow: _isHovered && isEnabled
                      ? [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: isDark ? 0.2 : 0.15),
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
                const Color(0xFF3B82F6).withValues(alpha: 0.05),
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
                  Color(0xFF3B82F6),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                  Color(0xFFF59E0B),
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
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          // 描述
          Text(
            isEnabled ? widget.tool.description : '功能暂未开放',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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
                  const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.4 : 0.3),
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
                (isEnabled ? const Color(0xFF3B82F6) : const Color(0xFF6B7280))
                    .withValues(alpha: _isHovered && isEnabled ? 0.25 : 0.15),
                (isEnabled ? const Color(0xFF9333EA) : const Color(0xFF6B7280))
                    .withValues(alpha: _isHovered && isEnabled ? 0.25 : 0.15),
              ],
            ),
          ),
          child: Icon(
            isEnabled ? widget.tool.icon : MdiIcons.lockOutline,
            size: 32,
            color: isEnabled
                ? (_isHovered 
                    ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                    : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6)))
                : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
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
            color: const Color(0xFF22C55E),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.5),
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
        color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
      ),
      child: Center(
        child: Icon(
          MdiIcons.lock,
          size: 8,
          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
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
