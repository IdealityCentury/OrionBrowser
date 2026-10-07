# 打包与故障排查

工程路径相对 `.uproject` 目录，插件路径相对 `OrionBrowser.uplugin` 目录。完整插件与同版本 CEF SDK 必须配套。

## 标准打包

使用 Unreal 正常 Win64 打包或 Project Launcher。插件在 Editor Cook 准备入口校验 Helper，必要时下载，再把已验证文件复制到工程 `Binaries/Win64/OrionBrowserHelper.exe`。准备失败会报告错误并请求非零 Cook 退出。Cook 不需要 Studio。

CEF DLL、资源、语言包及版权声明通过 NonUFS 收录，Helper 也是 NonUFS。工程 `Content/UI/WebUI/<AppId>/dist` 和插件 `WebUIApps/<AppId>/dist` 的生产文件作为 UFS 资源收录。制作源码、`node_modules`、Studio 和未完成下载不属于游戏发行内容。

打包实际使用的关卡及资产。动态选择或软引用资产可能需要额外 Asset Manager 规则。声音、字体、纹理和 App Definition 应由已 Cook 资产引用；在 JSON 里写资产名不会自动形成 Cook 依赖。

## 固定命令行入口

插件 `Scripts/Package-OrionBrowserProject.ps1` 在固定 BuildCookRun 命令前复用 Helper 预检。以参数提供引擎根目录、精确工程文件和输出目录。在插件根目录执行：

```powershell
.\Scripts\Package-OrionBrowserProject.ps1 -EngineRoot $EngineRoot -ProjectFile $ProjectFile -ArchiveDirectory $ArchiveDirectory -Configuration Shipping
```

示例工程还提供 `Scripts/Package-Development.ps1` 与 `Scripts/Package-Shipping.ps1`，均接受 `-EngineRoot`。重复 Stage 已 Cook 内容时，对插件入口传入 `-ReuseCooked`；即使跳过编译和 Cook，也会检查 Helper。复用内容必须已经与当前工程、插件及配置匹配，该选项不会更新过期的 Cook 资产。

普通 Unreal C++ 编译和 BuildPlugin 不下载工具。不要在 Build.cs 构造函数中下载。`Scripts/Build-FabPlugin.ps1` 使用官方 RunUAT BuildPlugin，对新输出目录执行 Win64 插件构建。

插件描述文件还声明了 Editor 构建后步骤：`Prepare-OrionCEFRuntime.ps1` 将随包的匹配 CEF 运行文件复制到插件 `Binaries/Win64/OrionCEF3`。这只准备本地文件，用于补齐官方插件预编译过滤普通运行依赖复制动作的情况，不下载配套 EXE。

## 成品游戏

Development 与 Shipping 游戏使用打包到游戏二进制旁的 Helper，不进行 EXE 存在性预检、版本/哈希检查、下载或修复。缺失或损坏文件仍可能产生正常的操作系统或 CEF 启动错误，此时应修复发行包。

验证迁移运行时要复制**整个归档目录**，包含工程目录、引擎运行资源、必要前置组件和松散浏览器依赖，不能只复制顶层启动 EXE。本地界面无需联网；官网面板等明确远程内容除外。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| 准备返回 404 | 核对 VersionName、同名 Release Tag 及附件名，不替换成 latest 或其他版本。 |
| 下载中断 | 保留 .part 和续传记录，重试；续传完成仍会计算完整哈希。 |
| 大小相同却校验失败 | 从同一不可变 Release 重新获取，长度不能代替完整性校验。 |
| 无权限或文件占用 | 修复访问权限，或正常关闭占用程序；插件不会提权或结束它。 |
| 本地空白页面 | 核对 AppId、dist/index.html、生产构建及 AppDefinition，检查 On Web Error 与浏览器控制台。 |
| Studio 正常但 Unreal 不响应 | 核对事件/请求绑定、事件名、参数类型和蓝图校验；预览数据不执行业务。 |
| Editor 正常但包体缺失 | 核对 Cook 资产引用、关卡列表、UFS/NonUFS 收录，生产资源变化后重新打包。 |
| CEF 启动异常 | DLL、资源、Helper 必须同版本，不混用其他插件或引擎浏览器运行库。 |
| Helper 源码构建被拒绝 | 安装版引擎可能不支持 Program Target。普通用户使用已验证发行 EXE；重建需要兼容的源码引擎。 |

## 从源码重建 Helper

插件附带 Helper 源码，以及 `Scripts/BuildSupport/OrionBrowserHelper.Target.cs.template`。在支持 Program Target 的源码引擎宿主工程中，把模板复制到工程 `Source/OrionBrowserHelper.Target.cs`，安装本插件，使用匹配的 Win64 工具链构建。模板会把结果复制到现有插件二进制位置。正常使用纯蓝图示例时不需要添加这个 Target。

任何配套二进制内容变化都应递增插件版本，发布新的同名 Tag。用最终 EXE 生成校验清单，将同一清单放入插件与 Release，不覆盖已经发布版本的附件。
