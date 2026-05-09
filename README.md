# BearOCR

macOS 菜单栏 OCR 工具，支持截图识别、表格提取和截图翻译。

![platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## 功能

| 功能 | 说明 | 默认快捷键 |
|------|------|-----------|
| 截图识别 | 框选屏幕区域，识别中英文文字 | `⌥A` |
| 表格识别 | 框选表格区域，输出 HTML 表格并支持导出 XLSX | `⌥T` |
| 截图翻译 | 框选屏幕区域，中英双向翻译 | `⌥S` |

- 常驻菜单栏，无 Dock 图标
- 全局热键，任何应用下均可触发
- 识别结果弹出浮动窗口，支持一键复制
- 快捷键完全可自定义

## 安装

### 从源码构建

**前置条件：**
- macOS 14.0+
- Xcode 16+（提供 Swift 5.9 工具链）

```bash
git clone https://github.com/yourusername/BearOCR.git
cd BearOCR
bash build.sh
```

构建产物位于 `.build/BearOCR.app`，可直接运行或分发给其他 Mac 用户。

### 首次启动

由于应用未签名，首次打开请使用 **右键 → 打开**，或终端执行：

```bash
open .build/BearOCR.app
```

## 配置

首次使用需在设置（`⌘,`）中配置以下服务：

### OCR 模型（必需）

BearOCR 依赖兼容 OpenAI API 的视觉模型服务（如 LM Studio、Ollama 等）：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| 请求地址 | API 端点 | `http://127.0.0.1:8000/v1` |
| API Key | 认证密钥 | 留空（LM Studio 默认无需） |
| 模型 ID | 视觉语言模型名称 | `GLM-OCR-bf16` |

推荐使用 [LM Studio](https://lmstudio.ai/) 加载 GLM-OCR 模型。

### 百度翻译（可选）

如需使用截图翻译功能，请在 [百度翻译开放平台](https://fanyi-api.baidu.com/) 注册并获取 App ID 和 Secret Key。

## 架构

```
BearOCR
├── Sources/BearOCR/
│   ├── BearOCRApp.swift      应用入口、状态管理
│   ├── AppDelegate.swift     启动初始化、全局热键绑定
│   ├── MenuBarView.swift     菜单栏界面
│   ├── CaptureHandler.swift  截图→识别→窗口展示 协调器
│   ├── OCRService.swift      调用 LM Studio API
│   ├── TranslationService.swift 百度翻译 API
│   ├── ScreenshotManager.swift  系统截图调用
│   ├── OCRResultView.swift   OCR/表格结果窗口（SwiftUI）
│   ├── HTMLTableView.swift   WKWebView 表格渲染
│   ├── XLSXWriter.swift      纯 Swift XLSX 生成
│   ├── Constants.swift       快捷键定义
│   ├── SettingsView.swift    设置界面
│   └── ...
├── Info.plist
├── Package.swift
└── build.sh
```

**技术栈：**
- SwiftUI + AppKit（菜单栏应用 + 浮动窗口）
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)（全局热键）
- OpenAI 兼容 API（视觉语言模型调用）
- `screencapture` 命令行（系统截图）
- WKWebView（HTML 表格渲染）
- OOXML（纯 Swift XLSX 文件生成）

## 工作流程

```
快捷键 / 菜单栏点击
    │
    ▼
screencapture -i（区域截图）
    │
    ▼
GLM-OCR 模型识别（LM Studio API）
    │
    ├── OCR 模式 ──→ 文本提取 ──→ 浮动窗口
    ├── 表格模式 ──→ HTML 表格 ──→ WKWebView 渲染 ──→ XLSX 导出
    └── 翻译模式 ──→ 文本提取 ──→ 百度翻译 API ──→ 双语对照窗口
```

## 许可

MIT License
