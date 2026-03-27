import 'platform_app_stub.dart'
    if (dart.library.io) 'platform_app_native.dart'
    if (dart.library.js_interop) 'platform_app_web.dart';

Future<void> runPlatformApp(List<String> args) => runPlatformAppImpl(args);
