# 弹幕峰值分析器 v2.0

<div align="center">

![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343?style=flat&logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-13.0+-000000?style=flat&logo=apple&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg)

**现代化的弹幕数据分析与网络录播管理工具**

[功能特性](#-功能特性) • [快速开始](#-快速开始) • [使用指南](#-使用指南) • [技术架构](#-技术架构)

</div>

## 📋 项目简介

弹幕峰值分析器是一个专为网络录播文件设计的弹幕数据分析工具，支持网络存储（SMB）和本地文件分析。通过智能算法检测弹幕密度峰值，帮助内容创作者分析直播互动热点，提供完整的录播文件管理和定时分析功能。

### 🎯 核心价值

- **网络存储支持**: 完整的SMB网络存储支持和自动发现
- **智能分析**: 基于密度分布的峰值检测算法  
- **自动化**: 定时任务和后台分析
- **用户友好**: 现代化 macOS 原生界面
- **实时监控**: 活动日志和状态监控

## ✨ 功能特性

### 🌐 网络存储管理
- **SMB服务发现**: 自动扫描网络中的SMB服务器
- **多服务器配置**: 支持配置和管理多个SMB服务器
- **连接测试**: 实时测试SMB连接状态
- **自动重连**: 网络中断后自动重新连接

### 🤖 智能定时任务
- **可配置间隔**: 5分钟到24小时的扫描间隔选择
- **后台处理**: 定时扫描和分析录播文件
- **状态监控**: 实时显示任务执行状态和进度
- **错误恢复**: 自动重试和错误处理机制

### 🔍 弹幕分析引擎
- **XML解析**: 支持各种录播格式的XML弹幕文件
- **峰值检测**: 动态阈值的弹幕密度峰值分析
- **时间定位**: 精确的相对时间和绝对时间定位
- **统计信息**: 详细的弹幕统计和频率分析

### 📊 数据可视化
- **实时活动**: 活动日志和操作历史记录
- **分析结果**: 弹幕峰值的详细展示和扩展视图
- **状态仪表盘**: 系统状态、网络连接和任务进度
- **交互式界面**: 直观的录播文件管理和操作

### 🛠️ 开发者友好
- **模块化架构**: Actor并发模型和观察者模式
- **配置持久化**: UserDefaults配置存储和恢复
- **错误处理**: 完善的错误恢复和用户提示
- **日志系统**: 详细的活动记录和调试信息

## 🚀 快速开始

### 系统要求
- macOS 13.0+
- Swift 5.9+
- 4GB+ 内存

### 构建和运行

```bash
# 克隆项目
git clone git@github.com:4utumn395/danmu-analyzer.git
cd danmu-analyzer

# 构建项目
swift build

# 运行应用
swift run
```

### 创建应用包

```bash
# 构建发布版本
swift build -c release

# 应用将生成在 dist/ 目录中
./dist/DanmuAnalyzer.app/Contents/MacOS/DanmuAnalyzer
```

## 📖 使用指南

### 🎮 主要功能

#### 1. 网络配置
- **仪表盘**: 查看系统状态和网络连接
- **设置**: 配置SMB服务器连接
- **自动发现**: 扫描网络中的SMB服务
- **连接管理**: 测试和选择SMB服务器

#### 2. 录播管理
- **文件扫描**: 自动扫描网络中的录播文件
- **格式支持**: 支持XML格式的弹幕文件
- **文件信息**: 显示录播时间、频道和标题信息
- **本地操作**: 在Finder中打开录播文件

#### 3. 分析功能
- **手动分析**: 选择录播文件进行即时分析
- **定时分析**: 配置自动定时分析任务
- **结果查看**: 详细的弹幕峰值分析结果
- **历史记录**: 保存和查看分析历史

#### 4. 定时任务
- **间隔配置**: 自定义扫描间隔（5分钟-24小时）
- **任务监控**: 实时查看任务执行状态
- **自动处理**: 后台自动扫描和分析
- **错误处理**: 失败重试和错误统计

## 📊 技术架构

### 核心组件

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SwiftUI       │    │   Network       │    │   Activity      │
│   Interface     │───▶│   Manager       │───▶│   Manager       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Schedule      │    │   SMB Config    │    │   XML Danmaku   │
│   Manager       │───▶│   Manager       │───▶│   Parser        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Analysis      │    │   Discovery     │    │   Configuration │
│   Engine        │    │   Manager       │    │   Persistence   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 技术特性

- **Swift 并发**: Actor模型和结构化并发
- **网络框架**: 原生Network框架进行SMB连接
- **配置管理**: UserDefaults和JSON序列化
- **观察者模式**: ObservableObject和Combine
- **错误处理**: 结构化错误处理和重试机制

## 🔧 项目结构

```
danmu-analyzer/
├── MainApp.swift              # 主应用界面
├── NetworkManager.swift       # 网络和定时任务管理
├── ActivityManager.swift      # 活动日志管理
├── SMBConfigurationManager.swift    # SMB配置管理
├── ScheduleConfigurationManager.swift # 定时任务配置
├── SMBDiscoveryManager.swift  # SMB服务发现
├── XMLDanmakuParser.swift     # XML弹幕解析
├── AddSMBConfigurationView.swift # SMB配置界面
├── Models.swift              # 数据模型
├── NetworkModels.swift       # 网络相关模型
├── Constants.swift           # 常量定义
├── Utilities.swift           # 工具函数
├── ErrorHandler.swift        # 错误处理
└── Package.swift            # Swift包配置
```

## 📈 主要界面

### 仪表盘
- 系统状态监控
- 今日统计信息
- 实时活动日志

### 录播管理
- 网络录播文件列表
- 文件信息和操作
- 分析功能入口

### 定时任务
- 任务开关和状态
- 手动触发扫描
- 任务历史记录

### 分析结果
- 弹幕峰值详情
- 时间轴定位
- 统计信息展示

### 设置
- SMB服务器配置
- 定时任务设置
- 网络状态监控

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🎉 更新日志

### v2.0.0 
- 🌐 **新增SMB网络存储支持**
  - 自动发现网络SMB服务
  - 多服务器配置和管理
  - 连接状态监控和自动重连
  
- 🤖 **智能定时任务系统**
  - 可配置的扫描间隔（5分钟-24小时）
  - 后台自动分析和处理
  - 任务状态监控和错误恢复
  
- 📊 **现代化用户界面**
  - SwiftUI原生界面重构
  - 实时活动日志和状态监控
  - 响应式布局和交互设计
  
- 🔍 **增强的分析引擎**
  - XML弹幕文件解析
  - 改进的峰值检测算法
  - 详细的时间定位和统计信息
  
- 🛠️ **架构优化**
  - Actor并发模型
  - 模块化配置管理
  - 完善的错误处理机制

---

<div align="center">

**Made with ❤️ for the streaming community**

[⭐ Star](https://github.com/4utumn395/danmu-analyzer) • [🐛 Report Bug](https://github.com/4utumn395/danmu-analyzer/issues) • [💡 Request Feature](https://github.com/4utumn395/danmu-analyzer/issues)

</div>