import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:http/http.dart' as http;

import '../utils/app_directory_service.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';
import '../utils/platform_utils.dart';

/// TTS 模型区域标签
enum TtsModelRegion {
  /// 国内可访问
  domestic,

  /// 国外源
  international,
}

/// TTS 模型信息
class TtsModelInfo {
  final String id;
  final String name;
  final String description;
  final String language;
  final String downloadUrl;
  /// 加速下载地址（国内镜像），为空则不支持加速
  final String? acceleratedUrl;
  final String dirName;
  final String modelFile;
  final String lexicon;
  final String tokens;
  final TtsModelRegion region;
  final String estimatedSize;

  const TtsModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.language,
    required this.downloadUrl,
    this.acceleratedUrl,
    required this.dirName,
    required this.modelFile,
    required this.lexicon,
    required this.tokens,
    required this.region,
    required this.estimatedSize,
  });
}

/// TTS 下载状态
enum TtsDownloadStatus { idle, downloading, extracting, completed, failed }

/// TTS 下载进度
class TtsDownloadProgress {
  final TtsDownloadStatus status;
  final double progress; // 0.0 - 1.0
  final String? error;

  const TtsDownloadProgress({
    this.status = TtsDownloadStatus.idle,
    this.progress = 0.0,
    this.error,
  });
}

/// 离线 TTS 服务（单例）
///
/// 使用 sherpa-onnx 引擎，支持离线中文语音合成。
/// 模型按需下载到本地，不增加应用安装体积。
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  static const String _keyTtsVolume = 'tts_volume';
  static const String _keyTtsModelDownloaded = 'tts_model_downloaded';
  static const String _keyTtsSpeakerId = 'tts_speaker_id';
  static const String _keyTtsSpeed = 'tts_speed';
  static const String _keyTtsSelectedModel = 'tts_selected_model';

  /// 可用模型列表
  static const List<TtsModelInfo> availableModels = [
    // ====== 国内可访问 ======
    TtsModelInfo(
      id: 'vits-zh-aishell3',
      name: 'AISHELL3 中文',
      description: '中文女声语音合成，发音清晰自然',
      language: '中文',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-aishell3.tar.bz2',
      acceleratedUrl:
          'https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-aishell3.tar.bz2',
      dirName: 'vits-zh-aishell3',
      modelFile: 'vits-aishell3.onnx',
      lexicon: 'lexicon.txt',
      tokens: 'tokens.txt',
      region: TtsModelRegion.domestic,
      estimatedSize: '~35MB',
    ),
    // ====== 国外源 ======
    TtsModelInfo(
      id: 'vits-melo-tts-zh_en',
      name: 'MeloTTS 中英混合',
      description: '支持中英文混读的高质量模型',
      language: '中文/英文',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2',
      acceleratedUrl:
          'https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2',
      dirName: 'vits-melo-tts-zh_en',
      modelFile: 'model.onnx',
      lexicon: 'lexicon.txt',
      tokens: 'tokens.txt',
      region: TtsModelRegion.international,
      estimatedSize: '~50MB',
    ),
    TtsModelInfo(
      id: 'vits-icefall-zh-aishell3',
      name: 'Icefall 中文',
      description: 'Icefall 框架训练的中文模型，音质优秀',
      language: '中文',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-icefall-zh-aishell3.tar.bz2',
      acceleratedUrl:
          'https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-icefall-zh-aishell3.tar.bz2',
      dirName: 'vits-icefall-zh-aishell3',
      modelFile: 'model.onnx',
      lexicon: 'lexicon.txt',
      tokens: 'tokens.txt',
      region: TtsModelRegion.international,
      estimatedSize: '~35MB',
    ),
  ];

  /// 获取当前选中的模型信息
  TtsModelInfo get selectedModelInfo {
    final selectedId =
        StorageUtils.getString(_keyTtsSelectedModel) ?? 'vits-zh-aishell3';
    return availableModels.firstWhere(
      (m) => m.id == selectedId,
      orElse: () => availableModels.first,
    );
  }

  /// 设置选中的模型
  Future<void> selectModel(String modelId) async {
    await StorageUtils.setString(_keyTtsSelectedModel, modelId);
    // 切换模型需要重新初始化
    if (_isInitialized) {
      _tts?.free();
      _tts = null;
      _isInitialized = false;
    }
  }

  /// 检查指定模型是否已下载
  bool isModelDownloadedById(String modelId) {
    return StorageUtils.getBool('${_keyTtsModelDownloaded}_$modelId');
  }

  sherpa_onnx.OfflineTts? _tts;
  double _volume = 0.8;
  int _speakerId = 0;
  double _speed = 1.0;
  bool _isInitialized = false;

  /// 下载进度流
  final _downloadProgressController =
      StreamController<TtsDownloadProgress>.broadcast();
  Stream<TtsDownloadProgress> get downloadProgressStream =>
      _downloadProgressController.stream;

  /// 当前下载状态
  TtsDownloadProgress _currentProgress = const TtsDownloadProgress();

  /// 下载取消标记
  bool _downloadCancelled = false;

  /// 当前音量 (0.0 - 1.0)
  double get volume => _volume;

  /// 当前语速 (0.5 - 2.0)
  double get speed => _speed;

  /// 当前说话人 ID
  int get speakerId => _speakerId;

  /// 当前选中模型是否已下载
  bool get isModelDownloaded => isModelDownloadedById(selectedModelInfo.id);

  /// TTS 引擎是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否可用（模型已下载且，桌面平台）
  bool get isAvailable => isModelDownloaded && PlatformUtils.isDesktopPlatform;

  /// 当前选中的模型ID
  String get selectedModelId => selectedModelInfo.id;

  /// 加载设置（不初始化引擎，节省内存）
  Future<void> loadSettings() async {
    _volume = StorageUtils.getDouble(_keyTtsVolume) ?? 0.8;
    _speakerId = StorageUtils.getInt(_keyTtsSpeakerId) ?? 0;
    _speed = StorageUtils.getDouble(_keyTtsSpeed) ?? 1.0;
    LogService.d(
      '[TTS] 设置已加载: 音量=${(_volume * 100).toInt()}%, '
      '语速=$_speed, 说话人=$_speakerId',
    );
  }

  /// 初始化 TTS 引擎（首次使用时调用）
  Future<bool> initialize() async {
    if (_isInitialized && _tts != null) return true;
    if (!isModelDownloaded) return false;
    if (!PlatformUtils.isDesktopPlatform) return false;

    try {
      final model = selectedModelInfo;
      final modelDir = await _getModelDirectoryFor(model);
      final modelPath = p.join(modelDir.path, model.modelFile);
      final lexiconPath = p.join(modelDir.path, model.lexicon);
      final tokensPath = p.join(modelDir.path, model.tokens);

      // 检查文件是否存在
      if (!File(modelPath).existsSync() || !File(tokensPath).existsSync()) {
        LogService.e('[TTS] 模型文件不完整');
        return false;
      }

      sherpa_onnx.initBindings();

      final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
        model: modelPath,
        lexicon: lexiconPath,
        tokens: tokensPath,
      );

      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        vits: vits,
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );

      final config = sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 2,
      );

      _tts = sherpa_onnx.OfflineTts(config);
      _isInitialized = true;
      LogService.i('[TTS] 引擎初始化成功');
      return true;
    } catch (e) {
      LogService.e('[TTS] 引擎初始化失败', e);
      return false;
    }
  }

  /// 播报地图订阅提醒
  ///
  /// [mapLabel] 地图中文名
  /// [mapName] 地图代码名
  /// [serverName] 服务器名称
  /// [categoryName] 分类名称
  Future<bool> speakMapAlert({
    required String mapLabel,
    required String mapName,
    String? serverName,
    String? categoryName,
  }) async {
    if (_volume <= 0) return false;
    if (!PlatformUtils.isDesktopPlatform) return false;

    // 延迟初始化引擎
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    try {
      // 构建播报文本
      final displayName = mapLabel.isNotEmpty ? mapLabel : mapName;
      String text;
      if (categoryName != null && categoryName.isNotEmpty) {
        text = '$categoryName换图到$displayName';
      } else if (serverName != null && serverName.isNotEmpty) {
        text = '${serverName}换图到$displayName';
      } else {
        text = '订阅的地图$displayName有服务器正在游玩';
      }

      LogService.d('[TTS] 播报: $text');

      // 生成音频
      final audio = _tts!.generate(text: text, sid: _speakerId, speed: _speed);

      if (audio.samples.isEmpty) {
        LogService.e('[TTS] 生成音频为空');
        return false;
      }

      // 使用 audioplayers 或直接写 WAV 文件播放
      await _playAudio(audio.samples, audio.sampleRate);
      return true;
    } catch (e) {
      LogService.e('[TTS] 播报失败', e);
      return false;
    }
  }

  /// 播放音频采样数据
  Future<void> _playAudio(Float32List samples, int sampleRate) async {
    try {
      // 将 Float32 采样数据写入临时 WAV 文件，然后播放
      final tempDir = await getTemporaryDirectory();
      final wavFile = File(p.join(tempDir.path, 'tts_alert.wav'));

      // 音量调整
      final adjustedSamples = Float32List(samples.length);
      for (int i = 0; i < samples.length; i++) {
        adjustedSamples[i] = samples[i] * _volume;
      }

      // 写入 WAV 文件
      final wavData = _createWavData(adjustedSamples, sampleRate);
      await wavFile.writeAsBytes(wavData);

      // 使用系统命令播放 WAV 文件（Windows）
      if (Platform.isWindows) {
        // 使用 PowerShell 播放音频
        await Process.run('powershell', [
          '-c',
          '(New-Object Media.SoundPlayer "${wavFile.path}").PlaySync()',
        ]);
      }
    } catch (e) {
      LogService.e('[TTS] 播放音频失败', e);
    }
  }

  /// 创建 WAV 文件数据
  Uint8List _createWavData(Float32List samples, int sampleRate) {
    final numChannels = 1;
    final bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = samples.length * blockAlign;

    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt subchunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // subchunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    // Write samples (convert Float32 to Int16)
    for (int i = 0; i < samples.length; i++) {
      final sample = (samples[i] * 32767.0).clamp(-32768, 32767).toInt();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  /// 设置音量（支持 0.0 - 3.0，即 0% - 300%）
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 3.0);
    try {
      await StorageUtils.setDouble(_keyTtsVolume, _volume);
      LogService.d('[TTS] 音量已设置: ${(_volume * 100).toInt()}%');
    } catch (e) {
      LogService.e('[TTS] 保存音量设置失败', e);
    }
  }

  /// 设置语速
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    try {
      await StorageUtils.setDouble(_keyTtsSpeed, _speed);
      LogService.d('[TTS] 语速已设置: $_speed');
    } catch (e) {
      LogService.e('[TTS] 保存语速设置失败', e);
    }
  }

  /// 设置说话人 ID
  Future<void> setSpeakerId(int id) async {
    _speakerId = id;
    try {
      await StorageUtils.setInt(_keyTtsSpeakerId, _speakerId);
      LogService.d('[TTS] 说话人已设置: $_speakerId');
    } catch (e) {
      LogService.e('[TTS] 保存说话人设置失败', e);
    }
  }

  /// 测试 TTS 播报
  Future<bool> testSpeak() async {
    return await speakMapAlert(
      mapLabel: '炙热沙城',
      mapName: 'de_dust2',
      categoryName: '休闲服',
    );
  }

  // ======== 模型下载相关 ========

  /// 获取指定模型的存储目录
  Future<Directory> _getModelDirectoryFor(TtsModelInfo model) async {
    final modelDir = Directory(
      p.join(AppDirectoryService.basePath, 'tts_models', model.dirName),
    );
    return modelDir;
  }

  /// 获取当前选中模型的存储目录
  Future<Directory> _getModelDirectory() async {
    return _getModelDirectoryFor(selectedModelInfo);
  }

  /// 在后台线程解压 tar.bz2 文件
  static Future<int> _extractTarBz2InBackground(List<int> bytes, String targetDir) async {
    // 使用 compute 在后台 isolate 执行解压，避免阻塞主线程
    return await compute(_doExtract, {'bytes': bytes, 'targetDir': targetDir});
  }

  /// 实际执行解压的方法（在后台 isolate 中运行）
  static Future<int> _doExtract(Map<String, dynamic> params) async {
    final bytes = params['bytes'] as List<int>;
    final targetDir = params['targetDir'] as String;
    
    // 先解压 bzip2
    final bz2Decoded = BZip2Decoder().decodeBytes(Uint8List.fromList(bytes));
    
    // 再解压 tar
    final tarArchive = TarDecoder().decodeBytes(bz2Decoded);
    
    int fileCount = 0;
    // 提取文件到目标目录
    for (final file in tarArchive.files) {
      final filePath = p.join(targetDir, file.name);
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
        fileCount++;
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
    
    return fileCount;
  }

  /// 下载 TTS 模型
  ///
  /// [modelId] 指定要下载的模型 ID，为空则下载当前选中的模型
  /// [useAcceleration] 是否使用加速下载地址（国内镜像）
  Future<bool> downloadModel({String? modelId, bool useAcceleration = false}) async {
    final model = modelId != null
        ? availableModels.firstWhere(
            (m) => m.id == modelId,
            orElse: () => selectedModelInfo,
          )
        : selectedModelInfo;
    if (isModelDownloadedById(model.id)) return true;

    _downloadCancelled = false;
    _updateDownloadProgress(
      const TtsDownloadProgress(
        status: TtsDownloadStatus.downloading,
        progress: 0.0,
      ),
    );

    try {
      // 选择下载地址：优先使用加速地址（如果启用且可用）
      final downloadUrl = (useAcceleration && model.acceleratedUrl != null)
          ? model.acceleratedUrl!
          : model.downloadUrl;
      
      LogService.i('[TTS] 开始下载模型: $downloadUrl${useAcceleration ? " (加速)" : ""}');

      // 下载文件
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in response.stream) {
        if (_downloadCancelled) {
          client.close();
          _updateDownloadProgress(
            const TtsDownloadProgress(status: TtsDownloadStatus.idle),
          );
          LogService.i('[TTS] 下载已取消');
          return false;
        }

        bytes.addAll(chunk);
        received += chunk.length;

        if (contentLength > 0) {
          _updateDownloadProgress(
            TtsDownloadProgress(
              status: TtsDownloadStatus.downloading,
              progress: received / contentLength,
            ),
          );
        }
      }

      client.close();

      if (_downloadCancelled) return false;

      // 解压到模型目录
      _updateDownloadProgress(
        const TtsDownloadProgress(
          status: TtsDownloadStatus.extracting,
          progress: 0.9,
        ),
      );

      final modelsDir = Directory(p.join(AppDirectoryService.basePath, 'tts_models'));
      if (!modelsDir.existsSync()) {
        modelsDir.createSync(recursive: true);
      }

      // 使用 archive 包解压 tar.bz2（跨平台支持）
      LogService.d('[TTS] 开始解压 tar.bz2 文件...');
      
      // 在后台线程解压以避免 UI 卡顿
      final extractedFiles = await _extractTarBz2InBackground(bytes, modelsDir.path);
      LogService.d('[TTS] 文件提取完成，共 $extractedFiles 个文件');

      // 验证模型文件
      final modelDir = await _getModelDirectoryFor(model);
      
      LogService.d('[TTS] 验证模型目录: ${modelDir.path}');
      
      // 列出目录内容帮助调试
      if (modelDir.existsSync()) {
        final files = modelDir.listSync(recursive: true);
        LogService.d('[TTS] 目录内容 (${files.length} 个文件):');
        for (final f in files) {
          LogService.d('[TTS]   - ${f.path}');
        }
      } else {
        LogService.d('[TTS] 模型目录不存在!');
        // 列出 modelsDir 的内容
        final allFiles = modelsDir.listSync(recursive: true);
        LogService.d('[TTS] tts_models 目录内容:');
        for (final f in allFiles) {
          LogService.d('[TTS]   - ${f.path}');
        }
      }

      // 尝试查找 .onnx 文件
      File? foundModelFile;
      File? foundTokensFile;
      
      if (modelDir.existsSync()) {
        final files = modelDir.listSync(recursive: true);
        for (final f in files) {
          if (f is File) {
            final name = p.basename(f.path);
            if (name.endsWith('.onnx')) {
              foundModelFile = f;
              LogService.d('[TTS] 找到模型文件: ${f.path}');
            }
            if (name == 'tokens.txt') {
              foundTokensFile = f;
              LogService.d('[TTS] 找到 tokens 文件: ${f.path}');
            }
          }
        }
      }

      final modelFile = File(p.join(modelDir.path, model.modelFile));
      final tokensFile = File(p.join(modelDir.path, model.tokens));

      LogService.d('[TTS] 期望模型文件: ${modelFile.path}, 存在: ${modelFile.existsSync()}');
      LogService.d('[TTS] 期望 tokens 文件: ${tokensFile.path}, 存在: ${tokensFile.existsSync()}');

      if (!modelFile.existsSync() || !tokensFile.existsSync()) {
        // 如果找到了 .onnx 文件但名字不对，输出提示
        if (foundModelFile != null && !modelFile.existsSync()) {
          LogService.w('[TTS] 模型文件名不匹配! 期望: ${model.modelFile}, 实际: ${p.basename(foundModelFile.path)}');
        }
        throw Exception('模型文件解压不完整: model=${modelFile.existsSync()}, tokens=${tokensFile.existsSync()}');
      }

      // 标记下载完成（per-model key）
      await StorageUtils.setBool('${_keyTtsModelDownloaded}_${model.id}', true);

      _updateDownloadProgress(
        const TtsDownloadProgress(
          status: TtsDownloadStatus.completed,
          progress: 1.0,
        ),
      );

      LogService.i('[TTS] 模型下载完成');
      return true;
    } catch (e) {
      LogService.e('[TTS] 模型下载失败', e);
      _updateDownloadProgress(
        TtsDownloadProgress(
          status: TtsDownloadStatus.failed,
          error: e.toString(),
        ),
      );
      return false;
    }
  }

  /// 取消下载
  void cancelDownload() {
    _downloadCancelled = true;
  }

  /// 删除已下载的模型
  Future<void> deleteModel({String? modelId}) async {
    try {
      final model = modelId != null
          ? availableModels.firstWhere(
              (m) => m.id == modelId,
              orElse: () => selectedModelInfo,
            )
          : selectedModelInfo;

      // 如果删除的是当前使用的模型，释放引擎
      if (model.id == selectedModelInfo.id) {
        _tts?.free();
        _tts = null;
        _isInitialized = false;
      }

      // 删除模型文件
      final modelDir = await _getModelDirectoryFor(model);
      if (modelDir.existsSync()) {
        modelDir.deleteSync(recursive: true);
      }

      // 清除标记
      await StorageUtils.setBool(
        '${_keyTtsModelDownloaded}_${model.id}',
        false,
      );

      _updateDownloadProgress(
        const TtsDownloadProgress(status: TtsDownloadStatus.idle),
      );

      LogService.i('[TTS] 模型已删除: ${model.id}');
    } catch (e) {
      LogService.e('[TTS] 删除模型失败', e);
    }
  }

  /// 导入本地模型
  Future<bool> importLocalModel({
    required String sourcePath,
    required String modelId,
  }) async {
    try {
      final model = availableModels.firstWhere(
        (m) => m.id == modelId,
        orElse: () => throw Exception('未知模型ID: $modelId'),
      );

      final sourceDir = Directory(sourcePath);
      if (!sourceDir.existsSync()) {
        throw Exception('源目录不存在: $sourcePath');
      }

      final targetDir = await _getModelDirectoryFor(model);
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      // 复制文件
      await for (final entity in sourceDir.list()) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          await entity.copy(p.join(targetDir.path, fileName));
        }
      }

      // 验证
      final modelFile = File(p.join(targetDir.path, model.modelFile));
      final tokensFile = File(p.join(targetDir.path, model.tokens));
      if (!modelFile.existsSync() || !tokensFile.existsSync()) {
        throw Exception('导入的模型文件不完整');
      }

      await StorageUtils.setBool('${_keyTtsModelDownloaded}_${model.id}', true);
      LogService.i('[TTS] 本地模型导入成功: ${model.id}');
      return true;
    } catch (e) {
      LogService.e('[TTS] 导入本地模型失败', e);
      return false;
    }
  }

  void _updateDownloadProgress(TtsDownloadProgress progress) {
    _currentProgress = progress;
    if (!_downloadProgressController.isClosed) {
      _downloadProgressController.add(progress);
    }
  }

  /// 获取当前下载进度
  TtsDownloadProgress get currentProgress => _currentProgress;

  /// 释放资源
  void dispose() {
    try {
      _tts?.free();
      _tts = null;
      _isInitialized = false;
      _downloadProgressController.close();
      LogService.i('[TTS] 服务已释放');
    } catch (e) {
      LogService.e('[TTS] 释放服务失败', e);
    }
  }
}
