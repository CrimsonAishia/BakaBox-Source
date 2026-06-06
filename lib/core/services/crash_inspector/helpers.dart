// 工具函数 - 从 Python 版逐项复刻
//
// 来源: _cs2_error/lib/helpers.dart (1:1 拷贝, 仅调整文件位置).
import 'rules.dart';

/// 返回 [path] 是否落在某模块地址区间内, 是则返回该模块.
T? addrIn<T>(List<T> modules, int addr, int Function(T) base,
    int Function(T) size) {
  for (final m in modules) {
    final b = base(m);
    if (b <= addr && addr < b + size(m)) return m;
  }
  return null;
}

/// 资源后缀分类.
String classify(String path) {
  final p = path.toLowerCase();
  for (final suf in resSuffixes) {
    if (p.endsWith('.$suf')) return suf;
  }
  return 'other';
}

/// 取末两段路径作为归并键.
String canonical(String path) {
  final p = path.replaceAll('\\', '/').toLowerCase().replaceAll(RegExp(r'^/+'), '');
  final parts = p.split('/').where((s) => s.isNotEmpty).toList();
  return parts.length >= 2
      ? parts.sublist(parts.length - 2).join('/')
      : p;
}

final RegExp _shortPrefixRe = RegExp(r'^[a-z]{1,3}_[a-z]');

/// 启发式: 路径是否像被从更长字符串中间截出来.
bool looksTruncated(String path) {
  final p = path.replaceAll('\\', '/').toLowerCase();
  if (!p.contains('/')) {
    final base = p.split('.').first;
    if (base.length < 12) return true;
    if (_shortPrefixRe.hasMatch(base)) return true;
    return false;
  }
  final head = p.split('/').first;
  if (knownTops.contains(head)) return false;
  final parts = p.split('/').where((s) => s.isNotEmpty).toList();
  if (parts.length >= 2) {
    if (parts[0].length <= 2) return true;
    return false;
  }
  return true;
}

/// 从虚拟地址读取一个可打印 ASCII 字符串.
String? tryReadString(dynamic reader, int addr, {int maxLen = 512}) {
  if (addr < 0x10000 || addr > 0x00007FFFFFFFFFFF) return null;
  final s = reader.read(addr, maxLen);
  if (s == null) return null;
  // 在原始字节上匹配开头连续可打印字符
  var end = 0;
  while (end < s.length && s[end] >= 0x20 && s[end] <= 0x7e) {
    end++;
  }
  if (end < 6) return null;
  final txt = String.fromCharCodes(s.sublist(0, end)).trim();
  return txt.length >= 6 ? txt : null;
}

/// 解释 AV 目标地址的常见模式.
String explainAvTarget(int? addr) {
  if (addr == null) return '';
  if (addr == 0) return '空指针解引用 (this/object 为 NULL)';
  if (addr == 0xFFFFFFFFFFFFFFFF) {
    return '目标为 -1 / std::string::npos / 容器越界';
  }
  if (addr < 0x1000) {
    return 'this 指针为空, 试图访问 +0x${addr.toRadixString(16).toUpperCase()} 字段';
  }
  if (addr & 0xFFFF == 0xFEEE) return 'Windows 调试堆已释放标记 (use-after-free)';
  if (addr & 0xFFFF == 0xCDCD || addr & 0xFFFF == 0xCCCC) {
    return '未初始化内存模式';
  }
  if (addr > 0x7FFFFFFFFFFF) return '内核地址 / 非法地址';
  return '';
}

final RegExp _fatalDupRe = RegExp(r'(FATAL ERROR:\s*)+', caseSensitive: false);

/// 对错误消息去重, 返回按 stack_offset 排序的列表.
List<Map<String, dynamic>> dedupeMessages(Map<String, int> msgDict) {
  // 1) 折叠重复的 'FATAL ERROR: ' 前缀
  final cleaned = <String, int>{};
  msgDict.forEach((text, off) {
    final norm = text.replaceAll(_fatalDupRe, 'FATAL ERROR: ');
    if (!cleaned.containsKey(norm) || off < cleaned[norm]!) {
      cleaned[norm] = off;
    }
  });

  // 2) 子串去重: 长的在前
  final items = cleaned.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  final kept = <MapEntry<String, int>>[];
  for (final e in items) {
    final tCore = e.key.replaceAll('FATAL ERROR: ', '').trim();
    var redundant = false;
    for (final k in kept) {
      final ktCore = k.key.replaceAll('FATAL ERROR: ', '').trim();
      if (tCore.isNotEmpty && ktCore.contains(tCore)) {
        redundant = true;
        break;
      }
    }
    if (!redundant) kept.add(e);
  }

  final result = kept
      .map((e) => {'text': e.key, 'stack_offset': e.value})
      .toList()
    ..sort((a, b) =>
        (a['stack_offset'] as int).compareTo(b['stack_offset'] as int));
  return result.take(20).toList();
}
