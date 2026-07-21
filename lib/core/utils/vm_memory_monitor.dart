import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'app_directory_service.dart';

/// 内存刺客雷达：自动抓取 VM 快照并生成对象排行榜
class VmMemoryMonitor {
  static Timer? _timer;
  static bool _isRunning = false;

  /// 启动内存监控
  /// [interval] 抓取快照的频率，默认 30 秒
  /// [topN] 显示前 N 个对象
  static void start({
    Duration interval = const Duration(seconds: 30),
    int topN = 20,
  }) {
    if (_isRunning) return;
    _isRunning = true;

    // 延迟 5 秒启动，防止在 App 首屏启动时占用过多资源卡顿
    Future.delayed(const Duration(seconds: 5), () {
      _timer = Timer.periodic(interval, (_) {
        _takeSnapshot(topN);
      });
      // 启动时立即拉取一次作为基线
      _takeSnapshot(topN);
    });
  }

  /// 停止内存监控
  static void stop() {
    _timer?.cancel();
    _isRunning = false;
  }

  static Future<void> _takeSnapshot(int topN) async {
    try {
      // 1. 获取本地 VM 服务的 URI
      final info = await developer.Service.getInfo();
      final uri = info.serverWebSocketUri;
      if (uri == null) {
        debugPrint('[VmMemoryMonitor] 无法获取 VM Service URI，请确保在 Debug/Profile 模式下运行');
        return;
      }

      // 2. 连接到 VM 服务
      final vmService = await vmServiceConnectUri(uri.toString());
      final vm = await vmService.getVM();

      // 3. 找到 Main Isolate (UI 线程)
      final mainIsolate = vm.isolates?.firstWhere(
        (i) => i.name == 'main',
        orElse: () => vm.isolates!.first,
      );

      if (mainIsolate == null || mainIsolate.id == null) {
        vmService.dispose();
        return;
      }

      // 4. 强行触发一次 GC，确保剔除那些已经被废弃但还没回收的垃圾对象
      await vmService.getAllocationProfile(mainIsolate.id!, gc: true);

      // 5. 拉取内存分配快照
      final profile = await vmService.getAllocationProfile(mainIsolate.id!);
      final members = profile.members;
      
      if (members == null) {
        vmService.dispose();
        return;
      }

      // 6. 根据实例数量降序排列
      members.sort((a, b) {
        final aCount = a.instancesCurrent ?? 0;
        final bCount = b.instancesCurrent ?? 0;
        return bCount.compareTo(aCount);
      });

      // 7. 格式化排行榜
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      final nowStr = dateFormat.format(DateTime.now());
      
      final buffer = StringBuffer();
      buffer.writeln('=========================================');
      buffer.writeln('[$nowStr] 内存对象排行榜 (Top $topN)');
      buffer.writeln('=========================================');

      int count = 0;
      for (final stat in members) {
        if (count >= topN) break;
        final className = stat.classRef?.name ?? 'Unknown';
        
        // 过滤掉底层的基础数据类型，让业务对象的泄露更明显
        if (className == 'int' || 
            className == 'double' || 
            className == 'bool' || 
            className == 'Null' ||
            className == '_Smi' ||
            className == '_Mint') {
          continue;
        }

        final instances = stat.instancesCurrent ?? 0;
        final bytes = stat.bytesCurrent ?? 0;
        final mb = (bytes / (1024 * 1024)).toStringAsFixed(3);
        
        buffer.writeln('${count + 1}. $className: $instances instances ($mb MB)');
        count++;
      }
      buffer.writeln(''); // 空行分隔

      // 8. 写入到单独的日志文件
      await _writeToFile(buffer.toString());

      // 9. 断开连接
      vmService.dispose();
    } catch (e) {
      debugPrint('[VmMemoryMonitor] 抓取内存快照失败: $e');
    }
  }

  static Future<void> _writeToFile(String content) async {
    try {
      final logFilePath = AppDirectoryService.getLogFilePath('memory_monitor.log');
      final file = File(logFilePath);
      
      // 如果文件不存在则自动创建，否则追加内容
      await file.writeAsString(content, mode: FileMode.append);
      debugPrint('[VmMemoryMonitor] 已成功写入内存快照到 memory_monitor.log');
    } catch (e) {
      debugPrint('[VmMemoryMonitor] 写入文件失败: $e');
    }
  }
}
