# OrionBrowser 1.0.2

HTML, CSS and JavaScript interfaces for **Unreal Engine 5.8 / Win64**. Use Blueprint events to connect AI-authored web interfaces to your Unreal game state, sounds, textures and interactive WorldUI.

[English manual](Documentation/README.md) · [简体中文手册](Documentation/README.zh-CN.md) · [Companion downloads](https://github.com/IdealityCentury/OrionBrowser/releases) · [Support](https://orionue.com)

This public repository contains documentation, AI creation Skills, a separate Blueprint sample project and companion-tool releases. The commercial Unreal plugin is distributed separately. A Fab listing link will be added once the real listing is available; this repository does not claim Fab approval.

## Install the plugin and open the example

1. Install the complete OrionBrowser plugin in your Unreal project and enable it.
2. **Download the dependencies:** click the **WebUIStudio** button on the Level Editor toolbar, click **Download** in the **OrionBrowser Dependencies** window that opens, and wait for it to finish. The plugin never downloads them by itself; see [Download the dependencies](Documentation/installation.md#download-the-dependencies).
3. In a blank project, complete the [CommonUI viewport setup](Documentation/installation.md#commonui-viewport). The supplied separate sample already includes it.
4. Show Plugin Content, open `/OrionBrowser/Showcase/L_OrionBrowserOverview`, and Play.
5. Inspect `WBP_OrionBrowserShowcase` and `BP_OrionStationController` for the Blueprint-to-web wiring.

The separate [Orion Station Blueprint project](Examples/OrionBrowserTemplate/README.md) contains its own startup map, configuration and fixed packaging scripts. Install your licensed OrionBrowser plugin under its `Plugins/OrionBrowser` directory before opening the project. The example does not include the commercial plugin or any private game module.

[Tutorial 1: Build an interface with AI](Documentation/tutorial-1-ai.md) · [Tutorial 2: WebUIStudio](Documentation/tutorial-2-webui-studio.md) · [Tutorial 3: Blueprint and C++ integration](Documentation/tutorial-3-blueprint-and-cpp.md) · [Tutorial 4: Write the interface by hand](Documentation/tutorial-4-write-by-hand.md) · [Orion Station sample](Documentation/sample.md)

The supported default is `DefaultWebUIRenderMode=LegacyTexture`. Unreal Blueprint or C++ owns game state; web code displays state and submits action requests.

## Companion tools

Each plugin version carries `Config/OrionBrowserDistribution.json`, which pins every executable to its own GitHub Release tag (no `v` prefix), file size and SHA-256. An executable that a plugin update leaves unchanged stays in the release that first published it. Plugin version `1.0.2` uses:

- `OrionBrowserHelper.exe` from release [`1.0.0`](https://github.com/IdealityCentury/OrionBrowser/releases/tag/1.0.0)
- `WebUIStudio.exe` from release [`1.0.2`](https://github.com/IdealityCentury/OrionBrowser/releases/tag/1.0.2)

Nothing is downloaded until you ask for it. Click the **WebUIStudio** button on the Level Editor toolbar: when an EXE is missing, incomplete or left over from an earlier plugin version, the **OrionBrowser Dependencies** window lists it, and **Download** fetches it from the release its manifest entry names into the plugin's existing `Binaries/Win64` directory and verifies it before use. When both files are correct, the button opens WebUIStudio directly and the network is not used. GitHub sign-in is not required; GitHub connectivity and write access to the installation directory are needed for the download. [Offline import and recovery](Documentation/installation.md#offline-import) are documented.

Cook and packaging verify and stage Helper and never download it: without it they stop with an error that tells you to download the dependencies in the editor first. Packaged Development and Shipping games use their staged Helper and CEF runtime, do not download or repair executables, and do not include Studio. Keep each release's paired CEF files and Helper together.

## 中文说明

此仓库公开文档、AI 制作 Skill、独立纯蓝图示例与配套工具，收费 Unreal 插件单独分发。[下载并使用猎户空间站示例](Examples/OrionBrowserTemplate/README.zh-CN.md)，打开前将已购买的完整插件安装到示例的 `Plugins/OrionBrowser`。示例不包含收费插件源码或任何私有游戏模块。插件不会自行下载依赖：启用插件后，点击关卡编辑器工具栏上的 **WebUIStudio** 按钮，在弹出的“OrionBrowser 依赖”窗口里点“下载”，插件才按随附清单为每个 EXE 写明的 Release Tag 下载 Helper 和 WebUIStudio 到插件 `Binaries/Win64`，并执行文件大小与 SHA-256 校验；插件 `1.0.2` 的 Helper 来自 Tag `1.0.0`，WebUIStudio 来自 Tag `1.0.2`。更新插件后，与新清单不一致的 EXE 同样要再点一次按钮下载。打包不会下载，缺少 Helper 时直接报错并提示先在编辑器里下载。无需登录 GitHub，支持中断恢复、取消、重试及离线导入。

“猎户空间站”是中英双语蓝图示例，展示菜单、设置、背包、任务状态、声音、输入、WorldUI、纹理、运行时图片、three.js 和独立官网浏览区域。具体实现与运行验收边界请查看发行验收记录，Studio 预览不代替 Unreal 或成品包测试。

[教程 1：用 AI 制作界面](Documentation/tutorial-1-ai.zh-CN.md) · [教程 2：WebUIStudio](Documentation/tutorial-2-webui-studio.zh-CN.md) · [教程 3：蓝图与 C++ 接入](Documentation/tutorial-3-blueprint-and-cpp.zh-CN.md) · [教程 4：人工编写界面](Documentation/tutorial-4-write-by-hand.zh-CN.md) · [打包说明](Documentation/packaging.zh-CN.md) · [第三方声明](THIRD_PARTY_NOTICES.md)

Preserve the original third-party notices when redistributing their files. The companion release is immutable: changed binary bytes require a new plugin version and matching release tag.