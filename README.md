# BakaBox App

一个用于查看CS2服务器信息和Steam工作坊更新日志的Flutter应用程序。

## 功能特性

### 🖥️ 服务器浏览
- 浏览不同类型的CS2服务器（竞技、休闲、死斗等）
- 查看服务器详细信息（地图、玩家数量、延迟等）
- 实时服务器状态更新
- 支持刷新和加载更多服务器

### 📋 更新日志
- 查看Steam工作坊的最新更新日志
- 支持HTML内容解析和显示
- 复制更新内容到剪贴板
- 时间格式化显示

### 🎨 用户界面
- 现代化的Material Design 3设计
- 响应式布局适配不同屏幕尺寸
- 流畅的动画和过渡效果
- 深色/浅色主题支持

## 技术架构

### 状态管理
- 使用Provider进行状态管理
- 分离的数据层和UI层

### 网络请求
- 基于Dio的HTTP客户端
- 网络连接状态检测
- 请求缓存和错误处理

### 数据模型
- 类型安全的数据模型
- JSON序列化/反序列化
- 扩展模型支持加载状态

## 项目结构

```
lib/
├── api/                    # API客户端和服务
├── constants/              # 常量定义
├── models/                 # 数据模型
├── providers/              # 状态管理
├── screens/                # 页面组件
├── utils/                  # 工具类
├── widgets/                # 可复用组件
└── main.dart              # 应用入口
```

## 开发环境

### 要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

### 依赖包
- `provider`: 状态管理
- `dio`: HTTP客户端
- `connectivity_plus`: 网络连接检测
- `intl`: 国际化和格式化

## 运行应用

1. 安装依赖：
```bash
flutter pub get
```

2. 运行应用：
```bash
flutter run
```

3. 构建发布版本：
```bash
flutter build apk  # Android
flutter build ios  # iOS
```

## API接口

应用连接到BakaBox后端API，获取：
- 服务器分类和列表
- 服务器详细信息
- Steam工作坊更新日志

## 贡献指南

1. Fork项目
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

## 许可证

MIT License
