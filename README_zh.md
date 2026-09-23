<div align="center">
  <img src="windows/runner/resources/app_icon.ico" alt="Logo" width="80" height="80">

  <h3>BakaBox</h3>

  <p>
    CS2 登录器
  </p>

  <p>
    <a href="https://github.com/CrimsonAishia/BakaBox-Source/graphs/contributors"><img src="https://img.shields.io/github/contributors/CrimsonAishia/BakaBox-Source.svg?style=flat-square" alt="Contributors"></a>
    <a href="https://github.com/CrimsonAishia/BakaBox-Source/network/members"><img src="https://img.shields.io/github/forks/CrimsonAishia/BakaBox-Source.svg?style=flat-square" alt="Forks"></a>
    <a href="https://github.com/CrimsonAishia/BakaBox-Source/stargazers"><img src="https://img.shields.io/github/stars/CrimsonAishia/BakaBox-Source.svg?style=flat-square" alt="Stargazers"></a>
    <a href="https://github.com/CrimsonAishia/BakaBox-Source/issues"><img src="https://img.shields.io/github/issues/CrimsonAishia/BakaBox-Source.svg?style=flat-square" alt="Issues"></a>
    <a href="https://github.com/CrimsonAishia/BakaBox-Source/blob/main/LICENSE"><img src="https://img.shields.io/github/license/CrimsonAishia/BakaBox-Source.svg?style=flat-square" alt="License"></a>
  </p>

  <p>
    <a href="README.md">English</a> · <strong>简体中文</strong>
  </p>

  <p>
    <a href="https://baka.aishia.cc/"><strong>访问项目官网 »</strong></a> ·
    <a href="https://github.com/CrimsonAishia/BakaBox-Source/issues">报告 Bug</a> ·
    <a href="https://github.com/CrimsonAishia/BakaBox-Source/issues">提出新特性</a>
  </p>
</div>

<div align="center">
  <img src="assets/images/software-pic.png" alt="BakaBox Screenshot" />
</div>

## 目录

- [上手指南](#上手指南)
  - [开发前的配置要求](#开发前的配置要求)
  - [安装步骤](#安装步骤)
- [文件目录说明](#文件目录说明)
- [使用到的框架](#使用到的框架)
- [部署与编译](#部署与编译)
- [版本控制](#版本控制)
- [作者](#作者)

### 上手指南

#### 开发前的配置要求

1. Flutter SDK >= 3.9.0
2. Dart SDK >= 3.0.0
3. (仅 Windows) Visual Studio 2022 及 C++ 桌面开发工作负载

#### 安装步骤

1. 克隆仓库
```sh
git clone https://github.com/CrimsonAishia/BakaBox-Source.git
```
2. 获取依赖
```sh
flutter pub get
```
3. 运行应用
```sh
flutter run -d windows
```

### 文件目录说明

```text
BakaBox/
├── lib/
│   ├── app/             # 应用层包装
│   ├── core/            # 核心业务逻辑 (API/BLoC/Models/Router)
│   ├── desktop/         # 桌面端差异化实现 (Windows)
│   ├── mobile/          # 移动端差异化实现
│   ├── web/             # Web 端支持层
│   └── main.dart        # 启动入口
├── proto/               # Protobuf 定义文件
├── windows/             # Windows 原生工程及 MSIX 配置
├── android/             # Android 原生工程
├── ios/                 # iOS 原生工程
├── web/                 # Web 端原生工程
├── assets/              # 静态资源 (图标/本地化等)
├── generate_proto.bat   # Protobuf 一键编译脚本
└── pubspec.yaml         # 依赖配置
```

### 使用到的框架

- [Flutter](https://flutter.dev/) - 跨平台 UI 框架
- [flutter_bloc](https://bloclibrary.dev/) - 状态管理
- [go_router](https://pub.dev/packages/go_router) - 路由管理
- [dio](https://pub.dev/packages/dio) - HTTP 客户端
- [Nakama](https://heroiclabs.com/) - 实时后端服务交互
- [Flame](https://flame-engine.org/) - 2D 游戏引擎集成
- [sherpa_onnx](https://github.com/k2-fsa/sherpa-onnx) - 离线 TTS (文本转语音)

### 部署与编译

由于本项目为标准的 Flutter 跨平台工程，在开源分支中去除了私有的全自动 CI/CD 脚本，您可以直接使用标准的 Flutter 命令进行本地编译与打包。

#### 1. 桌面端 (Windows)
桌面端支持构建为标准的 Windows 绿色免安装程序，或发布到 Microsoft Store 的 MSIX 安装包。

```sh
# 1. 构建标准的 Windows 可执行程序 (输出至 build/windows/runner/Release)
flutter build windows

# 2. (可选) 构建 MSIX 安装包以供分发
flutter pub run msix:create
```

#### 2. 移动端 (Android / iOS)
```sh
# Android 构建 APK (输出至 build/app/outputs/flutter-apk/app-release.apk)
flutter build apk

# iOS 构建 (必须在 macOS 并在 Xcode 中配置好证书)
flutter build ios
```

### 版本控制

该项目使用 Git 进行版本管理。您可以在 repository 参看当前可用版本。

### 作者

Aishia Studio 
- Github: [@CrimsonAishia](https://github.com/CrimsonAishia)
