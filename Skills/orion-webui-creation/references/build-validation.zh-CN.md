# 构建、检查与验证

新建或修改 WebUI App 之后按本文构建、检查并分层报告。工程骨架见 [Web App 脚手架](web-app-scaffold.zh-CN.md)，InstantScreen Package 的配置与排错见 [InstantScreen](instant-screen.zh-CN.md)。

## 先读宿主规则

- 先读宿主工程的指令文件（`AGENTS.md`、`CLAUDE.md` 等，包括 `<WebUIRoot>` 目录下的同类文件）。其中的构建命令白名单（Unreal 编译、Cook、打包的固定参数）、测试授权（能否启动 Editor、PIE、包体或浏览器验证）和额外门禁（宿主自己的合同脚本、确定性校验、换行与编码要求）优先于本文。
- 本文只描述插件提供的工具和通用顺序。没有被授权的验证层不执行，交付时写“未执行”，不用别的层代替。
- 只改文档不触发 Web 构建；已通过的检查只在后续改动影响其结论时重跑。

## 端到端顺序

| 步骤 | 工作目录 | 命令 | 何时需要 |
| --- | --- | --- | --- |
| 1 安装依赖 | `<WebUIRoot>/<AppId>` | `npm ci` | 首次或锁文件变化；新 App 第一次用 `npm install` 生成锁文件 |
| 2 类型检查 | 同上 | `npm run typecheck` | App 实现变化 |
| 3 既有测试 | 同上 | `npm test` | 同上；只验证局部时可传单个测试文件 |
| 4 生产构建 | 同上 | `npm run build` | 同上 |
| 5 共享 Runtime | `<OrionBrowser>/Content/UI/WebUI/Shared` | `npm ci`（一次），`npm run instant:runtime:syntax`，`npm run instant:runtime:build`，`npm run instant:runtime:check` | 仅当工程使用 InstantScreen；`build` 只在插件 Runtime 源码变化或生成目录不存在时运行，平时只跑 `check` |
| 6 InstantScreen Package | `<OrionBrowser>/Content/UI/WebUI/Shared` | `npm run instant:build -- --app <AppRoot>`，再对每个 route 运行 `npm run instant:validate -- --package <AppRoot>/dist/instant/routes/<route>` | App 带 `instant-screen.config.ts` |
| 7 全工程校验与按 App 的合同检查器 | `<OrionBrowser>/Content/UI/WebUI/Shared`；检查器在 `<ProjectRoot>` | 见“插件脚本清单”第三、五组 | 仅当宿主工程在用这些校验 |
| 8 Unreal 编译 | `<ProjectRoot>` | 宿主工程规定的构建命令 | 改了 C++、蓝图可见接口、资产接入或配置 |
| 9 Studio 发现检查 | `<ProjectRoot>` | `WebUIStudio.exe --project … --check-discovery --app <AppId>`，见 [WebUI Studio 预览合同](studio-preview.zh-CN.md) | 新建 App，或改了路由、预览状态导出、`webui-preview.json` |

- 第 4 步必须在第 6 步之前：`vite build` 会清空 `dist`，连带删除 `dist/instant`；Package 构建器又要从 `dist/index.html` 解析入口模块。之后每重新 build 一次，都要重做第 6 步。
- 类型检查与构建互不替代：Vite 不做类型检查，`vue-tsc` 不产出 Bundle。
- 构建器串行运行：不同时启动两个 Package 构建，也不在它运行期间重新 build 同一个 App。
- 第 5、6、7 步的脚本依赖插件目录自己的 `node_modules`，所以要先在 `<OrionBrowser>/Content/UI/WebUI/Shared` 执行一次 `npm ci`；App 内 `npm test` 调用的合同脚本只用 Node 内置模块，不需要。
- 空 route 的包目录名是 `default`。

```powershell
function Invoke-Checked
{
	param([string]$Name, [scriptblock]$Command)
	& $Command
	if ($LASTEXITCODE -ne 0)
	{
		throw "$Name failed with exit code $LASTEXITCODE"
	}
}

$AppRoot = (Resolve-Path '<WebUIRoot>/<AppId>').Path
$BrowserWebUI = (Resolve-Path '<OrionBrowser>/Content/UI/WebUI/Shared').Path

Push-Location $AppRoot
try
{
	Invoke-Checked 'npm ci' { npm.cmd ci }
	Invoke-Checked 'typecheck' { npm.cmd run typecheck }
	Invoke-Checked 'test' { npm.cmd test }
	Invoke-Checked 'build' { npm.cmd run build }
}
finally
{
	Pop-Location
}

Push-Location $BrowserWebUI
try
{
	Invoke-Checked 'instant:build' { npm.cmd run instant:build -- --app $AppRoot }
	Invoke-Checked 'instant:validate' { npm.cmd run instant:validate -- --package (Join-Path $AppRoot 'dist\instant\routes\default') }
}
finally
{
	Pop-Location
}
```

## 插件脚本清单

以下是 `<OrionBrowser>/Content/UI/WebUI/Shared/package.json` 里的 script 实际做的事；表中 `scripts/…`、`src/…` 都相对 `<OrionBrowser>/Content/UI/WebUI/Shared`，除标明 App 目录的入口外，都在该目录下运行。

第一组，App 级，任何工程可直接使用：

| 入口 | 实际执行 | 参数与结果 |
| --- | --- | --- |
| App 内 `npm test` | `scripts/test-webui-app-contract.mjs`，以当前目录为 App 根 | 无参数。检查 `orionWebUI` 四个字段、`vite.config.ts` 里的两段字面量、`src/App.vue` 存在、`src` 内的禁用样式与 `<img decoding="async">`。成功打印 `Validated <AppId> WebUI app contract.` |
| `instant:build` | `scripts/build-instant-screen-package.mjs` | `--app <AppRoot>` 必填（也接受第一个位置参数），`--config <path>` 默认 `<AppRoot>/instant-screen.config.ts`，`--chrome <path>` 指定浏览器。用 App 的 `vite.config.ts` 起临时 dev server，以无头 Chrome 或 Edge 截取 DOM，写入 `<AppRoot>/dist/instant/routes/<route>/` 并逐包自检。成功打印 `InstantScreen built: <ScreenId> route=… path=…` |
| `instant:validate` | `scripts/validate-instant-screen-package.mjs` | `--package <PackageDir>` 可重复（也接受位置参数）。目录是含 `package.header` 的具体 route 包目录，不是 App 根。成功打印 `InstantScreen valid: <ScreenId> bindings=… actions=… path=…` |

第二组，只处理插件自身源码，输出写入宿主的 `<WebUIRoot>`；宿主的位置按下文“定位宿主工程”确定：

| 入口 | 实际执行 | 参数与结果 |
| --- | --- | --- |
| `instant:runtime:syntax` | `node --check ./src/instant-screen-runtime/runtime.js` | 只做语法检查 |
| `instant:runtime:build` | `scripts/build-instant-screen-runtime.mjs` | 除定位参数外不接受其他参数。把 `src/instant-screen-runtime` 打包写入 `<WebUIRoot>/__instant__/dist/runtime/`（`index.html`、`runtime.css`、`runtime.js`、`runtime-optional.js`），目录不存在时创建，逐文件打印 sha256。源文件必须是 CRLF；启动脚本超过脚本内的体积上限即失败 |
| `instant:runtime:check` | 同一脚本加 `--check` | 不写文件，只比对生成目录与当前源码的构建结果，文件集合或内容不一致即失败 |

第三组，全工程校验，一次扫描 `<WebUIRoot>` 下的所有 App；同样按“定位宿主工程”确定位置：

| 入口 | 实际执行 | 检查内容 |
| --- | --- | --- |
| `contracts:project` | `scripts/validate-project-webui-contracts.mjs` | `<WebUIRoot>` 下每个含 `package.json` 的目录（跳过 `node_modules`、`dist`）都必须：带 `webui-button-contract.json` 且源码里的 Bridge 调用全部登记；`orionWebUI` 声明合法、profile 与 lifecycle 匹配；已经构建出 `dist/assets/index-<interface-name>.js`；产物文件名与内容不含预览、fixture 信号，manifest 与包头不含已废弃的哈希、摘要字段；`dist` 里每个 `package.header` 通过包校验。另外 `<WebUIRoot>/Shared/src` 里不得直接调用 Bridge |
| `contracts:intents` | `scripts/validate-webui-intent-contracts.mjs` | `<WebUIRoot>` 第一层每个含 `package.json` 的目录都要通过 Intent 合同校验；宿主维护了审计清单时，发现的 App 还必须与清单完全一致 |
| `images:decoding:check`、`images:decoding:fix` | `scripts/enforce-webui-image-decoding.mjs`，`fix` 加 `--write` | 扫描 `<WebUIRoot>` 下全部 `.vue` 与非测试 `.ts`，`<img>` 没有 `decoding` 属性即失败；`fix` 直接改写源码并把改动文件统一成 CRLF |
| `animations:contract:check`、`animations:contract:fix` | `scripts/enforce-webui-animation-contract.mjs`，`fix` 加 `--write` | 扫描 `<WebUIRoot>` 下全部 `.css`、`.vue`，拒绝 `prefers-reduced-motion`、`backdrop-filter:`、`mix-blend-mode:` 以及 `transition` 中的 `filter`，并检查插件自身的生命周期源码；`fix` 会删除命中的声明和规则，并改写所有换行不是 CRLF 的被扫描文件 |

第四组，只读取插件自身文件，不需要宿主工程：

| 入口 | 实际执行 | 说明 |
| --- | --- | --- |
| 插件自己的 `npm test` | `vitest run` 加固定的测试文件清单 | 只读取 `<OrionBrowser>` 下的源码和脚本。读取宿主源码、配置或具名 App 的合同测试属于宿主工程，由宿主自己维护和运行 |
| `<OrionBrowser>/Content/UI/WebUI/Shared` 的 `typecheck` | 检查共享前端运行库和构建工具的类型 | 不生成示例页面 |
| `<OrionBrowser>/Content/UI/WebUI/Sample` 的 `dev`、`build`、`typecheck`，以及 `<OrionBrowser>/Scripts/Build-OrionWebUI.ps1` | 开发、检查或构建插件基础示例 | 产物写到 `<OrionBrowser>/Content/UI/WebUI/<AppId>/dist`，AppId 取环境变量 `ORION_WEBUI_APP_ID`（默认 `Sample`）。不是宿主 App 的构建入口 |

`scripts/test-webui-stable-packages.mjs` 没有注册成 npm script：`--package <包目录>` 必填，传入宿主任意一个已构建的 route 包目录（`<AppRoot>/dist/instant/routes/<route>`），只读取不修改。它会加载插件的 TypeScript 源码，需要能直接运行 `.ts` 的 Node（Node 22 加 `--experimental-strip-types`）。

第五组，`<OrionBrowser>/Scripts` 下按 App 运行的 PowerShell 检查器（Windows PowerShell 5.1 与 PowerShell 7 均可），参数以脚本自己的 `param(...)` 为准：

| 脚本 | 参数 | 说明 |
| --- | --- | --- |
| `check-webui-rendering-contract.ps1` | `-Path <AppRoot>` | 渲染合同：稳定产物命名、交互元素的字面量 ControlId 等。只接受 `-Path` |
| `check-webui-button-interface-contract.ps1` | `-Path <AppRoot> -ProjectRoot <ProjectRoot>`，可加 `-Check` 或 `-UpdateDocumentation`（二选一） | 按 `webui-button-contract.json` 核对模板里的按钮标记、ControlId、点击表达式、禁用条件与 C++ 的分发、Native 接口和 guard；合同里的源码与文档路径都相对 `-ProjectRoot`。默认与 `-Check` 还要求 `documentation` 指向的接口文档存在且是最新；`-UpdateDocumentation` 先生成该文档再校验。成功打印 `OK: …`，失败逐条打印 `ERROR: …` 并以 1 退出 |

`check-component-button-contract.ps1` 由按钮检查器在合同含 `componentControls` 时自动加载，不单独运行。

### 定位宿主工程

第二、三组脚本按以下顺序确定宿主工程，与插件装在哪里无关：

1. 命令行 `--project-root <dir>`（WebUI 根取 `<dir>/Content/UI/WebUI`）或 `--webui-root <dir>`，也可写成 `--name=value`。
2. 环境变量 `ORION_PROJECT_ROOT`、`ORION_WEBUI_ROOT`。
3. 从当前工作目录向上找到第一个含 `.uproject` 的目录；找不到再从插件目录向上找。

- 插件位于工程目录内时不需要任何参数。插件装在引擎目录时显式指定：`npm.cmd run contracts:project -- --project-root <ProjectRoot>`，或先设置环境变量。
- 自动发现找到的是“最近的含 `.uproject` 的上级目录”。在工程目录内部的局部工作区副本（自己没有 `.uproject` 的草稿、隔离校验目录）里运行时必须显式传 `--project-root <副本根>`，否则校验的是外层的真实工程而不是副本。
- 定位失败报 `Cannot locate the host project`，目录不存在报 `Host project root was not found` 或 `Orion WebUI root was not found`，消息里写明该传哪个参数。
- App 清单由发现得到：`<WebUIRoot>` 第一层含 `package.json` 的目录。宿主可以在 `<WebUIRoot>/orion-webui-apps.json` 维护一份审计清单（`{ "apps": ["<AppId>", …] }`）：文件存在时 `contracts:intents` 要求它与发现结果完全一致，不存在时只按发现结果校验。`--app-inventory <file>` 可指定另一份清单，此时文件必须存在。
- 根清单可用 `additionalRoots` 声明其他 Content 中的 WebUI 根：路径相对该清单文件，必须是相对路径。`contracts:intents` 分别核对各根的本地 App 清单；项目合同、图片与动画检查覆盖全部声明根。该字段不替代 Unreal 的 RuntimeDependencies，玩法模块仍须收录自己的 dist。
- App 的 `vite.config.ts` 调用 `createOrionWebUIVueOptions(rootDir)` 时，以 App 根目录的上一级作为 `<WebUIRoot>`；宿主把 WebUI 根放在别处时设置 `ORION_WEBUI_ROOT`；跨 Content 复用组件时，在第二参数传入共享组件所属的 WebUI 根数组，以保持原有 CSS scope 名称。

新增 App 时：

- 宿主工程在用 `contracts:project` 或 `contracts:intents`：新 App 必须带 `webui-button-contract.json`（见 [控件与资源](controls-resources.zh-CN.md)）并先完成 production build，否则整轮校验失败。宿主维护了 `orion-webui-apps.json` 时把新 App 加进去。
- `images:*` 与 `animations:*` 不需要登记，但会扫描到新 App。两个 `fix` 变体会改动所有 App 的源码，只在用户明确要求时运行；平时跑 `check`，手工修自己的 App。
- 宿主工程没有使用这些校验时，不为新 App 主动引入，只跑第一组命令。
- 宿主自己的门禁（Package 双轮确定性校验、读取宿主源码的合同测试、npm 包装脚本等）不随插件提供，入口以宿主指令文件为准。

## PowerShell 与命令行要点

- 外部程序失败不会终止 PowerShell 脚本。每条 npm / node 命令之后检查 `$LASTEXITCODE`；PowerShell 脚本自身不保证设置它，调用 `.ps1` 时看 `$?` 或让失败直接抛出，不拿上一条原生命令遗留的退出码判断。
- 在 PowerShell 里写 `npm.cmd`。裸 `npm` 可能解析到 PowerShell shim，`--` 及其后的参数会被吞掉或被 npm 当成自己的配置。参数仍传不到脚本时，改为在同一目录直接运行 script 对应的 `node ./scripts/<脚本>.mjs …`。
- 宿主若用自己的 `.ps1` 包装 npm，且参数声明为 `ValueFromRemainingArguments`，裸写 `& $Wrapper run instant:build -- --app …` 会把 `--` 当成参数边界吞掉。先组一维数组再 splat：`$Arguments = @('run', 'instant:build', '--', '--app', $AppRoot)`，然后 `& $Wrapper @Arguments`。验证多个包时为每个目录各追加一组 `'--package'`、`<目录>`。
- 调用仓库内的 `.ps1` 先 `Resolve-Path` 得到完整路径再用 `&`；`Push-Location` 之前把日志和证据目录解析成绝对路径。
- 校验 `package-lock.json` 时用 `Get-Content -Raw | ConvertFrom-Json -AsHashtable`（PowerShell 7 及以上）：锁文件的 `packages[""]` 是空字符串键，普通 `ConvertFrom-Json` 会报空属性名。旧版 PowerShell 改用 Node 的 `JSON.parse`。不要为此删除 `packages[""]`。
- Vitest 不接受 Jest 的 `--runInBand`。单个文件用 `npm.cmd test -- <相对测试文件>`，收敛日志用 `--silent=true`，不要写成 `--silent <文件>`。只有 `test` script 是 `vitest run` 时才能这样传文件。

## 失败签名

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `typecheck` 只打印 `Version …`，随后是 `COMMON COMMANDS`、`COMMAND LINE FLAGS` 帮助 | `vue-tsc` 在当前目录没找到 `tsconfig.json`，没有检查任何文件 | 这不是通过。补上 `tsconfig.json` 或回到 App 根重跑 |
| Vitest 报 `Unknown option` | 传了测试运行器不认识的参数 | 修正命令后重跑；既不记成测试失败也不记成通过 |
| `Unknown cli config "--…"`，或脚本抛出 `Usage: npm run instant:…` | `--` 之后的参数没传到脚本 | 用 `npm.cmd`，或直接 `node ./scripts/<脚本>.mjs` |
| `ERR_MODULE_NOT_FOUND`，缺 `vite`、`esbuild` 或 `typescript` | 没在 `<OrionBrowser>/Content/UI/WebUI/Shared` 安装依赖 | 在该目录执行 `npm ci` |
| `Chrome or Edge was not found; set ORION_INSTANT_SCREEN_CHROME` | 默认安装位置没有浏览器 | 传 `--chrome <path>` 或设置该环境变量 |
| `instant:build` 报 `ENOENT`，路径指向 `dist/index.html` | 还没有 production build | 先完成第 4 步 |
| `instant:validate` 报 `ENOENT`，路径指向 `package.header` | 传进去的是 App 根 | 传 `dist/instant/routes/<route>` |
| `Chromium capture did not contain a rendered #app` | 页面在无宿主的设计预览里没有渲染出结构 | 见 [Web App 脚手架](web-app-scaffold.zh-CN.md) 的“设计预览”，不靠加等待或重试解决 |
| `InstantScreen Runtime source must use CRLF` | 插件 Runtime 源文件被检出成 LF | 恢复 CRLF 检出，不改脚本 |
| `Generated InstantScreen Runtime is stale` 或 `output file set mismatch` | 生成目录落后于插件源码 | 运行 `instant:runtime:build` 后再 `check` |
| `Cannot locate the host project`，或 `Orion WebUI root was not found` | 脚本不在工程目录内运行，或工程没有 `Content/UI/WebUI` | 按“定位宿主工程”传 `--project-root` / `--webui-root` 或设置环境变量 |
| `WebUI Apps under … do not match …; update the audited inventory explicitly` | 宿主的 `orion-webui-apps.json` 与目录里的 App 不一致 | 核对消息里列出的两组名字，更新清单 |
| `declared event source was not found`，或 `missing <object> = { ... } as const` | `intentTransport` 的 `eventConstants` / `eventExpansions` 指向的文件或对象不存在 | 修正合同里的 `file` 与 `object` |
| `missing button/intent contract` | 全工程校验扫到没有 `webui-button-contract.json` 的 App | 为该 App 补合同 |
| `vite build` 清理 `dist` 时报 `EPERM … unlink` 或文件被占用 | `dist` 里的文件被别的进程打开，常见是把预览日志写进了 `dist`，或 IDE、Git 客户端正在扫描 | 确认占用者；只停止本轮自己启动的进程，不结束用户的程序，空闲后重跑 |

失败时保留第一个有效错误。不通过更新快照、跳过测试、降低断言、提高超时或手改 `dist` 让命令变绿。

## 验证分层

| 层 | 手段 | 能证明 | 不能证明 |
| --- | --- | --- | --- |
| 静态 | App 合同脚本、全工程校验、Studio 发现检查、源码与 diff 检查 | 声明、命名、禁用样式、控件与 Intent 登记在文本层面一致；Studio 列得出页面与视图、找得到预览状态 | 代码能编译、页面能显示 |
| 类型与构建 | `typecheck`、单元测试、production build、Package 校验 | 类型正确、被测逻辑正确、Bundle 与包结构合法并通过构建门禁 | CEF 里的渲染、字体、输入、Bridge 时序 |
| 浏览器预览 | Vite dev 或 `vite preview`，加 DOM、计算样式、截图、console | 无宿主分支下的布局、样式、预览状态切换，没有脚本错误 | 真实 Bridge 与 C++ 状态、展示事务、UE 字体与声音、Native Surface、UE 输入路由、离屏透明合成 |
| Editor 设计器 | UMG Designer 里的 WebUI 控件 | AppDefinition 经本地 Scheme 到 `dist` 或 dev server 的加载链路，CEF 离屏渲染结果 | 运行时行为：Designer 带 `orionDesignPreview=1`，页面不等待宿主，也没有游戏运行时的权威状态、展示事务与输入路由 |
| PIE | 已授权的编辑器内运行 | 真实 Bridge、C++ 权威状态与 Intent、展示事务、真实键鼠与手柄输入、Native Surface、声音 | Cook 后的资产、`dist` 是否进包、发行配置下的行为与性能 |
| 包体 | 已授权的打包运行 | `dist` 进包并能离线加载，目标配置下的实际行为 | 其他平台与配置；没有实际操作到的页面和状态 |

- 上一层通过推不出下一层，每层单独下结论。浏览器预览、静态 DOM、JS `.click()`、截图文件存在、Web build 成功，都不等于 Unreal 内的 Native Surface、真实输入或包体证据。
- 证据只用本轮产物：先确认被预览或运行的就是刚构建的 `dist`，不复用旧截图。
- Editor 开着时重新构建同一 App 的 `dist`，文档会自动重载（`UOrionWebUIAppDefinition.bAutoReloadLocalDistInEditor`，日志含 `after stable local dist entry change`）。这只说明新产物已被加载。
- Web-only 改动跑 Web 层；同时改了 C++、蓝图可见接口、资产或配置时还要编译对应 Unreal Target。是否启动 Editor、PIE、包体按宿主授权。

## 浏览器视觉验收

1. 用本轮 production `dist`：构建后在 App 根运行 `node .\node_modules\vite\bin\vite.js preview --host 127.0.0.1 --port <Port> --strictPort`。不要假设存在 `preview` script，不用 `npm exec vite -- preview`，也不为一次验收修改 `package.json`。后台启动时把 `vite.js` 与 App 根都写成绝对路径（`node <AppRoot>\node_modules\vite\bin\vite.js preview <AppRoot> …`），否则可能服务到另一个 App。端口占用的处理见 [Web App 脚手架](web-app-scaffold.zh-CN.md) 的“设计预览”。
2. 打开页面前先请求首页，确认标题和 `index-<interface-name>.js` 属于目标 App；属于别的 App 就停下，不在错误页面上继续。
3. production 预览没有宿主，页面只走无宿主分支。预览数据只存在于 DEV 分支时，production 预览只能验证结构和 console；带数据的画面改用 dev server，并在结论里写明用的是哪一种。
4. 视口固定为页面的设计逻辑分辨率，设备像素比固定；另取一种非目标长宽比，确认整体等比缩放、没有滚动条和裁切。
5. 等正式展示流程结束再截图：以页面自身的展示状态或有限动画全部结束为准，不用固定延时猜。需要过渡中间帧时单独标注。
6. 画面状态只通过页面的预览输入驱动（query 参数、预览状态）。不注入 CSS、不改 class、不改 `display` 或 `opacity` 把元素强行显示或隐藏来得到截图。
7. 用一次只读脚本收集结构化证据：关键节点的边界与计算样式、图片 `complete && naturalWidth > 0`、console 错误。
8. 文字检查用最长文案、可选字段存在与缺失两种数据、列表最大项数：不得溢出、截断或重叠；固定页脚和操作区保持在面板内。
9. `html`、`body`、`#app` 的计算背景为透明，最外层文档没有横向或纵向溢出。
10. 两种输入设备分别取证：键鼠的 hover、pressed，手柄的焦点高亮与按键提示。无头或隐藏的浏览器里移动坐标可能不触发 `:hover`，取不到就交给组件测试并如实标注，不伪造。
11. 点击前确认定位器只命中一个元素，点击后读取 DOM 的实际状态再截图。JS `.click()` 只证明处理函数存在，不证明真实输入可达。
12. 实际打开截图查看，不只确认文件存在；核对它是本轮生成的、扩展名与真实格式相符、像素尺寸正确。发现问题回到源码修改并重新构建，受影响的证据整套重拍。
13. 截图和日志写到 `dist` 与源码目录之外、宿主约定的位置；结束时只停止本轮记录了 PID 的预览进程，并确认端口已释放。

## 交付清单

1. 改动：新增与修改的源码、`dist`、锁文件，以及 UE 侧的 C++、资产、配置。
2. 命令：实际执行的每条命令、工作目录和退出码；失败的给出第一个有效错误。
3. 分层结论：静态、类型与构建、浏览器预览、Editor 设计器、PIE、包体六层，各写“已验证（证据位置）”“未执行（原因）”或“不适用”。
4. InstantScreen：Package 是否在最后一次 production build 之后重新生成并逐包校验。
5. 全工程校验：宿主是否在用、是否运行、新 App 是否完成登记（按钮合同、宿主的 App 审计清单）。Studio 发现检查的退出码、报告位置，以及报告列出的页面与视图。
6. 遗留：未验证的状态与风险、需要用户授权才能继续的验证层；确认没有留下预览进程、临时文件，`node_modules` 没有进入版本控制。
