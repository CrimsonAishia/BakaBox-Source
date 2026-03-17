import 'package:flutter/material.dart';
import 'obs_color_picker.dart';

/// 构建 OBS 浮动属性面板
Widget buildObsFloatingPanel({
  required BuildContext context,
  required ThemeData theme,
  required Size screenSize,
  required double panelWidth,
  required Offset panelPosition,
  required double dx,
  required double dy,
  required Map<String, dynamic> element,
  required Function(Offset) onPositionChanged,
  required VoidCallback onClose,
  required VoidCallback onDelete,
  required VoidCallback onSave,
  required VoidCallback onChanged,
  Map<String, TextEditingController>? textControllers,
}) {
  // 获取当前元素的 controller
  final elId = element['id']?.toString() ?? '';
  final textController = textControllers?[elId];

  return Positioned(
    left: dx,
    top: dy,
    width: panelWidth,
    child: Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部支持拖动
            GestureDetector(
              onPanUpdate: (details) {
                onPositionChanged(Offset(
                  panelPosition.dx + details.delta.dx,
                  panelPosition.dy + details.delta.dy,
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      element['type']?.toString() == 'server_card'
                          ? Icons.dns
                          : Icons.text_fields,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        element['type']?.toString() == 'server_card'
                            ? '服务器卡片设置'
                            : '文本信息设置',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
            // 属性内容
            Flexible(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: buildProperties(context, element, theme, onSave, setState, onChanged, textController),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 构建属性设置
Widget buildProperties(
  BuildContext context,
  Map<String, dynamic> el,
  ThemeData theme,
  VoidCallback onSave,
  StateSetter setState,
  VoidCallback onChanged,
  TextEditingController? textController,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('缩放比例', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 8),
      Slider(
        value: (el['scale'] as num?)?.toDouble() ?? 1.0,
        min: 0.5,
        max: 3.0,
        divisions: 25,
        label: ((el['scale'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(1),
        onChanged: (v) {
          el['scale'] = v;
          onSave();
          onChanged();
          setState(() {});
        },
      ),
      const Divider(height: 24),
      if (el['type'] == 'server_card') ...buildServerCardSettings(el, onSave, setState, onChanged),
      if (el['type'] == 'text') ...buildTextSettings(context, el, theme, onSave, setState, onChanged, textController),
    ],
  );
}

/// 构建服务器卡片设置
List<Widget> buildServerCardSettings(Map<String, dynamic> el, VoidCallback onSave, StateSetter setState, VoidCallback onChanged) {
  return [
    // 显示/隐藏设置
    _buildSectionTitle('显示内容'),
    _buildSwitchRow('显示服务器名称', el['showTitle'] ?? true, (v) {
      el['showTitle'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    _buildSwitchRow('显示地图信息', el['showMap'] ?? true, (v) {
      el['showMap'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    _buildSwitchRow('显示地图背景图', el['showMapImage'] ?? true, (v) {
      el['showMapImage'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    _buildSwitchRow('显示服务器地址', el['showIp'] ?? true, (v) {
      el['showIp'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    _buildSwitchRow('显示玩家人数', el['showPlayers'] ?? true, (v) {
      el['showPlayers'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    const SizedBox(height: 16),

    // 背景效果
    _buildSectionTitle('背景效果'),
    const SizedBox(height: 8),
    _buildSliderRow('渐变遮罩透明度', el['gradientOpacity'] ?? 0.6, 0.0, 1.0, (v) {
      el['gradientOpacity'] = v;
      onSave();
      onChanged();
      setState(() {});
    }, divide: 10),
    _buildSliderRow('背景模糊', el['bgBlur'] ?? 0.0, 0.0, 20.0, (v) {
      el['bgBlur'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    const SizedBox(height: 16),

    // 文字大小
    _buildSectionTitle('文字大小'),
    const SizedBox(height: 8),
    _buildSliderRow('服务器名称', el['titleFontSize'] ?? 20.0, 12.0, 36.0, (v) {
      el['titleFontSize'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    _buildSliderRow('地图名称', el['mapFontSize'] ?? 16.0, 10.0, 28.0, (v) {
      el['mapFontSize'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    _buildSliderRow('IP地址', el['ipFontSize'] ?? 15.0, 10.0, 24.0, (v) {
      el['ipFontSize'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
  ];
}

Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    ),
  );
}

Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    ),
  );
}

Widget _buildSliderRow(
  String label,
  double value,
  double min,
  double max,
  Function(double) onChanged, {
  int? divide,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value.toStringAsFixed(divide != null ? 1 : 0),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      SliderTheme(
        data: const SliderThemeData(
          trackHeight: 3,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divide ?? (max - min).toInt(),
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

/// 构建文本设置
List<Widget> buildTextSettings(
  BuildContext context,
  Map<String, dynamic> el,
  ThemeData theme,
  VoidCallback onSave,
  StateSetter setState,
  VoidCallback onChanged,
  TextEditingController? textController,
) {
  // 使用传入的 controller，如果不存在则创建一个临时的
  final controller = textController ?? TextEditingController(text: el['template']?.toString() ?? '');

  return [
    const Text('文本内容', style: TextStyle(fontSize: 12, color: Colors.grey)),
    const SizedBox(height: 8),
    TextField(
      controller: controller,
      onChanged: (v) {
        el['template'] = v;
        onSave();
        onChanged();
      },
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        hintText: '支持变量见下方说明',
      ),
      maxLines: 4,
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '支持如下变量替换：',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text('{serverName} - 显示当前连接的服务器名称', style: TextStyle(fontSize: 11)),
          Text('{map} - 显示当前地图名', style: TextStyle(fontSize: 11)),
          Text('{ip} - 显示该服务器的IP地址或绑定的域名', style: TextStyle(fontSize: 11)),
          Text(
            '{players} - 显示当前对局玩家人数 (例如: 12/64)',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),

    // 文字样式
    _buildSectionTitle('文字样式'),
    _buildSliderRow('字体大小', el['fontSize'] ?? 24.0, 12.0, 128.0, (v) {
      el['fontSize'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: _buildStyleToggle(
            '粗体',
            Icons.format_bold,
            el['fontWeight'] == 'bold',
            () {
              el['fontWeight'] = el['fontWeight'] == 'bold' ? 'normal' : 'bold';
              onSave();
              onChanged();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStyleToggle(
            '斜体',
            Icons.format_italic,
            el['fontStyle'] == 'italic',
            () {
              el['fontStyle'] = el['fontStyle'] == 'italic' ? 'normal' : 'italic';
              onSave();
              onChanged();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStyleToggle(
            '下划线',
            Icons.format_underlined,
            el['decoration'] == 'underline',
            () {
              el['decoration'] = el['decoration'] == 'underline' ? 'none' : 'underline';
              onSave();
              onChanged();
              setState(() {});
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),

    // 对齐方式
    _buildSectionTitle('对齐方式'),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: _buildAlignButton(
            '左对齐',
            Icons.format_align_left,
            el['textAlign'] == 'left' || el['textAlign'] == null,
            () {
              el['textAlign'] = 'left';
              onSave();
              onChanged();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildAlignButton(
            '居中',
            Icons.format_align_center,
            el['textAlign'] == 'center',
            () {
              el['textAlign'] = 'center';
              onSave();
              onChanged();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildAlignButton(
            '右对齐',
            Icons.format_align_right,
            el['textAlign'] == 'right',
            () {
              el['textAlign'] = 'right';
              onSave();
              onChanged();
              setState(() {});
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),

    // 文字阴影和描边互斥，不能同时启用
    _buildSwitchRow('显示阴影', el['showTextShadow'] ?? true, (v) {
      el['showTextShadow'] = v;
      // 启用阴影时，自动禁用描边
      if (v) {
        el['showTextStroke'] = false;
      }
      onSave();
      onChanged();
      setState(() {});
    }),
    if (el['showTextShadow'] ?? true) ...[
      _buildSliderRow('阴影模糊', el['shadowBlur'] ?? 4.0, 0.0, 16.0, (v) {
        el['shadowBlur'] = v;
        onSave();
        onChanged();
        setState(() {});
      }),
      _buildSliderRow('阴影偏移', el['shadowOffset'] ?? 2.0, 0.0, 8.0, (v) {
        el['shadowOffset'] = v;
        onSave();
        onChanged();
        setState(() {});
      }),
    ],
    const SizedBox(height: 16),

    // 文字描边（与阴影互斥）
    _buildSectionTitle('文字描边'),
    Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '与阴影互斥，启用描边将自动关闭阴影',
        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
      ),
    ),
    _buildSwitchRow('启用描边', el['showTextStroke'] ?? false, (v) {
      el['showTextStroke'] = v;
      // 启用描边时，自动禁用阴影
      if (v) {
        el['showTextShadow'] = false;
      }
      onSave();
      onChanged();
      setState(() {});
    }),
    if (el['showTextStroke'] ?? false) ...[
      _buildSliderRow('描边宽度', el['strokeWidth'] ?? 2.0, 0.5, 8.0, (v) {
        el['strokeWidth'] = v;
        onSave();
        onChanged();
        setState(() {});
      }),
      const SizedBox(height: 8),
      const Text('描边颜色', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          buildStrokeColorOption(el, '#000000', Colors.black, onChanged: () {
            onSave();
            onChanged();
            setState(() {});
          }),
          buildStrokeColorOption(el, '#FFFFFF', Colors.white, onChanged: () {
            onSave();
            onChanged();
            setState(() {});
          }),
          buildStrokeColorOption(el, '#FF0000', Colors.red, onChanged: () {
            onSave();
            onChanged();
            setState(() {});
          }),
          buildStrokeColorOption(el, '#00FF00', Colors.green, onChanged: () {
            onSave();
            onChanged();
            setState(() {});
          }),
          buildStrokeColorOption(el, '#0000FF', Colors.blue, onChanged: () {
            onSave();
            onChanged();
            setState(() {});
          }),
          buildStrokeColorOption(el, '#FFFF00', Colors.yellow, onChanged: () {
            onSave();
            onChanged();
            setState(() {});
          }),
          buildCustomColorOption(
            context,
            el,
            'strokeColor',
            el['strokeColor'] ?? '#000000',
            onChanged: () {
              onSave();
              onChanged();
              setState(() {});
            },
          ),
        ],
      ),
    ],
    const SizedBox(height: 16),

    // 间距和圆角
    _buildSectionTitle('间距与圆角'),
    _buildSliderRow('内边距', el['padding'] ?? 12.0, 0.0, 32.0, (v) {
      el['padding'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    _buildSliderRow('圆角大小', el['borderRadius'] ?? 8.0, 0.0, 24.0, (v) {
      el['borderRadius'] = v;
      onSave();
      onChanged();
      setState(() {});
    }),
    const SizedBox(height: 16),

    // 颜色设置
    const Divider(),
    _buildSectionTitle('颜色设置'),
    const SizedBox(height: 8),
    const Text('字体颜色', style: TextStyle(fontSize: 12)),
    const SizedBox(height: 4),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        buildTextColorOption(el, '#FFFFFF', Colors.white, onChanged: () {
          onSave();
          onChanged();
          setState(() {});
        }),
        buildTextColorOption(el, '#000000', Colors.black, onChanged: () {
          onSave();
          onChanged();
          setState(() {});
        }),
        buildTextColorOption(el, '#FF0000', Colors.red, onChanged: () {
          onSave();
          onChanged();
          setState(() {});
        }),
        buildTextColorOption(el, '#00FF00', Colors.green, onChanged: () {
          onSave();
          onChanged();
          setState(() {});
        }),
        buildTextColorOption(el, '#0000FF', Colors.blue, onChanged: () {
          onSave();
          onChanged();
          setState(() {});
        }),
        buildTextColorOption(el, '#FFFF00', Colors.yellow, onChanged: () {
          onSave();
          onChanged();
          setState(() {});
        }),
        buildTextColorOption(el, '#FFA500', Colors.orange, onChanged: () {
          onSave();
          onChanged();
          setState(() {});
        }),
        buildTextColorOption(el, '#FF00FF', Colors.purple, onChanged: () {
          onSave();
          onChanged();
          setState(() {});
        }),
        buildCustomColorOption(
          context,
          el,
          'textColor',
          el['textColor'] ?? '#FFFFFF',
          onChanged: () {
            onSave();
            onChanged();
            setState(() {});
          },
        ),
      ],
    ),
    const SizedBox(height: 16),
    SwitchListTile(
      title: const Text('显示背景', style: TextStyle(fontSize: 13)),
      value: el['showBackground'] ?? true,
      contentPadding: EdgeInsets.zero,
      onChanged: (v) {
        el['showBackground'] = v;
        onSave();
        onChanged();
        setState(() {});
      },
    ),
    if (el['showBackground'] ?? true) ...[
      const Text('背景颜色', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          buildBgColorOption(
            el,
            '#80000000',
            Colors.black.withValues(alpha: 0.5),
            onChanged: () {
              onSave();
              onChanged();
              setState(() {});
            },
          ),
          buildBgColorOption(
            el,
            '#80FFFFFF',
            Colors.white.withValues(alpha: 0.5),
            onChanged: () {
              onSave();
              onChanged();
              setState(() {});
            },
          ),
          buildBgColorOption(
            el,
            '#00000000',
            Colors.transparent,
            onChanged: () {
              onSave();
              onChanged();
              setState(() {});
            },
          ),
          buildBgColorOption(
            el,
            '#80FF0000',
            Colors.red.withValues(alpha: 0.5),
            onChanged: () {
              onSave();
              onChanged();
              setState(() {});
            },
          ),
          buildBgColorOption(
            el,
            '#8000FF00',
            Colors.green.withValues(alpha: 0.5),
            onChanged: () {
              onSave();
              onChanged();
              setState(() {});
            },
          ),
          buildBgColorOption(
            el,
            '#800000FF',
            Colors.blue.withValues(alpha: 0.5),
            onChanged: () {
              onSave();
              onChanged();
              setState(() {});
            },
          ),
          buildCustomColorOption(
            context,
            el,
            'backgroundColor',
            el['backgroundColor'] ?? '#80000000',
            enableAlpha: true,
            onChanged: () {
              onSave();
              onChanged();
              setState(() {});
            },
          ),
        ],
      ),
    ],
  ];
}

Widget _buildStyleToggle(String label, IconData icon, bool isSelected, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.blue : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.blue : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildAlignButton(String label, IconData icon, bool isSelected, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.blue : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.blue : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}
