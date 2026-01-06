/// 按键占位符解析器
///
/// 占位符格式: {{KEY:标签名}}
/// 例如: bind "{{KEY:跳投}}" "+jump; -attack"
class KeyPlaceholderParser {
  /// 占位符正则表达式
  static final RegExp placeholderPattern = RegExp(r'\{\{KEY:([^}]+)\}\}');

  /// 解析配置脚本，提取所有占位符
  ///
  /// 返回按出现顺序排列的占位符列表，同名占位符只返回第一个
  static List<KeyPlaceholder> parse(String script) {
    final matches = placeholderPattern.allMatches(script);
    final seen = <String>{};
    final placeholders = <KeyPlaceholder>[];

    for (final match in matches) {
      final label = match.group(1)!;
      if (!seen.contains(label)) {
        seen.add(label);
        placeholders.add(KeyPlaceholder(
          label: label,
          startIndex: match.start,
          endIndex: match.end,
        ));
      }
    }

    return placeholders;
  }

  /// 获取所有唯一的占位符标签名
  static List<String> getUniqueLabels(String script) {
    return parse(script).map((p) => p.label).toList();
  }

  /// 替换占位符为实际按键
  ///
  /// [script] 配置脚本
  /// [keyBindings] 按键映射，key 为标签名，value 为按键值
  static String replace(String script, Map<String, String> keyBindings) {
    return script.replaceAllMapped(placeholderPattern, (match) {
      final label = match.group(1)!;
      return keyBindings[label] ?? match.group(0)!;
    });
  }

  /// 验证所有占位符是否都有对应的按键
  ///
  /// 返回 true 表示所有占位符都有对应的按键
  static bool validate(String script, Map<String, String> keyBindings) {
    final labels = getUniqueLabels(script);
    for (final label in labels) {
      if (!keyBindings.containsKey(label) || keyBindings[label]!.isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// 获取缺失的按键绑定标签
  static List<String> getMissingBindings(String script, Map<String, String> keyBindings) {
    final labels = getUniqueLabels(script);
    return labels.where((label) => 
      !keyBindings.containsKey(label) || keyBindings[label]!.isEmpty
    ).toList();
  }

  /// 检查脚本是否包含占位符
  static bool hasPlaceholders(String script) {
    return placeholderPattern.hasMatch(script);
  }

  /// 统计占位符出现次数（包括重复的）
  static int countAllOccurrences(String script) {
    return placeholderPattern.allMatches(script).length;
  }

  /// 统计特定标签的出现次数
  static int countLabelOccurrences(String script, String label) {
    final pattern = RegExp(RegExp.escape('{{KEY:$label}}'));
    return pattern.allMatches(script).length;
  }
}

/// 按键占位符
class KeyPlaceholder {
  final String label;
  final int startIndex;
  final int endIndex;

  const KeyPlaceholder({
    required this.label,
    required this.startIndex,
    required this.endIndex,
  });

  @override
  String toString() => 'KeyPlaceholder(label: $label, start: $startIndex, end: $endIndex)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeyPlaceholder &&
        other.label == label &&
        other.startIndex == startIndex &&
        other.endIndex == endIndex;
  }

  @override
  int get hashCode => Object.hash(label, startIndex, endIndex);
}
