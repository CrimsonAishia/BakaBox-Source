import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/core.dart';

/// 移动端日志页面
class AppLogsMobile extends StatefulWidget {
  const AppLogsMobile({super.key});

  @override
  State<AppLogsMobile> createState() => _AppLogsMobileState();
}

class _AppLogsMobileState extends State<AppLogsMobile> {
  List<String> _logFiles = [];
  bool _isLoading = true;
  String? _selectedLogFile;
  List<String> _logLines = [];
  String _fullLogContent = '';
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // 如果距离底部超过 200 像素，显示"滚动到底部"按钮
    final shouldShow = maxScroll - currentScroll > 200;
    if (shouldShow != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadLogFiles() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final files = await LogService.getLogFiles();
      if (mounted) {
        setState(() {
          _logFiles = files.reversed.toList(); // 最新的在前面
          if (_logFiles.isNotEmpty) {
            _selectedLogFile = _logFiles.first;
            _loadLogContent(_selectedLogFile!);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      LogService.e('加载日志文件列表失败', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLogContent(String filePath) async {
    setState(() {
      _isLoading = true;
      _logLines = [];
      _fullLogContent = '';
    });
    try {
      final content = await LogService.readLogFile(filePath);
      if (mounted && content != null) {
        // 在后台解析可能会更好，但对于移动端日志一般不会太大，直接 split 即可
        final lines = content.split('\n');
        setState(() {
          _fullLogContent = content;
          _logLines = lines.where((line) => line.trim().isNotEmpty).toList();
          _isLoading = false;
        });

        // 延迟滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      LogService.e('读取日志内容失败', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _copyLog() async {
    if (_fullLogContent.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _fullLogContent));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('日志已全部复制到剪贴板'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showFileSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '选择日志文件',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _logFiles.length,
                  itemBuilder: (context, index) {
                    final file = _logFiles[index];
                    final fileName = path.basename(file);
                    final isSelected = file == _selectedLogFile;

                    return ListTile(
                      title: Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? AppColors.blue500 : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(MdiIcons.check, color: AppColors.blue500)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (!isSelected) {
                          setState(() {
                            _selectedLogFile = file;
                          });
                          _loadLogContent(file);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getLogLineColor(String line, ThemeData theme) {
    if (line.contains('[ERROR]') || line.contains('[FATAL]')) {
      return AppColors.red500;
    } else if (line.contains('[WARN]') || line.contains('[WARNING]')) {
      return AppColors.amber500;
    } else if (line.contains('[INFO]')) {
      return AppColors.blue500;
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.contentCopy),
            onPressed: _fullLogContent.isNotEmpty ? _copyLog : null,
            tooltip: '复制全部',
          ),
          IconButton(
            icon: Icon(MdiIcons.refresh),
            onPressed: () {
              if (_selectedLogFile != null) {
                _loadLogContent(_selectedLogFile!);
              } else {
                _loadLogFiles();
              }
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部日志选择器
          if (_logFiles.isNotEmpty)
            InkWell(
              onTap: _showFileSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      MdiIcons.fileDocumentOutline,
                      color: AppColors.blue500,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前日志文件',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          Text(
                            _selectedLogFile != null
                                ? path.basename(_selectedLogFile!)
                                : '无',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      MdiIcons.chevronDown,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),

          // 日志内容列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logLines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          MdiIcons.textBoxRemoveOutline,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ).animate().scale(delay: 200.ms),
                        const SizedBox(height: 16),
                        Text(
                          '暂无日志记录',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surface,
                    child: Scrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _logLines.length,
                        itemBuilder: (context, index) {
                          final line = _logLines[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SelectableText(
                              line,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: _getLogLineColor(line, theme),
                                height: 1.4,
                                fontSize: 12,
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
      floatingActionButton: _showScrollToBottom && _logLines.isNotEmpty
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                MdiIcons.arrowDown,
                color: theme.colorScheme.onSurface,
              ),
            ).animate().fadeIn().scale()
          : null,
    );
  }
}
