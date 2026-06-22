// 核心分析逻辑 - 从 Python analyze()/deep_analyze() 复刻
//
// 来源: _cs2_error/lib/analyzer.dart (1:1 拷贝, 仅调整文件位置).
import 'dart:io';
import 'dart:typed_data';

import 'minidump.dart';
import 'rules.dart';
import 'helpers.dart';

/// 小端读 uint64.
int _u64(Uint8List data, int off) =>
    ByteData.sublistView(data, off, off + 8).getUint64(0, Endian.little);

Map<String, dynamic> analyze(String path, {bool deep = false}) {
  final mf = MinidumpFile.parse(path);
  final reader = mf.getReader();
  final modules = mf.modules;
  final moduleNames = modules
      .map((m) => basename(m.name).toLowerCase())
      .toSet();

  final out = <String, dynamic>{
    'file': basename(path),
    'size': File(path).lengthSync(),
    'ok': true,
    'exception': null,
    'crash_module': null,
    'crash_category': null,
    'registers': <String, int>{},
    'register_strings': <String, dynamic>{},
    'stack_size': 0,
    'stack_read': 0,
    'stack_base': 0,
    'call_chain': <Map<String, dynamic>>[],
    'module_hits': <String, int>{},
    'resources': <Map<String, dynamic>>[],
    'raw_paths': <Map<String, dynamic>>[],
    'workshop_vpks': <Map<String, dynamic>>[],
    'fatal_strings': <Map<String, dynamic>>[],
    'assert_strings': <Map<String, dynamic>>[],
    'third_party_modules': <Map<String, dynamic>>[],
    'subsystems': <Map<String, dynamic>>[],
    'is_tool_dump': false,
  };

  final exr = mf.exception;
  if (exr == null) {
    out['ok'] = false;
    out['error'] = '无异常记录';
    return out;
  }

  // --- 异常 ---
  final crashTid = exr.threadId;
  final code = exr.exceptionCode & 0xFFFFFFFF;
  final exc = <String, dynamic>{
    'thread_id': crashTid,
    'code': code,
    'code_name': excCodes[code] ?? '未知异常码',
    'address': exr.exceptionAddress,
    'params': List<int>.from(exr.exceptionInformation),
  };
  if (code == 0xC0000005 && exc['params'].length >= 2) {
    final op = exc['params'][0];
    exc['av_op'] = {0: 'READ', 1: 'WRITE', 8: 'EXEC'}[op] ?? '$op';
    exc['av_target'] = exc['params'][1];
    exc['av_explain'] = explainAvTarget(exc['av_target'] as int);
  }
  out['exception'] = exc;

  final cm = addrIn<MinidumpModule>(
    modules,
    exr.exceptionAddress,
    (m) => m.baseaddress,
    (m) => m.size,
  );
  if (cm != null) {
    out['crash_module'] = {
      'name': basename(cm.name),
      'base': cm.baseaddress,
      'rva': exr.exceptionAddress - cm.baseaddress,
    };
  }

  // --- 崩溃类别判定 ---
  final crashModLower = out['crash_module'] != null
      ? (out['crash_module']['name'] as String).toLowerCase()
      : '';
  if (gpuDriverModules.contains(crashModLower)) {
    out['crash_category'] = 'gpu';
  } else if (toolModules.contains(crashModLower) ||
      toolModules.any((t) => moduleNames.contains(t))) {
    out['is_tool_dump'] = toolModules.any((t) => moduleNames.contains(t));
    out['crash_category'] = toolModules.contains(crashModLower)
        ? 'tools'
        : 'resource';
  } else if (crashModuleProfile.containsKey(crashModLower)) {
    out['crash_category'] = 'resource';
  } else if (crashModLower == 'kernelbase.dll') {
    out['crash_category'] = 'system';
  } else if (out['crash_module'] == null) {
    if (code == 0xC0000005 && exc['av_op'] == 'EXEC') {
      out['crash_category'] = 'code_exec';
    } else {
      out['crash_category'] = 'unknown';
    }
  } else {
    out['crash_category'] = 'unknown';
  }

  // --- 第三方注入模块 ---
  final seenThird = <String>{};
  for (final m in modules) {
    final nm = basename(m.name);
    final nl = nm.toLowerCase();
    for (final entry in thirdPartyHints.entries) {
      if (nl.contains(entry.key) && !seenThird.contains(nl)) {
        out['third_party_modules'].add({
          'name': nm,
          'sev': entry.value.sev,
          'label': entry.value.name,
          'advice': entry.value.advice,
        });
        seenThird.add(nl);
        break;
      }
    }
  }

  // --- 崩溃线程 ---
  MinidumpThread? crashThread;
  for (final t in mf.threads) {
    if (t.threadId == crashTid) {
      crashThread = t;
      break;
    }
  }
  if (crashThread == null) {
    out['ok'] = false;
    out['error'] = '未找到崩溃线程';
    return out;
  }

  final ctx = mf.contextForThread(crashTid);
  final regNames = [
    'Rip',
    'Rsp',
    'Rbp',
    'Rax',
    'Rbx',
    'Rcx',
    'Rdx',
    'Rsi',
    'Rdi',
    'R8',
    'R9',
    'R10',
    'R11',
    'R12',
    'R13',
    'R14',
    'R15',
  ];
  final registers = out['registers'] as Map<String, int>;
  if (ctx != null) {
    for (final r in regNames) {
      final v = ctx[r];
      if (v != null) registers[r] = v;
    }
  }

  // --- 寄存器直接指向的字符串 ---
  final regStrings = out['register_strings'] as Map<String, dynamic>;
  for (final rname in [...argRegs, 'Rax', 'Rbx', 'Rsi', 'Rdi']) {
    final v = registers[rname];
    if (v == null) continue;
    final s = tryReadString(reader, v);
    if (s != null && s.length <= 300) {
      regStrings[rname] = {'addr': v, 'text': s};
    }
  }

  // --- 读栈 ---
  final stackAddr = crashThread.stackStart;
  final stackSize = crashThread.stackSize;
  out['stack_size'] = stackSize;

  Uint8List? data = reader.read(stackAddr, stackSize);
  if (data == null) {
    final rsp = ctx?['Rsp'] ?? stackAddr;
    data = reader.read(rsp, stackSize < 0x4000 ? stackSize : 0x4000);
    out['stack_base'] = rsp;
  } else {
    out['stack_base'] = stackAddr;
  }

  if (data == null) {
    out['ok'] = false;
    out['error'] = '无法读取栈数据';
    return out;
  }
  out['stack_read'] = data.length;

  // --- 调用链 ---
  final moduleHits = <String, int>{};
  final chain = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (var off = 0; off < data.length - 8; off += 8) {
    final v = _u64(data, off);
    if (v < 0x10000 || v > 0x00007FFFFFFFFFFF) continue;
    final m = addrIn<MinidumpModule>(
      modules,
      v,
      (mm) => mm.baseaddress,
      (mm) => mm.size,
    );
    if (m == null) continue;
    final nm = basename(m.name);
    moduleHits[nm] = (moduleHits[nm] ?? 0) + 1;
    final rva = v - m.baseaddress;
    final key = '${nm.toLowerCase()}|$rva';
    if (!seen.contains(key)) {
      seen.add(key);
      chain.add({
        'stack_offset': off,
        'addr': v,
        'module': nm,
        'rva': rva,
        'is_core': coreModules.contains(nm.toLowerCase()),
      });
    }
  }
  out['call_chain'] = chain;
  out['module_hits'] = _mostCommon(moduleHits, 40);

  // --- 嫌疑子系统 ---
  final subsystems = <Map<String, dynamic>>[];
  moduleHits.forEach((nm, cnt) {
    final nl = nm.toLowerCase();
    if (subsystemLabels.containsKey(nl) && cnt >= 3) {
      subsystems.add({'module': nm, 'label': subsystemLabels[nl], 'hits': cnt});
    }
  });
  subsystems.sort((a, b) => (b['hits'] as int).compareTo(a['hits'] as int));
  out['subsystems'] = subsystems;

  // --- 栈中字符串 (指针指向) ---
  final pointerStrings = <String, List<int>>{}; // text -> [off, ptr]
  for (var off = 0; off < data.length - 8; off += 8) {
    final ptr = _u64(data, off);
    final s = tryReadString(reader, ptr);
    if (s != null) {
      final cur = pointerStrings[s];
      if (cur == null || off < cur[0]) {
        pointerStrings[s] = [off, ptr];
      }
    }
  }

  // 内联扫描 (在栈原始字节上)
  final text = latin1Decode(data);
  final inlineStrings = <String, int>{};
  final wsFullRe = RegExp(
    r'[A-Za-z0-9_/\\\-\.]*?\d{6,12}[/\\]\d{6,12}\.vpk(?::[A-Za-z0-9_/\\\-\.]+?\.\w{3,9})?',
    caseSensitive: false,
  );
  for (final m in wsFullRe.allMatches(text)) {
    final s = m.group(0)!;
    inlineStrings.putIfAbsent(s, () => m.start);
  }
  for (final m in pathRe.allMatches(text)) {
    final s = m.group(0)!;
    inlineStrings.putIfAbsent(s, () => m.start);
  }
  for (final m in resRe.allMatches(text)) {
    final s = m.group(0)!;
    inlineStrings.putIfAbsent(s, () => m.start);
  }

  // --- 资源 + 路径 + 错误 ---
  final resources = <Map<String, dynamic>>[];
  final raws = <String, int>{};
  final fatals = <String, int>{};
  final asserts = <String, int>{};
  final workshopVpks = <String, Map<String, dynamic>>{};

  final contentFragRe = RegExp(r'^[a-z]{0,6}tent/\d{3,}/');

  bool recordResource(String s, int off, String source) {
    final inner = vpkInnerRe.firstMatch(s);
    final wmFull = workshopVpkRe.firstMatch(s.replaceAll('\\', '/'));
    if (wmFull != null) {
      final wid = wmFull.group(1)!;
      final innerPath = inner != null
          ? inner.group(1)!.replaceAll('\\', '/')
          : '';
      var cur = workshopVpks[wid];
      if (cur == null) {
        cur = {'offset': off, 'inner': <String>{}};
        workshopVpks[wid] = cur;
      }
      if (off >= 0 &&
          ((cur['offset'] as int) < 0 || off < (cur['offset'] as int))) {
        cur['offset'] = off;
      }
      if (innerPath.isNotEmpty) {
        (cur['inner'] as Set<String>).add(innerPath);
      }
    }

    final m = resRe.firstMatch(s);
    if (m == null) return false;
    final rp = m.group(0)!.replaceAll('\\', '/');
    if (looksTruncated(rp)) return false;
    if (contentFragRe.hasMatch(rp)) return false;
    final basenamePart = rp.split('/').last;
    if (basenamePart.contains('.') &&
        basenamePart.split('.').first.length < 4) {
      return false;
    }
    resources.add({
      'path': rp,
      'canonical': canonical(rp),
      'kind': classify(rp),
      'stack_offset': off,
      'source': source,
    });
    return true;
  }

  void recordText(String s, int off) {
    final sl = s.toLowerCase();
    final isFatal = fatalKeywords.any((k) => sl.contains(k.toLowerCase()));
    final isAssert = assertKeywords.any((k) => sl.contains(k.toLowerCase()));
    if ((isFatal || isAssert) && s.length > 12) {
      if (noisePrefixes.any((p) => s.startsWith(p))) return;
      final target = isFatal ? fatals : asserts;
      if (!target.containsKey(s) || off < target[s]!) target[s] = off;
    }
  }

  // 指针字符串
  pointerStrings.forEach((s, op) {
    final off = op[0];
    final sl = s.toLowerCase();
    final isFatal = fatalKeywords.any((k) => sl.contains(k.toLowerCase()));
    final isAssert = assertKeywords.any((k) => sl.contains(k.toLowerCase()));
    if ((isFatal || isAssert) &&
        s.length > 12 &&
        !noisePrefixes.any((p) => s.startsWith(p))) {
      final target = isFatal ? fatals : asserts;
      if (!target.containsKey(s) || off < target[s]!) target[s] = off;
      for (final m in resRe.allMatches(s)) {
        final rp = m.group(0)!.replaceAll('\\', '/');
        if (!looksTruncated(rp)) recordResource(rp, off, 'fatal');
      }
      return;
    }
    if (recordResource(s, off, 'ptr')) return;
    final m = pathRe.firstMatch(s);
    if (m != null) {
      final p = m.group(0)!.replaceAll('\\', '/');
      if (!raws.containsKey(p) || off < raws[p]!) raws[p] = off;
    }
  });

  // 内联字符串
  inlineStrings.forEach((s, off) {
    final sl = s.toLowerCase();
    final isFatal = fatalKeywords.any((k) => sl.contains(k.toLowerCase()));
    final isAssert = assertKeywords.any((k) => sl.contains(k.toLowerCase()));
    if ((isFatal || isAssert) &&
        s.length > 12 &&
        !noisePrefixes.any((p) => s.startsWith(p))) {
      final target = isFatal ? fatals : asserts;
      if (!target.containsKey(s) || off < target[s]!) target[s] = off;
      for (final m in resRe.allMatches(s)) {
        final rp = m.group(0)!.replaceAll('\\', '/');
        if (!looksTruncated(rp)) recordResource(rp, off, 'fatal');
      }
      return;
    }
    if (recordResource(s, off, 'inline')) return;
    if (pathRe.hasMatch(s)) {
      if (!raws.containsKey(s) || off < raws[s]!) raws[s] = off;
    }
  });

  // 寄存器命中
  regStrings.forEach((rn, info) {
    recordResource(info['text'] as String, -1, 'reg:$rn');
    recordText(info['text'] as String, -1);
  });

  // 归并 (按 canonical 分组)
  final byCanon = <String, Map<String, dynamic>>{};
  for (final r in resources) {
    final c = r['canonical'] as String;
    final cur = byCanon[c];
    if (cur == null) {
      byCanon[c] = {
        'path': r['path'],
        'canonical': c,
        'kind': r['kind'],
        'stack_offset': r['stack_offset'],
        'sources': <String>{r['source'] as String},
      };
    } else {
      if ((r['path'] as String).length > (cur['path'] as String).length) {
        cur['path'] = r['path'];
      }
      final offs = [
        cur['stack_offset'] as int,
        r['stack_offset'] as int,
      ].where((o) => o >= 0).toList();
      if (offs.isNotEmpty) {
        cur['stack_offset'] = offs.reduce((a, b) => a < b ? a : b);
      }
      (cur['sources'] as Set<String>).add(r['source'] as String);
    }
  }
  for (final v in byCanon.values) {
    v['sources'] = (v['sources'] as Set<String>).toList()..sort();
  }
  final resList = byCanon.values.toList()
    ..sort((a, b) {
      final oa = (a['stack_offset'] as int) >= 0
          ? a['stack_offset'] as int
          : -1;
      final ob = (b['stack_offset'] as int) >= 0
          ? b['stack_offset'] as int
          : -1;
      if (oa != ob) return oa.compareTo(ob);
      return (a['canonical'] as String).compareTo(b['canonical'] as String);
    });
  out['resources'] = resList;

  final rawEntries = raws.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  out['raw_paths'] = rawEntries
      .take(30)
      .map((e) => {'path': e.key, 'stack_offset': e.value})
      .toList();

  // 去掉 asserts 中与 fatals 重复的
  for (final t in asserts.keys.toList()) {
    if (fatals.containsKey(t)) {
      asserts.remove(t);
    } else if (fatals.keys.any((ft) => t.contains(ft) || ft.contains(t))) {
      asserts.remove(t);
    }
  }

  out['fatal_strings'] = dedupeMessages(fatals);
  out['assert_strings'] = dedupeMessages(asserts);

  final wsEntries = workshopVpks.entries.toList()
    ..sort(
      (a, b) => (a.value['offset'] as int).compareTo(b.value['offset'] as int),
    );
  out['workshop_vpks'] = wsEntries.map((e) {
    final inner = (e.value['inner'] as Set<String>).toList()..sort();
    return {'id': e.key, 'stack_offset': e.value['offset'], 'inner': inner};
  }).toList();

  // --- 扫描整个 dump 文件中的 Workshop 订阅列表 ---
  // 模型崩溃时, 栈里通常没有 wid/wid.vpk 路径, 但 dump 堆内存里
  // 会保留控制台日志快照: "Addons: 1234567890, 2345678901".
  // 这条是崩溃当下还挂着的订阅项, 把里面的 ID 补到 workshop_vpks.
  // (历史日志里的 "Unmounting addon" 是已卸载的, 跟崩溃无关, 不收录.)
  final knownIds = (out['workshop_vpks'] as List)
      .map((e) => e['id'] as String)
      .toSet();
  final subscribedIds = <String>{};
  final fileText = latin1Decode(mf.bytes);
  final addonsLineRe = RegExp(r'Addons:\s*(\d{6,12}(?:\s*,\s*\d{6,12})*)');
  for (final m in addonsLineRe.allMatches(fileText)) {
    for (final idM in RegExp(r'\d{6,12}').allMatches(m.group(1)!)) {
      subscribedIds.add(idM.group(0)!);
    }
  }
  final extra = <Map<String, dynamic>>[];
  for (final id in subscribedIds) {
    if (knownIds.contains(id)) continue;
    if (id.length < 9) continue; // 排除 build 号等短数字
    extra.add({'id': id, 'stack_offset': -1, 'inner': <String>[]});
  }
  extra.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  (out['workshop_vpks'] as List).addAll(extra);

  if (deep) {
    out['deep'] = deepAnalyze(reader, modules, data, ctx);
  }

  return out;
}

Map<String, dynamic> deepAnalyze(
  MinidumpReader reader,
  List<MinidumpModule> modules,
  Uint8List data,
  ThreadContext? ctx,
) {
  MinidumpModule? modOf(int addr) => addrIn<MinidumpModule>(
    modules,
    addr,
    (m) => m.baseaddress,
    (m) => m.size,
  );

  final result = <String, dynamic>{
    'vtables': <Map<String, dynamic>>[],
    'near_strings': <Map<String, dynamic>>[],
    'object_vtables': <String, dynamic>{},
  };

  // 1) 寄存器指向对象的 vtable
  for (final rn in ['Rcx', 'Rdx', 'R8', 'R9', 'Rax', 'Rbx', 'Rsi', 'Rdi']) {
    final v = ctx?[rn];
    if (v == null || v < 0x10000 || v > 0x00007FFFFFFFFFFF) continue;
    final o = reader.read(v, 8);
    if (o == null || o.length < 8) continue;
    final vp = _u64(o, 0);
    final m = modOf(vp);
    if (m != null) {
      (result['object_vtables'] as Map)[rn] = {
        'obj_addr': v,
        'vtable':
            '${basename(m.name)}+0x${(vp - m.baseaddress).toRadixString(16).toUpperCase()}',
      };
    }
  }

  // 2) 栈上对象 vtable 频次
  final vtab = <String, int>{}; // "name|rva" -> count
  for (var off = 0; off < data.length - 8; off += 8) {
    final p = _u64(data, off);
    if (p < 0x10000 || p > 0x00007FFFFFFFFFFF) continue;
    final o = reader.read(p, 8);
    if (o == null || o.length < 8) continue;
    final vp = _u64(o, 0);
    final m = modOf(vp);
    if (m != null) {
      final k = '${basename(m.name)}|${vp - m.baseaddress}';
      vtab[k] = (vtab[k] ?? 0) + 1;
    }
  }
  final vtabKeys = vtab.keys.toList();
  final vtabSorted =
      List.generate(
        vtabKeys.length,
        (i) => (vtabKeys[i], vtab[vtabKeys[i]]!, i),
      )..sort((a, b) {
        final c = b.$2.compareTo(a.$2);
        return c != 0 ? c : a.$3.compareTo(b.$3);
      });
  for (final e in vtabSorted.take(15)) {
    if (e.$2 >= 3) {
      final parts = e.$1.split('|');
      final nm = parts[0];
      final rva = int.parse(parts[1]);
      (result['vtables'] as List).add({
        'module': nm,
        'rva': rva,
        'count': e.$2,
        'fingerprint': '$nm+0x${rva.toRadixString(16).toUpperCase()}',
      });
    }
  }

  // 3) 崩溃帧附近原始可读字符串 (前 0x6000)
  final seen = <String>{};
  final limit = data.length < 0x6000 ? data.length : 0x6000;
  final head = String.fromCharCodes(data.sublist(0, limit), 0, limit);
  final strRe = RegExp(r'[\x20-\x7e]{6,200}');
  final letterRe = RegExp(r'[A-Za-z]{4,}');
  final collected = <Map<String, dynamic>>[];
  for (final m in strRe.allMatches(head)) {
    final s = m.group(0)!;
    if (seen.contains(s)) continue;
    seen.add(s);
    if (letterRe.hasMatch(s) && !s.endsWith('.mdmp')) {
      collected.add({'offset': m.start, 'text': s});
    }
  }
  result['near_strings'] = collected.take(40).toList();

  return result;
}

/// latin1 解码 (等价 python bytes.decode("latin1")).
String latin1Decode(Uint8List data) {
  return String.fromCharCodes(data);
}

/// 取 map 中计数最高的前 n 项 (等价 Counter.most_common: 计数降序, 同分保持插入序).
Map<String, int> _mostCommon(Map<String, int> m, int n) {
  final keys = m.keys.toList(); // 插入序
  final entries = List.generate(keys.length, (i) => (keys[i], m[keys[i]]!, i));
  entries.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    return c != 0 ? c : a.$3.compareTo(b.$3);
  });
  final out = <String, int>{};
  for (final e in entries.take(n)) {
    out[e.$1] = e.$2;
  }
  return out;
}
