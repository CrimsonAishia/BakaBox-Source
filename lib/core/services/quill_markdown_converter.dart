import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:markdown/markdown.dart' as md;

/// Quill Delta 和 Markdown 之间的转换服务
class QuillMarkdownConverter {
  /// 将 Quill Document 转换为 Markdown
  static String toMarkdown(Document document) {
    final plainText = document.toPlainText();
    if (plainText.trim().isEmpty) {
      return '';
    }
    
    final buffer = StringBuffer();
    final delta = document.toDelta();
    
    for (final op in delta.operations) {
      if (op.isInsert) {
        final data = op.data;
        final attributes = op.attributes ?? {};
        
        if (data is String) {
          String text = data;
          
          // 处理换行符
          if (text == '\n') {
            // 检查块级样式
            if (attributes.containsKey('header')) {
              // 标题已在前面处理
            } else if (attributes.containsKey('list')) {
              // 列表已在前面处理
            } else if (attributes.containsKey('blockquote')) {
              // 引用已在前面处理
            } else if (attributes.containsKey('code-block')) {
              // 代码块已在前面处理
            }
            buffer.writeln();
            continue;
          }
          
          // 应用行内样式
          if (attributes.containsKey('bold')) {
            text = '**$text**';
          }
          if (attributes.containsKey('italic')) {
            text = '*$text*';
          }
          if (attributes.containsKey('underline')) {
            text = '<u>$text</u>';
          }
          if (attributes.containsKey('strike')) {
            text = '~~$text~~';
          }
          if (attributes.containsKey('code')) {
            text = '`$text`';
          }
          if (attributes.containsKey('link')) {
            final link = attributes['link'] as String;
            text = '[$text]($link)';
          }
          
          buffer.write(text);
        } else if (data is Map) {
          // 嵌入对象
          if (data.containsKey('image')) {
            final src = data['image'] as String;
            buffer.write('![image]($src)');
          }
        }
      }
    }
    
    return buffer.toString().trim();
  }
  
  /// 将 Markdown 转换为 Quill Document
  static Document fromMarkdown(String markdown) {
    if (markdown.trim().isEmpty) {
      return Document();
    }
    
    // 解析 Markdown
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );
    
    final lines = markdown.split('\n');
    final nodes = document.parseLines(lines);
    
    // 转换为 Quill Delta
    final delta = Delta();
    
    for (final node in nodes) {
      _convertNodeToDelta(node, delta);
    }
    
    // 确保文档以换行符结尾
    if (delta.isEmpty || !delta.last.data.toString().endsWith('\n')) {
      delta.insert('\n');
    }
    
    return Document.fromDelta(delta);
  }
  
  /// 将 Markdown 节点转换为 Delta
  static void _convertNodeToDelta(md.Node node, Delta delta) {
    if (node is md.Element) {
      _convertElementToDelta(node, delta);
    } else if (node is md.Text) {
      delta.insert(node.text);
    }
  }
  
  /// 将 Markdown 元素转换为 Delta
  static void _convertElementToDelta(md.Element element, Delta delta) {
    switch (element.tag) {
      case 'h1':
        _insertStyledText(element, delta, {});
        delta.insert('\n', {'header': 1});
        break;
      case 'h2':
        _insertStyledText(element, delta, {});
        delta.insert('\n', {'header': 2});
        break;
      case 'h3':
        _insertStyledText(element, delta, {});
        delta.insert('\n', {'header': 3});
        break;
      case 'h4':
        _insertStyledText(element, delta, {});
        delta.insert('\n', {'header': 4});
        break;
      case 'h5':
        _insertStyledText(element, delta, {});
        delta.insert('\n', {'header': 5});
        break;
      case 'h6':
        _insertStyledText(element, delta, {});
        delta.insert('\n', {'header': 6});
        break;
      case 'p':
        _insertStyledText(element, delta, {});
        delta.insert('\n');
        break;
      case 'strong':
      case 'b':
        _insertStyledText(element, delta, {'bold': true});
        break;
      case 'em':
      case 'i':
        _insertStyledText(element, delta, {'italic': true});
        break;
      case 'u':
        _insertStyledText(element, delta, {'underline': true});
        break;
      case 'del':
      case 's':
        _insertStyledText(element, delta, {'strike': true});
        break;
      case 'code':
        _insertStyledText(element, delta, {'code': true});
        break;
      case 'a':
        final href = element.attributes['href'] ?? '';
        _insertStyledText(element, delta, {'link': href});
        break;
      case 'img':
        final src = element.attributes['src'] ?? '';
        delta.insert({'image': src});
        delta.insert('\n');
        break;
      case 'ul':
        for (final child in element.children ?? []) {
          if (child is md.Element && child.tag == 'li') {
            _insertStyledText(child, delta, {});
            delta.insert('\n', {'list': 'bullet'});
          }
        }
        break;
      case 'ol':
        for (final child in element.children ?? []) {
          if (child is md.Element && child.tag == 'li') {
            _insertStyledText(child, delta, {});
            delta.insert('\n', {'list': 'ordered'});
          }
        }
        break;
      case 'blockquote':
        _insertStyledText(element, delta, {});
        delta.insert('\n', {'blockquote': true});
        break;
      case 'pre':
        if (element.children != null && element.children!.isNotEmpty) {
          final code = element.children!.first;
          if (code is md.Element && code.tag == 'code') {
            final text = _getElementText(code);
            delta.insert(text);
            delta.insert('\n', {'code-block': true});
          }
        }
        break;
      default:
        // 递归处理子节点
        if (element.children != null) {
          for (final child in element.children!) {
            _convertNodeToDelta(child, delta);
          }
        }
    }
  }
  
  /// 插入带样式的文本
  static void _insertStyledText(
    md.Element element,
    Delta delta,
    Map<String, dynamic> attributes,
  ) {
    if (element.children == null || element.children!.isEmpty) {
      return;
    }
    
    for (final child in element.children!) {
      if (child is md.Text) {
        if (attributes.isNotEmpty) {
          delta.insert(child.text, attributes);
        } else {
          delta.insert(child.text);
        }
      } else if (child is md.Element) {
        // 合并样式
        final childAttributes = Map<String, dynamic>.from(attributes);
        
        switch (child.tag) {
          case 'strong':
          case 'b':
            childAttributes['bold'] = true;
            break;
          case 'em':
          case 'i':
            childAttributes['italic'] = true;
            break;
          case 'u':
            childAttributes['underline'] = true;
            break;
          case 'del':
          case 's':
            childAttributes['strike'] = true;
            break;
          case 'code':
            childAttributes['code'] = true;
            break;
          case 'a':
            childAttributes['link'] = child.attributes['href'] ?? '';
            break;
        }
        
        _insertStyledText(child, delta, childAttributes);
      }
    }
  }
  
  /// 获取元素的纯文本内容
  static String _getElementText(md.Element element) {
    final buffer = StringBuffer();
    
    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Text) {
          buffer.write(child.text);
        } else if (child is md.Element) {
          buffer.write(_getElementText(child));
        }
      }
    }
    
    return buffer.toString();
  }
}
