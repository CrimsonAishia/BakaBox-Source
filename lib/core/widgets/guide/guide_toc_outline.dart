import 'dart:convert';

import 'package:flutter/widgets.dart';

/// 攻略 TOC 单项（Heading）
class GuideTocHeading {
  GuideTocHeading({
    required this.level,
    required this.text,
    required this.index,
    GlobalKey? key,
  }) : key = key ?? GlobalKey(debugLabel: 'guide-toc-h$index');

  /// 标题级别（1=h1, 2=h2, 3=h3）
  final int level;

  /// 标题纯文本（仅文字部分）
  final String text;

  /// 在文档中的序号（0-based）
  final int index;

  /// 挂载在 heading 切片渲染容器上的 GlobalKey
  final GlobalKey key;
}

/// 攻略正文切片
class GuideContentChunk {
  GuideContentChunk.text(this.deltaJson)
      : isHeading = false,
        heading = null;

  GuideContentChunk.heading({
    required this.deltaJson,
    required GuideTocHeading this.heading,
  }) : isHeading = true;

  /// 该切片的子 Delta JSON（List<Map> 序列化结果）
  final String deltaJson;

  /// 是否是 heading 切片
  final bool isHeading;

  /// 对应的 TOC 项（heading 切片才有）
  final GuideTocHeading? heading;
}

/// Delta 切片结果
class GuideContentSlice {
  const GuideContentSlice({
    required this.chunks,
    required this.outline,
  });

  /// 渲染顺序的切片列表
  final List<GuideContentChunk> chunks;

  /// 文档中的 heading 列表（按出现顺序）
  final List<GuideTocHeading> outline;

  bool get hasOutline => outline.isNotEmpty;
}

/// Quill Delta 切片器
///
/// Quill Delta 中，块级属性（包括 `header`）挂在该行末尾的换行 op 上：
/// ```
/// [{insert:"标题"},{insert:"\n", attributes:{header:1}}]
/// ```
/// 因此切片算法按 `\n` 拆行，每行 = 之前累积的 inline ops + 当前 \n op。
///
/// 切片产物：
/// - 普通行连续合并为一个 text chunk（减少 QuillEditor 实例数量）
/// - h1/h2/h3 单独成 heading chunk，并生成 TOC 项
class GuideTocSlicer {
  const GuideTocSlicer._();

  /// 入口：解析 Delta JSON，返回切片结果。
  static GuideContentSlice slice(String deltaJson) {
    if (deltaJson.trim().isEmpty) {
      return const GuideContentSlice(chunks: [], outline: []);
    }

    List<dynamic> ops;
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is! List) {
        return GuideContentSlice(
          chunks: [GuideContentChunk.text(deltaJson)],
          outline: const [],
        );
      }
      ops = decoded;
    } catch (_) {
      return GuideContentSlice(
        chunks: [GuideContentChunk.text(deltaJson)],
        outline: const [],
      );
    }

    final lines = _splitOpsByLine(ops);
    return _buildChunks(lines);
  }
}

/// 一行 Delta：包含若干 inline ops 和一个结尾的 `\n` op（带块级属性）。
class _DeltaLine {
  _DeltaLine();

  final List<Map<String, dynamic>> ops = [];

  /// 块级属性（取自结尾 \n op 的 attributes）
  Map<String, dynamic>? blockAttrs;

  /// 该行的纯文本（用于 TOC label）
  String get plainText {
    final buf = StringBuffer();
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is String) {
        buf.write(insert.replaceAll('\n', ''));
      }
      // embed (Map) 不参与 TOC 文字
    }
    return buf.toString();
  }

  bool get isEmpty => ops.isEmpty && blockAttrs == null;

  /// 序列化为 Delta JSON（保留行末 \n + blockAttrs）
  String toDeltaJson() {
    final out = <Map<String, dynamic>>[...ops];
    final newlineOp = <String, dynamic>{'insert': '\n'};
    if (blockAttrs != null && blockAttrs!.isNotEmpty) {
      newlineOp['attributes'] = blockAttrs;
    }
    out.add(newlineOp);
    return jsonEncode(out);
  }
}

/// 把整篇 Delta 按 `\n` 切成多行。
///
/// Quill Delta 规则：
/// - 文字 op 的 insert 是 String，可以包含多个 `\n`。
///   每个 `\n` 都是一行结尾，行末 \n 上的 attributes 才是块级属性。
/// - embed op 的 insert 是 Map，永远算一个 inline 对象。
List<_DeltaLine> _splitOpsByLine(List<dynamic> ops) {
  final lines = <_DeltaLine>[];
  var current = _DeltaLine();

  void commitNewline(Map<String, dynamic>? blockAttrs) {
    current.blockAttrs = blockAttrs;
    lines.add(current);
    current = _DeltaLine();
  }

  for (final raw in ops) {
    if (raw is! Map) continue;
    final op = Map<String, dynamic>.from(raw);
    final insert = op['insert'];
    final attrs = op['attributes'];
    final inlineAttrs = attrs is Map ? Map<String, dynamic>.from(attrs) : null;

    if (insert is String) {
      // 把字符串按 \n 切，每个 \n 作为一行结束
      var remaining = insert;
      while (true) {
        final nlIdx = remaining.indexOf('\n');
        if (nlIdx < 0) {
          if (remaining.isNotEmpty) {
            current.ops.add({
              'insert': remaining,
              if (inlineAttrs != null) 'attributes': inlineAttrs,
            });
          }
          break;
        }
        // \n 之前的部分进入当前行
        if (nlIdx > 0) {
          current.ops.add({
            'insert': remaining.substring(0, nlIdx),
            if (inlineAttrs != null) 'attributes': inlineAttrs,
          });
        }
        // 提交一行（块级属性来自这次 op 的 attributes）
        commitNewline(inlineAttrs);
        remaining = remaining.substring(nlIdx + 1);
      }
    } else if (insert is Map) {
      // embed inline 节点
      current.ops.add({
        'insert': Map<String, dynamic>.from(insert),
        if (inlineAttrs != null) 'attributes': inlineAttrs,
      });
    }
  }

  // 末尾未以 \n 结束的残留行
  if (!current.isEmpty) {
    lines.add(current);
  }

  return lines;
}

/// 把行序列合并为 chunk：连续非 heading 行合并，h1/h2/h3 单独切出。
GuideContentSlice _buildChunks(List<_DeltaLine> lines) {
  final chunks = <GuideContentChunk>[];
  final outline = <GuideTocHeading>[];

  List<_DeltaLine> buffer = [];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    // 合并 buffer 内所有行为一个 Delta
    final ops = <dynamic>[];
    for (final line in buffer) {
      final encoded = jsonDecode(line.toDeltaJson());
      if (encoded is List) {
        ops.addAll(encoded);
      }
    }
    chunks.add(GuideContentChunk.text(jsonEncode(ops)));
    buffer = [];
  }

  for (final line in lines) {
    final headerLevel = _readHeaderLevel(line.blockAttrs);
    if (headerLevel != null) {
      flushBuffer();
      final text = line.plainText.trim();
      // 空标题：依然作为切片渲染（保留视觉空白），但不进入 TOC
      if (text.isEmpty) {
        chunks.add(GuideContentChunk.text(line.toDeltaJson()));
        continue;
      }
      final heading = GuideTocHeading(
        level: headerLevel,
        text: text,
        index: outline.length,
      );
      outline.add(heading);
      chunks.add(GuideContentChunk.heading(
        deltaJson: line.toDeltaJson(),
        heading: heading,
      ));
    } else {
      buffer.add(line);
    }
  }
  flushBuffer();

  return GuideContentSlice(chunks: chunks, outline: outline);
}

/// 从 blockAttrs 里读出 h1/h2/h3 级别（其它级别视为普通段落）
int? _readHeaderLevel(Map<String, dynamic>? attrs) {
  if (attrs == null) return null;
  final value = attrs['header'];
  if (value is num) {
    final lv = value.toInt();
    if (lv >= 1 && lv <= 3) return lv;
  }
  return null;
}
