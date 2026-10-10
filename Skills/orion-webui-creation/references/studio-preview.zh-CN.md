# WebUI Studio 预览合同

让新建的 App 在插件自带的 WebUI Studio（`<OrionBrowser>/Binaries/Win64/WebUIStudio.exe`）里被完整发现：列出每个页面和子界面，打开时带着预览数据。工程骨架见 [Web App 脚手架](web-app-scaffold.zh-CN.md)，路由配置见 [InstantScreen](instant-screen.zh-CN.md)，构建顺序见 [构建与验证](build-validation.zh-CN.md)。

## Studio 怎样发现一个 App

Studio 只读文件，不执行工程代码：发现阶段对源码和配置做静态解析，写法超出它能读的范围时，结果是 App 不出现、页面缺失，或页面打开后停在空状态，而不是报错。

| Studio 要得到的 | 读取位置 | 写法要求 |
| --- | --- | --- |
| App 本身 | 工程里任意层级、名为 `WebUI` 的目录之下，带 `orionWebUI` 声明的 `package.json`（或 `index.html`、`dist/index.html`）所在目录 | `orionWebUI.appId` 即 AppId；`node_modules`、`dist`、`Saved`、`Intermediate`、`Binaries` 和目录链接不参与查找 |
| 源码预览 | `src/main.ts`，以及 App 自己的 `node_modules`（含 Vite） | 没装依赖时只能预览 `dist` |
| 页面（路由） | `instant-screen.config.ts` 的 `screens`，以及 `dist/instant/routes/<route>/package.header` | 配置是纯字面量的 `export default { ... } as const;`：只含字符串、数字、布尔、数组和普通键的对象，不引用变量、不展开、不调用函数、不用计算属性名。每个 route 都要构建出 `package.header`，两处的 `screenId` 一致 |
| 状态事件、回执与 revision 字段 | `webui-button-contract.json` 的 `cpp.stateChangedEvent`、`cpp.stateAcknowledgementEvent`；没有时从源码里的字面量匹配 | 事件名写成字符串字面量（`"ue:<前缀>.stateChanged"`、`"<前缀>.stateApplied"`），不拼接；页面用 `stateCommitted(<状态>.stateRevision)` 回执 |
| 预览状态 | `src` 下导出的预览状态，或 `webui-preview.json` 指定的导出 | 见“预览状态” |
| 视图 | `webui-preview.json` 的 `views` | 见“视图” |

没有 `instant-screen.config.ts` 的 App 只有一个页面，路由是空字符串。

## 预览状态

Studio 给页面装的是模拟 Bridge：`resolveOrionWebUIForMount()` 拿到的 `api` 存在，页面走有宿主的分支，等状态事件送来快照。所以只在 `api` 为 `undefined` 时才加载的预览数据在 Studio 里不会出现；Studio 需要自己取到这份数据，再经状态事件下发。每个 App 都要导出一份预览状态：

- 放在 `src` 下的独立模块，例如 `src/model/<interface-name>-preview.ts`。它同时供页面的无宿主回退分支动态 `import()`，生产入口不静态导入它；Studio 直接从源码加载这个模块，与它是否进入 `dist` 无关。
- 导出名同时含 `preview` 与 `state`（不分大小写），例如 `create<AppId>PreviewState`。导出可以是常量，也可以是函数；函数可以返回 Promise。
- 形状与 C++ 发布的完整状态快照一致，能经 `JSON.stringify` 往返：不含函数、`Map`、`Set`、类实例和循环引用。revision 字段由 Studio 改写，填什么都可以。
- 函数的参数全部带默认值。Studio 调用时不知道该传什么：带必填参数的导出会被跳过，页面停在空状态。确实需要参数（例如场景名）时，在 `webui-preview.json` 的 `state.args` 或各视图的 `args` 里写明。
- 多路由的 App，用默认参数从 `window.location.hash`（`#/<route>`）取当前路由，返回该路由的状态；Studio 取数据时带着页面的路由。
- 图片、字体等资源用 Vite 的资源导入得到 URL，位置在 App 的 `src` 或 `<WebUIRoot>/Shared/src` 下；Studio 预览 `dist` 时会把它们换成缓存副本。

```ts
import type { SamplePanelState } from "./sample-panel-state";

/** 设计预览与 WebUI Studio 共用的示例快照；原生宿主存在时页面不加载本模块。 */
export function createSamplePanelPreviewState(view = "main"): SamplePanelState {
	return { stateRevision: 1, ready: true, view, title: "Sample Panel", rows: [] };
}
```

- 同一个 App 里有多个符合命名的导出时，Studio 按名字猜一个并给出提示。要确定用哪一个，在 `webui-preview.json` 的 `state` 里指明。
- 另外两种来源 Studio 也认，但只适合很小的页面：`App.vue` 顶层名为 `state` 的变量，初始值是纯字面量（`ref({ ... })` 这类；初始值里有函数调用就读不出）；或导出名形如 `create…Preview…WebUIApi` 的预览 Bridge 适配器，由它自己提供状态和模拟交互。

## 视图

子界面有两种做法，Studio 的处理不同：

- 独立的页面做成路由：在 `instant-screen.config.ts` 的 `screens` 里各占一项。Studio 直接把每个路由列为一个页面，不需要别的声明。新界面优先这样做。
- 同一路由内由状态切换的子界面（C++ 在同一份快照里发布 `view` 之类的字段，页面按它显示装备页、选项页、HUD 的各个状态）。路由里看不出它们，Studio 称为视图，必须在 App 根目录的 `webui-preview.json` 里逐个声明，否则列表里只有路由，子界面找不到。

`webui-preview.json` 是纯数据，Studio 只读取、不执行；它不进 `dist`，不随游戏打包。

```json
{
	"schemaVersion": 1,
	"state": {
		"module": "src/model/sample-panel-preview.ts",
		"export": "createSamplePanelPreviewState"
	},
	"views": [
		{ "id": "main", "route": "panel", "title": "主面板", "args": ["main"] },
		{
			"id": "detail",
			"route": "panel",
			"title": "详情",
			"args": ["detail"],
			"enter": ["samplePanel.openDetailRequested"],
			"leave": ["samplePanel.detailBackRequested"]
		},
		{ "id": "options", "route": "panel", "title": "选项", "args": ["main"], "patch": { "view": "options" } },
		{
			"id": "confirm",
			"route": "panel",
			"title": "确认弹窗",
			"events": [
				{
					"name": "ue:samplePanel.confirmChanged",
					"payload": { "presentationRevision": "$presentationRevision", "title": "确认退出" }
				},
				{
					"name": "ue:samplePanel.confirmEnterRequested",
					"at": "afterReady",
					"payload": { "presentationRevision": "$presentationRevision" }
				}
			]
		}
	],
	"intents": [
		{
			"match": { "name": "samplePanel.tabChangeRequested" },
			"response": { "status": "completed", "code": "preview.tabChanged" },
			"statePatch": { "activeTab": "$payload.tabId" }
		}
	]
}
```

| 字段 | 含义 |
| --- | --- |
| `schemaVersion` | 固定为 `1` |
| `state.module`、`state.export` | 预览状态所在模块（相对 App 根，以 `src/` 开头的 `.ts` 或 `.js`，用正斜杠）和导出名。可省略，省略时按“预览状态”的命名规则查找 |
| `state.args` | 没有视图另行指定时调用预览状态的参数；JSON 数组 |
| `views[].id` | 视图标识：字母、数字、`_`、`-`，同一 App 内唯一 |
| `views[].route` | 视图所属的路由，必须是本 App 声明的路由之一 |
| `views[].title` | 列表里显示的名字，写玩家看到的界面名 |
| `views[].args` | 这个视图调用预览状态时的参数；省略时用 `state.args` |
| `views[].patch` | 合并到预览状态之上的对象：对象逐层合并，数组和其他值整体替换。视图只差一两个状态字段时用它，不必为此给预览状态加参数 |
| `views[].enter` | 页面发出这些 Intent 时进入本视图 |
| `views[].leave` | 页面在本视图里发出这些 Intent 时回到来时的视图 |
| `views[].events` | 显示本视图时宿主发给页面的事件，用来表达不在状态快照里的内容。每项有事件名 `name`、载荷 `payload` 和可选的时机 `at` |
| `intents` | 整个界面通用的 Intent 应答规则，对每个页面和视图都生效 |

- 一个视图只属于一个路由。两个路由都能进入的同一个子界面，各声明一个、`id` 不同。每个路由的第一个视图是打开该页面时的默认视图。
- 路由有两个及以上视图时，Studio 在该页面下列出它们，场景下拉里也有；点一个视图即按它的状态重新打开预览。
- `enter`、`leave` 里只登记切换视图的 Intent（事件名与页面 `requestIntent` 的字面量一致）。页面触发时 Studio 回 `completed` 并下发目标视图的状态，页面按正常的状态更新切过去；其余没有登记的 Intent 照旧被拒绝，Studio 不会替业务写操作伪造成功。由原生输入切换、页面不发 Intent 的视图（例如按返回键打开的选项页）不写 `enter`，从列表打开。
- 预览状态是常量时 `args` 没有意义，各视图用 `patch` 区分。

有些子界面不由状态快照决定，而由宿主单独发的事件驱动（通用确认弹窗的描述、世界里的交互进度条）。这类视图用 `events` 把事件写出来：

- 省略 `at` 的事件，页面一开始就拿得到，相当于宿主保留的最新一份事件，页面订阅时即收到。带 `at` 的事件在那个时刻发出：`"afterReady"`（页面调用 `ready()` 之后）、`"afterPresented"`（展示完成之后）、`"afterStateCommitted"`（页面回执初始状态之后），或距 `ready()` 的毫秒数。按真实宿主的时序选择：描述、数据类事件省略 `at`，入场请求这类“页面就绪后才会收到”的事件用 `"afterReady"`。
- 载荷里的文本 `"$presentationRevision"` 会换成预览当前这次展示的 revision。页面按 revision 核对展示事务时，事件载荷里的 revision 用它，不写死数字。
- 同名的无 `at` 事件只保留最后一份。页面经 `enter` 从别的视图切进带事件的视图时，这些事件按声明顺序立即发出；离开时不会撤回。

`intents` 让页面里的操作在预览中有回应。每条规则由三部分组成：`match` 指定 Intent 名（`name`，或 `names` 数组；可再用 `payload` 限定载荷字段、用 `controlId` 限定控件），`response` 是给页面的回执（`status` 为 `completed` 或 `rejected`，加一个 `code`），`statePatch` 是随后合并进当前状态并重新下发的对象，其中 `"$payload.<字段>"` 取页面这次请求载荷里的字段。

- 只为页面内能如实模拟的操作写规则：切页签、选中条目、展开折叠这类“状态里一个字段跟着请求变”的情况。涉及账户、库存、匹配、购买等业务结果的 Intent 不写成成功，保持被拒绝。
- 规则按声明顺序匹配，第一条命中的生效；用户在 Studio 里保存的自定义场景可以另写规则。没有规则也不是视图切换的 Intent，一律被拒绝。
- 规则只应答 `requestIntent`。页面用 `emit` 或 `call` 发出的业务事件不经过 `intents`：模拟 Bridge 只应答生命周期与回执类事件，其余以错误码 `studio.unhandledCall` 拒绝。页面要捕获这个拒绝；以 `emit` 为业务通道的页面（随插件的 Showcase 示例）在收到该错误码后改用自己的预览模拟，游戏内仍只由宿主改变状态。

## 发现检查

Studio 程序自带只读检查，不开窗口、不执行工程代码、不要求工程已被信任，Studio 开着时也能运行：

```powershell
$Studio = (Resolve-Path '<OrionBrowser>/Binaries/Win64/WebUIStudio.exe').Path
$Project = (Resolve-Path '<ProjectRoot>/<工程名>.uproject').Path
$Report = Join-Path (Split-Path $Project) 'Saved\OrionUE\WebUIStudio\checks\discovery\<AppId>'
$Arguments = @('--project', "`"$Project`"", '--check-discovery', '--app', '<AppId>', '--report', "`"$Report`"")
$Process = Start-Process -FilePath $Studio -ArgumentList $Arguments -Wait -PassThru
$Process.ExitCode
Get-Content -Raw -Encoding UTF8 (Join-Path $Report 'report.json')
```

- 程序不向控制台输出，结论只看退出码和报告文件：`0` 通过；`3` 报告里有 `error` 级发现；`1` 没能运行。`--project` 指向的文件不存在时，程序会先弹出提示框等待确认，所以路径先用 `Resolve-Path` 取得。
- `--app <AppId>` 只检查一个 App，写错名字时报告里只有一条“App 未登记”；`--app all` 或省略时检查全部生产 App，工程里别的 App 的问题也会让退出码变成 `3`。`--locale zh-CN` 或 `--locale en` 指定报告文字的语言。不给 `--report` 时报告写到 `<ProjectRoot>/Saved/OrionUE/WebUIStudio/checks/discovery/<时间戳>/report.json`。
- 报告里逐项核对：`apps[].pages` 是否列全了路由，每个页面的 `views` 是否列全了子界面（各视图的 `events` 与界面的 `intents` 也列在其中）；`previewState.source` 是 `manifest`（`webui-preview.json` 指定）、`export`（按名字找到）、`adapter` 或 `component`，不能是 `none`；`findings` 里没有 `error`。`note` 级的发现只是说明，例如 AppDefinition 资产不在 App 目录里。

| 报告里的发现 | 原因 | 处理 |
| --- | --- | --- |
| 没有可用的预览状态 | `src` 下没有符合命名的导出，`App.vue` 的初始状态也不是字面量 | 按“预览状态”导出一份 |
| 预览状态导出有必填参数 | 导出是带必填参数的函数 | 给参数加默认值，或在 `webui-preview.json` 写 `state.args`、各视图的 `args` |
| `webui-preview.json` 无法使用 | 不是合法 JSON，或字段不符合上表 | 按提示的字段修正 |
| 预览状态模块不存在、没有导出某个名字 | `state.module` 或 `state.export` 写错 | 对照源码改成实际的路径与导出名 |
| 视图的路由不在本界面声明的路由里 | `views[].route` 与 `instant-screen.config.ts` 的 `route` 不一致 | 改成声明过的路由；没有该配置文件的 App 用空字符串 |
| 视图 id 重复 | 两个视图同名 | 改成唯一的 `id` |
| 视图写了 `args`，但预览状态导出不是函数 | 常量不接收参数，各视图会得到同一份状态 | 把导出改成函数，或改用 `patch` |
| 缺少 `package.header`，或源码与产物的 ScreenId 不一致 | 改了 `instant-screen.config.ts` 之后没有重新构建 Package | 重新执行 production build、`instant:build` 和 `instant:validate` |
| 配置含可执行表达式 | `instant-screen.config.ts` 不是纯字面量 | 改回纯数据 |

发现检查只证明 Studio 能列出页面与视图、能找到预览状态。视图实际显示得出来、登记的 Intent 确实能切换，由下面的视图检查证明；游戏内的表现另行验证。

## 视图检查

同一个程序还能把每个视图真的打开一遍。它会运行页面代码，并打开一个不抢焦点的窗口，结束后自己关闭；源码预览需要 App 已经装好依赖。它属于运行验证，是否执行按宿主工程的授权。

```powershell
$Report = Join-Path (Split-Path $Project) 'Saved\OrionUE\WebUIStudio\checks\views\<AppId>'
$Arguments = @('--project', "`"$Project`"", '--check-views', '--app', '<AppId>', '--report', "`"$Report`"")
$Process = Start-Process -FilePath $Studio -ArgumentList $Arguments -Wait -PassThru
$Process.ExitCode
```

- 逐个页面、逐个视图打开预览，等页面就绪后截图到报告目录，并在 `report.json` 里记下页面是否渲染出内容、开头的文字和页面报错。页面报错包括未捕获的异常、未处理的 Promise 拒绝和 `console.error` 输出，有一条该项即不通过。登记了 `enter` 的视图，再让页面自己发出该 Intent，核对预览切到这个视图；登记了 `leave` 的再切回来。退出码 `0` 表示每一项都成功且页面没有报错，`1` 表示有失败，原因在各项的 `error` 与 `pageErrors` 里。
- 加上 `--view <视图 id> --click-control <ControlId>` 时只做一件事：打开该视图，用真实鼠标点击这个控件，等 `--expect-view <视图 id>` 或 `--expect-state <状态路径>=<值>` 成立。同一 ControlId 有多个控件时用 `--click-index <序号>`（从 0 起）选择；多路由的 App 用 `--route <route>` 指定页面。用它核对 `enter` 的控件和 `intents` 的规则确实接上了，例如点第二个页签后 `--expect-state activeTab=events`。
- 页面没有画的地方是透明的，Studio 在那里显示预览底色，截图也合成到同一个底上；默认是深色的透明网格。加上 `--backdrop grid`、`--backdrop #RRGGBB` 或 `--backdrop <PNG 或 JPG 文件>` 为这一次检查指定底色，例如用一张游戏画面的截图看文字在实际画面上是否看得清；它只作用于这次检查，不改工程里保存的选择。底色衬在页面后面，不进入页面：叠在游戏画面之上的界面保持透明，不要为了在 Studio 里看得清而给页面加背景。
- 截图要打开看。检查只判断页面渲染出了内容、期望的视图或状态成立，不判断画面对不对。

## 新建 App 时的清单

1. App 位于名为 `WebUI` 的目录下，`package.json` 有 `orionWebUI.appId`。
2. `instant-screen.config.ts` 是纯字面量；每个 route 构建出了 `package.header`。
3. `src` 下有预览状态导出：命名含 `preview` 与 `state`，没有必填参数，返回可序列化的完整状态；多路由时按 `location.hash` 取路由。
4. 同一路由内由状态切换的每个子界面，都在 `webui-preview.json` 的 `views` 里；切换它们的 Intent 登记在 `enter` 与 `leave`。由单独事件驱动的子界面用 `events` 登记；切页签这类页面内操作在 `intents` 里有规则。
5. 发现检查对这个 App 的退出码为 `0`，报告里的页面与视图和预期一致。
6. 得到授权时运行视图检查，退出码为 `0`，并打开每张截图确认视图显示的是预期内容；叠在游戏画面之上的界面，截图里透明处应当露出底色。
