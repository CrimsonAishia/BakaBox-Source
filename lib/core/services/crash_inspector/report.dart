// 报告渲染 - 从 Python render() 复刻
//
// 来源: _cs2_error/lib/report.dart (1:1 拷贝, 仅将 print 替换为
//      StringBuffer 写入并返回完整文本, 便于在 UI 中显示).
import 'rules.dart';

/// 渲染崩溃报告并返回为字符串.
///
/// 与原 `render()` 等价, 但不直接 `print`, 而是写入 [StringBuffer] 后返回.
String renderToString(Map<String, dynamic> r, {bool verbose = false}) {
  final buf = StringBuffer();
  void p(String s) => buf.writeln(s);

  void section(String title) {
    final pad = (74 - title.length) < 4 ? 4 : (74 - title.length);
    p('\n---- $title ${'-' * pad}');
  }

  p('=' * 80);
  p('CS2 崩溃报告');
  p('=' * 80);

  if (r['ok'] != true) {
    p('[FAIL] ${r['error']}');
    return buf.toString();
  }

  // --- 异常 ---
  final exc = r['exception'] as Map<String, dynamic>;
  section('异常');
  p('  线程ID    : ${exc['thread_id']}');
  p(
    '  异常码    : 0x${(exc['code'] as int).toRadixString(16).toUpperCase().padLeft(8, '0')}  -> ${exc['code_name']}',
  );
  p('  异常地址  : ${fmtAddr(exc['address'] as int)}');
  if (exc.containsKey('av_op')) {
    var line =
        '  访问类型  : ${exc['av_op']} 目标 ${fmtAddr(exc['av_target'] as int)}';
    if ((exc['av_explain'] as String).isNotEmpty) {
      line += '  (${exc['av_explain']})';
    }
    p(line);
  }
  final crashModule = r['crash_module'] as Map<String, dynamic>?;
  if (crashModule != null) {
    final prof =
        crashModuleProfile[(crashModule['name'] as String).toLowerCase()];
    final tag = prof != null ? '  [${prof.$1}]' : '';
    p(
      '  崩溃位置  : ${crashModule['name']}+0x${_hex(crashModule['rva'] as int)}$tag',
    );
  } else {
    p('  崩溃位置  : <非已加载模块>');
  }

  // --- 崩溃类别速判 ---
  final cat = r['crash_category'] as String?;
  section('崩溃类别');
  if (cat == 'gpu') {
    p(
      '  [GPU/驱动]  崩在 ${crashModule!['name']}, '
      '通常与显卡驱动 / 硬件 / DX11 资源相关, 与 mod 内容关系小',
    );
    p('    建议: 更新显卡驱动、降低画质设置、关闭硬件加速、关闭 RTSS/MSI Afterburner');
  } else if (cat == 'tools') {
    p('  [Workshop 工具]  这是 ModelDoc / Hammer 等编辑工具的崩溃, 不是游戏运行时');
  } else if (cat == 'system') {
    p('  [系统/异常处理]  崩在 KERNELBASE.dll, 多半是上层抛出未捕获异常的系统转发');
  } else if (cat == 'resource') {
    final prof =
        crashModuleProfile[(crashModule!['name'] as String).toLowerCase()];
    if (prof != null) {
      final kinds = prof.$2.map((k) => kindLabel[k] ?? k).join(', ');
      p('  [资源/逻辑]  ${prof.$1}, 重点排查类型: ${kinds.isEmpty ? '(综合)' : kinds}');
    }
  } else if (cat == 'code_exec') {
    p('  [非法代码执行]  异常地址不在任何已加载模块中, 且是 EXEC 类型访问违规');
    p('    程序试图跳转到一个非法/已释放的地址去执行代码. 常见原因:');
    p('    - 函数指针/回调被破坏, 虚表(vtable)被改写 (use-after-free)');
    p('    - 栈被破坏后返回到垃圾地址');
    p('    - 注入的第三方代码(外挂/覆盖层)被卸载后仍被调用');
    p('    建议: 结合下方调用链的最后有效模块判断, 优先排查第三方注入模块');
  } else {
    p('  [未知]  ${crashModule != null ? crashModule['name'] : '?'}');
  }

  if (r['is_tool_dump'] == true) {
    p('  [!] 进程加载了 Qt - 可能是 Workshop 工具的崩溃 dump');
  }

  // --- 寄存器直接命中字符串 ---
  final regStrings = r['register_strings'] as Map<String, dynamic>;
  if (regStrings.isNotEmpty) {
    section('[强证据] 寄存器直接指向字符串 (≈ 函数参数)');
    regStrings.forEach((rn, info) {
      var txt = info['text'] as String;
      if (txt.length > 200) txt = '${txt.substring(0, 200)}...';
      p(
        '  $rn -> 0x${_uhex(info['addr'] as int).padLeft(16, '0')}  ${_repr(txt)}',
      );
    });
  }

  // --- 致命错误 ---
  final fatals = r['fatal_strings'] as List;
  if (fatals.isNotEmpty) {
    section('[★] 致命错误线索 (Fatal)');
    for (final f in fatals) {
      final tag = depthTag(f['stack_offset'] as int);
      var txt = f['text'] as String;
      if (txt.length > 240 && !verbose) txt = '${txt.substring(0, 240)} ...';
      p('  $tag  $txt');
    }
  }

  // --- 嫌疑资源 ---
  section('嫌疑资源  (栈深度越浅越接近崩溃帧)');
  final resources = r['resources'] as List;
  if (resources.isNotEmpty) {
    final crashMod = crashModule != null
        ? (crashModule['name'] as String).toLowerCase()
        : '';
    final profKinds = crashModuleProfile.containsKey(crashMod)
        ? crashModuleProfile[crashMod]!.$2.toSet()
        : <String>{};

    final byKind = <String, List>{};
    for (final res in resources) {
      byKind.putIfAbsent(res['kind'] as String, () => []).add(res);
    }

    final kindOrder = [
      'vmap_c',
      'vmap',
      'vwnod_c',
      'vwnod',
      'vmdl_c',
      'vmdl',
      'vmat_c',
      'vmat',
      'vpcf_c',
      'vpcf',
      'vtex_c',
      'vsnd_c',
      'vsnd',
      'vsndevts_c',
      'vsndevts',
      'vanim_c',
      'vphys_c',
      'vphys',
      'vnmgraph_c',
      'vrman_c',
      'vpk',
      'other',
    ];
    for (final k in byKind.keys) {
      if (!kindOrder.contains(k)) kindOrder.add(k);
    }
    for (final kind in kindOrder) {
      if (!byKind.containsKey(kind)) continue;
      final label = kindLabel[kind] ?? kind;
      final highlight = profKinds.contains(kind) ? ' ★' : '';
      p('  [$label]$highlight');
      final items = List.from(byKind[kind]!)
        ..sort((a, b) {
          final oa = (a['stack_offset'] as int) >= 0
              ? a['stack_offset'] as int
              : -1;
          final ob = (b['stack_offset'] as int) >= 0
              ? b['stack_offset'] as int
              : -1;
          return oa.compareTo(ob);
        });
      final limit = verbose
          ? items.length
          : (items.length < 8 ? items.length : 8);
      for (final r_ in items.take(limit)) {
        final tag = depthTag(r_['stack_offset'] as int);
        var src = '';
        final sources = (r_['sources'] as List).cast<String>();
        if (sources.any((s) => s.startsWith('reg:'))) src = '  (寄存器命中)';
        final offText = (r_['stack_offset'] as int) < 0
            ? '+REG'
            : '+${_off5(r_['stack_offset'] as int)}';
        p('    $tag  $offText  ${r_['path']}$src');
      }
      if (!verbose && items.length > limit) {
        p('    ... 省略 ${items.length - limit} 个 (用 -v 查看完整)');
      }
    }
  } else {
    p('  (栈中未发现资源路径字符串)');
  }

  // --- Workshop VPK ---
  final wsVpks = r['workshop_vpks'] as List;
  if (wsVpks.isNotEmpty) {
    section('Workshop VPK 包 (社区订阅内容)');
    for (final v in wsVpks) {
      final off = v['stack_offset'] as int;
      // 仅在 dump 订阅列表里发现 (栈中无引用) 的, 用 [订阅] 标示
      final offText = off < 0 ? '[订阅]' : '+${_off5(off)}';
      p(
        '  WorkshopID=${v['id']}  $offText  '
        '-> https://steamcommunity.com/sharedfiles/filedetails/?id=${v['id']}',
      );
      for (final inner in (v['inner'] as List)) {
        final kind = classifyExt(inner as String);
        final label = kindLabel[kind] ?? kind;
        p('      包内[$label]: $inner');
      }
    }
  }

  // --- 调用链 ---
  section('调用链 (核心模块)');
  final coreChain =
      (r['call_chain'] as List).where((c) => c['is_core'] == true).toList()
        ..sort(
          (a, b) =>
              (a['stack_offset'] as int).compareTo(b['stack_offset'] as int),
        );
  if (coreChain.isNotEmpty) {
    final limit = verbose ? 80 : 20;
    for (final c in coreChain.take(limit)) {
      p(
        '  +${_off5(c['stack_offset'] as int)}  ${c['module']}+0x${_hex(c['rva'] as int)}',
      );
    }
    if (!verbose && coreChain.length > limit) {
      p('  ... 省略 ${coreChain.length - limit} 项');
    }
  } else {
    p('  (无)');
  }

  // --- 嫌疑子系统 ---
  final subsystems = r['subsystems'] as List;
  if (subsystems.isNotEmpty) {
    section('嫌疑子系统 (栈中频次)');
    for (final sub in subsystems.take(8)) {
      p(
        '  ${(sub['module'] as String).padRight(30)}  x${(sub['hits'] as int).toString().padRight(4)}  ${sub['label']}',
      );
    }
  }

  // --- 一般错误 ---
  final asserts = r['assert_strings'] as List;
  if (asserts.isNotEmpty) {
    section('内部错误线索');
    for (final a in asserts.take(10)) {
      final tag = depthTag(a['stack_offset'] as int);
      var txt = a['text'] as String;
      if (txt.length > 200 && !verbose) txt = '${txt.substring(0, 200)} ...';
      p('  $tag  $txt');
    }
  }

  // --- 模块频次 (verbose) ---
  if (verbose) {
    section('栈中模块频次 Top 15');
    final hits = (r['module_hits'] as Map).entries.toList();
    for (final e in hits.take(15)) {
      final flag = coreModules.contains((e.key as String).toLowerCase())
          ? ' *core'
          : '';
      p('  ${(e.key as String).padRight(30)}  x${e.value}$flag');
    }
  }

  // --- 第三方注入 ---
  final tpm = r['third_party_modules'] as List;
  if (tpm.isNotEmpty) {
    section('注入到游戏的非游戏模块');
    const sevLabel = {'high': '[高危]', 'medium': '[可疑]', 'benign': '[正常]'};
    const order = {'high': 0, 'medium': 1, 'benign': 2};
    final mods = List.from(tpm)
      ..sort((a, b) => (order[a['sev']] ?? 1).compareTo(order[b['sev']] ?? 1));
    for (final tp in mods) {
      final sev = tp['sev'] as String? ?? 'medium';
      p('  ${sevLabel[sev] ?? '[可疑]'} ${tp['name']}  (${tp['label'] ?? ''})');
      p('      ${tp['advice']}');
    }
  }

  // --- 深度分析 ---
  final deep = r['deep'] as Map<String, dynamic>?;
  if (deep != null) {
    section('[深度] C++ 对象 vtable 指纹 (无符号, 仅作同类崩溃比对)');
    final objVtables = deep['object_vtables'] as Map;
    if (objVtables.isNotEmpty) {
      p('  崩溃寄存器指向的对象:');
      objVtables.forEach((rn, info) {
        p(
          '    $rn=0x${_uhex(info['obj_addr'] as int)}  -> vtable ${info['vtable']}',
        );
      });
    }
    final vtables = deep['vtables'] as List;
    if (vtables.isNotEmpty) {
      p('  栈上对象 vtable 频次 (出现最多的即崩溃核心对象类型):');
      for (final vt in vtables.take(8)) {
        p(
          '    x${(vt['count'] as int).toString().padRight(4)} ${vt['fingerprint']}',
        );
      }
      p('  说明: vtable RVA 是该 C++ 类的唯一指纹; 不同 dump 出现相同指纹');
      p('        = 崩在同一类对象上. 因无符号, 无法还原类名.');
    }
    section('[深度] 崩溃帧附近原始字符串 (前 0x6000)');
    final nearStrings = deep['near_strings'] as List;
    if (nearStrings.isNotEmpty) {
      for (final s in nearStrings) {
        p('    +${_off5(s['offset'] as int)}  ${_repr(s['text'] as String)}');
      }
    } else {
      p('    (无)');
    }
  }

  p('');
  p('  注: 以上为事实性线索 (崩溃位置/资源/错误文本/模块).');
  p('      资源出现在栈上 ≠ 它就是凶手; [●●●]/[REG] 最可信, [○○○] 较低.');

  return buf.toString();
}

/// 无符号 64 位十六进制 (Dart int 为有符号 64 位, 高位置 1 时会变负,
/// toUnsigned(64) 仍为负, 故按高低 32 位拼接输出无符号形式).
String _uhex(int v) {
  if (v >= 0) return v.toRadixString(16).toUpperCase();
  final hi = (v >> 32) & 0xFFFFFFFF;
  final lo = v & 0xFFFFFFFF;
  final hiStr = hi.toRadixString(16).toUpperCase();
  final loStr = lo.toRadixString(16).toUpperCase().padLeft(8, '0');
  return '$hiStr$loStr';
}

String fmtAddr(int? a) =>
    (a != null && a != 0) ? '0x${_uhex(a).padLeft(16, '0')}' : '0x0';

String depthTag(int offset) {
  if (offset < 0) return '[REG ]';
  if (offset < 0x1000) return '[●●●]';
  if (offset < 0x4000) return '[●●○]';
  if (offset < 0xC000) return '[●○○]';
  return '[○○○]';
}

String _hex(int v) => v.toRadixString(16).toUpperCase();

String _off5(int v) => '0x${v.toRadixString(16).toUpperCase().padLeft(5, '0')}';

/// 模拟 python repr() 对字符串的输出.
/// python: 默认单引号; 若串含单引号但不含双引号, 改用双引号且不转义单引号.
String _repr(String s) {
  final hasSingle = s.contains("'");
  final hasDouble = s.contains('"');
  final useDouble = hasSingle && !hasDouble;
  final quote = useDouble ? '"' : "'";
  final b = StringBuffer(quote);
  for (final rune in s.runes) {
    if (rune == 0x5c) {
      b.write('\\\\');
    } else if (!useDouble && rune == 0x27) {
      b.write("\\'");
    } else if (useDouble && rune == 0x22) {
      b.write('\\"');
    } else if (rune == 0x0a) {
      b.write('\\n');
    } else if (rune == 0x0d) {
      b.write('\\r');
    } else if (rune == 0x09) {
      b.write('\\t');
    } else if (rune < 0x20 || rune == 0x7f) {
      b.write('\\x${rune.toRadixString(16).padLeft(2, '0')}');
    } else {
      b.writeCharCode(rune);
    }
  }
  b.write(quote);
  return b.toString();
}

/// 资源后缀分类 (供报告内调用, 与 helpers.classify 同逻辑).
String classifyExt(String path) {
  final p = path.toLowerCase();
  for (final suf in resSuffixes) {
    if (p.endsWith('.$suf')) return suf;
  }
  return 'other';
}
