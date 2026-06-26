import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'log_service.dart';

// ignore_for_file: non_constant_identifier_names, constant_identifier_names

/// Windows API 绑定，避免依赖不同版本的 win32 包导致的不兼容问题
final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _CreateToolhelp32Snapshot = _kernel32.lookupFunction<
    Pointer<Void> Function(Uint32, Uint32),
    Pointer<Void> Function(int, int)>('CreateToolhelp32Snapshot');

final _Process32FirstW = _kernel32.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<_PROCESSENTRY32W>),
    int Function(Pointer<Void>, Pointer<_PROCESSENTRY32W>)>('Process32FirstW');

final _Process32NextW = _kernel32.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<_PROCESSENTRY32W>),
    int Function(Pointer<Void>, Pointer<_PROCESSENTRY32W>)>('Process32NextW');

final _CloseHandle = _kernel32.lookupFunction<
    Int32 Function(Pointer<Void>),
    int Function(Pointer<Void>)>('CloseHandle');

const _TH32CS_SNAPPROCESS = 0x00000002;

base class _PROCESSENTRY32W extends Struct {
  @Uint32()
  external int dwSize;

  @Uint32()
  external int cntUsage;

  @Uint32()
  external int th32ProcessID;

  @IntPtr()
  external int th32DefaultHeapID;

  @Uint32()
  external int th32ModuleID;

  @Uint32()
  external int cntThreads;

  @Uint32()
  external int th32ParentProcessID;

  @Int32()
  external int pcPriClassBase;

  @Uint32()
  external int dwFlags;

  @Array(260)
  external Array<Uint16> szExeFile;
}

final _OpenProcess = _kernel32.lookupFunction<
    Pointer<Void> Function(Uint32, Int32, Uint32),
    Pointer<Void> Function(int, int, int)>('OpenProcess');

final _QueryFullProcessImageNameW = _kernel32.lookupFunction<
    Int32 Function(Pointer<Void>, Uint32, Pointer<Uint16>, Pointer<Uint32>),
    int Function(Pointer<Void>, int, Pointer<Uint16>, Pointer<Uint32>)>('QueryFullProcessImageNameW');

const _PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

class NativeProcessUtils {
  /// 使用 Windows Native API 高效/高权限穿透检测进程是否运行
  /// [processNames] 需要检测的进程名列表（忽略大小写，例如 ['cs2.exe', 'csgo.exe']）
  static bool isAnyProcessRunning(List<String> processNames) {
    final lowerNames = processNames.map((e) => e.toLowerCase()).toSet();
    
    final hSnapshot = _CreateToolhelp32Snapshot(_TH32CS_SNAPPROCESS, 0);
    // 判断无效句柄 INVALID_HANDLE_VALUE
    if (hSnapshot.address == 0xFFFFFFFFFFFFFFFF || hSnapshot.address == 0xFFFFFFFF || hSnapshot.address == 0) {
      LogService.e('无法获取系统进程快照 (hSnapshot=${hSnapshot.address})');
      return false;
    }

    final pe32 = calloc<_PROCESSENTRY32W>();
    pe32.ref.dwSize = sizeOf<_PROCESSENTRY32W>();

    try {
      var result = _Process32FirstW(hSnapshot, pe32);
      while (result != 0) {
        final chars = <int>[];
        for (int i = 0; i < 260; i++) {
          final char = pe32.ref.szExeFile[i];
          if (char == 0) break;
          chars.add(char);
        }
        
        final currentProcessName = String.fromCharCodes(chars).toLowerCase();
        if (lowerNames.contains(currentProcessName)) {
          return true;
        }

        result = _Process32NextW(hSnapshot, pe32);
      }
    } catch (e) {
      LogService.e('枚举 Native 进程失败', e);
    } finally {
      calloc.free(pe32);
      _CloseHandle(hSnapshot);
    }
    
    return false;
  }

  /// 获取指定进程名的完整可执行文件路径
  /// [processName] 进程名（如 'steam.exe'）
  static String? getProcessExecutablePath(String processName) {
    final targetName = processName.toLowerCase();
    final hSnapshot = _CreateToolhelp32Snapshot(_TH32CS_SNAPPROCESS, 0);
    
    if (hSnapshot.address == 0xFFFFFFFFFFFFFFFF || hSnapshot.address == 0xFFFFFFFF || hSnapshot.address == 0) {
      return null;
    }

    final pe32 = calloc<_PROCESSENTRY32W>();
    pe32.ref.dwSize = sizeOf<_PROCESSENTRY32W>();
    String? foundPath;

    try {
      var result = _Process32FirstW(hSnapshot, pe32);
      while (result != 0) {
        final chars = <int>[];
        for (int i = 0; i < 260; i++) {
          final char = pe32.ref.szExeFile[i];
          if (char == 0) break;
          chars.add(char);
        }
        
        final currentProcessName = String.fromCharCodes(chars).toLowerCase();
        if (currentProcessName == targetName) {
          // 找到了进程，尝试获取其完整路径
          final hProcess = _OpenProcess(_PROCESS_QUERY_LIMITED_INFORMATION, 0, pe32.ref.th32ProcessID);
          if (hProcess.address != 0) {
            final buffer = calloc<Uint16>(1024);
            final sizePtr = calloc<Uint32>();
            sizePtr.value = 1024;
            
            final queryResult = _QueryFullProcessImageNameW(hProcess, 0, buffer, sizePtr);
            if (queryResult != 0) {
              final pathChars = <int>[];
              for (int i = 0; i < sizePtr.value; i++) {
                pathChars.add(buffer[i]);
              }
              foundPath = String.fromCharCodes(pathChars);
            }
            
            calloc.free(buffer);
            calloc.free(sizePtr);
            _CloseHandle(hProcess);
            
            if (foundPath != null) {
              break;
            }
          }
        }

        result = _Process32NextW(hSnapshot, pe32);
      }
    } catch (e) {
      LogService.e('获取 Native 进程路径失败', e);
    } finally {
      calloc.free(pe32);
      _CloseHandle(hSnapshot);
    }
    
    return foundPath;
  }
}
