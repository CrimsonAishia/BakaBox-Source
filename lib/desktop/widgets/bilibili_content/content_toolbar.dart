import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/core.dart';

/// 内容工具栏组件 - 包含Tab切换、搜索、刷新和用户中心按钮
class BilibiliContentToolbar extends StatelessWidget {
  final TabController tabController;
  final TextEditingController searchController;
  final BilibiliContentState state;
  final VoidCallback onUserCenterTap;
  final VoidCallback onRefreshTap;
  final Function(int) onTabChanged;
  final VoidCallback onLiveRoomTabTap;
  final VoidCallback onVideoTabTap;

  static const _bilibiliBlue = Color(0xFF00A1D6);
  static const _bilibiliBlueLight = Color(0xFF00C8FF);

  const BilibiliContentToolbar({
    super.key,
    required this.tabController,
    required this.searchController,
    required this.state,
    required this.onUserCenterTap,
    required this.onRefreshTap,
    required this.onTabChanged,
    required this.onLiveRoomTabTap,
    required this.onVideoTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildAnimatedCapsuleTab(context),
          const Spacer(),
          _buildSearchBox(context),
          const SizedBox(width: 8),
          _buildRefreshButton(context),
          const SizedBox(width: 8),
          _buildUserCenterButton(context),
        ],
      ),
    );
  }

  Widget _buildAnimatedCapsuleTab(BuildContext context) {
    final inkColor = _getInkColor(context);
    final cardBg = _getCardBackground(context);

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _bilibiliBlue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: state.currentTabIndex * 73,
            top: 0,
            bottom: 0,
            child: Container(
              width: 73,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_bilibiliBlueLight, _bilibiliBlue],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _bilibiliBlue.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _buildTabItem(
                label: '直播间',
                icon: Icons.live_tv_outlined,
                isSelected: state.currentTabIndex == 0,
                onTap: onLiveRoomTabTap,
                textColor: inkColor,
              ),
              _buildTabItem(
                label: '视频',
                icon: Icons.play_circle_outline,
                isSelected: state.currentTabIndex == 1,
                onTap: onVideoTabTap,
                textColor: inkColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return _HoverableTabItem(
      label: label,
      icon: icon,
      isSelected: isSelected,
      onTap: onTap,
      textColor: textColor,
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    final inkColor = _getInkColor(context);
    final inputBg = _getInputBackground(context);

    return Container(
      width: 160,
      height: 32,
      decoration: BoxDecoration(
        color: inputBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: searchController,
        style: TextStyle(color: inkColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: '搜索...',
          hintStyle: TextStyle(
            color: inkColor.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search, color: _bilibiliBlue, size: 18),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: _getScrollBrown(context),
                    size: 16,
                  ),
                  onPressed: () {
                    searchController.clear();
                    context.read<BilibiliContentBloc>().add(
                      BilibiliContentSearchChanged(''),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _bilibiliBlue.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _bilibiliBlue.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _bilibiliBlue),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          context.read<BilibiliContentBloc>().add(
            BilibiliContentSearchChanged(value),
          );
        },
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context) {
    return Tooltip(
      message: '刷新',
      child: InkWell(
        onTap: state.isRefreshing ? null : onRefreshTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: state.isRefreshing
                ? _bilibiliBlue.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: state.isRefreshing
                  ? _bilibiliBlue.withValues(alpha: 0.3)
                  : _bilibiliBlue.withValues(alpha: 0.5),
            ),
          ),
          child: state.isRefreshing
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_bilibiliBlue),
                  ),
                )
              : Icon(Icons.refresh, size: 18, color: _bilibiliBlue),
        ),
      ),
    );
  }

  Widget _buildUserCenterButton(BuildContext context) {
    final hasLiveRoom = state.myLiveRoomId != null;
    final hasVideo = state.myVideoId != null;

    return Tooltip(
      message: '用户中心',
      child: InkWell(
        onTap: onUserCenterTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasLiveRoom || hasVideo
                  ? _bilibiliBlue.withValues(alpha: 0.5)
                  : _bilibiliBlue.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: hasLiveRoom || hasVideo
                      ? const LinearGradient(
                          colors: [_bilibiliBlueLight, _bilibiliBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: hasLiveRoom || hasVideo ? null : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: hasLiveRoom || hasVideo
                      ? Colors.white
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '用户中心',
                style: TextStyle(
                  color: _bilibiliBlue,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getInkColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE8E0D8)
        : const Color(0xFF2C1810);
  }

  Color _getScrollBrown(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB8956A)
        : const Color(0xFF8B4513);
  }

  Color _getInputBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3D3632)
        : Colors.white;
  }

  Color _getCardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF352F2A)
        : Colors.white;
  }
}

class _HoverableTabItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color textColor;

  const _HoverableTabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.textColor,
  });

  @override
  State<_HoverableTabItem> createState() => _HoverableTabItemState();
}

class _HoverableTabItemState extends State<_HoverableTabItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isSelected
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 73,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _isHovered && !widget.isSelected
                ? BilibiliContentToolbar._bilibiliBlue.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: widget.isSelected
                    ? Colors.white
                    : widget.textColor.withValues(
                        alpha: _isHovered ? 1.0 : 0.7,
                      ),
                fontWeight: widget.isSelected
                    ? FontWeight.w600
                    : FontWeight.normal,
                fontSize: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 14,
                    color: widget.isSelected
                        ? Colors.white
                        : widget.textColor.withValues(
                            alpha: _isHovered ? 0.9 : 0.6,
                          ),
                  ),
                  const SizedBox(width: 4),
                  Text(widget.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
