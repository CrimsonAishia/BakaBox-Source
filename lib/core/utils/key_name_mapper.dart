import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

/// CS2 按键名称映射工具
///
/// 将 Flutter [LogicalKeyboardKey] 和鼠标按键转换为 CS2 bind 命令兼容的按键名称。
/// 统一由此类提供映射，避免多处重复实现。
class KeyNameMapper {
  KeyNameMapper._();

  /// 修饰键集合，用于快速判断
  static final _modifierKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  /// 将 [LogicalKeyboardKey] 转换为 CS2 可用的大写按键名称。
  ///
  /// 如果按键是修饰键（Shift / Ctrl / Alt / Meta），返回空字符串。
  static String getReadableKeyName(LogicalKeyboardKey key) {
    // 修饰键不能单独绑定
    if (_modifierKeys.contains(key)) return '';

    String name = key.keyLabel.toLowerCase();

    // F 区按键 (F1 – F24)：keyLabel 本身就是 'f1', 'f2'... 保持不变
    if (key.keyId >= LogicalKeyboardKey.f1.keyId &&
        key.keyId <= LogicalKeyboardKey.f24.keyId) {
      // 已是正确格式
    }
    // 小键盘数字 (Numpad 0-9)
    else if (key.keyId >= LogicalKeyboardKey.numpad0.keyId &&
        key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
      // key.keyLabel 格式通常为 "Numpad 0"，需要提取数字部分
      final numStr = key.keyLabel.replaceAll(RegExp(r'[^0-9]'), '');
      name = 'kp_$numStr';
    }
    // 其他小键盘按键
    else if (key == LogicalKeyboardKey.numpadAdd) {
      name = 'kp_plus';
    } else if (key == LogicalKeyboardKey.numpadSubtract) {
      name = 'kp_minus';
    } else if (key == LogicalKeyboardKey.numpadMultiply) {
      name = 'kp_multiply';
    } else if (key == LogicalKeyboardKey.numpadDivide) {
      name = 'kp_divide';
    } else if (key == LogicalKeyboardKey.numpadEnter) {
      name = 'kp_enter';
    } else if (key == LogicalKeyboardKey.numpadDecimal) {
      name = 'kp_del';
    }
    // 方向键
    else if (key == LogicalKeyboardKey.arrowUp) {
      name = 'uparrow';
    } else if (key == LogicalKeyboardKey.arrowDown) {
      name = 'downarrow';
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      name = 'leftarrow';
    } else if (key == LogicalKeyboardKey.arrowRight) {
      name = 'rightarrow';
    }
    // 编辑区按键
    else if (key == LogicalKeyboardKey.pageUp) {
      name = 'pgup';
    } else if (key == LogicalKeyboardKey.pageDown) {
      name = 'pgdn';
    } else if (key == LogicalKeyboardKey.home) {
      name = 'home';
    } else if (key == LogicalKeyboardKey.end) {
      name = 'end';
    } else if (key == LogicalKeyboardKey.insert) {
      name = 'ins';
    } else if (key == LogicalKeyboardKey.delete) {
      name = 'del';
    }
    // 控制键
    else if (key == LogicalKeyboardKey.space) {
      name = 'space';
    } else if (key == LogicalKeyboardKey.escape) {
      name = 'escape';
    } else if (key == LogicalKeyboardKey.tab) {
      name = 'tab';
    } else if (key == LogicalKeyboardKey.capsLock) {
      name = 'capslock';
    } else if (key == LogicalKeyboardKey.backspace) {
      name = 'backspace';
    } else if (key == LogicalKeyboardKey.enter) {
      name = 'enter';
    }
    // 标点符号映射（CS2 标准绑定格式，使用符号字符）
    else if (key == LogicalKeyboardKey.minus) {
      name = '-';
    } else if (key == LogicalKeyboardKey.equal) {
      name = '=';
    } else if (key == LogicalKeyboardKey.bracketLeft) {
      name = '[';
    } else if (key == LogicalKeyboardKey.bracketRight) {
      name = ']';
    } else if (key == LogicalKeyboardKey.semicolon) {
      name = ';';
    } else if (key == LogicalKeyboardKey.quote) {
      name = "'";
    } else if (key == LogicalKeyboardKey.comma) {
      name = ',';
    } else if (key == LogicalKeyboardKey.period) {
      name = '.';
    } else if (key == LogicalKeyboardKey.slash) {
      name = '/';
    } else if (key == LogicalKeyboardKey.backslash) {
      name = '\\';
    } else if (key == LogicalKeyboardKey.backquote) {
      name = '`';
    }

    return name.toUpperCase();
  }

  /// 将鼠标按键 bitmask 转换为 CS2 按键名称。
  ///
  /// 仅处理中键、侧键（Mouse4/5），左键和右键返回 null 以忽略。
  static String? mouseButtonToCS2Name(int buttons) {
    if (buttons & kMiddleMouseButton != 0) {
      return 'MOUSE3';
    } else if (buttons & kBackMouseButton != 0) {
      return 'MOUSE4';
    } else if (buttons & kForwardMouseButton != 0) {
      return 'MOUSE5';
    }
    return null;
  }
}
