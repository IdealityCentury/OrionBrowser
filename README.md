# OrionBrowser 1.0.1

HTML, CSS and JavaScript interfaces for **Unreal Engine 5.8 / Win64**. Use Blueprint events to connect AI-authored web interfaces to your Unreal game state, sounds, textures and interactive WorldUI.

[English manual](Documentation/README.md) · [简体中文手册](Documentation/README.zh-CN.md) · [Companion downloads](https://github.com/IdealityCentury/OrionBrowser/releases) · [Support](https://orionue.com)

This public repository contains documentation, AI creation Skills, a separate Blueprint sample project and companion-tool releases. The commercial Unreal plugin is distributed separately. A Fab listing link will be added once the real listing is available; this repository does not claim Fab approval.

## Install the plugin and open the example

1. Install the complete OrionBrowser plugin in your Unreal project and enable it.
2. In a blank project, complete the [CommonUI viewport setup](Documentation/installation.md#commonui-viewport). The supplied separate sample already includes it.
3. Let the editor prepare the matching Helper and WebUIStudio files. Progress, cancellation and retry appear in the editor.
4. Show Plugin Content, open `/OrionBrowser/Showcase/L_OrionBrowserOverview`, and Play.
5. Inspect `WBP_OrionBrowserShowcase` and `BP_OrionStationController` for the Blueprint-to-web wiring.

The separate [Orion Station Blueprint project](Examples/OrionBrowserTemplate/README.md) contains its own startup map, configuration and fixed packaging scripts. Install your licensed OrionBrowser plugin under its `Plugins/OrionBrowser` directory before opening the project. The example does not include the commercial plugin or any private game module.

[Tutorial 1: Build an interface with AI](Documentation/tutorial-1-ai.md) · [Tutorial 2: Build it yourself](Documentation/tutorial-2-build-it-yourself.md) · [Tutorial 3: Blueprint and C++ integration](Documentation/tutorial-3-blueprint-and-cpp.md) · [Tutorial 4: WebUIStudio](Documentation/tutorial-4-webui-studio.md) · [Orion Station sample](Documentation/sample.md)

The supported default is `DefaultWebUIRenderMode=LegacyTexture`. Unreal Blueprint or C++ owns game state; web code displays state and submits action requests.

## Companion tools

Each plugin version carries `Config/OrionBrowserDistribution.json`, which pins every executable to its own GitHub Release tag (no `v` prefix), file size and SHA-256. An executable that a plugin update leaves unchanged stays in the release that first published it. Plugin version `1.0.1` uses:

- `OrionBrowserHelper.exe` from release [`1.0.0`](https://github.com/IdealityCentury/OrionBrowser/releases/tag/1.0.0)
- `WebUIStudio.exe` from release [`1.0.1`](https://github.com/IdealityCentury/OrionBrowser/releases/tag/1.0.1)

The editor installs both EXEs in the plugin's existing `Binaries/Win64` directory. Correct local files are reused without network access. Missing or incomplete files, and files left over from an earlier plugin version, are restored from the release their manifest entry names, then verified before use. GitHub sign-in is not required; GitHub connectivity and write access to the installation directory are needed for first preparation. [Offline import and recovery](Documentation/installation.md) are documented.

Cook/packaging prepares Helper. Packaged Development and Shipping games use their staged Helper and CEF runtime, do not download or repair executables, and do not include Studio. Keep each release's paired CEF files and Helper together.

## 中文说明

此仓库公开文档、AI 制作 Skill、独立纯蓝图示例与配套工具，收费 Unreal 插件单独分发。[下载并使用猎户空间站示例](Examples/OrionBrowserTemplate/README.zh-CN.md)，打开前将已购买的完整插件安装到示例的 `Plugins/OrionBrowser`。示例不包含收费插件源码或任何私有游戏模块。首次打开编辑器时，插件按随附清单为每个 EXE 写明的 Release Tag 下载 Helper 和 WebUIStudio 到插件 `Binaries/Win64`，并执行文件大小与 SHA-256 校验；插件 `1.0.1` 的 Helper 来自 Tag `1.0.0`，WebUIStudio 来自 Tag `1.0.1`。更新插件后，与新清单不一致的 EXE 会在下次打开编辑器时自动替换。无需登录 GitHub，支持中断恢复、取消、重试及离线导入。

“猎户空间站”是中英双语蓝图示例，展示菜单、设置、背包、任务状态、声音、输入、WorldUI、纹理、运行时图片、three.js 和独立官网浏览区域。具体实现与运行验收边界请查看发行验收记录，Studio 预览不代替 Unreal 或成品包测试。

[教程 1：用 AI 制作界面](Documentation/tutorial-1-ai.zh-CN.md) · [教程 2：自己动手做界面](Documentation/tutorial-2-build-it-yourself.zh-CN.md) · [教程 3：蓝图与 C++ 接入](Documentation/tutorial-3-blueprint-and-cpp.zh-CN.md) · [教程 4：WebUIStudio](Documentation/tutorial-4-webui-studio.zh-CN.md) · [打包说明](Documentation/packaging.zh-CN.md) · [第三方声明](THIRD_PARTY_NOTICES.md)

Preserve the original third-party notices when redistributing their files. The companion release is immutable: changed binary bytes require a new plugin version and matching release tag.