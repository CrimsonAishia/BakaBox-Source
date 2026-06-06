// Minidump (.mdmp) 解析器 - 纯 Dart 实现
// 复刻 python `minidump` 库中本工具所需的最小功能子集:
//   - MINIDUMP_HEADER / DIRECTORY
//   - ModuleListStream      (模块列表)
//   - ThreadListStream      (线程 + 栈 + Context)
//   - ExceptionStream       (异常记录)
//   - MemoryListStream / Memory64ListStream (虚拟地址 -> 文件数据 映射)
//   - x64 CONTEXT 寄存器读取
//
// 参考微软公开的 minidump 结构定义.
//
// 来源: _cs2_error/lib/minidump.dart (1:1 拷贝, 仅调整文件位置).

import 'dart:io';
import 'dart:typed_data';

const int _kSignatureMDMP = 0x504D444D; // 'MDMP' (小端)

// Stream 类型
const int streamThreadList = 3;
const int streamModuleList = 4;
const int streamMemoryList = 5;
const int streamException = 6;
const int streamMemory64List = 9;

/// x64 CONTEXT 结构中各寄存器相对 Context 起始的字节偏移.
const Map<String, int> _ctxOffsets = {
  'Rax': 0x78,
  'Rcx': 0x80,
  'Rdx': 0x88,
  'Rbx': 0x90,
  'Rsp': 0x98,
  'Rbp': 0xA0,
  'Rsi': 0xA8,
  'Rdi': 0xB0,
  'R8': 0xB8,
  'R9': 0xC0,
  'R10': 0xC8,
  'R11': 0xD0,
  'R12': 0xD8,
  'R13': 0xE0,
  'R14': 0xE8,
  'R15': 0xF0,
  'Rip': 0xF8,
};

class MinidumpModule {
  final String name; // 完整路径
  final int baseaddress;
  final int size;
  MinidumpModule(this.name, this.baseaddress, this.size);
}

class MemoryLocation {
  final int dataSize;
  final int rva;
  MemoryLocation(this.dataSize, this.rva);
}

class MinidumpThread {
  final int threadId;
  final int stackStart; // StartOfMemoryRange
  final int stackSize; // 栈数据字节数
  final int stackRva; // 栈数据在文件中的偏移
  final int contextRva;
  final int contextSize;
  MinidumpThread(this.threadId, this.stackStart, this.stackSize, this.stackRva,
      this.contextRva, this.contextSize);
}

class ExceptionRecord {
  final int threadId;
  final int exceptionCode;
  final int exceptionAddress;
  final List<int> exceptionInformation;
  ExceptionRecord(this.threadId, this.exceptionCode, this.exceptionAddress,
      this.exceptionInformation);
}

/// 虚拟地址 -> 文件数据 的一段映射.
class _MemRegion {
  final int start;
  final int size;
  final int fileOffset;
  _MemRegion(this.start, this.size, this.fileOffset);
}

/// 提供 read(addr, size) 能力, 把进程虚拟地址映射回 dump 文件中的字节.
class MinidumpReader {
  final Uint8List _bytes;
  final List<_MemRegion> _regions;
  MinidumpReader(this._bytes, this._regions);

  /// 读取虚拟地址 [addr] 起的 [size] 字节; 失败返回 null.
  /// 与 python minidump 行为一致: 跨段边界则视为失败 (不截断).
  Uint8List? read(int addr, int size) {
    for (final r in _regions) {
      if (addr >= r.start && addr < r.start + r.size) {
        // python: virtual_address+size > end_virtual_address => 抛异常
        if (addr + size > r.start + r.size) return null;
        final fo = r.fileOffset + (addr - r.start);
        if (fo < 0 || fo + size > _bytes.length) return null;
        return Uint8List.sublistView(_bytes, fo, fo + size);
      }
    }
    return null;
  }
}

class ThreadContext {
  final Map<String, int> _regs;
  ThreadContext(this._regs);
  int? operator [](String name) => _regs[name];
  int? get(String name) => _regs[name];
}

class MinidumpFile {
  final List<MinidumpModule> modules;
  final List<MinidumpThread> threads;
  final ExceptionRecord? exception;
  final Map<int, ThreadContext> _contexts; // threadId -> context
  final Uint8List _bytes;
  final List<_MemRegion> _regions;

  MinidumpFile._(this.modules, this.threads, this.exception, this._contexts,
      this._bytes, this._regions);

  MinidumpReader getReader() => MinidumpReader(_bytes, _regions);

  /// 整个 dump 文件的原始字节 (含所有内存段, 不止崩溃线程的栈).
  /// 用于扫描像 "Addons:" 订阅列表这种位于堆里的字符串.
  Uint8List get bytes => _bytes;

  ThreadContext? contextForThread(int threadId) => _contexts[threadId];

  static MinidumpFile parse(String path) {
    final bytes = File(path).readAsBytesSync();
    final bd = ByteData.sublistView(bytes);

    if (bytes.length < 32) {
      throw const FormatException('文件过小, 不是有效 minidump');
    }
    final sig = bd.getUint32(0, Endian.little);
    if (sig != _kSignatureMDMP) {
      throw FormatException(
          '签名不匹配, 不是 minidump (期望 MDMP, 实际 0x${sig.toRadixString(16)})');
    }
    final numStreams = bd.getUint32(8, Endian.little);
    final dirRva = bd.getUint32(12, Endian.little);

    final modules = <MinidumpModule>[];
    final threads = <MinidumpThread>[];
    ExceptionRecord? exception;
    final regions = <_MemRegion>[];

    // 遍历目录
    for (var i = 0; i < numStreams; i++) {
      final entry = dirRva + i * 12;
      if (entry + 12 > bytes.length) break;
      final streamType = bd.getUint32(entry, Endian.little);
      // final dataSize = bd.getUint32(entry + 4, Endian.little); // 未使用
      final rva = bd.getUint32(entry + 8, Endian.little);

      switch (streamType) {
        case streamModuleList:
          _parseModuleList(bytes, bd, rva, modules);
          break;
        case streamThreadList:
          _parseThreadList(bd, rva, threads);
          break;
        case streamException:
          exception = _parseException(bd, rva);
          break;
        case streamMemoryList:
          _parseMemoryList(bd, rva, regions);
          break;
        case streamMemory64List:
          _parseMemory64List(bd, rva, regions);
          break;
      }
    }

    // 解析每个线程的 Context (取需要的寄存器)
    // 注: 复刻 python 行为, 崩溃线程也使用线程列表里的 ContextObject,
    //     而非异常流的 context (两者可能不同).
    final contexts = <int, ThreadContext>{};
    for (final t in threads) {
      final ctx = _parseContext(bd, t.contextRva, t.contextSize, bytes.length);
      if (ctx != null) contexts[t.threadId] = ctx;
    }

    return MinidumpFile._(
        modules, threads, exception, contexts, bytes, regions);
  }

  static void _parseModuleList(Uint8List bytes, ByteData bd, int rva,
      List<MinidumpModule> out) {
    final count = bd.getUint32(rva, Endian.little);
    var p = rva + 4;
    for (var i = 0; i < count; i++) {
      final base = bd.getUint64(p, Endian.little);
      final size = bd.getUint32(p + 8, Endian.little);
      final nameRva = bd.getUint32(p + 20, Endian.little);
      final name = _readMinidumpString(bytes, bd, nameRva);
      out.add(MinidumpModule(name, base, size));
      p += 108; // sizeof(MINIDUMP_MODULE)
    }
  }

  static void _parseThreadList(ByteData bd, int rva, List<MinidumpThread> out) {
    final count = bd.getUint32(rva, Endian.little);
    var p = rva + 4;
    for (var i = 0; i < count; i++) {
      final threadId = bd.getUint32(p, Endian.little);
      // +4 SuspendCount, +8 PriorityClass, +12 Priority, +16 Teb(8)
      final stackStart = bd.getUint64(p + 24, Endian.little);
      final stackDataSize = bd.getUint32(p + 32, Endian.little);
      final stackRva = bd.getUint32(p + 36, Endian.little);
      final ctxSize = bd.getUint32(p + 40, Endian.little);
      final ctxRva = bd.getUint32(p + 44, Endian.little);
      out.add(MinidumpThread(
          threadId, stackStart, stackDataSize, stackRva, ctxRva, ctxSize));
      p += 48; // sizeof(MINIDUMP_THREAD)
    }
  }

  static ExceptionRecord _parseException(ByteData bd, int rva) {
    final threadId = bd.getUint32(rva, Endian.little);
    // +4 __alignment
    final code = bd.getUint32(rva + 8, Endian.little);
    // +12 ExceptionFlags, +16 ExceptionRecord(8)
    final address = bd.getUint64(rva + 24, Endian.little);
    final numParams = bd.getUint32(rva + 32, Endian.little);
    // +36 __unusedAlignment, ExceptionInformation[15] 从 +40 起
    final info = <int>[];
    final n = numParams > 15 ? 15 : numParams;
    for (var i = 0; i < n; i++) {
      info.add(bd.getUint64(rva + 40 + i * 8, Endian.little));
    }
    return ExceptionRecord(threadId, code, address, info);
  }

  static void _parseMemoryList(ByteData bd, int rva, List<_MemRegion> out) {
    final count = bd.getUint32(rva, Endian.little);
    var p = rva + 4;
    for (var i = 0; i < count; i++) {
      final start = bd.getUint64(p, Endian.little);
      final dataSize = bd.getUint32(p + 8, Endian.little);
      final memRva = bd.getUint32(p + 12, Endian.little);
      out.add(_MemRegion(start, dataSize, memRva));
      p += 16; // sizeof(MINIDUMP_MEMORY_DESCRIPTOR)
    }
  }

  static void _parseMemory64List(ByteData bd, int rva, List<_MemRegion> out) {
    final count = bd.getUint64(rva, Endian.little);
    final baseRva = bd.getUint64(rva + 8, Endian.little);
    var p = rva + 16;
    var fileOff = baseRva;
    for (var i = 0; i < count; i++) {
      final start = bd.getUint64(p, Endian.little);
      final dataSize = bd.getUint64(p + 8, Endian.little);
      out.add(_MemRegion(start, dataSize, fileOff));
      fileOff += dataSize;
      p += 16; // sizeof(MINIDUMP_MEMORY_DESCRIPTOR64)
    }
  }

  static ThreadContext? _parseContext(
      ByteData bd, int rva, int size, int total) {
    if (rva <= 0 || rva + 0x100 > total) return null;
    final regs = <String, int>{};
    _ctxOffsets.forEach((name, off) {
      if (rva + off + 8 <= total) {
        regs[name] = bd.getUint64(rva + off, Endian.little);
      }
    });
    return ThreadContext(regs);
  }

  /// 读取 MINIDUMP_STRING (UTF-16LE), 返回 Dart 字符串.
  static String _readMinidumpString(Uint8List bytes, ByteData bd, int rva) {
    if (rva <= 0 || rva + 4 > bytes.length) return '';
    final lenBytes = bd.getUint32(rva, Endian.little);
    final start = rva + 4;
    final units = <int>[];
    var p = start;
    final end = start + lenBytes;
    while (p + 1 < bytes.length && p < end) {
      final cu = bd.getUint16(p, Endian.little);
      if (cu == 0) break;
      units.add(cu);
      p += 2;
    }
    return String.fromCharCodes(units);
  }
}

/// 取路径的文件名部分 (等价 os.path.basename), 兼容 / 与 \\.
String basename(String path) {
  var idx = -1;
  for (var i = path.length - 1; i >= 0; i--) {
    final c = path[i];
    if (c == '/' || c == '\\') {
      idx = i;
      break;
    }
  }
  return idx >= 0 ? path.substring(idx + 1) : path;
}
