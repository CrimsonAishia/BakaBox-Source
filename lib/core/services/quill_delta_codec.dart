import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

/// Quill Delta 编解码服务
class QuillDeltaCodec {
  /// 将 Quill Document 编码为 JSON 字符串
  static String encode(Document document) {
    final delta = document.toDelta();
    final json = delta.toJson();
    return jsonEncode(json);
  }

  /// 将 JSON 字符串解码为 Quill Document
  static Document decode(String encoded) {
    if (encoded.trim().isEmpty) {
      return Document();
    }

    try {
      final json = jsonDecode(encoded);
      if (json is List) {
        return Document.fromJson(json);
      }
    } catch (_) {
      // 解码失败，返回纯文本文档
      return Document()..insert(0, encoded);
    }

    return Document();
  }

  /// 检查字符串是否为 Delta JSON 格式
  static bool isDeltaJson(String content) {
    if (content.trim().isEmpty) return false;
    try {
      final json = jsonDecode(content);
      return json is List && json.isNotEmpty && json.first is Map;
    } catch (_) {
      return false;
    }
  }
}
