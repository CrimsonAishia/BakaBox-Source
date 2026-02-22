import 'dart:async';
import 'dart:io';

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

/// TTS 模型类型
enum TtsModelType {
  /// VITS 模型
  vits,
  /// Kokoro 模型
  kokoro,
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
  final String? lexicon;
  final String tokens;

  /// espeak-ng 数据目录（Piper 模型需要）
  final String? dataDir;
  
  /// Kokoro 模型专用：voices.bin 文件
  final String? voicesFile;
  
  /// 模型类型
  final TtsModelType modelType;
  
  /// 说话人数量（多音色模型）
  final int speakerCount;
  
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
    this.lexicon,
    required this.tokens,
    this.dataDir,
    this.voicesFile,
    this.modelType = TtsModelType.vits,
    this.speakerCount = 1,
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

  /// 可用模型列表（仅支持中英文混合的模型）
  static const List<TtsModelInfo> availableModels = [
    // ====== MeloTTS 系列（官方支持中英文混合） ======
    TtsModelInfo(
      id: 'vits-melo-tts-zh_en',
      name: 'MeloTTS 中英混合',
      description: '官方支持中英文混读的高质量模型，推荐使用',
      language: '中文/英文',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2',
      acceleratedUrl:
          'https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2',
      dirName: 'vits-melo-tts-zh_en',
      modelFile: 'model.onnx',
      lexicon: 'lexicon.txt',
      tokens: 'tokens.txt',
      modelType: TtsModelType.vits,
      speakerCount: 1,
      region: TtsModelRegion.domestic,
      estimatedSize: '~170MB',
    ),
    // ====== Kokoro 系列（支持中英文混合，多音色） ======
    TtsModelInfo(
      id: 'kokoro-multi-lang-v1_0',
      name: 'Kokoro 中英混合 (53人)',
      description: '53种音色，支持中英文混读，音质优秀',
      language: '中文/英文',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2',
      acceleratedUrl:
          'https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2',
      dirName: 'kokoro-multi-lang-v1_0',
      modelFile: 'model.onnx',
      tokens: 'tokens.txt',
      dataDir: 'espeak-ng-data',
      voicesFile: 'voices.bin',
      modelType: TtsModelType.kokoro,
      speakerCount: 53,
      region: TtsModelRegion.domestic,
      estimatedSize: '~350MB',
    ),
    TtsModelInfo(
      id: 'kokoro-multi-lang-v1_1',
      name: 'Kokoro 中英混合 v1.1 (103人)',
      description: '103种音色，更多中文音色，最新版本',
      language: '中文/英文',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2',
      acceleratedUrl:
          'https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2',
      dirName: 'kokoro-multi-lang-v1_1',
      modelFile: 'model.onnx',
      tokens: 'tokens.txt',
      dataDir: 'espeak-ng-data',
      voicesFile: 'voices.bin',
      modelType: TtsModelType.kokoro,
      speakerCount: 103,
      region: TtsModelRegion.domestic,
      estimatedSize: '~380MB',
    ),
  ];

  /// 获取当前选中的模型信息
  TtsModelInfo get selectedModelInfo {
    final selectedId =
        StorageUtils.getString(_keyTtsSelectedModel) ?? 'vits-melo-tts-zh_en';
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
      final tokensPath = p.join(modelDir.path, model.tokens);

      // 检查文件是否存在
      if (!File(modelPath).existsSync() || !File(tokensPath).existsSync()) {
        LogService.e('[TTS] 模型文件不完整');
        return false;
      }

      sherpa_onnx.initBindings();

      sherpa_onnx.OfflineTtsModelConfig modelConfig;

      if (model.modelType == TtsModelType.kokoro) {
        // Kokoro 模型配置
        final voicesPath = model.voicesFile != null
            ? p.join(modelDir.path, model.voicesFile!)
            : '';
        final dataDirPath = model.dataDir != null
            ? p.join(modelDir.path, model.dataDir!)
            : '';
        // Kokoro 模型需要 lexicon 文件（中英文）
        final lexiconZhPath = p.join(modelDir.path, 'lexicon-zh.txt');
        final lexiconEnPath = p.join(modelDir.path, 'lexicon-us-en.txt');
        String lexiconPath = '';
        if (File(lexiconEnPath).existsSync() && File(lexiconZhPath).existsSync()) {
          lexiconPath = '$lexiconEnPath,$lexiconZhPath';
        }

        final kokoro = sherpa_onnx.OfflineTtsKokoroModelConfig(
          model: modelPath,
          voices: voicesPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
          lexicon: lexiconPath,
        );

        modelConfig = sherpa_onnx.OfflineTtsModelConfig(
          kokoro: kokoro,
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        );
      } else {
        // VITS 模型配置
        final lexiconPath = model.lexicon != null
            ? p.join(modelDir.path, model.lexicon!)
            : '';
        final dataDirPath = model.dataDir != null
            ? p.join(modelDir.path, model.dataDir!)
            : '';

        final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
          model: modelPath,
          lexicon: lexiconPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
        );

        modelConfig = sherpa_onnx.OfflineTtsModelConfig(
          vits: vits,
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        );
      }

      final config = sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 2,
      );

      _tts = sherpa_onnx.OfflineTts(config);
      _isInitialized = true;
      LogService.i('[TTS] 引擎初始化成功 (${model.modelType.name})');
      return true;
    } catch (e) {
      LogService.e('[TTS] 引擎初始化失败', e);
      return false;
    }
  }

  /// 清理文本中的特殊字符，避免 TTS 截断
  /// 同时将数字转换为中文读法
  String _cleanTextForTts(String text) {
    // 将 #数字 转换为 "数字服"（如 #5 → 5服 → 五服）
    var cleaned = text.replaceAllMapped(
      RegExp(r'[#＃](\d+)'),
      (match) => '${match.group(1)}服',
    );

    // 移除方括号等特殊字符（包括剩余的 # 符号）
    cleaned = cleaned
        .replaceAll(RegExp(r'[\[\]【】\(\)（）<>《》#＃]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 将数字转换为中文
    cleaned = _convertNumbersToChinese(cleaned);

    return cleaned;
  }

  /// 清理地图名中的数字，转换为中文读法
  String _cleanMapNameForTts(String mapName) {
    // 将地图名中的数字转换为中文
    return _convertNumbersToChinese(mapName);
  }

  /// 将文本中的数字转换为中文读法
  String _convertNumbersToChinese(String text) {
    const digitMap = {
      '0': '零',
      '1': '一',
      '2': '二',
      '3': '三',
      '4': '四',
      '5': '五',
      '6': '六',
      '7': '七',
      '8': '八',
      '9': '九',
    };

    // 逐字符替换数字
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(digitMap[char] ?? char);
    }
    return buffer.toString();
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

    try {
      // 构建播报文本
      // 地图名也需要数字转换
      final cleanedMapLabel = mapLabel.isNotEmpty 
          ? _cleanMapNameForTts(mapLabel) 
          : _cleanMapNameForTts(mapName);
      // 清理服务器名中的特殊字符，避免 TTS 截断
      final cleanServerName = serverName != null
          ? _cleanTextForTts(serverName)
          : null;
      String text;
      if (cleanServerName != null && cleanServerName.isNotEmpty) {
        text = '$cleanServerName更换地图至$cleanedMapLabel';
      } else if (categoryName != null && categoryName.isNotEmpty) {
        text = '$categoryName更换地图至$cleanedMapLabel';
      } else {
        text = '订阅的地图$cleanedMapLabel有服务器正在游玩';
      }

      LogService.d('[TTS] 播报: $text');

      // 使用异步方法在后台生成并播放
      return await speakAsync(text: text);
    } catch (e) {
      LogService.e('[TTS] 播报失败', e);
      return false;
    }
  }

  /// 设置音量（支持 0.0 - 5.0，即 0% - 500%）
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 5.0);
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

  /// 测试 TTS 播报（异步执行，不阻塞主线程）
  Future<bool> testSpeak() async {
    return await testSpeakWithCallback();
  }

  /// 测试 TTS 播报（带回调，用于更新 UI 状态）
  Future<bool> testSpeakWithCallback({
    VoidCallback? onPlayingStart,
  }) async {
    return await speakMapAlertWithCallback(
      mapLabel: '炙热沙城2',
      mapName: 'de_dust2',
      serverName: '【僵尸乐园】 CS2 ZE #5',
      onPlayingStart: onPlayingStart,
    );
  }

  /// 播报地图订阅提醒（带回调）
  Future<bool> speakMapAlertWithCallback({
    required String mapLabel,
    required String mapName,
    String? serverName,
    String? categoryName,
    VoidCallback? onPlayingStart,
  }) async {
    if (_volume <= 0) return false;
    if (!PlatformUtils.isDesktopPlatform) return false;

    try {
      // 构建播报文本
      final cleanedMapLabel = mapLabel.isNotEmpty 
          ? _cleanMapNameForTts(mapLabel) 
          : _cleanMapNameForTts(mapName);
      final cleanServerName = serverName != null
          ? _cleanTextForTts(serverName)
          : null;
      String text;
      if (cleanServerName != null && cleanServerName.isNotEmpty) {
        text = '$cleanServerName更换地图至$cleanedMapLabel';
      } else if (categoryName != null && categoryName.isNotEmpty) {
        text = '$categoryName更换地图至$cleanedMapLabel';
      } else {
        text = '订阅的地图$cleanedMapLabel有服务器正在游玩';
      }

      LogService.d('[TTS] 播报: $text');

      return await speakAsyncWithCallback(text: text, onPlayingStart: onPlayingStart);
    } catch (e) {
      LogService.e('[TTS] 播报失败', e);
      return false;
    }
  }

  /// 异步播报（带回调，在后台 isolate 中生成音频，主线程只负责播放）
  Future<bool> speakAsyncWithCallback({
    required String text,
    VoidCallback? onPlayingStart,
  }) async {
    if (_volume <= 0) return false;
    if (!PlatformUtils.isDesktopPlatform) return false;
    if (!isModelDownloaded) return false;

    try {
      final model = selectedModelInfo;
      final modelDir = await _getModelDirectoryFor(model);
      final modelPath = p.join(modelDir.path, model.modelFile);
      final tokensPath = p.join(modelDir.path, model.tokens);
      final dataDirPath = model.dataDir != null
          ? p.join(modelDir.path, model.dataDir!)
          : '';

      if (!File(modelPath).existsSync() || !File(tokensPath).existsSync()) {
        LogService.e('[TTS] 模型文件不完整');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(tempDir.path, 'tts_output_${DateTime.now().millisecondsSinceEpoch}.wav');

      LogService.d('[TTS] 开始在后台生成音频: $text');

      // 准备参数
      final params = <String, dynamic>{
        'modelPath': modelPath,
        'tokensPath': tokensPath,
        'dataDirPath': dataDirPath,
        'text': text,
        'speakerId': _speakerId,
        'speed': _speed,
        'volume': _volume,
        'outputPath': outputPath,
        'modelType': model.modelType.name,
      };

      // 根据模型类型添加额外参数
      if (model.modelType == TtsModelType.kokoro) {
        params['voicesPath'] = model.voicesFile != null
            ? p.join(modelDir.path, model.voicesFile!)
            : '';
        // Kokoro 模型的 lexicon 路径
        final lexiconZhPath = p.join(modelDir.path, 'lexicon-zh.txt');
        final lexiconEnPath = p.join(modelDir.path, 'lexicon-us-en.txt');
        if (File(lexiconEnPath).existsSync() && File(lexiconZhPath).existsSync()) {
          params['lexiconPath'] = '$lexiconEnPath,$lexiconZhPath';
        } else {
          params['lexiconPath'] = '';
        }
      } else {
        params['lexiconPath'] = model.lexicon != null
            ? p.join(modelDir.path, model.lexicon!)
            : '';
      }

      // 在后台 isolate 中生成音频
      final wavPath = await compute(_generateTtsInIsolate, params);

      if (wavPath == null) {
        LogService.e('[TTS] 后台生成音频失败');
        return false;
      }

      // 通知开始播放
      onPlayingStart?.call();

      // 主线程播放音频
      if (Platform.isWindows) {
        await Process.run('powershell', [
          '-c',
          '(New-Object Media.SoundPlayer "$wavPath").PlaySync()',
        ]);
      }

      // 清理临时文件
      try {
        await File(wavPath).delete();
      } catch (_) {}

      return true;
    } catch (e) {
      LogService.e('[TTS] 异步播报失败', e);
      return false;
    }
  }

  /// 在后台 isolate 中生成 TTS 音频并保存到文件
  /// 返回生成的 WAV 文件路径，失败返回 null
  static Future<String?> _generateTtsInIsolate(Map<String, dynamic> params) async {
    try {
      final modelPath = params['modelPath'] as String;
      final lexiconPath = params['lexiconPath'] as String;
      final tokensPath = params['tokensPath'] as String;
      final dataDirPath = params['dataDirPath'] as String;
      final text = params['text'] as String;
      final speakerId = params['speakerId'] as int;
      final speed = params['speed'] as double;
      final volume = params['volume'] as double;
      final outputPath = params['outputPath'] as String;
      final modelType = params['modelType'] as String;

      // 在 isolate 中初始化 TTS 引擎
      sherpa_onnx.initBindings();

      sherpa_onnx.OfflineTtsModelConfig modelConfig;

      if (modelType == 'kokoro') {
        // Kokoro 模型配置
        final voicesPath = params['voicesPath'] as String? ?? '';

        final kokoro = sherpa_onnx.OfflineTtsKokoroModelConfig(
          model: modelPath,
          voices: voicesPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
          lexicon: lexiconPath,
        );

        modelConfig = sherpa_onnx.OfflineTtsModelConfig(
          kokoro: kokoro,
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        );
      } else {
        // VITS 模型配置
        final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
          model: modelPath,
          lexicon: lexiconPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
        );

        modelConfig = sherpa_onnx.OfflineTtsModelConfig(
          vits: vits,
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        );
      }

      final config = sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 2,
      );

      final tts = sherpa_onnx.OfflineTts(config);

      // 生成音频
      final audio = tts.generate(text: text, sid: speakerId, speed: speed);

      if (audio.samples.isEmpty) {
        tts.free();
        return null;
      }

      // 调整音量（使用软限幅避免削波）
      final adjustedSamples = Float32List(audio.samples.length);
      for (int i = 0; i < audio.samples.length; i++) {
        double sample = audio.samples[i] * volume;
        // 软限幅：使用 tanh 函数平滑处理超出范围的值
        if (sample > 1.0 || sample < -1.0) {
          // 对于超出范围的值，使用 tanh 进行软限幅
          sample = sample > 0 
              ? (1.0 - 0.1 / (sample + 0.1))  // 正值软限幅
              : -(1.0 - 0.1 / (-sample + 0.1)); // 负值软限幅
        }
        adjustedSamples[i] = sample;
      }

      // 创建 WAV 数据
      final wavData = _createWavDataStatic(adjustedSamples, audio.sampleRate);

      // 写入文件
      final file = File(outputPath);
      await file.writeAsBytes(wavData);

      tts.free();
      return outputPath;
    } catch (e) {
      return null;
    }
  }

  /// 静态方法：创建 WAV 文件数据（供 isolate 使用）
  static Uint8List _createWavDataStatic(Float32List samples, int sampleRate) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
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
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
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

    for (int i = 0; i < samples.length; i++) {
      final sample = (samples[i] * 32767.0).clamp(-32768, 32767).toInt();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  /// 异步播报（在后台 isolate 中生成音频，主线程只负责播放）
  Future<bool> speakAsync({
    required String text,
  }) async {
    if (_volume <= 0) return false;
    if (!PlatformUtils.isDesktopPlatform) return false;
    if (!isModelDownloaded) return false;

    try {
      final model = selectedModelInfo;
      final modelDir = await _getModelDirectoryFor(model);
      final modelPath = p.join(modelDir.path, model.modelFile);
      final tokensPath = p.join(modelDir.path, model.tokens);
      final dataDirPath = model.dataDir != null
          ? p.join(modelDir.path, model.dataDir!)
          : '';

      // 检查文件是否存在
      if (!File(modelPath).existsSync() || !File(tokensPath).existsSync()) {
        LogService.e('[TTS] 模型文件不完整');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(tempDir.path, 'tts_output_${DateTime.now().millisecondsSinceEpoch}.wav');

      LogService.d('[TTS] 开始在后台生成音频: $text');

      // 准备参数
      final params = <String, dynamic>{
        'modelPath': modelPath,
        'tokensPath': tokensPath,
        'dataDirPath': dataDirPath,
        'text': text,
        'speakerId': _speakerId,
        'speed': _speed,
        'volume': _volume,
        'outputPath': outputPath,
        'modelType': model.modelType.name,
      };

      // 根据模型类型添加额外参数
      if (model.modelType == TtsModelType.kokoro) {
        params['voicesPath'] = model.voicesFile != null
            ? p.join(modelDir.path, model.voicesFile!)
            : '';
        // Kokoro 模型的 lexicon 路径
        final lexiconZhPath = p.join(modelDir.path, 'lexicon-zh.txt');
        final lexiconEnPath = p.join(modelDir.path, 'lexicon-us-en.txt');
        if (File(lexiconEnPath).existsSync() && File(lexiconZhPath).existsSync()) {
          params['lexiconPath'] = '$lexiconEnPath,$lexiconZhPath';
        } else {
          params['lexiconPath'] = '';
        }
      } else {
        params['lexiconPath'] = model.lexicon != null
            ? p.join(modelDir.path, model.lexicon!)
            : '';
      }

      // 在后台 isolate 中生成音频
      final wavPath = await compute(_generateTtsInIsolate, params);

      if (wavPath == null) {
        LogService.e('[TTS] 后台生成音频失败');
        return false;
      }

      // 主线程播放音频
      if (Platform.isWindows) {
        await Process.run('powershell', [
          '-c',
          '(New-Object Media.SoundPlayer "$wavPath").PlaySync()',
        ]);
      }

      // 清理临时文件
      try {
        await File(wavPath).delete();
      } catch (_) {}

      return true;
    } catch (e) {
      LogService.e('[TTS] 异步播报失败', e);
      return false;
    }
  }

  // ======== 模型下载相关 ========

  /// 获取指定模型的存储目录
  Future<Directory> _getModelDirectoryFor(TtsModelInfo model) async {
    final modelDir = Directory(
      p.join(AppDirectoryService.basePath, 'tts_models', model.dirName),
    );
    return modelDir;
  }

  /// 在后台线程解压 tar.bz2 文件
  static Future<int> _extractTarBz2InBackground(
    List<int> bytes,
    String targetDir,
  ) async {
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
  Future<bool> downloadModel({
    String? modelId,
    bool useAcceleration = false,
  }) async {
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

      LogService.i(
        '[TTS] 开始下载模型: $downloadUrl${useAcceleration ? " (加速)" : ""}',
      );

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

      final modelsDir = Directory(
        p.join(AppDirectoryService.basePath, 'tts_models'),
      );
      if (!modelsDir.existsSync()) {
        modelsDir.createSync(recursive: true);
      }

      // 使用 archive 包解压 tar.bz2（跨平台支持）
      LogService.d('[TTS] 开始解压 tar.bz2 文件...');

      // 在后台线程解压以避免 UI 卡顿
      final extractedFiles = await _extractTarBz2InBackground(
        bytes,
        modelsDir.path,
      );
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
              LogService.d('[TTS] 找到 tokens 文件: ${f.path}');
            }
          }
        }
      }

      final modelFile = File(p.join(modelDir.path, model.modelFile));
      final tokensFile = File(p.join(modelDir.path, model.tokens));

      LogService.d(
        '[TTS] 期望模型文件: ${modelFile.path}, 存在: ${modelFile.existsSync()}',
      );
      LogService.d(
        '[TTS] 期望 tokens 文件: ${tokensFile.path}, 存在: ${tokensFile.existsSync()}',
      );

      if (!modelFile.existsSync() || !tokensFile.existsSync()) {
        // 如果找到了 .onnx 文件但名字不对，输出提示
        if (foundModelFile != null && !modelFile.existsSync()) {
          LogService.w(
            '[TTS] 模型文件名不匹配! 期望: ${model.modelFile}, 实际: ${p.basename(foundModelFile.path)}',
          );
        }
        throw Exception(
          '模型文件解压不完整: model=${modelFile.existsSync()}, tokens=${tokensFile.existsSync()}',
        );
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
