# OrionBrowser 1.0.1 使用手册

**Unreal Engine 5.8 · Windows 64 位 · 支持蓝图与 C++**

OrionBrowser 将本地 HTML、CSS 与 JavaScript 界面嵌入 Unreal Widget。可以使用网页开发工具或 AI 编写界面，由 Unreal 蓝图或 C++ 保存游戏规则、库存和存档。当前支持的默认配置为 `DefaultWebUIRenderMode=LegacyTexture`。

[English](README.md) | 简体中文

## 从这里开始

1. [安装与工具准备](installation.zh-CN.md)
2. 运行[猎户空间站示例](sample.zh-CN.md)，确认环境正常

## 教程

| 教程 | 适合 | 内容 |
| --- | --- | --- |
| [1. 用 AI 制作界面（推荐）](tutorial-1-ai.zh-CN.md) | 想最快做出界面，或不熟悉网页开发 | 每一步该对 Codex 或 Claude 说什么：定 UI 设定集、定数据与操作、写界面、提修改、蓝图接线、指定声音、测试 |
| [2. 自己动手做界面](tutorial-2-build-it-yourself.zh-CN.md) | 想自己写网页，或要查某项功能的做法 | 从空目录建 App，到通信、输入、声音、文字、字体、图片、WorldUI、远程网站、安全、性能与调试的全部操作 |
| [3. 蓝图与 C++ 接入](tutorial-3-blueprint-and-cpp.zh-CN.md) | 负责 Unreal 这一侧 | 纯蓝图、C++、C++ 基类加蓝图子类三种接法，蓝图节点速查，CommonUI 与 InstantScreen |
| [4. WebUIStudio](tutorial-4-webui-studio.zh-CN.md) | 要预览和检查界面，或在界面上标注后交给 AI | 启动、预览与视图、检查与日志、标注与发送、新建界面、隔离草稿、命令行检查 |

四篇教程使用同一个例子（设置面板 `SettingsPanel`），可以对照阅读。

## 参考

- [打包与故障排查](packaging.zh-CN.md)
- [猎户空间站示例](sample.zh-CN.md)
- [第三方软件与分发](third-party.zh-CN.md)
- [制作 Skill](../Skills/orion-webui-creation/SKILL.md)：给 Codex、Claude 等编程助手阅读的制作规则

支持入口：[Orion 官网](https://orionue.com) · [问题反馈](https://github.com/IdealityCentury/OrionBrowser/issues) · [版本下载](https://github.com/IdealityCentury/OrionBrowser/releases)。

公开仓库提供文档、示例和配套工具。商业 Unreal 插件单独分发；只下载示例工程不会自动取得或安装收费插件。
