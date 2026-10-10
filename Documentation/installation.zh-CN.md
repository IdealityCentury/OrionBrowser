# 安装与自动准备工具

下文插件路径以 `OrionBrowser.uplugin` 所在目录为基准，工程路径以 `.uproject` 所在目录为基准。

## 安装

1. 使用 UE 5.8 / Win64。替换插件前正常关闭工程。
2. 通过 Fab 安装，或者把完整插件目录复制到工程的 `Plugins/OrionBrowser`。同一引擎与工程组合不要保留两个插件副本。
3. 打开工程，在 Plugins 中启用 **OrionBrowser**，按 Unreal 提示重启。插件使用 CommonUI 等引擎内置能力，不需要其他私有游戏框架。
4. 编辑器初始化后自动在后台检查两个配套程序。Helper 准备好之后才创建浏览器；Studio 的准备状态独立，下载 Studio 不阻塞已经可用的 WebUI。
5. 空白工程先按下文配置 CommonUI 视口；随附的猎户空间站工程已经包含此设置。
6. 在内容浏览器启用 **显示插件内容**，打开 `OrionBrowser/Showcase/L_OrionBrowserOverview`，点击运行。

每次打开工程不会自动启动 WebUIStudio。需要制作和预览页面时，使用关卡编辑器工具栏上的 **WebUIStudio** 按钮，见[教程 4](tutorial-4-webui-studio.zh-CN.md)。

宿主在构造 Widget 时读取默认浏览器材质，不要求 Helper 已经就绪。插件分别管理这些同步默认值和 CEF 初始化；Helper 校验完成后，等待中的 Widget 或后续浏览器请求通过同一个单例入口完成初始化，无须重建宿主 Widget 或重启 Editor。真正的 CEF 初始化失败会报告错误，后续单例访问不会循环重试。

## CommonUI 视口

OrionBrowser 会启用引擎的 CommonUI 插件。CommonUI 输入路由要求游戏视口继承 **CommonGameViewportClient**。在空白蓝图工程的 Project Settings 中，将 **Game Viewport Client Class** 设为 **CommonGameViewportClient**，然后重启编辑器。对应的工程 `Config/DefaultEngine.ini` 设置如下：

```ini
[/Script/Engine.Engine]
GameViewportClientClassName=/Script/CommonUI.CommonGameViewportClient
```

如果游戏已有自定义视口，保留该类并确保其继承 CommonGameViewportClient；直接替换可能丢失游戏原有的视口行为。插件不会覆盖工程的自定义视口。缺少此配置时，页面仍可能显示并响应鼠标点击，同时 CommonUI 报告输入路由错误，因此首次显示不能证明键盘和手柄路由已经就绪。不要用关闭诊断替代视口配置。

## 版本与固定位置

| 程序 | 插件内安装位置 | 用途 |
| --- | --- | --- |
| Helper | `Binaries/Win64/OrionBrowserHelper.exe` | 编辑器及成品游戏使用的浏览器子进程 |
| WebUIStudio | `Binaries/Win64/WebUIStudio.exe` | 界面制作与预览工具，不随游戏分发 |

随插件提供的 `Config/OrionBrowserDistribution.json` 为每个 EXE 单独写明 `releaseTag`，即存放它的 GitHub Release 精确 Tag，并固定它的字节数与 SHA-256。下载只使用这个 Tag，不读取 `latest`。两个 EXE 的 Tag 互相独立：插件更新中没有变化的 EXE 沿用原来的 Tag，因此插件 `1.0.1` 可以从 Tag `1.0.0` 取 Helper、从 Tag `1.0.1` 取 WebUIStudio。清单的 `version` 必须与 `OrionBrowser.uplugin` 的 `VersionName` 一致。CEF 库及资源随插件提供，必须与清单固定的 Helper 配套使用。

首次准备需要通过 HTTPS 访问 GitHub 及其发行附件托管站点。公开下载不需要 GitHub 登录或令牌。已有文件完整且哈希正确时，不访问 GitHub。该功能负责准备当前版本依赖，不会自动升级插件版本。

通过 Fab 或手动更新插件之后，新版清单随插件一起到达。下一次打开编辑器时，仍与新清单一致的 EXE 直接沿用，不一致或缺失的 EXE 自动重新下载、校验并替换，不需要手动删除旧文件。

## 进度、取消与恢复

原生编辑器通知显示检查、下载、校验、完成或失败，以及当前组件、下载字节数和进度。可以取消或重试。准备失败（包括没有网络）时，通知不会自动消失，标题变为 `OrionBrowser额外安装包下载失败`（英文编辑器显示 `OrionBrowser tools failed to download`），下方保留失败原因，**重试**按钮可用；通知文字跟随编辑器语言。取消后保留正式 EXE 同目录的 `.exe.part` 与 `.exe.part.json`，下次自动准备时尝试 Range 续传。服务器不支持续传、返回完整文件时，会安全重置该下载，不会把完整响应追加到旧片段上。

只有完整文件的大小与 SHA-256 都符合清单，才替换正式 EXE。长度相同但内容损坏也视为无效；截断的现有 EXE 可以作为续传候选，但必须再次完成整文件校验。一次操作内每个程序最多自动尝试三次，失败后保留原因，排除问题后可重试。

多个编辑器或打包进程通过跨进程锁协调同一安装目录。请等待当前准备完成，不要手动启动或重命名 `.part` 文件。

## 离线导入

在能够联网的机器上打开[版本页面](https://github.com/IdealityCentury/OrionBrowser/releases)，按插件 `Config/OrionBrowserDistribution.json` 中每个 EXE 各自的 `releaseTag` 找到对应 **Tag** 取得该 EXE（两个 Tag 可以不同），复制到上述固定目录。保留插件附带的校验清单，不要对任意 EXE 重新生成清单来绕过校验。重启编辑器即可验证，也可在插件根目录执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Scripts\Ensure-OrionBrowserTools.ps1 -Component All -CheckOnly
```

退出码 `0` 表示匹配，`1` 表示无效或不可用，`2` 表示取消。下载与校验使用 Windows PowerShell，不要求安装 Node 或 Python；制作网页需要 Node.js，见[教程 2](tutorial-2-build-it-yourself.zh-CN.md#准备)。

## 目录权限

自动准备需要插件目录可写。安装在受保护的引擎目录时，可能需要目录所有者授予适当写入权限，或者离线导入已验证文件。插件不会自动提权、修改目录权限、结束运行中的程序或改变下载位置。EXE 被占用、磁盘已满或目录不可写时，会显示失败原因。正常关闭相关工具、腾出空间或修复访问权限后重试。

反馈问题时提供插件版本、引擎版本、错误信息和工程 `Saved/OrionUE/OrionBrowser/Preparation` 下的相关日志。分享前移除私有路径及凭据。
