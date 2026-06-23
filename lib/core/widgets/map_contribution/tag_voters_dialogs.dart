part of '../map_contribution_dialog.dart';

/// 地图所有标签投票记录对话框
class _MapAllVotersDialog extends StatefulWidget {
  final String mapName;
  final String? mapLabel;
  final bool isDifficultySeparated;
  final String? serverAddress;

  const _MapAllVotersDialog({
    required this.mapName,
    this.mapLabel,
    this.isDifficultySeparated = false,
    this.serverAddress,
  });

  @override
  State<_MapAllVotersDialog> createState() => _MapAllVotersDialogState();
}

class _MapAllVotersDialogState extends State<_MapAllVotersDialog> {
  bool _isLoading = true;
  String? _error;
  MapAllTagVotesResponse? _data;
  int _pageIndex = 1;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;
  String? _loadMoreError;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVotes();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || _isLoading) return;
    if (_data == null || _data!.items.length >= _data!.total) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      _loadMore();
    }
  }

  Future<void> _loadVotes() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _data = null;
      _pageIndex = 1;
    });
    try {
      final result = await MapTagApi().getMapAllTagUserVotes(
        widget.mapName,
        pageIndex: 1,
        pageSize: _pageSize,
        address: widget.serverAddress,
      );
      if (mounted) {
        if (result != null) {
          setState(() {
            _data = result;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = '加载失败，请稍后重试';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败，请稍后重试';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final nextPage = _pageIndex + 1;
      final result = await MapTagApi().getMapAllTagUserVotes(
        widget.mapName,
        pageIndex: nextPage,
        pageSize: _pageSize,
        address: widget.serverAddress,
      );
      if (mounted) {
        if (result != null) {
          setState(() {
            _pageIndex = nextPage;
            _data = MapAllTagVotesResponse(
              mapName: result.mapName,
              items: [...(_data?.items ?? []), ...result.items],
              total: result.total,
            );
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _isLoadingMore = false;
            _loadMoreError = '加载更多失败，请下拉重试';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _loadMoreError = '加载更多失败，请下拉重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.slate800 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final secondaryColor = isDark ? Colors.white54 : AppColors.gray500;
    final displayName = widget.mapLabel ?? widget.mapName;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.accountGroupOutline,
                    color: AppColors.indigo500,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '标签投票记录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (_data != null) ...[
                              Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryColor,
                                ),
                              ),
                              Text(
                                '共 ${_data!.total} 条记录',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            // 内容区域
            Flexible(child: _buildContent(isDark, textColor, secondaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, Color textColor, Color secondaryColor) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.indigo500),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.alertCircleOutline,
                size: 48,
                color: AppColors.red500,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadVotes, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final items = _data?.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.accountOffOutline,
                size: 48,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(height: 12),
              Text('暂无投票记录', style: TextStyle(color: secondaryColor)),
            ],
          ),
        ),
      );
    }

    final hasMore = items.length < (_data?.total ?? 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      // +1 for the footer (loading spinner / error / end hint)
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          if (_isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (_loadMoreError != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    _loadMoreError!,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
              ),
            );
          }
          if (!hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  '已加载全部记录',
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        return _buildVoteItem(items[index], isDark, secondaryColor);
      },
    );
  }

  Widget _buildVoteItem(
    MapAllTagVoteItem item,
    bool isDark,
    Color secondaryColor,
  ) {
    final isUpvote = item.isUpvote;
    final voteColor = isUpvote ? AppColors.emerald500 : AppColors.red500;
    final voteIcon = isUpvote ? MdiIcons.thumbUp : MdiIcons.thumbDown;
    final voteLabel = isUpvote ? '赞成' : '反对';

    // 标签颜色
    final tagColor = item.tagColorValue;
    final tagBgColor =
        tagColor ??
        (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!);
    final tagTextColor = tagColor != null
        ? (tagColor.computeLuminance() > 0.5 ? AppColors.gray800 : Colors.white)
        : (isDark ? Colors.white70 : AppColors.gray700);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // 头像
          _buildAvatar(item, isDark),
          const SizedBox(width: 10),
          // 用户名
          Expanded(
            child: Text(
              item.username,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // 标签名胶囊
          Container(
            constraints: const BoxConstraints(maxWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tagBgColor,
              borderRadius: BorderRadius.circular(12),
              border: tagColor == null
                  ? Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1),
                    )
                  : null,
            ),
            child: Text(
              item.tagName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tagTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // 投票类型标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: voteColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: voteColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(voteIcon, size: 13, color: voteColor),
                const SizedBox(width: 4),
                Text(
                  voteLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: voteColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(MapAllTagVoteItem item, bool isDark) {
    const size = 32.0;
    final initial = item.username.isNotEmpty
        ? item.username[0].toUpperCase()
        : '?';

    Widget placeholder = Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.indigo500,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 4),
        color: AppColors.indigo500.withValues(alpha: 0.15),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.avatar.isNotEmpty
          ? DiskCachedImage(
              imageUrl: item.avatar,
              fit: BoxFit.cover,
              placeholder: placeholder,
              errorWidget: placeholder,
            )
          : placeholder,
    );
  }
}

/// 标签投票用户对话框
class _TagVotersDialog extends StatefulWidget {
  final String mapName;
  final MapTag tag;
  final bool isDifficultySeparated;
  final String? serverAddress;

  const _TagVotersDialog({
    required this.mapName,
    required this.tag,
    this.isDifficultySeparated = false,
    this.serverAddress,
  });

  @override
  State<_TagVotersDialog> createState() => _TagVotersDialogState();
}

class _TagVotersDialogState extends State<_TagVotersDialog> {
  bool _isLoading = true;
  String? _error;
  TagUserVotesResponse? _data;
  int _pageIndex = 1;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;
  String? _loadMoreError;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVotes();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || _isLoading) return;
    if (_data == null || _data!.items.length >= _data!.total) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      _loadMore();
    }
  }

  Future<void> _loadVotes() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _data = null;
      _pageIndex = 1;
    });
    try {
      final result = await MapTagApi().getTagUserVotes(
        widget.mapName,
        widget.tag.id,
        pageIndex: 1,
        pageSize: _pageSize,
        address: widget.serverAddress,
      );
      if (mounted) {
        if (result != null) {
          setState(() {
            _data = result;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = '加载失败，请稍后重试';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败，请稍后重试';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final nextPage = _pageIndex + 1;
      final result = await MapTagApi().getTagUserVotes(
        widget.mapName,
        widget.tag.id,
        pageIndex: nextPage,
        pageSize: _pageSize,
        address: widget.serverAddress,
      );
      if (mounted) {
        if (result != null) {
          setState(() {
            _pageIndex = nextPage;
            _data = TagUserVotesResponse(
              mapName: result.mapName,
              tagId: result.tagId,
              tagName: result.tagName,
              items: [...(_data?.items ?? []), ...result.items],
              total: result.total,
            );
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _isLoadingMore = false;
            _loadMoreError = '加载更多失败，请下拉重试';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _loadMoreError = '加载更多失败，请下拉重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.slate800 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final secondaryColor = isDark ? Colors.white54 : AppColors.gray500;
    final tag = widget.tag;
    final tagColor = tag.colorValue;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.accountGroupOutline,
                    color: AppColors.indigo500,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '投票用户',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // 标签名称胶囊
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    tagColor ??
                                    (isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(10),
                                border: tagColor == null
                                    ? Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.15,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                      )
                                    : null,
                              ),
                              child: Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: tagColor != null
                                      ? (tagColor.computeLuminance() > 0.5
                                            ? AppColors.gray800
                                            : Colors.white)
                                      : secondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (_data != null)
                              Text(
                                '共 ${_data!.total} 条记录',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            // 内容区域
            Flexible(child: _buildContent(isDark, textColor, secondaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, Color textColor, Color secondaryColor) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.indigo500),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.alertCircleOutline,
                size: 48,
                color: AppColors.red500,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadVotes, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final items = _data?.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.accountOffOutline,
                size: 48,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(height: 12),
              Text('暂无投票记录', style: TextStyle(color: secondaryColor)),
            ],
          ),
        ),
      );
    }

    final hasMore = items.length < (_data?.total ?? 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          if (_isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (_loadMoreError != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    _loadMoreError!,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
              ),
            );
          }
          if (!hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  '已加载全部记录',
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        final item = items[index];
        return _buildVoterItem(item, isDark, secondaryColor);
      },
    );
  }

  Widget _buildVoterItem(
    TagUserVoteItem item,
    bool isDark,
    Color secondaryColor,
  ) {
    final isUpvote = item.isUpvote;
    final voteColor = isUpvote ? AppColors.emerald500 : AppColors.red500;
    final voteIcon = isUpvote ? MdiIcons.thumbUp : MdiIcons.thumbDown;
    final voteLabel = isUpvote ? '赞成' : '反对';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // 头像
          _buildAvatar(item, isDark),
          const SizedBox(width: 10),
          // 用户名
          Expanded(
            child: Text(
              item.username,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 投票类型标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: voteColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: voteColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(voteIcon, size: 13, color: voteColor),
                const SizedBox(width: 4),
                Text(
                  voteLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: voteColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(TagUserVoteItem item, bool isDark) {
    const size = 32.0;
    final initial = item.username.isNotEmpty
        ? item.username[0].toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 4),
        color: AppColors.indigo500.withValues(alpha: 0.15),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.avatar.isNotEmpty
          ? DiskCachedImage(
              imageUrl: item.avatar,
              fit: BoxFit.cover,
              placeholder: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.indigo500,
                  ),
                ),
              ),
              errorWidget: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.indigo500,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.indigo500,
                ),
              ),
            ),
    );
  }
}
