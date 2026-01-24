import 'package:flutter/material.dart';

/// CSGO Legacy 安装教程对话框
/// 
/// 参考现代应用的引导设计（Discord、Notion 风格）
/// 采用卡片式布局，左侧步骤导航，右侧内容展示
class CsgoLegacyInstallDialog extends StatefulWidget {
  const CsgoLegacyInstallDialog({super.key});

  @override
  State<CsgoLegacyInstallDialog> createState() => _CsgoLegacyInstallDialogState();
}

class _CsgoLegacyInstallDialogState extends State<CsgoLegacyInstallDialog> 
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<InstallStep> _steps = [
    InstallStep(
      title: '打开游戏属性',
      subtitle: '在 Steam 库中右键 CS2',
      description: '在 Steam 客户端的库中找到 Counter-Strike 2，右键点击游戏，在弹出菜单中选择"属性"',
      imagePath: 'assets/images/tutorials/steam_library_and_menu.png',
    ),
    InstallStep(
      title: '切换到 CSGO 分支',
      subtitle: '选择 csgo_legacy 测试版',
      description: '在属性窗口中点击"游戏版本及测试版"标签，在下拉菜单中选择"csgo_legacy - Legacy Version of CS:GO"，Steam 会自动开始下载',
      imagePath: 'assets/images/tutorials/properties_and_select.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (step != _currentStep) {
      _animationController.reset();
      setState(() => _currentStep = step);
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 900,
        height: 600,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧导航栏
            _buildSidebar(isDark),
            
            // 右侧内容区
            Expanded(
              child: _buildContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8F9FA),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'CSGO 安装',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '按照步骤安装 CSGO Legacy',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // 步骤列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;
                
                return _buildStepItem(
                  index: index,
                  step: step,
                  isActive: isActive,
                  isCompleted: isCompleted,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int index,
    required InstallStep step,
    required bool isActive,
    required bool isCompleted,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goToStep(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(color: Colors.orange.withValues(alpha: 0.5))
                  : null,
            ),
            child: Row(
              children: [
                // 步骤图标
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green
                        : isActive
                            ? Colors.orange
                            : (isDark ? Colors.white12 : Colors.black12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // 步骤文字
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                          color: isActive
                              ? Colors.orange
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final step = _steps[_currentStep];
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // 顶部关闭按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              ),
            ),
            
            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 步骤标题
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 截图 - 限制大小
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 500,
                          maxHeight: 320,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            step.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 300,
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 48,
                                        color: isDark ? Colors.white24 : Colors.black26,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '图片加载失败',
                                        style: TextStyle(
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 安装步骤数据模型
class InstallStep {
  final String title;
  final String subtitle;
  final String description;
  final String imagePath;

  InstallStep({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imagePath,
  });
}
