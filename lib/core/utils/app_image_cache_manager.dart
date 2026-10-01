// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:file/file.dart' as pf;
import 'package:file/local.dart';
import 'app_directory_service.dart';

class AppImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'bakabox_image_cache';
  static final AppImageCacheManager _instance = AppImageCacheManager._();

  factory AppImageCacheManager() {
    return _instance;
  }

  AppImageCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 1000,
          repo: JsonCacheInfoRepository(
            path: p.join(
              AppDirectoryService.cachePath,
              'image_cache_meta',
              '$key.json',
            ),
          ),
          fileSystem: _AppFileSystem(key),
        ),
      );

  static AppImageCacheManager get instance => _instance;
}

class _AppFileSystem implements FileSystem {
  final Future<pf.Directory> _fileDir;
  final String _cacheKey;

  _AppFileSystem(this._cacheKey) : _fileDir = createDirectory(_cacheKey);

  static Future<pf.Directory> createDirectory(String key) async {
    final path = p.join(AppDirectoryService.cachePath, key);
    const fs = LocalFileSystem();
    final directory = fs.directory(path);
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<pf.File> createFile(String name) async {
    final directory = await _fileDir;
    if (!(await directory.exists())) {
      await createDirectory(_cacheKey);
    }
    return directory.childFile(name);
  }
}
