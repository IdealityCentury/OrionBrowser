# OrionBrowser 1.0.0

HTML, CSS and JavaScript interfaces for **Unreal Engine 5.8 / Win64**. Use Blueprint events to connect AI-authored web interfaces to your Unreal game state, sounds, textures and interactive WorldUI.

[English manual](Documentation/README.md) · [简体中文手册](Documentation/README.zh-CN.md) · [Companion downloads](https://github.com/IdealityCentury/OrionBrowser/releases/tag/1.0.0) · [Support](https://orionue.com)

This public repository contains documentation, AI creation Skills and companion-tool releases. The commercial Unreal plugin is distributed separately. A Fab listing link will be added once the real listing is available; this repository does not claim Fab approval.

## Install the plugin and open the example

1. Install the complete OrionBrowser plugin in your Unreal project and enable it.
2. Let the editor prepare the matching Helper and WebUIStudio files. Progress, cancellation and retry appear in the editor.
3. Show Plugin Content, open `/OrionBrowser/Showcase/L_OrionBrowserOverview`, and Play.
4. Inspect `WBP_OrionBrowserShowcase` and `BP_OrionStationController` for the Blueprint-to-web wiring.

[Create a Blueprint interface](Documentation/blueprint-quick-start.md) · [Use AI to build a web app](Documentation/ai-workflow.md) · [Orion Station sample](Documentation/sample.md)

The supported default is `DefaultWebUIRenderMode=LegacyTexture`. Unreal Blueprint or C++ owns game state; web code displays state and submits action requests.

## Companion tools

Plugin version `1.0.0` uses GitHub Release tag `1.0.0`, without a `v` prefix. The release provides:

- `OrionBrowserHelper.exe`
- `WebUIStudio.exe`
- `OrionBrowserDistribution.json`, containing the expected file sizes and SHA-256 values

The editor installs both EXEs in the plugin's existing `Binaries/Win64` directory. Correct local files are reused without network access. Missing or incomplete files are restored from the exact matching release, then verified before use. GitHub sign-in is not required; GitHub connectivity and write access to the installation directory are needed for first preparation. [Offline import and recovery](Documentation/installation.md) are documented.

Cook/packaging prepares Helper. Packaged Development and Shipping games use their staged Helper and CEF runtime, do not download or repair executables, and do not include Studio. Keep each release's paired CEF files and Helper together.

## 中文说明

此仓库公开文档、AI 制作 Skill 与配套工具，收费 Unreal 插件单独分发。首次打开编辑器时，插件按自身版本从同名 Release 下载 Helper 和 WebUIStudio 到插件 `Binaries/Win64`，并执行文件大小与 SHA-256 校验。无需登录 GitHub，支持中断恢复、取消、重试及离线导入。

“猎户空间站”是中英双语蓝图示例，展示菜单、设置、背包、任务状态、声音、输入、WorldUI、纹理、运行时图片、three.js 和独立官网浏览区域。具体实现与运行验收边界请查看发行验收记录，Studio 预览不代替 Unreal 或成品包测试。

[蓝图快速开始](Documentation/blueprint-quick-start.zh-CN.md) · [AI 制作流程](Documentation/ai-workflow.zh-CN.md) · [打包说明](Documentation/packaging.zh-CN.md) · [第三方声明](THIRD_PARTY_NOTICES.md)

Preserve the original third-party notices when redistributing their files. The companion release is immutable: changed binary bytes require a new plugin version and matching release tag.