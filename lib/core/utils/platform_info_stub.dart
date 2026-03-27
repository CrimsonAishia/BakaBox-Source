import 'package:flutter/foundation.dart';

String getOperatingSystem() {
  if (kIsWeb) {
    return 'web';
  }
  throw UnsupportedError('Web environment does not expose dart:io Platform');
}

bool get isAndroid => false;
bool get isIOS => false;
bool get isWindows => false;
