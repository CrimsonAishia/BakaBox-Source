import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/update_models.dart';
import '../bloc/bloc.dart';
import '../utils/toast_utils.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final bool canSkip;
  
  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.canSkip = true,
  });
  
  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
  
  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo, {bool canSkip = true}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: canSkip && !updateInfo.isForced,
      builder: (context) => UpdateDialog(updateInfo: updateInfo, canSkip: canSkip && !updateInfo.isForced),
    );
  }
}

class _UpdateDialogState extends State<UpdateDialog> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonWidthAnimation;
  final ScrollController _scrollController = ScrollController();
  
  // 倒计时相关
  int _countdown = 3;
  bool _isCountingDown = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _buttonAnimationController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)));
    _buttonWidthAnimation = CurvedAnimation(parent: _buttonAnimationController, curve: Curves.easeInOutCubic);
    _animationController.forward();
  }
  
  void _startCountdown() {
    if (_isCountingDown) return;
    _isCountingDown = true;
    _countdown = 3;
    _countdownTick();
  }
  
  void _countdownTick() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateBloc, UpdateState>(
      builder: (context, updateState) {
        final status = updateState.status;
        final downloadProgress = updateState.downloadProgress;
        final errorMessage = updateState.errorMessage;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (errorMessage != null && errorMessage.isNotEmpty) {
            ToastUtils.showError(context, errorMessage);
            context.read<UpdateBloc>().add(UpdateClearError());
          }
        });
        
        return PopScope(
          canPop: widget.canSkip && !widget.updateInfo.isForced,
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2196F3), width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10)),
                        BoxShadow(color: const Color(0xFF2196F3).withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2),
                        BoxShadow(color: const Color(0xFF2196F3).withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeaderSection(),
                          _buildContentSection(),
                          _buildActionSection(context, status, downloadProgress),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection() {
    final versionText = '${widget.updateInfo.currentVersion} → ${widget.updateInfo.latestVersion}';
    return Container(
      height: 160,
      width: double.infinity,
      decoration: const BoxDecoration(borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset('assets/images/update_bg.jpg', fit: BoxFit.cover)),
            Positioned(
              top: 20, left: 20, right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('发现新版本', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26)])),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                    child: Text(versionText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(widget.updateInfo.formattedPublishDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.orange)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContentSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('更新内容', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1), borderRadius: BorderRadius.circular(8)),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              radius: const Radius.circular(6),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: _buildReleaseNotes(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionSection(BuildContext context, UpdateStatus status, DownloadProgress? downloadProgress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 15),
      child: Column(
        children: [
          if (status == UpdateStatus.installing) ...[_buildInstallingStatus(), const SizedBox(height: 16)],
          _buildButtons(context, status, downloadProgress),
        ],
      ),
    );
  }
  
  Widget _buildButtons(BuildContext context, UpdateStatus status, DownloadProgress? downloadProgress) {
    final isDownloadingOrInstalling = status == UpdateStatus.downloading || status == UpdateStatus.installing || status == UpdateStatus.preparing;
    final isDownloaded = status == UpdateStatus.downloaded;
    
    // 当进入 preparing 状态时启动倒计时
    if (status == UpdateStatus.preparing && !_isCountingDown) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
    }
    
    if (isDownloadingOrInstalling) {
      if (_buttonAnimationController.status == AnimationStatus.dismissed) _buttonAnimationController.forward();
      return AnimatedBuilder(
        animation: _buttonWidthAnimation,
        builder: (context, child) {
          return Row(
            children: [
              Expanded(child: _buildUpdateButton(context, status, downloadProgress, isFullWidth: true)),
              if (widget.canSkip) SizedBox(width: 12 * (1 - _buttonWidthAnimation.value)),
              if (widget.canSkip) SizedBox(width: 50 * (1 - _buttonWidthAnimation.value), child: Opacity(opacity: 1 - _buttonWidthAnimation.value, child: _buildCloseButton(context))),
            ],
          );
        },
      );
    } else if (isDownloaded) {
      // 下载完成，显示"立即安装"按钮
      // 强制更新时不显示"取消"按钮
      if (_buttonAnimationController.status == AnimationStatus.completed) _buttonAnimationController.reverse();
      
      // 强制更新：只显示"立即安装"按钮
      if (widget.updateInfo.isForced) {
        return Row(
          children: [
            Expanded(child: _buildUpdateButton(context, status, downloadProgress, isFullWidth: true)),
          ],
        );
      }
      
      // 非强制更新：显示"取消"和"立即安装"按钮
      return Row(
        children: [
          if (widget.canSkip) SizedBox(width: 80, child: _buildCloseButton(context)),
          if (widget.canSkip) const SizedBox(width: 12),
          Expanded(flex: 2, child: _buildUpdateButton(context, status, downloadProgress, isFullWidth: false)),
        ],
      );
    } else {
      if (_buttonAnimationController.status == AnimationStatus.completed) _buttonAnimationController.reverse();
      return AnimatedBuilder(
        animation: _buttonWidthAnimation,
        builder: (context, child) {
          return Row(
            children: [
              if (widget.canSkip) SizedBox(width: 80 * (1 - _buttonWidthAnimation.value), child: Opacity(opacity: 1 - _buttonWidthAnimation.value, child: _buildCloseButton(context))),
              if (widget.canSkip) SizedBox(width: 12 * (1 - _buttonWidthAnimation.value)),
              Expanded(flex: widget.canSkip ? 2 : 1, child: _buildUpdateButton(context, status, downloadProgress, isFullWidth: false)),
            ],
          );
        },
      );
    }
  }
  
  Widget _buildCloseButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // 强制更新时禁用取消按钮（理论上不应该显示，但作为双重保险）
    final isEnabled = !widget.updateInfo.isForced;
    
    return SizedBox(
      height: 48, width: 80,
      child: Container(
        decoration: BoxDecoration(
          color: isEnabled ? colorScheme.surface : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: isEnabled ? 0.2 : 0.1),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isEnabled ? () => Navigator.of(context).pop() : null,
            child: Center(
              child: Text(
                '取消',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isEnabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton(BuildContext context, UpdateStatus status, DownloadProgress? downloadProgress, {required bool isFullWidth}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    switch (status) {
      case UpdateStatus.downloading:
        final progress = downloadProgress;
        return SizedBox(
          height: 48,
          child: Stack(
            children: [
              Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: colorScheme.surfaceContainerHighest),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(value: progress?.progress ?? 0.0, backgroundColor: colorScheme.surfaceContainerHighest, valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange), minHeight: 48),
                ),
              ),
              Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (progress != null) ...[
                        Text('${progress.formattedProgress} ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)])),
                        const Text('• ', style: TextStyle(fontSize: 14, color: Colors.white, shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)])),
                      ],
                      const Text('正在下载...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      
      case UpdateStatus.downloaded:
        return SizedBox(
          width: double.infinity, height: 48,
          child: Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF27AE60), Color(0xFF229954)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF27AE60).withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 8)]),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.read<UpdateBloc>().add(UpdateInstall()),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.install_desktop, size: 18, color: Colors.white), const SizedBox(width: 8), Text('立即安装', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))])),
              ),
            ),
          ),
        );
      
      case UpdateStatus.preparing:
        return SizedBox(
          height: 48,
          child: Stack(
            children: [
              Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF9800).withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 8)],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                      const SizedBox(width: 10),
                      Text('$_countdown 秒后开始安装...', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      
      case UpdateStatus.installing:
        return Container(
          width: double.infinity, height: 48,
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2), width: 1.5)),
          child: Center(child: Text('正在安装中...', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
        );
      
      case UpdateStatus.failed:
        return SizedBox(
          width: double.infinity, height: 48,
          child: Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 8)]),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () { context.read<UpdateBloc>().add(UpdateClearError()); context.read<UpdateBloc>().add(UpdateDownloadAndInstall()); },
                child: Center(child: Text('更新错误，重试', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
              ),
            ),
          ),
        );
      
      case UpdateStatus.completed:
        // Windows: 不会到达此状态（安装后自动退出）
        // Android/iOS: 安装完成，显示"完成"按钮
        // 强制更新时：不允许关闭对话框，提示用户重启应用
        if (widget.updateInfo.isForced) {
          return SizedBox(
            width: double.infinity, height: 48,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF27AE60), Color(0xFF229954)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFF27AE60).withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 8)],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '安装完成，请重启应用',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        // 非强制更新：允许关闭对话框
        return SizedBox(
          width: double.infinity, height: 48,
          child: Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF27AE60), Color(0xFF229954)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF27AE60).withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 8)]),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle, size: 18, color: Colors.white), const SizedBox(width: 8), Text('完成', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))])),
              ),
            ),
          ),
        );
      
      default:
        final fileSizeText = widget.updateInfo.fileSize > 0 ? ' (${widget.updateInfo.formattedFileSize})' : '';
        return SizedBox(
          width: double.infinity, height: 48,
          child: Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF2196F3).withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 8)]),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.read<UpdateBloc>().add(UpdateDownloadAndInstall()),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.upgrade, size: 18, color: Colors.white), const SizedBox(width: 8), Text('立即更新$fileSizeText', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))])),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildReleaseNotes() {
    final releaseNotes = widget.updateInfo.releaseNotes.isNotEmpty ? widget.updateInfo.releaseNotes : '暂无更新说明';
    return Builder(
      builder: (context) {
        return Markdown(
          data: releaseNotes,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 14, height: 1.5, color: Theme.of(context).colorScheme.onSurface),
            h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            h2: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
            listBullet: const TextStyle(fontSize: 14, color: Colors.orange),
            code: TextStyle(fontSize: 13, fontFamily: 'monospace', backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh, color: Colors.orange),
            codeblockDecoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(8))),
          ),
          padding: EdgeInsets.zero,
        );
      },
    );
  }
  
  Widget _buildInstallingStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.orange))),
              const SizedBox(width: 16),
              Text('正在安装更新...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          Text('安装完成后应用将自动重启', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
