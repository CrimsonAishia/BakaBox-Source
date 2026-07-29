/// VDF 节点类型
enum VdfNodeType { document, property, object }

abstract class VdfNode {
  VdfNodeType get type;

  /// 生成带格式的文本
  String toText();
}

/// 表示一段纯文本（空白、缩进、换行等），用于保留原始格式
class VdfTrivia extends VdfNode {
  final String text;

  VdfTrivia(this.text);

  @override
  VdfNodeType get type => throw UnimplementedError('Trivia has no node type');

  @override
  String toText() => text;
}

/// 一个由双引号包裹的字符串键或值
class VdfStringNode extends VdfNode {
  String value;

  /// 字符串前后的 Trivia
  List<VdfTrivia> leadingTrivia;
  List<VdfTrivia> trailingTrivia;

  VdfStringNode(
    this.value, {
    List<VdfTrivia>? leading,
    List<VdfTrivia>? trailing,
  }) : leadingTrivia = leading ?? [],
       trailingTrivia = trailing ?? [];

  @override
  VdfNodeType get type =>
      throw UnimplementedError('StringNode has no node type');

  @override
  String toText() {
    final sb = StringBuffer();
    for (final t in leadingTrivia) {
      sb.write(t.toText());
    }
    sb.write('"$value"');
    for (final t in trailingTrivia) {
      sb.write(t.toText());
    }
    return sb.toString();
  }
}

/// VDF 对象块，包含在 {} 内部的内容
class VdfObjectNode extends VdfNode {
  /// { 之前的 Trivia
  List<VdfTrivia> leadingTrivia;

  /// } 之前的 Trivia（对象内部最后的空白）
  List<VdfTrivia> trailingTrivia;

  /// } 之后的 Trivia
  List<VdfTrivia> postTrivia;

  List<VdfPropertyNode> properties;

  VdfObjectNode({
    List<VdfTrivia>? leading,
    List<VdfTrivia>? trailing,
    List<VdfTrivia>? post,
    List<VdfPropertyNode>? properties,
  }) : leadingTrivia = leading ?? [],
       trailingTrivia = trailing ?? [],
       postTrivia = post ?? [],
       properties = properties ?? [];

  @override
  VdfNodeType get type => VdfNodeType.object;

  @override
  String toText() {
    final sb = StringBuffer();
    for (final t in leadingTrivia) {
      sb.write(t.toText());
    }
    sb.write('{');
    for (final prop in properties) {
      sb.write(prop.toText());
    }
    for (final t in trailingTrivia) {
      sb.write(t.toText());
    }
    sb.write('}');
    for (final t in postTrivia) {
      sb.write(t.toText());
    }
    return sb.toString();
  }
}

/// VDF 属性，包含键和值（值可以是字符串或对象）
class VdfPropertyNode extends VdfNode {
  VdfStringNode key;
  VdfNode value; // VdfStringNode 或 VdfObjectNode

  VdfPropertyNode(this.key, this.value);

  @override
  VdfNodeType get type => VdfNodeType.property;

  @override
  String toText() {
    return key.toText() + value.toText();
  }
}

/// VDF 文档根节点
class VdfDocumentNode extends VdfNode {
  List<VdfTrivia> leadingTrivia = [];
  List<VdfPropertyNode> properties = [];
  List<VdfTrivia> trailingTrivia = [];

  @override
  VdfNodeType get type => VdfNodeType.document;

  @override
  String toText() {
    final sb = StringBuffer();
    for (final t in leadingTrivia) {
      sb.write(t.toText());
    }
    for (final prop in properties) {
      sb.write(prop.toText());
    }
    for (final t in trailingTrivia) {
      sb.write(t.toText());
    }
    return sb.toString();
  }
}

/// VDF 解析器，支持保留原有格式（包括空格、制表符、换行等）
class VdfParser {
  final String _input;
  int _pos = 0;

  VdfParser(this._input);

  /// 扫描空白字符和注释，作为 Trivia 返回
  List<VdfTrivia> _scanTrivia() {
    final start = _pos;
    while (_pos < _input.length) {
      final c = _input.codeUnitAt(_pos);
      if (c == 32 || c == 9 || c == 13 || c == 10) { // ' ', '\t', '\r', '\n'
        _pos++;
      } else if (c == 47 && // '/'
          _pos + 1 < _input.length &&
          _input.codeUnitAt(_pos + 1) == 47) {
        // C-style comments
        _pos += 2;
        while (_pos < _input.length && _input.codeUnitAt(_pos) != 10) { // '\n'
          _pos++;
        }
      } else {
        break;
      }
    }
    if (_pos > start) {
      return [VdfTrivia(_input.substring(start, _pos))];
    }
    return [];
  }

  /// 扫描一个被双引号包裹的字符串
  VdfStringNode? _scanString(List<VdfTrivia> leadingTrivia) {
    if (_pos >= _input.length || _input.codeUnitAt(_pos) != 34) { // '"'
      return null;
    }
    _pos++; // skip "
    final start = _pos;
    while (_pos < _input.length && _input.codeUnitAt(_pos) != 34) {
      // 简单处理，VDF 中转义用的比较少，如需处理 \" 可以加逻辑
      if (_input.codeUnitAt(_pos) == 92 && _pos + 1 < _input.length) { // '\'
        _pos += 2;
      } else {
        _pos++;
      }
    }
    final value = _input.substring(start, _pos);
    if (_pos < _input.length && _input.codeUnitAt(_pos) == 34) {
      _pos++; // skip "
    }

    // 如果字符串同行后面还有空格或者制表符，我们可以把它当做 trailing 吗？
    // 为了简单，我们只在扫描下一个节点前收集 leading trivia
    return VdfStringNode(value, leading: leadingTrivia);
  }

  /// 解析单个 Property (key 和 value)
  VdfPropertyNode? _parseProperty(List<VdfTrivia> leadingTrivia) {
    final keyNode = _scanString(leadingTrivia);
    if (keyNode == null) return null;

    final valueLeadingTrivia = _scanTrivia();
    if (_pos >= _input.length) {
      // 不完整
      return null;
    }

    final c = _input.codeUnitAt(_pos);
    if (c == 123) { // '{'
      // Object value
      _pos++; // skip {
      final objNode = VdfObjectNode(leading: valueLeadingTrivia);

      while (_pos < _input.length) {
        final innerTrivia = _scanTrivia();
        if (_pos < _input.length && _input.codeUnitAt(_pos) == 125) { // '}'
          _pos++; // skip }
          objNode.trailingTrivia = innerTrivia;
          break;
        }

        final prop = _parseProperty(innerTrivia);
        if (prop != null) {
          objNode.properties.add(prop);
        } else {
          // 遇到无法解析的内容，跳过或中止
          break;
        }
      }
      return VdfPropertyNode(keyNode, objNode);
    } else if (c == 34) { // '"'
      // String value
      final valNode = _scanString(valueLeadingTrivia);
      if (valNode != null) {
        return VdfPropertyNode(keyNode, valNode);
      }
    }

    return null;
  }

  /// 解析整个文档
  VdfDocumentNode parse() {
    final doc = VdfDocumentNode();

    while (_pos < _input.length) {
      final trivia = _scanTrivia();
      if (_pos >= _input.length) {
        doc.trailingTrivia.addAll(trivia);
        break;
      }

      final prop = _parseProperty(trivia);
      if (prop != null) {
        doc.properties.add(prop);
      } else {
        // 如果遇到未知内容，收集剩余内容作为 trailing
        doc.trailingTrivia.addAll(_scanTrivia());
        break;
      }
    }

    return doc;
  }
}

/// 针对 ACF / VDF 文档提供更高级的增删查改方法
class VdfEditor {
  final VdfDocumentNode _doc;

  VdfEditor(String input) : _doc = VdfParser(input).parse();

  /// 转换回文本
  String toText() => _doc.toText();

  /// 根据键名路径（例如 ['AppWorkshop', 'WorkshopItemsInstalled']）查找对象节点
  VdfObjectNode? findObjectNode(List<String> path) {
    List<VdfPropertyNode> currentProps = _doc.properties;
    VdfObjectNode? targetObj;

    for (int i = 0; i < path.length; i++) {
      final key = path[i];
      VdfPropertyNode? foundProp;
      for (final prop in currentProps) {
        if (prop.key.value == key) {
          foundProp = prop;
          break;
        }
      }

      if (foundProp == null) return null;

      if (foundProp.value is VdfObjectNode) {
        targetObj = foundProp.value as VdfObjectNode;
        currentProps = targetObj.properties;
      } else {
        return null; // 路径未结束但遇到了字符串节点
      }
    }

    return targetObj;
  }

  /// 获取字符串值
  String? getStringValue(List<String> path) {
    if (path.isEmpty) return null;

    final objPath = path.sublist(0, path.length - 1);
    final key = path.last;

    List<VdfPropertyNode> currentProps = _doc.properties;
    if (objPath.isNotEmpty) {
      final obj = findObjectNode(objPath);
      if (obj == null) return null;
      currentProps = obj.properties;
    }

    for (final prop in currentProps) {
      if (prop.key.value == key && prop.value is VdfStringNode) {
        return (prop.value as VdfStringNode).value;
      }
    }
    return null;
  }

  /// 从指定的对象节点中删除对应的属性（保留周围的格式）
  /// 如果成功删除返回 true
  bool deleteProperty(List<String> objPath, String keyToDelete) {
    List<VdfPropertyNode> currentProps = _doc.properties;
    VdfObjectNode? targetObj;

    if (objPath.isNotEmpty) {
      targetObj = findObjectNode(objPath);
      if (targetObj == null) return false;
      currentProps = targetObj.properties;
    }

    for (int i = 0; i < currentProps.length; i++) {
      if (currentProps[i].key.value == keyToDelete) {
        // 如果是要删除的属性，连带它前后的 trivia 都会被移除（由于是节点的一部分）
        // 但通常 VDF 中的每一项前导 trivia 是换行和制表符
        // 删除该项后，我们需要稍微清理多余的换行，不过简单移除节点也能保证不破坏后续格式。
        currentProps.removeAt(i);
        return true;
      }
    }

    return false;
  }
}
