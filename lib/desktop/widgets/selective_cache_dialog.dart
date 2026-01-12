import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/bloc/settings/settings_state.dart';

/// 选择性缓存清理对话框
class SelectiveCacheDialog extends StatefulWidget {
  final List<CacheItemInfo> cacheDetails;
  final Function(List<CacheType>) onConfirm;

  const SelectiveCacheDialog({
    super.key,
    required this.cacheDetails,
    required this.onConfirm,
  });

  @override
  State<SelectiveCacheDialog> createState() => _SelectiveCacheDialogState();

  static Future<void> show(
    BuildContext context, {
    required List<CacheItemInfo> cacheDetails,
    required Function(List<CacheType>) onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (dialogContext) => SelectiveCacheDialog(
        cacheDetails: cacheDetails,
        onConfirm: onConfirm,
      ),
    );
  }
}

class _SelectiveCacheDialogState extends State<SelectiveCacheDialog> {
  final Set<CacheType> _selectedTypes = {};
  bool _isClearing = false;

  List<CacheItemInfo> get _availableCacheItems =>
      widget.cacheDetails.where((item) => item.sizeInBytes > 0).toList();

  int get _selectedTotalSize => widget.cacheDetails
      .where((item) => _selectedTypes.contains(item.type))
      .fold(0, (sum, item) => sum + item.sizeInBytes);

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _toggleCacheType(CacheType type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
  }

  void _toggleSelectAll(bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedTypes.addAll(_availableCacheItems.map((item) => item.type));
      } else {
        _selectedTypes.clear();
      }
    });
  }

  Color _getCacheTypeColor(CacheType type) {
    switch (type) {
      case CacheType.cacheFiles: return Colors.blue;
      case CacheType.serverData: return Colors.green;
      case CacheType.userData: return Colors.orange;
      case CacheType.logs: return Colors.amber;
    }
  }

  IconData _getCacheTypeIcon(CacheType type) {
    switch (type) {
      case CacheType.cacheFiles: return MdiIcons.imageOutline;
      case CacheType.serverData: return MdiIcons.serverNetwork;
      case CacheType.userData: return MdiIcons.accountOutline;
      case CacheType.logs: return MdiIcons.textBoxOutline;
    }
  }

  void _handleConfirm() {
    if (_selectedTypes.isEmpty) return;
    setState(() => _isClearing = true);
    widget.onConfirm(_selectedTypes.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final totalSize = widget.cacheDetails.fold(0, (sum, item) => sum + item.sizeInBytes);
    final isAllSelected = _availableCacheItems.isNotEmpty &&
        _availableCacheItems.every((item) => _selectedTypes.contains(item.type));

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(MdiIcons.deleteOutline, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('清理缓存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('总计 ${_formatBytes(totalSize)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 全选行
            _buildSelectAllRow(isAllSelected),
            const Divider(height: 20),
            // 缓存项列表
            ...widget.cacheDetails.map((item) => _buildCacheItem(item)),
            // 选中统计
            if (_selectedTypes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(MdiIcons.informationOutline, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text(
                      '已选择 ${_selectedTypes.length} 项，共 ${_formatBytes(_selectedTotalSize)}',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isClearing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isClearing || _selectedTypes.isEmpty ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _isClearing
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_selectedTypes.isEmpty ? '请选择' : '清理选中项'),
        ),
      ],
    );
  }

  Widget _buildSelectAllRow(bool isAllSelected) {
    return InkWell(
      onTap: () => _toggleSelectAll(!isAllSelected),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isAllSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAllSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20, height: 20,
              child: Checkbox(
                value: isAllSelected,
                tristate: true,
                onChanged: _toggleSelectAll,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            const Text('全选', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            if (_availableCacheItems.isEmpty) ...[
              const Spacer(),
              Text('无可清理的缓存', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCacheItem(CacheItemInfo item) {
    final isSelected = _selectedTypes.contains(item.type);
    final color = _getCacheTypeColor(item.type);
    final hasData = item.sizeInBytes > 0;

    return Opacity(
      opacity: hasData ? 1.0 : 0.5,
      child: InkWell(
        onTap: hasData ? () => _toggleCacheType(item.type) : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: isSelected,
                  onChanged: hasData ? (v) => _toggleCacheType(item.type) : null,
                  activeColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(_getCacheTypeIcon(item.type), color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? color : null,
                    )),
                    Text(item.description, style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasData ? color : Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.formattedSize,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: hasData ? color : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
