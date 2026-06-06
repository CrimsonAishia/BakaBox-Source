// 规则常量 - 从 Python 版逐项复刻
// 资源后缀、正则、关键字、模块分类表等.
//
// 来源: _cs2_error/lib/rules.dart (1:1 拷贝, 仅调整文件位置).

const List<String> resSuffixes = [
  'vmap_c', 'vmdl_c', 'vmat_c', 'vtex_c', 'vpcf_c',
  'vsndevts_c', 'vsnd_c', 'vanim_c', 'vrman_c',
  'vwnod_c', 'vwnod', 'vphys_c', 'vphys', 'vnmgraph_c',
  'vmap', 'vmdl', 'vpcf', 'vmat', 'vsnd', 'vsndevts',
  'vpk',
];

// 资源路径正则 (大小写不敏感)
final RegExp resRe = RegExp(
  r'[A-Za-z0-9_/\\\-\.]+?\.(?:' + resSuffixes.join('|') + r')\b',
  caseSensitive: false,
);

// 严格路径: 必须以已知顶级目录开头
final RegExp pathRe = RegExp(
  r'(?:[A-Za-z]:[\\/])?(?:maps|models|particles|materials|sounds|panorama|'
  r'scripts|resource|csgo|cstrike|core|addons|characters|weapons|player|'
  r'props|vehicles|animgraphs|effects|soundevents)[\\/][A-Za-z0-9_/\\\-\.]{3,200}',
  caseSensitive: false,
);

// Workshop ID 风格的 vpk: 全数字命名
final RegExp workshopVpkRe = RegExp(r'\b(\d{6,12})/\1\.vpk\b');

// vpk 内部引用的资源: "xxx.vpk:maps\\yyy"
final List<String> _vpkInnerSuffixes = [
  'vmap_c', 'vmdl_c', 'vmat_c', 'vtex_c', 'vpcf_c', 'vsndevts_c',
  'vsnd_c', 'vanim_c', 'vrman_c', 'vmap', 'vmdl', 'vpcf', 'vmat',
  'vsnd', 'vwnod', 'vpk',
];
final RegExp vpkInnerRe = RegExp(
  r'\.vpk:([A-Za-z0-9_/\\\-\.]+?\.(?:' +
      _vpkInnerSuffixes.join('|') +
      r'))\b',
  caseSensitive: false,
);

// 关键内部错误关键字 (高优先级)
const List<String> fatalKeywords = [
  'FATAL ERROR', 'attempting to render with error material',
  'failed to load', 'unable to find', 'unable to load',
  'PoseRecipe', 'AG2_', 'was not composed of',
  'out of memory', 'heap corruption',
];

// 一般错误关键字 (= fatal + 附加)
const List<String> assertKeywords = [
  ...fatalKeywords,
  'SchemaSystem', 'ResourceSystem', 'AssertionFailed',
  'failed', 'assert', 'corrupt', 'invalid', 'mismatch',
  'out of', 'bad cast', 'Unknown ', 'not found',
];

// UI/渲染常量字符串 (噪音)
const List<String> noisePrefixes = [
  'Decals', 'Translucent', 'Bloom', 'ViewModel', 'Glow', 'Smoke',
  'Mboit', 'Effects', 'Downsample', 'Upsample', 'Composite',
  'Clear ', 'Render ', 'Pass ', 'Resolve ', 'Cubemap',
];

const Map<int, String> excCodes = {
  0xC0000005: 'EXCEPTION_ACCESS_VIOLATION (空指针/已释放/越界)',
  0xC000001D: 'EXCEPTION_ILLEGAL_INSTRUCTION',
  0xC0000094: 'EXCEPTION_INT_DIVIDE_BY_ZERO',
  0xC00000FD: 'EXCEPTION_STACK_OVERFLOW',
  0xC0000409: 'STATUS_STACK_BUFFER_OVERRUN (栈/缓冲被破坏)',
  0xC0000374: 'STATUS_HEAP_CORRUPTION (堆被破坏)',
  0xE06D7363: 'C++ EH Exception',
  0x80000003: 'EXCEPTION_BREAKPOINT (调试断点/断言)',
  0xC0000139: 'STATUS_ENTRYPOINT_NOT_FOUND',
  0x40010005: 'DBG_CONTROL_C',
};

class ThirdPartyHint {
  final String sev; // benign / medium / high
  final String name;
  final String advice;
  const ThirdPartyHint(this.sev, this.name, this.advice);
}

// 第三方注入模块及推荐处置
const Map<String, ThirdPartyHint> thirdPartyHints = {
  // 良性
  'gameoverlayrenderer': ThirdPartyHint('benign',
      'Steam 游戏内覆盖层 (Shift+Tab / 帧数显示)', 'Steam 官方组件, 正常注入, 一般无需处理'),
  'steamoverlayvulkanlayer':
      ThirdPartyHint('benign', 'Steam Vulkan 覆盖层', 'Steam 官方组件, 正常'),
  'gameoverlayrenderer64': ThirdPartyHint('benign',
      'Steam 游戏内覆盖层 (Shift+Tab / 帧数显示)', 'Steam 官方组件, 正常注入, 一般无需处理'),
  // 高危
  'rivatuner': ThirdPartyHint(
      'high', 'RivaTuner Statistics Server (RTSS)', '已知会引发 CS2 崩溃'),
  'rtss': ThirdPartyHint(
      'high', 'RivaTuner Statistics Server (RTSS)', '已知会引发 CS2 崩溃'),
  'nahimic': ThirdPartyHint(
      'high', 'Nahimic 音效软件', '历史上多次引发游戏崩溃, 建议卸载或禁用其服务'),
  // 中等
  'msi.dll':
      ThirdPartyHint('medium', 'MSI Afterburner', '部分版本与 CS2 不兼容, 建议升级或关闭'),
  'afterburner':
      ThirdPartyHint('medium', 'MSI Afterburner', '部分版本与 CS2 不兼容, 建议升级或关闭'),
  'discord':
      ThirdPartyHint('medium', 'Discord 覆盖层', '偶尔引发崩溃, 可临时关闭覆盖层'),
  'overwolf': ThirdPartyHint('medium', 'Overwolf 覆盖层', '可临时关闭测试'),
  'razer': ThirdPartyHint('medium', 'Razer Synapse', '可临时退出 Razer Synapse 测试'),
  'logitech': ThirdPartyHint('medium', 'Logitech G HUB', '可临时关闭测试'),
  'ghub': ThirdPartyHint('medium', 'Logitech G HUB', '可临时关闭测试'),
  'wallpaper': ThirdPartyHint('medium', 'Wallpaper Engine', '可临时暂停测试'),
  'obs': ThirdPartyHint('medium', 'OBS', '部分版本/插件会引发崩溃, 可临时关闭'),
  'bandicam': ThirdPartyHint('medium', 'Bandicam 录屏', '可临时关闭测试'),
  'fraps': ThirdPartyHint('medium', 'Fraps 录屏', '老旧软件, 建议关闭'),
  'shadowplay':
      ThirdPartyHint('medium', 'NVIDIA ShadowPlay', '可临时关闭即时回放测试'),
  'rtsshooks': ThirdPartyHint(
      'high', 'RivaTuner Statistics Server (RTSS) Hook', '已知会引发 CS2 崩溃'),
  'rtssvklayer':
      ThirdPartyHint('high', 'RivaTuner Vulkan 层', '已知会引发 CS2 崩溃'),
};

const Set<String> coreModules = {
  'client.dll', 'server.dll', 'engine2.dll', 'rendersystemdx11.dll',
  'scenesystem.dll', 'tier0.dll', 'vphysics2.dll', 'schemasystem.dll',
  'resourcesystem.dll', 'soundsystem.dll', 'particles.dll',
  'filesystem_stdio.dll', 'panorama.dll', 'host.dll', 'matchmaking.dll',
  'animationsystem.dll', 'meshsystem.dll', 'materialsystem2.dll',
  'worldrenderer.dll', 'vscript.dll', 'navsystem.dll', 'networksystem.dll',
  'inputsystem.dll', 'vguimatsurface.dll', 'valve_avi.dll',
};

const Map<String, String> subsystemLabels = {
  'animationsystem.dll': '动画系统',
  'meshsystem.dll': '网格系统',
  'scenesystem.dll': '场景渲染',
  'rendersystemdx11.dll': 'DX11 渲染',
  'particles.dll': '粒子系统',
  'vphysics2.dll': '物理系统',
  'soundsystem.dll': '声音系统',
  'worldrenderer.dll': '世界渲染',
  'materialsystem2.dll': '材质系统',
  'resourcesystem.dll': '资源加载',
  'schemasystem.dll': '数据模式',
  'panorama.dll': 'Panorama UI',
  'filesystem_stdio.dll': '文件系统',
  'networksystem.dll': '网络',
  'vscript.dll': '脚本系统',
  'engine2.dll': '引擎核心',
  'client.dll': '客户端逻辑',
  'server.dll': '服务端逻辑',
  'tier0.dll': '底层基础库 (容器/内存)',
};

// 崩溃模块 -> (推测原因, 嫌疑资源类型)
const Map<String, (String, List<String>)> crashModuleProfile = {
  'client.dll': ('客户端逻辑/动画', ['vmdl_c', 'vmdl', 'vanim_c']),
  'server.dll': ('服务端逻辑', ['vmdl_c', 'vmap_c']),
  'engine2.dll': ('引擎核心', []),
  'scenesystem.dll': ('场景渲染', ['vmdl_c', 'vmap_c', 'vmat_c']),
  'meshsystem.dll': ('网格/Mesh', ['vmdl_c']),
  'rendersystemdx11.dll': ('DX11 渲染', ['vmat_c', 'vtex_c']),
  'materialsystem2.dll': ('材质系统', ['vmat_c', 'vtex_c']),
  'particles.dll': ('粒子系统', ['vpcf_c', 'vpcf']),
  'soundsystem.dll': ('声音系统', ['vsnd_c', 'vsndevts_c']),
  'vphysics2.dll': ('物理系统', ['vmdl_c', 'vmap_c']),
  'animationsystem.dll': ('动画系统', ['vmdl_c', 'vanim_c']),
  'resourcesystem.dll':
      ('资源加载', ['vmdl_c', 'vmap_c', 'vmat_c', 'vsnd_c', 'vpcf_c']),
  'schemasystem.dll': ('数据模式', []),
  'tier0.dll': ('基础库 (上层数据问题)', []),
  'panorama.dll': ('Panorama UI', []),
};

const Set<String> gpuDriverModules = {
  'd3d11.dll', 'dxgi.dll',
  'amdxx64.dll', 'amdxx32.dll', 'atidxx64.dll', 'atidxx32.dll',
  'atiumd64.dll', 'amdvlk64.dll',
  'nvd3dum.dll', 'nvwgf2umx.dll', 'nvoglv64.dll', 'nvapi64.dll',
  'igdumdim64.dll', 'igd11dxva64.dll',
  'vulkan-1.dll',
};

const Set<String> toolModules = {
  'qt5core.dll', 'qt5gui.dll', 'qt5widgets.dll', 'qt5network.dll',
  'qt6core.dll', 'qt6gui.dll', 'qt6widgets.dll',
  'modeldoctool.dll', 'hammer.dll',
};

// x64 函数前 4 个参数寄存器
const List<String> argRegs = ['Rcx', 'Rdx', 'R8', 'R9'];

const Map<String, String> kindLabel = {
  'vmdl': '模型', 'vmdl_c': '模型',
  'vmap': '地图', 'vmap_c': '地图',
  'vmat': '材质', 'vmat_c': '材质',
  'vtex_c': '贴图',
  'vpcf': '粒子', 'vpcf_c': '粒子',
  'vsnd': '声音', 'vsnd_c': '声音',
  'vsndevts': '声音事件', 'vsndevts_c': '声音事件',
  'vanim_c': '动画',
  'vrman_c': '资源清单',
  'vwnod': '地图世界节点', 'vwnod_c': '地图世界节点',
  'vphys': '物理碰撞', 'vphys_c': '物理碰撞',
  'vnmgraph_c': '导航网格',
  'vpk': 'VPK 包',
  'other': '其他',
};

const Set<String> knownTops = {
  'maps', 'models', 'particles', 'materials', 'sounds',
  'panorama', 'scripts', 'resource', 'csgo', 'cstrike',
  'core', 'addons', 'characters', 'weapons', 'player',
  'props', 'vehicles', 'animgraphs', 'effects', 'soundevents',
  'rs', 'soundevents_addon', 'shared', 'valve',
  'd:', 'c:', 'e:', 'f:', 'g:',
};
