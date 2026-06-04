import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// 可缩放图片自定义 BlockEmbed 类型标识
const String resizableImageEmbedType = 'resizableImage';

/// 可缩放图片自定义 BlockEmbed
///
/// Delta 格式:
/// ```jsonc
/// { "insert": { "resizableImage": {
///     "src": "file:123",
///     "width": 1.0,          // 连续百分比，0.2 ~ 1.0
///     "gridCol": 0,          // 横向锚点：0 ~ (24 - widthCols)
///     "gridFloat": false,    // 是否启用段内自由 offset
///     "floatOffset": null,   // gridFloat=true 时：{ "dx": 0, "dy": -0.05 }
///     "alt": "",             // 可选 alt 文字
///     "caption": ""          // 可选图注
/// } } }
/// ```
class ResizableImageBlockEmbed extends CustomBlockEmbed {
  ResizableImageBlockEmbed(Map<String, dynamic> data)
      : super(resizableImageEmbedType, jsonEncode(data));

  /// 创建新的可缩放图片 embed
  ///
  /// [src] 为 fileId 引用格式 "file:123"
  /// [width] 为宽度百分比 (0.2 ~ 1.0)，默认 0.25（小图，居中显示）
  /// [gridCol] 为 24 列网格中的起始列；默认值会根据 [width] 自动居中
  factory ResizableImageBlockEmbed.create({
    required String src,
    double width = 0.25,
    int? gridCol,
    bool gridFloat = false,
    Map<String, double>? floatOffset,
    String? alt,
    String? caption,
  }) {
    final clampedWidth = width.clamp(0.2, 1.0);
    // 默认居中：根据宽度占用的列数自动算出居中起始列
    final widthCols = (clampedWidth * 24).round().clamp(3, 24);
    final maxCol = 24 - widthCols;
    final defaultCol = maxCol <= 0 ? 0 : (maxCol / 2).round();
    return ResizableImageBlockEmbed({
      'src': src,
      'width': clampedWidth,
      'gridCol': gridCol ?? defaultCol,
      'gridFloat': gridFloat,
      'floatOffset': floatOffset,
      'alt': alt ?? '',
      'caption': caption ?? '',
    });
  }

  /// 解析 embed data 为结构化数据
  static ResizableImageData? parseData(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return ResizableImageData.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// 从现有 embed 解析为数据对象
  static ResizableImageData? fromEmbed(Embed embed) {
    if (embed.value is! CustomBlockEmbed) return null;
    final custom = embed.value as CustomBlockEmbed;
    if (custom.type != resizableImageEmbedType) return null;
    return parseData(custom.data as String);
  }
}

/// 可缩放图片数据结构
class ResizableImageData {
  /// 图片源（fileId 引用格式: "file:123"）
  final String src;

  /// 宽度百分比 (0.2 ~ 1.0)
  final double width;

  /// 24 列网格中的起始列 (0 ~ 24-widthCols)
  final int gridCol;

  /// 是否启用段内自由偏移
  final bool gridFloat;

  /// 自由偏移量（gridFloat=true 时有效）
  final Map<String, double>? floatOffset;

  /// Alt 文字
  final String alt;

  /// 图注
  final String caption;

  const ResizableImageData({
    required this.src,
    this.width = 1.0,
    this.gridCol = 0,
    this.gridFloat = false,
    this.floatOffset,
    this.alt = '',
    this.caption = '',
  });

  factory ResizableImageData.fromJson(Map<String, dynamic> json) {
    Map<String, double>? floatOffset;
    if (json['floatOffset'] != null && json['floatOffset'] is Map) {
      floatOffset = (json['floatOffset'] as Map).map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      );
    }

    return ResizableImageData(
      src: json['src'] as String? ?? '',
      width: (json['width'] as num?)?.toDouble() ?? 1.0,
      gridCol: json['gridCol'] as int? ?? 0,
      gridFloat: json['gridFloat'] as bool? ?? false,
      floatOffset: floatOffset,
      alt: json['alt'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'src': src,
        'width': width,
        'gridCol': gridCol,
        'gridFloat': gridFloat,
        'floatOffset': floatOffset,
        'alt': alt,
        'caption': caption,
      };

  /// 计算在 24 列网格中占用的列数
  int get widthCols => (width * 24).round().clamp(3, 24);

  /// 创建修改后的副本
  ResizableImageData copyWith({
    String? src,
    double? width,
    int? gridCol,
    bool? gridFloat,
    Map<String, double>? floatOffset,
    bool clearFloatOffset = false,
    String? alt,
    String? caption,
  }) {
    return ResizableImageData(
      src: src ?? this.src,
      width: width ?? this.width,
      gridCol: gridCol ?? this.gridCol,
      gridFloat: gridFloat ?? this.gridFloat,
      floatOffset: clearFloatOffset ? null : (floatOffset ?? this.floatOffset),
      alt: alt ?? this.alt,
      caption: caption ?? this.caption,
    );
  }
}
