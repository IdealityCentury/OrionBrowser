# 安装与下载依赖

下文插件路径以 `OrionBrowser.uplugin` 所在目录为基准，工程路径以 `.uproject` 所在目录为基准。

## 安装

1. 使用 UE 5.8 / Win64。替换插件前正常关闭工程。
2. 通过 Fab 安装，或者把完整插件目录复制到工程的 `Plugins/OrionBrowser`。同一引擎与工程组合不要保留两个插件副本。
3. 打开工程，在 Plugins 中启用 **OrionBrowser**，按 Unreal 提示重启。插件使用 CommonUI 等引擎内置能力，不需要其他私有游戏框架。
4. **下载依赖。** 点击关卡编辑器工具栏上的 **WebUIStudio** 按钮，在弹出的“OrionBrowser 依赖”窗口里点“下载”，等它完成，见[下载依赖](#下载依赖)。插件不会自行下载；这一步完成之前，界面不会在编辑器里显示，工程也不能打包。
5. 空白工程先按下文配置 CommonUI 视口；随附的猎户空间站工程已经包含此设置。
6. 在内容浏览器启用 **显示插件内容**，打开 `OrionBrowser/Showcase/L_OrionBrowserOverview`，点击运行。

每次打开工程不会自动启动 WebUIStudio。需要制作和预览页面时，使用关卡编辑器工具栏上的 **WebUIStudio** 按钮，见[教程 2](tutorial-2-webui-studio.zh-CN.md)。

宿主在构造 Widget 时读取默认浏览器材质，不要求 Helper 已经就绪。插件分别管理这些同步默认值和 CEF 初始化；Helper 校验通过后（启动时已经齐全，或者刚刚下载完成），等待中的 Widget 或后续浏览器请求通过同一个单例入口完成初始化，无须重建宿主 Widget 或重启 Editor。真正的 CEF 初始化失败会报告错误，后续单例访问不会循环重试。

## 下载依赖

Fab 不分发可执行文件，所以插件的两个依赖放在公开的 GitHub Release 上，需要下载一次，合计约 160 MB：

| 依赖 | 插件内位置 | 用途 |
| --- | --- | --- |
| Helper | `Binaries/Win64/OrionBrowserHelper.exe` | 编辑器及成品游戏使用的浏览器子进程 |
| WebUIStudio | `Binaries/Win64/WebUIStudio.exe` | 界面制作与预览工具，不随游戏分发 |

**插件不会自行下载。** 打开编辑器、点击运行、编译、Cook 和打包都不访问网络；只有你在窗口里点了“下载”才会下载。

1. 点击关卡编辑器工具栏上的 **WebUIStudio** 按钮。插件按随附的清单核对两个文件的大小与 SHA-256。
2. 有文件缺失，或者与当前插件版本不一致时，弹出“OrionBrowser 依赖”窗口，列出每个文件是“已就绪”“缺失”还是“版本不一致”。
3. 点“下载”。窗口显示当前文件、已下载的字节数和进度，可以点“取消”。
4. 下载并校验完成后，窗口显示“OrionBrowser 依赖已就绪。”，点“打开 WebUIStudio”。编辑器里等待中的界面此时自动刷新，不需要重启。

两个文件都存在且与插件版本一致时，点击 **WebUIStudio** 按钮不弹出窗口，直接打开 WebUIStudio。窗口文字跟随编辑器语言；英文编辑器里窗口标题是 `OrionBrowser Dependencies`，按钮是 `Download`、`Cancel`、`Retry` 和 `Open WebUIStudio`。

依赖还没有下载时：

| 位置 | 表现 |
| --- | --- |
| 编辑器里的界面控件 | 显示 `OrionBrowser dependencies are missing. Click the WebUIStudio button on the toolbar to download them.`，下载完成后自动刷新 |
| Output Log | 一条 `LogOrionBrowserPreparation` 警告，说明 Helper 缺失或与插件版本不一致 |
| Cook 与打包 | 直接失败并写明原因，不会下载，见[打包](packaging.zh-CN.md#标准打包) |

编辑器启动时会在后台核对一次本地文件，用来决定能不能创建浏览器。这一步只读本地文件，不访问网络，也不弹出窗口。

## CommonUI 视口

OrionBrowser 会启用引擎的 CommonUI 插件。CommonUI 输入路由要求游戏视口继承 **CommonGameViewportClient**。在空白蓝图工程的 Project Settings 中，将 **Game Viewport Client Class** 设为 **CommonGameViewportClient**，然后重启编辑器。对应的工程 `Config/DefaultEngine.ini` 设置如下：

```ini
[/Script/Engine.Engine]
GameViewportClientClassName=/Script/CommonUI.CommonGameViewportClient
```

如果游戏已有自定义视口，保留该类并确保其继承 CommonGameViewportClient；直接替换可能丢失游戏原有的视口行为。插件不会覆盖工程的自定义视口。缺少此配置时，页面仍可能显示并响应鼠标点击，同时 CommonUI 报告输入路由错误，因此首次显示不能证明键盘和手柄路由已经就绪。不要用关闭诊断替代视口配置。

## 版本与清单

随插件提供的 `Config/OrionBrowserDistribution.json` 为每个 EXE 单独写明 `releaseTag`，即存放它的 GitHub Release 精确 Tag，并固定它的字节数与 SHA-256。下载只使用这个 Tag，不读取 `latest`。两个 EXE 的 Tag 互相独立：插件更新中没有变化的 EXE 沿用原来的 Tag，因此插件 `1.0.1` 可以从 Tag `1.0.0` 取 Helper、从 Tag `1.0.1` 取 WebUIStudio。清单的 `version` 必须与 `OrionBrowser.uplugin` 的 `VersionName` 一致。CEF 库及资源随插件提供，必须与清单固定的 Helper 配套使用。

下载需要通过 HTTPS 访问 GitHub 及其发行附件托管站点。公开下载不需要 GitHub 登录或令牌。已有文件完整且哈希正确时，点“下载”也不会重新下载它。该功能只取得当前版本的依赖，不会升级插件版本。

通过 Fab 或手动更新插件之后，新版清单随插件一起到达。仍与新清单一致的 EXE 直接沿用；不一致的 EXE 不会被自行替换，Helper 不一致时编辑器里的界面停用。再点一次 **WebUIStudio** 按钮，窗口会列出需要更新的文件，点“下载”即可，不需要手动删除旧文件。

## 进度、取消与恢复

“OrionBrowser 依赖”窗口显示检查、下载、校验、完成或失败，以及当前文件、已下载的字节数和进度。下载失败（包括没有网络）时，窗口显示 `OrionBrowser 依赖下载失败`（英文编辑器显示 `OrionBrowser dependencies failed to download`），下方保留失败原因，“重试”可用。点“取消”或者关闭窗口都会停止下载，并保留正式 EXE 同目录的 `.exe.part` 与 `.exe.part.json`，下次点“下载”时尝试 Range 续传。服务器不支持续传、返回完整文件时，会安全重置该下载，不会把完整响应追加到旧片段上。

只有完整文件的大小与 SHA-256 都符合清单，才替换正式 EXE。长度相同但内容损坏也视为无效；截断的现有 EXE 可以作为续传候选，但必须再次完成整文件校验。一次操作内每个程序最多自动尝试三次，失败后保留原因，排除问题后可重试。

多个编辑器或打包进程通过跨进程锁协调同一安装目录。请等待当前下载完成，不要手动启动或重命名 `.part` 文件。

## 离线导入

在能够联网的机器上打开[版本页面](https://github.com/IdealityCentury/OrionBrowser/releases)，按插件 `Config/OrionBrowserDistribution.json` 中每个 EXE 各自的 `releaseTag` 找到对应 **Tag** 取得该 EXE（两个 Tag 可以不同），复制到上文表格里的位置。保留插件附带的校验清单，不要对任意 EXE 重新生成清单来绕过校验。之后点击 **WebUIStudio** 按钮：文件相符时不弹出窗口，直接打开 WebUIStudio。也可在插件根目录执行下面的命令，它只核对，不下载：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Scripts\Ensure-OrionBrowserTools.ps1 -Component All
```

退出码 `0` 表示匹配，`1` 表示缺失或不一致并列出原因，`2` 表示取消。没有图形界面的构建机不能点按钮，可以在同一条命令末尾加上 `-Download`，由你显式下载缺少的文件。下载与校验使用 Windows PowerShell，不要求安装 Node 或 Python；制作网页需要 Node.js，见[教程 4](tutorial-4-write-by-hand.zh-CN.md#准备)。

## 目录权限

下载依赖需要插件目录可写。安装在受保护的引擎目录时，可能需要目录所有者授予适当写入权限，或者离线导入已验证文件。插件不会自动提权、修改目录权限、结束运行中的程序或改变下载位置。EXE 被占用、磁盘已满或目录不可写时，会显示失败原因。正常关闭相关工具、腾出空间或修复访问权限后重试。

反馈问题时提供插件版本、引擎版本、错误信息和工程 `Saved/OrionUE/OrionBrowser/Preparation` 下的相关日志。分享前移除私有路径及凭据。
