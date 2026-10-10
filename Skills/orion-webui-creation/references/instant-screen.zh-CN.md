# InstantScreen 接入

InstantScreen 让同一层的界面共用一个常驻 Runtime Browser：每个界面带一份构建期首帧包，是否可见由展示事务把关（状态、资源、输入、首帧全部精确确认后才 Reveal）。占位符：`<OrionBrowser>` 为 `OrionBrowser.uplugin` 所在目录，`<ProjectRoot>` 为 `.uproject` 所在目录，`<WebUIRoot>` 为 `<ProjectRoot>/Content/UI/WebUI`，`<AppId>` 为 PascalCase 的 App 目录名。插件的包校验、共享 Runtime 输出和 Scheme 都按 `<WebUIRoot>/<AppId>` 解析；Runtime Builder 找到宿主工程的方式见 [构建与验证](build-validation.zh-CN.md) 的“定位宿主工程”。

相邻主题只在此指路：Web 工程见 [Web App 脚手架](web-app-scaffold.zh-CN.md)；页面侧 Bridge、状态通道、展示 ACK 与入退场见 [Bridge 与生命周期](bridge-lifecycle.zh-CN.md)；不走 InstantScreen 的宿主见 [UE 侧宿主](native-host.zh-CN.md)；验证分层与交付见 [构建与验证](build-validation.zh-CN.md)。

## 选型与无预热合同

- 用 InstantScreen：进入 CommonUI 层栈的正式页面（菜单、设置、弹窗）和常驻 HUD 组合层，需要“加载完成再显示”、覆盖与恢复、输入租约，或要与同层其他 Web 页面共用 Browser。
- 用普通 WebUI Widget（自带 Browser 的 `UOrionWebUIWidget`）：不进层栈、生命周期独立、不需要展示事务的界面。
- 无预热合同对每个 InstantScreen 页面都有约束力：
	1. Browser 只由真实的 Show 请求创建。Catalog 注册、Runtime Host 构造、GameFeature 激活、加载界面都只登记配置。`AcquireRuntimeLease()` 已停用并恒返回 `false`；`DedicatedResident` 模式会被 Catalog 校验拒绝。
	2. 目标页面准备期间保留上一张有效画面或 Native Cover（宿主的加载遮罩）。不新建隐藏 Browser、隐藏 iframe 或隐藏路由 DOM，不预取其他路由，不在可见前运行动画。
	3. 唯一例外是启动期 Shell 预备 `UOrionInstantScreenSubsystem::RequestStartupShellWarmup(Owner, RuntimeId)`：由 Engine ini 的 `[OrionBrowser] bEnableStartupShellWarmup` 或命令行 `-OrionWebUIStartupWarmup=1` 显式开启，每个 GameInstance 只接受一次、只给主 LocalPlayer，Owner 必须是已用同一对象注册过 Catalog 的 `UUserWidget`，且指定 Runtime 的模式为 `Shared`、保留策略为 `RetainUntilLayoutRelease`。它只准备 Runtime Shell，不创建任何业务 Screen，真实 Show 到来时立即让位。业务界面不得照此自建预热。

## 层、Runtime 与根布局

层到 Runtime 的映射由宿主的 `UOrionInstantScreenCatalog.RuntimeProfile` 显式提供，插件不安装游戏层级或默认映射。每个 Screen 的层必须在 Profile 中声明；多个已注册 Catalog 使用同一 `RuntimeId` 时，其 Mode、Host、保留策略和有效空闲时长必须一致。

下表仅为可选配置示例。LayerTag 由宿主定义，RuntimeId 与 RuntimeHostId 可自行命名，并在 Profile 和 Runtime Host 中保持一致。

| LayerTag | RuntimeId | RuntimeMode | RuntimeHostId | RetentionPolicy | 常用组合 |
|---|---|---|---|---|---|
| `<GameLayerTag>` | `GameRuntime` | `DedicatedOnDemand` | `GameRuntimeHost` | `OnDemand` | `Composite`，多块 HUD 并存 |
| `<MenuLayerTag>` | `SharedRuntime` | `Shared` | `SharedRuntimeHost` | `RetainUntilLayoutRelease` | `Exclusive` |
| `<ModalLayerTag>` | `SharedRuntime` | `Shared` | `SharedRuntimeHost` | `RetainUntilLayoutRelease` | 弹窗栈 |

- GameplayTag 由宿主工程注册，插件不按固定名字查找。Runtime 用 Tag 的末段决定输入优先级：`.Modal` 高于 `.Menu`，高于 `.GameMenu`，高于其他；自定义层名不以这些结尾时取最低优先级。
- `CompositionMode` 写在 Definition 上：`Exclusive` 的 Screen 提交时把同层栈内其他 Screen 挂起为 `CoveredSuspended`，它移除后栈顶被恢复；`Composite` 与同层其他 Screen 并存，按 `ZOrder` 叠放。弹窗层自成一栈：覆盖期间下层页面保留画面与 DOM，只交出输入。
- 每个 LocalPlayer 的每个 `RuntimeId` 恰好一个共享 Browser，归 Subsystem 所有。业务组件不创建 Browser：WBP 里的 `UOrionInstantScreenWidget` 运行时不含 Browser，只发布几何并持有 Endpoint。
- 根布局是宿主自备的 UserWidget。在其中为每个 Runtime 放一个 `UOrionInstantScreenRuntimeHost`（控件面板名 “Orion InstantScreen Runtime Host”），填好 `RuntimeId` 与 `RuntimeHostId`。根据自己的层栈决定 Runtime Host 的位置；需要覆盖 Web Surface 的原生弹窗层放在相应 Host 上方。共用一个 Browser 的 Web 页面与 Web 弹窗在该 Browser 内组合，不要求宿主采用固定的游戏层名称或控件顺序。改完用编辑器工具回读真实 child 顺序，不要只看控件名存在。
- 需要临时隐藏某个 Runtime（菜单盖住 HUD、加载遮罩期间）时调用 `SetRuntimePresentationSuppressed(RuntimeId, bool)`。不要 Collapse Runtime Host，也不要手工改它的 Visibility，Pointer 命中由 Subsystem 按活动 Screen 的 `InputPolicy` 汇总设置。
- 渲染模式必须是 `LegacyTexture`：在 Engine ini 写 `[OrionBrowser] DefaultWebUIRenderMode=LegacyTexture`（或命令行 `-OrionWebUIRenderMode=LegacyTexture`、CVar `orion.WebUI.RenderMode`）。没有这一项时已经解析为 `LegacyTexture`。解析结果是其他模式时（这一项写成了 `Auto`、`HybridIR` 或 `FullIR`，或被命令行、CVar 覆盖），Catalog 注册和每次 Show 都被拒绝，且不会自动降级。

## 模块职责

| 位置 | 负责 |
|---|---|
| 模块 `OrionWebUI` | `OrionInstantScreenTypes.h` 中的枚举、Runtime Profile、Definition、Catalog、Show 请求与 Handle；`OrionInstantScreenPackage.h` 的 C++ 包校验器与协议版本；`orion-webui.local` Scheme 与包字节注册 |
| 模块 `OrionWebUIWidget` | `UOrionInstantScreenSubsystem`（Catalog、Runtime 驻留、展示事务、可靠投递、输入租约、诊断）、`UOrionInstantScreenEndpoint`、`UOrionInstantScreenWidget`、`UOrionInstantScreenRuntimeHost` |
| 模块 `OrionWebUICommonUI` | `UOrionInstantScreenActivatableWidget`：CommonUI 激活与失活、标准展示请求、Back / 通用 Action、输入方式与按键提示、控件声音策略、失败后自动失活 |
| `<OrionBrowser>/Content/UI/WebUI/Shared` | Runtime Shell 源码 `src/instant-screen-runtime/`、可选模块 `src/runtime/orion-instant-screen-runtime-optional.js`、Package Builder 与验证器 `scripts/`、页面侧辅助 `src/instant-screen/orion-instant-screen-vue.ts` |
| 宿主工程 | 层 Tag、根布局、Catalog 注册时机、具体 Definition / WBP / Presenter 与 C++ 权威状态、加载遮罩 |

## 资产与 WBP

| 资产类（插件提供，均为 PrimaryDataAsset） | 关键字段 | 规则 |
|---|---|---|
| `UOrionInstantScreenRuntimeProfile` | `Entries[]`：`LayerTag`、`RuntimeId`、`RuntimeMode`、`RuntimeHostId`、`RetentionPolicy`、`IdleRetirementSeconds` | `RuntimeId`、`RuntimeHostId` 非空；`IdleTimeout` 需要正数秒；同一 `RuntimeId` 的各层配置必须等价；`RuntimeMode` 描述如何共享，`RetentionPolicy` 描述最后一个真实所有者离开后的回收，二者不互相替代 |
| `UOrionInstantScreenDefinition` | `ScreenId`、`AppDefinition`、`PackageId`、`DefaultLayerTag`、`InputPolicy`、`FocusPolicy`、`CompositionMode`、`ZOrder`、`CachePolicy`、`SecurityPolicy`、`InitialRoute`、`InitialVariant` | `ScreenId` 等于配置里的 `screenId`；`PackageId` 留空取 AppDefinition 的 `AppId`；`InitialRoute` 留空取 AppDefinition 的 `InitialRoute`，再为空则用 `default` 包目录 |
| `UOrionInstantScreenCatalog` | `RuntimeProfile`、`Screens[]` | `RuntimeProfile` 必填；每个 Screen 需有 `ScreenId`、`AppDefinition` 且层已映射；`ScreenId` 不重复 |

- `InputPolicy`：`Passthrough`、`Game` 只绘制，点击穿透到游戏视口；`GameAndMenu`、`Menu`、`Modal` 才让 Runtime 参与 Pointer 命中，并且要求输入租约确认后才算可交互。
- `RetentionPolicy`：`OnDemand` 在最后一个 Screen 释放后立即关闭 Browser；`IdleTimeout` 先停驻、到时关闭；`RetainUntilLayoutRelease` 停驻到 LocalPlayer Subsystem 结束。`CachePolicy` 默认 `KeepDocument`：Screen 隐藏后保留 Controller 文档，下次同 Screen 重绑到新的实例身份。

业务 WBP：

1. 父类选宿主自备的、最终继承 `UOrionInstantScreenActivatableWidget`（Abstract）的 C++ 类。
2. 控件树里保留一个名字严格为 `WebUI` 的 `UOrionInstantScreenWidget`（控件面板名 “Orion InstantScreen”）。代理在 `NativeConstruct` 里按这个名字查找它；改名即失去几何与 Endpoint 绑定。
3. `ScreenDefinition` 配在代理或 `WebUI` 槽上，代理优先。槽上的 `LayerOverride`、`RouteOverride`、`VariantOverride` 只在直接调用槽的 `ShowScreen()`（含 `bAutoShowOnConstruct`）时生效，经代理 `ShowInstantScreen()` 显示时不读取。
4. 走 CommonUI 的页面保持 `bAutoShowOnConstruct=false`；只有不经代理的被动 HUD 槽才开启它。
5. 槽必须有非零排布尺寸且不是 Collapsed / Hidden，否则几何无效，最终可见帧一直等待。代理会强制自身 `SelfHitTestInvisible`、槽 `HitTestInvisible`，不要手工改。
6. 代理的时序：`NativeOnActivated` 调 `ShowInstantScreen()`（失败即 `DeactivateWidget()`），随后在 `bUseStandardPresentationLifecycle` 为真时调 `RequestStandardWebUIPresentation()`；`NativeOnDeactivated` 先让槽退出合成，再按 `ShouldKeepInstantScreenOnDeactivation()`（默认 `false`）决定是否 `HideInstantScreen()`。
7. 可覆写：`BuildInitialInstantScreenState()`、`HandleWebUIReady`、`HandleWebUIEvent`、`HandleWebUIRequest`、`HandleWebUIRouteChanged`、`HandleCommonAction`、`HandleWebUIBackAction`、`ShouldKeepInstantScreenOnDeactivation()`、`HandleInstantScreenDistinctVisualPresented()`、`HandleInstantScreenReplacementFailed()`；页面用自己的入场事件时，再覆写 `ShouldRequestStandardWebUIPresentationOnActivation()` 关闭标准请求。

Catalog 注册与注销：

- 接口是每个 LocalPlayer 上的 `RegisterCatalog(UObject* RegistrationOwner, UOrionInstantScreenCatalog*)` 与 `UnregisterCatalog(Owner, Catalog)`。注册时逐个 Screen 校验包目录并把包文件字节读入内存；失败返回 `false` 并打印 `Rejected InstantScreen ...`。
- Owner 语义：一个 Owner 只持有一个 Catalog，用同一 Owner 注册另一个 Catalog 会先注销旧的；注销必须传同一对 Owner 与 Catalog；包 URL 只在仍有存活 Owner 时可读；不同 Definition 复用同一 `ScreenId` 会被拒绝。重建包之后要重新注册才会读到新字节。
- 注册必须早于其中任一 Screen 的首次 Show，且注册本身不创建 Browser、不加载非当前页面资源。
- 插件不提供注册的调用方，宿主需要自备两类：根布局在 `NativeConstruct` 注册常驻前台 Catalog、在 `NativeDestruct` 注销；随玩法（例如 GameFeature Action）注册玩法 Catalog 的对象，职责是加载 Catalog，对现有与后续新增的每个 GameInstance、每个 LocalPlayer 注册，并在反激活、LocalPlayer 移除和 GameInstance 销毁时对称注销。不要在 Widget、Presenter 或页面里临时注册。

## `instant-screen.config.ts`

放在 `<WebUIRoot>/<AppId>/instant-screen.config.ts`。文件必须是 `export default { ... } as const;` 的纯数据：Builder 在沙箱里求值，源码文本中出现 `import`、`require`、`process`、`globalThis`、`Function`、`eval` 这些单词（即使在字符串或选择器里）都会被拒绝。

```ts
export default {
	"packageId": "SamplePanel",
	"firstFramePolicy": "controller",
	"captureBudgetMilliseconds": 1800,
	"firstFrameLayout": {
		"mode": "fit-design-stage",
		"selector": ".sample-stage",
		"designWidth": 1920,
		"designHeight": 1080
	},
	"screens": [
		{
			"screenId": "SamplePanel",
			"route": "default",
			"captureMustContain": ["id=\"sample-panel-title\"", "data-orion-control-id=\"sample-panel-confirm\""],
			"bindings": [
				{ "selector": "#sample-panel-title", "path": "title" },
				{ "selector": ".sample-shell", "path": "tone", "mode": "class-equals", "className": "is-warning", "equals": "warning" }
			]
		}
	]
} as const;
```

| 字段 | 含义与取值 |
|---|---|
| `packageId` | 必填，仅字母、数字、`_`、`-`。必须等于 `<AppId>`：C++ 到 `<WebUIRoot>/<PackageId>/dist/instant/routes/<Route>` 找包，URL 也用它作首段 |
| `screens` | 必填、非空。每项产出一个包目录 |
| `screens[].screenId` | 必填、不重复，等于 Definition 的 `ScreenId` |
| `screens[].route` | 路由键，仅字母、数字、`_`、`-`，不重复。省略时包头路由为空、输出目录为 `default`。必须与 Definition 解析出的路由一致（Definition 路由为空时只接受空或 `default`） |
| `screens[].hash` | 捕获 URL 的 hash；缺省在 `route` 非空时用 `#/<route>` |
| `screens[].query` | 追加到捕获 URL 的查询参数对象；Builder 另外固定追加 `orionDesignPreview=1` 与 `orionInstantBuild=1` |
| `screens[].captureMustContain` | 字符串数组，逐条要求原文出现在捕获 DOM 中，用来证明目标路由和关键控件确实渲染出来了 |
| `screens[].bindings` | 状态到 DOM 的静态绑定表，见下 |
| `firstFramePolicy` | `"controller"`（默认）或 `"static"`，可写在顶层或单个 screen 上 |
| `firstFrameLayout` | 可写在顶层或单个 screen 上：`selector`（必填）、`mode` 为 `fit-design-stage`（需 `designWidth`、`designHeight`）或 `height-design-stage`（需 `designHeight`）、可选非负 `edgeOverscan`。只有 `static` 首帧在运行时据此把舞台缩放到视口 |
| `captureBudgetMilliseconds` | Headless Chromium 的虚拟时间预算，缺省 2500；看门狗为该值的 8 倍且不低于 30 秒 |

绑定项的公共字段：`selector`（必填，`:scope` 表示当前根）、`path`（必填，点路径）、`mode`（缺省 `text`）、`id`（可选；缺省由 `screenId`、`selector`、`path`、`mode` 推导，四者相同的两条绑定会报重复）、`all`（匹配全部元素）、`applyWhenUndefined`、`defaultEmptyArray`、`format`（`number`、`template` 配 `template` 字符串中的 `{value}`、`array-length`、`array-index` 配 `indexPath`、`remaining-duration` 配 `otherPath`）。

| `mode` | 作用 | 额外字段 |
|---|---|---|
| `text` | 写 `textContent` | `format` |
| `attribute` / `attribute-map` / `attribute-path-equals` | 写属性；按映射写属性；写入“是否等于另一路径” | `attribute`，以及 `removeWhenEmpty` / `map` / `otherPath` |
| `class-boolean` / `class-false` / `class-equals` | 按真、假、等于常量切换类名 | `className`，`class-equals` 另需 `equals` |
| `class-path-equals` / `class-path-less` | 与另一路径相等、小于时加类名 | `className`、`otherPath` |
| `disabled-false` / `aria-disabled-false` | 值为假时禁用 | 无 |
| `visible` / `visible-map` / `visible-any` | 控制 `hidden` | `map`；`predicatePath`、`predicateEquals` |
| `style-percent` / `style-value` | 写样式属性 | `property`（百分比缺省 `width`）、`scale`（缺省 100） |
| `value` | 写表单 `value` | 无 |
| `repeat` | 按数组克隆模板子元素 | `itemSelector`（缺省 `:scope > *`，必须是绑定根的直接子元素）、`textSelector`、`textPath`（缺省 `label`）、`primaryClass` 与 `primaryPath`、`templates` 与 `templatePath`、子 `bindings`、`orderPath` 与 `keyPath`、`filterPath` 与 `filterEquals`、`takeLast`、`maxItems`；项内路径可用 `$item`、`$value`、`$index`、`$parent`、`$root` |

Builder 还会把捕获 DOM 里所有带 `data-orion-control-id` 的元素收进 `actions.bin`。绑定表与动作表只在 `static` 策略下于运行时生效；`controller` 策略下仍会生成并校验，`bindings` 可以为空数组。

## `firstFramePolicy`

| | `controller`（默认） | `static` |
|---|---|---|
| 可见文档 | 只有 Controller iframe（`controller-host.html`）。它在 Preparing 内完成挂载、状态应用、字体、图片与布局，成为唯一可见文档 | 先显示 `first-frame.html`（按绑定表套用初始状态，点击被排队），Reveal 后在同一文档内原位 Hydration |
| 对页面的要求 | 无额外要求 | 用 `createOrionWebUIApp()` 建 App（静态首帧内走 SSR Hydration）；捕获 DOM 加绑定结果必须与真实渲染逐节点一致，任何 Hydration 警告、根节点或控件被替换都判失败；捕获里不得有开发服务器文件系统 URL；用 `repeat` 时必须能取到 Vue Fragment 锚点 |
| `first-frame.html` 的作用 | 只参与包完整性与确定性校验，永不显示 | 真正的首帧 |

选择：需要精确入场动画、字体策略、动态图片或 Native Surface 的页面一律用 `controller`；只有布局固定、文本极少的页面才考虑 `static`。

不要设计“先 Reveal 静态首帧，再切换到另一个 Controller 文档”的流程：两个文档各自加载字体和图片、各自建立布局和动画时间线，表现为先闪出预览画面、字体或图片突然替换、尺寸跳变、入场动画像播了两次。出现这些现象先数可见文档数量和核对策略，不要加暂停、补播或延时。

Controller 的静态视觉就绪（`controllerVisualReady(stateRevision)`，阶段 `controller-visual-ready`）与展示 ACK（`webUI.presentationApplied`，阶段 `presentation-committed`）是两道独立的门：前者表示权威状态与本地化已形成完整静态 DOM，后者表示本次展示请求的入场已经提交，互不替代。宿主的加载遮罩若要等页面，只能等不依赖“可见”的事实（状态已提交、静态视觉就绪、资源就绪）；去等 Reveal 之后才会出现的事实（`OnDistinctVisualPresented`、遮罩撤掉后才发出的入场请求的 ACK）会形成遮罩等页面、页面等遮罩的循环。

## Package 2.0 与 URL

- 当前包格式 `2.0`，Runtime 协议 `8`。三处必须一致：`instant-screen-package-lib.mjs` 的 `PACKAGE_VERSION` / `RUNTIME_PROTOCOL_VERSION`、Runtime Shell `runtime.js` 的 `runtimeProtocolVersion`、C++ 的 `OrionInstantScreenPackage::RuntimeProtocolVersion`。插件升级改变了格式或协议时，旧包会被拒绝，需要重建。
- 每个包目录 `<WebUIRoot>/<AppId>/dist/instant/routes/<Route>/` 必须有八个文件：`package.header`、`first-frame.html`、`critical-style.css`、`bindings.bin`、`actions.bin`、`controller.mjs`、`controller-host.html`、`first-frame-runtime.mjs`。包头只保存格式、协议、`packageId`、`screenId`、`route`、首帧策略与 Hydration 模式，不含构建哈希或文件摘要。
- 生产 URL 固定为 `https://orion-webui.local/<AppId>/instant/routes/<Route>/<PayloadRelativePath>`，空路由用 `default`。Scheme 只查 Catalog 注册过的包与文件，不把请求路径拼成磁盘路径；`/<AppId>/dist/...` 与其他 `/<AppId>/instant/...` 一律不可读。
- `controller-host.html` 不得含内联可执行脚本，只能有一个 `<script data-orion-controller-host-bootstrap="true" type="module" src="./controller.mjs"></script>`。`controller.mjs` 先取得并安装当前 Screen 的 Scoped API、派发 `orion:webui-installed`，再动态导入位于本 App `dist/assets` 下的主入口。Node 与 C++ 校验器都检查这一点；不要为内联脚本放宽 CSP。
- App 的 `dist/index.html` 必须恰好有一个模块入口，且以 `./assets/` 开头（Vite `base` 用相对路径）。

## 构建与校验

```text
# 在 <WebUIRoot>/<AppId>：typecheck、既有测试，然后 production build（会清空 dist，连同 dist/instant）
npm run build
# 在 <OrionBrowser>/Content/UI/WebUI/Shared：共享 Runtime（输出不存在或 Runtime 源码变化时构建，随后检查）
npm run instant:runtime:build
npm run instant:runtime:check
# 在 <OrionBrowser>/Content/UI/WebUI/Shared：最后才生成并校验包
npm run instant:build -- --app <WebUIRoot>/<AppId>
npm run instant:validate -- --package <WebUIRoot>/<AppId>/dist/instant/routes/<Route>
```

- 顺序固定：App production build，共享 Runtime，最后 Package。App 每次 production build 之后都要重跑 `instant:build`。
- `instant:build` 可选 `--config <path>`、`--chrome <path>`；浏览器按 `--chrome`、环境变量 `ORION_INSTANT_SCREEN_CHROME`、脚本内置的 Chrome 与 Edge 默认安装位置依次查找。缺少 App 目录时抛出 Usage 错误，不是 Builder 故障。`instant:validate` 的输入是具体包目录，可重复 `--package`；传 App 根目录会得到缺少 `package.header` 的 `ENOENT`。
- Builder 的两个输入来源不同且不能混用：Controller 入口与样式来自已构建的 `dist`；`first-frame.html` 的 DOM 来自用 App 自己的 `vite.config.ts` 启动的 Designer Preview。页面必须能在 `?orionDesignPreview=1` 下不依赖 Bridge、用预览数据渲染出完整 `#app`。
- 共享 Runtime 的输出目录由脚本决定，是工程级的 `<WebUIRoot>/__instant__/dist/runtime/`（恰好 `index.html`、`runtime.css`、`runtime.js`、`runtime-optional.js` 四个文件），不在插件目录下。它是生成物：不手改，修改只发生在 `<OrionBrowser>/Content/UI/WebUI/Shared/src/instant-screen-runtime/`，源码必须是 CRLF。`instant:runtime:check` 报 `Generated InstantScreen Runtime is stale` 表示需要重建。
- 主 Runtime Bundle `runtime.js` 的硬上限是 48 KiB（按最终 CRLF 字节计），超限构建失败。处理办法只有一个：把不必在首个脚本任务内完成的策略移入可选模块，主 Runtime 保留 Screen 表、同步停驻切换与 Native ACK 入口；不放宽预算、不删展示门禁、不手改生成物。
- 确定性要求：对 `dist/instant` 下全部文件连续两轮构建，逐文件 SHA-256 完全一致，任何新增、缺失或哈希不同都算失败。每一轮都先清空 App 精确的 `dist/instant`（Builder 自己不清理旧路由），第一轮不能用调用前的残留。插件只导出 `hashPackageDirectory()` 与两个 npm 命令，双轮流程由宿主脚本或手工执行。
- 因为两轮之间要删除 `dist/instant`，同工程的 Editor 必须先正常退出。清理时报文件占用：不强杀任何进程、不无限重试，等占用者空闲后整轮重跑，仍失败就报告阻塞。
- Package Builder、Runtime Builder 与验证器串行运行，不并发启动第二个 Builder。Builder 为每个 route 顺序启动独立的临时 Headless Chromium，长时间没有新输出仍可能正常；只有 Node 明确报错或非零退出才判失败。重试前确认上一个 Builder 及其临时 Chromium 已退出，不按进程名结束用户自己的浏览器。

## 首帧捕获的确定性规则

这些规则直接约束页面写法：

- 捕获在 `orionInstantBuild=1`、无 GPU、虚拟时间下进行。实时 WebGL、Canvas 或 rAF 渲染层必须按该查询参数关闭（例如根组件里 `new URLSearchParams(location.search).get("orionInstantBuild") !== "1"` 作为渲染层的启用条件），否则随机撞上看门狗，首帧 DOM 还会混入 canvas。不要为此放宽看门狗或加等待。
- DOM 不得在动画结束时改变。由 `animationend`、`transitionend` 或 `getAnimations().finished` 触发的类名切换、条件卸载、属性变化会与 DOM 转储时刻竞争，造成两轮哈希不一致。入场相关类名只随状态变化；过渡元素常驻，用 `backwards` 填充，结束后回到元素自身样式；只有不进入 DOM 的逻辑才可以等动画结束。把 `captureBudgetMilliseconds` 临时压得很小可稳定复现入场途中的 DOM，用来确认是不是这一类。
- 捕获期间时钟被固定，不要把当前时间、随机数或环境相关内容渲染进首帧 DOM。
- 页面与捕获前导都不留永久定时器或循环计时器，否则 Headless Chromium 可能在 DOM 完成后仍不退出。
- 生成的 `first-frame.html` 不得含构建机路径、行尾空白或调试属性；Builder 负责清理并统一为 CRLF，验证器把行尾空白判为失败。发现问题改源码或 Builder，不手改生成物后补哈希。

## Presenter 与 Endpoint

Presenter（宿主的 C++ 页面类）只持有 `UOrionInstantScreenEndpoint*`，来自代理的 `GetInstantScreenEndpoint()` 或槽的 `ShowScreen()` 返回值；不持有 Browser 或 `UOrionWebUIWidget` 指针。Browser 重建、Surface 换代都由 Runtime 边界处理，旧代次的回调被 Endpoint 拒绝。Endpoint 失效后（`IsValidEndpoint()` 为假）不再使用。

| 成员 | 语义 |
|---|---|
| `AllocateRevision()` | 静态、单调、Web 安全的 revision 来源，状态与生命周期消息都从它取号 |
| `PushState(StateJson, StateRevision)` | 发布完整权威快照。revision 小于当前值返回 `false`；同一 revision 只能对应逐字相同的 JSON，否则经 `OnError` 报错。相同快照的重放复用原 revision |
| `PostEventToWeb` / `PostLatestEventToWeb` / `PostRetainedLatestEventToWeb` | 立即、只留最新、留存最新三种普通投递，不带 ACK 与重试 |
| `PostReliablePresentationEventToWeb(EventName, PayloadJson, AcknowledgementEventName, RevisionFieldName, Revision, ...)` | 可靠展示事件，见下 |
| `PostReliablePresentationRequestToWeb(...)`（参数同上） | 可靠展示事件，同时把这对页面自定义的事件名声明为本 Screen 的展示请求与 ACK，见下 |
| `PostFlowControlledLatestEventToWeb(...)` | 一个在途加一个可替换最新值的流控通道，适合高频状态；ACK 只释放槽位。离开页面时 `CancelAllFlowControlledLatestEvents()` |
| `RequestStandardPresentation()` | 没有业务入场事件的被动 C++ 宿主用：分配 revision 并可靠发送 `ue:webUI.presentationRequested`，ACK 为 `webUI.presentationApplied` |
| `IsReliablePresentationFrameCertified(AcknowledgementEventName, Revision)` | 仅当该精确正 revision 的 ACK 之后又认证了一张新 Runtime 帧才为真 |
| `IsDistinctVisualPresented()` | 只表示 Screen 自身完成过一次生命周期展示，不能证明之后的业务提交已画出 |
| `OnReady`、`OnLocalResourcesReady`、`OnEvent`、`OnRequest`、`OnRouteChanged`、`OnError`、`OnDistinctVisualPresented`、`OnReliablePresentationFrameCertified` | 事件出口；经 CommonUI 代理时由代理绑定并转给 `HandleWebUI*` |

- 初始状态 revision 与展示 revision 是两个命名空间。`ShowScreen(InitialStateJson, StateRevision)` 和 `BuildInitialInstantScreenState()` 输出的必须是当前权威状态 revision，之后每次 `PushState` 都不小于它；绝不能把弹窗的展示 revision 传进去。`StateRevision == 0` 只表示真正无状态的 Screen；任何正 revision 都要求页面显式 `stateCommitted(revision)`。
- 每个 Screen 都必须有一条展示请求，否则事务停在准备阶段：代理的标准生命周期、`RequestStandardPresentation()`，或自定义的可靠展示事件。Runtime 内置识别的展示请求是 `ue:webUI.presentationRequested`、`ue:webUI.presentationRestored` 和以 `.enterRequested` 结尾的事件，内置的展示 ACK 是 `webUI.presentationApplied`、`webUI.presentationEnterApplied`、`webUI.presentationRestoreApplied`，revision 必须精确相等。
- 展示请求需要用页面自己的一对事件名时（例如一个合成多路数据后才提交的 HUD），用 `PostReliablePresentationRequestToWeb` 发送：Native 在该事件的信封里声明 ACK 名，Runtime 把这次 revision 记为期望的展示 revision，只放行 revision 精确相等的那个 ACK，过期和超前的 ACK 在 Runtime 边界被拒绝。Runtime 不按名字认识任何页面事件；用 `PostReliablePresentationEventToWeb` 发送的其他事件只做可靠投递与帧认证，不改变 Screen 的展示里程碑。
- 可靠展示事件的流程：重发直到 Web 回传 `RevisionFieldName` 字段精确相等的 ACK；ACK 只停止重发；随后 Subsystem 申请一张严格晚于 ACK 的 Runtime paint fence；fence 就绪后才为 `(AcknowledgementEventName, Revision)` 建立证书并广播 `OnReliablePresentationFrameCertified`。`Revision` 必须为正。ACK 重试耗尽或帧认证超时会使整个展示失败并让 Endpoint 失效。被可靠投递消费的 ACK 不再出现在 `OnEvent`。
- State 快照不隐式创建 Enter：页面的状态处理即使看到快照里带展示 revision，也只能更新 Store、提交精确的状态 revision 并报告静态视觉就绪，不得据此播放入场或发送展示 ACK。零值、抢跑、旧版、未来版的 ACK 都会在 Runtime 边界被拒绝。
- 宿主的事件入口是 `HandleWebUIEvent_Implementation()` 的覆写。入口里先处理生命周期类事件（展示 ACK、退场完成、驻留页生命周期回执等宿主自己的约定），命中后立即 `return`，不能继续落入业务 Intent 分发。业务操作由页面的 `requestIntent()` 经 `HandleWebUIRequest` 进入；普通 `call` 只留给内置桥接服务，拿它发业务请求会被以 `E_INSTANT_USE_INTENT` 拒绝。

## 展示事务

原生阶段枚举 `EOrionInstantScreenPresentationPhase`（日志里的 `Phase=<n>` 是从 0 起的序号）：

| 序号与阶段 | 进入下一阶段的条件 |
|---|---|
| 0 `AwaitingPrepared` | Runtime 对精确状态 revision 报告 `prepared`，且 Bridge、资源、输入就绪，状态 ACK 等于当前 revision，展示 ACK 等于要求的展示 revision |
| 1 `PreparedQueued` | 同一 Runtime 同时只推进一个展示，其余排队 |
| 2 `AwaitingStagingPaint` | 严格晚于 `prepared` 的新 LegacyTexture 帧到达，且槽几何有效；记为首帧认证，随后向 Runtime 发 `commit` |
| 3 `AwaitingReveal` | Runtime 回报 `revealed`，展示 revision 精确匹配 |
| 4 `AwaitingVisiblePaint` | Reveal 之后的新帧就绪，且状态 ACK、展示 ACK、输入就绪、需要时的输入所有权确认全部成立 |
| 5 `AwaitingBackBuffer` | 该帧进入 BackBuffer；随后为 6 `Complete`，广播 `OnDistinctVisualPresented`，日志 `Presented InstantScreen` |
| 7 `Failed` | 调用 `FailPresentation()`：中止事务、移除实例、Endpoint 失效，最后广播 `OnError` |

- 页面侧对应的里程碑阶段名（日志 `Stage=<name>`）：`controller-host-installed`、`controller-module-evaluated`、`controller-bridge-ready`、`state-committed`、`controller-local-resources-ready`、`controller-input-ready`、`controller-visual-ready`、`presentation-committed`，之后才有 `prepared` 与 `revealed`。缺哪一个就查哪一个，不用其他事实推断。
- 状态在 `prepared` 之后继续推进时，旧的 prepared 立即作废：尚未提交暂存的事务回到 `AwaitingPrepared`，Reveal 之后的事务重启最终可见帧。不要假设“已经 prepared 就一定会显示”。
- 正在推进的展示每个阶段有 5 秒超时（源码常量）。等待有效可见几何时，以及 Runtime 被抑制或刚解除抑制尚未收到 Web 回执时的 3、4、5 阶段，计时暂停。尚未出队的实例不受它约束，由 Runtime 侧 15 秒的 Controller 屏障和可靠事件重试耗尽判失败。
- 覆盖抑制与恢复：`SetRuntimePresentationSuppressed` 以带单调 revision 的可靠绝对状态下发，Runtime 设置透明与 Pointer 后回执同一 revision。解除时只有收到 `suppressed=false` 的精确 Web 回执（日志 `InstantScreen Runtime presentation suppression applied by Web`）之后才请求恢复帧，仍处于 3、4、5 阶段的 Screen 统一回到 `AwaitingReveal` 重走最终帧。不要用延长超时、提前移除覆盖或折叠 Host 代替。
- 输入租约：`GameAndMenu`、`Menu`、`Modal` 的 Screen 由 Runtime 为每次真实所有权世代申请确认，Native 只接受实例、事务、Surface、文档、状态、展示全部匹配的请求。抑制、展示版本推进、文档更换都会清零旧确认。被覆盖页面保留画面但立即交出焦点与指针，恢复时重新申请，不重建页面、不重播常驻外壳的动画。
- Park 与 Resume：最后一个真实 Screen 释放后，非 `OnDemand` 的 Runtime 先隐藏 Surface，再通知 Web 停驻；Web 隐藏全部 Screen 并回执，透明帧认证后 Browser 才冻结，并从 Host 卸下。下一次真实 Show 先恢复再只发送一次 Show，使用新的实例、事务与 revision，Controller 文档可能被复用。页面因此必须：按 `ue:webUI.lifecycleChanged` 的实例身份重置自己的版本与异步延续，被隐藏、覆盖或停驻时停止无限动画、rAF 与定时器。
- 失败必须 fail-open。代理在 Endpoint 终止失败且自身仍激活时会自动 `DeactivateWidget()`，由页面栈恢复上一层与输入；宿主为该页面持有的其他租约（HUD 抑制令牌、原生遮罩、输入模式）要在失活路径或 `HandleInstantScreenReplacementFailed()` 里对称释放，需要时降级为可交互的原生提示。不经代理、直接用槽 `ShowScreen()` 的弹窗必须自己绑定 `Endpoint->OnError`。不伪造 ACK、不强行显示未认证页面、不重建共享 Browser。

## 动画契约

Runtime 侧保证以下行为，新页面只需要顺着它写（页面侧写法见 [Bridge 与生命周期](bridge-lifecycle.zh-CN.md)）：

1. 文档生命周期不是 `Visible` 时，Runtime 注入的样式以 `animation: none`、`transition: none` 禁止创建动画，所以入场必须用 CSS 动画或过渡声明在元素上，由生命周期切换自然启动。
2. 每次从隐藏变为可见，Runtime 在同一个脚本任务里先结算一次静态基线，再只切换一次 `Visible`；第一张可能到达屏幕的帧就是入场第 0 帧。
3. 每次出现获得新的 appearance revision 并从头播放；覆盖恢复、再次打开、路由往返都一样。页面和 C++ 都不再发送第二条“开始动画”命令。
4. 页面不调用 `Element.animate()`，不遍历动画实例做 pause / play / restart，不用 rAF 或延时定时器补播。
5. 入场动画必须有限且会收敛：Runtime 等当前出现的全部有限动画结束才判定展示 settle，期间占用该 Runtime 唯一的准备槽，后续 Screen 排队等待。无限循环动画不计入，但要在不可见时停止。
6. 入场根节点不做整屏 opacity、filter 动画（原子 Reveal 由 Native 负责）；有限动画落在面板、标题、卡片等内容组上，优先 `opacity` 加 `transform`。样式中不得出现 `backdrop-filter`、`mix-blend-mode`、`prefers-reduced-motion` 与对 `filter` 的过渡，`<OrionBrowser>/Content/UI/WebUI/Shared` 下的 `npm run animations:contract:check` 会拒绝。
7. 多路由 App 的共享外壳不随内部路由重新挂载；路由模块只在真实访问时加载，可以缓存，但不得提前创建隐藏 DOM 或提前运行动画。

## 页面级资源与声音路由

页面实例的权威路由键是 `ScreenInstanceId` → `ScreenDefinition` → `AppDefinition` → `SoundManifest` / `FontManifest` / `AssetManifest`。不要用 WBP 名、DOM 路由或临时 BrowserId 作为声音、字体、图片的长期键；声音事件用稳定的字面量 ControlId，动态业务 ID 只进 payload。图片只在真实页面请求且元素存在时参与就绪门禁，不能靠隐藏 iframe 提前加载来“修复”首帧；会在同一首帧事务内被替换的动态图片先在脱离文档的 `Image` 中加载解码，成功后再换入。细节见 [控件与资源](controls-resources.zh-CN.md)。

## 新增检查表

新增一个 Screen（已有 App）：

1. 页面路由与内容就绪，接好状态通道、展示 ACK 与输入处理。
2. `instant-screen.config.ts` 的 `screens[]` 增加一项：唯一 `screenId`、唯一 `route`、`captureMustContain`。
3. Designer Preview 能在该路由渲染出完整内容，实时渲染层受 `orionInstantBuild` 门控。
4. 重跑 App build、`instant:build`、`instant:validate`，并做双轮哈希比对。
5. 新建 `UOrionInstantScreenDefinition`：`ScreenId`、`AppDefinition`、`DefaultLayerTag`、`InputPolicy`、`CompositionMode`、`InitialRoute`（与配置的 `route` 一致）。
6. 加入某个 Catalog 的 `Screens`，确认该 Catalog 的 Profile 映射了这个层。
7. 建 WBP：父类、名为 `WebUI` 的槽、`ScreenDefinition`。
8. Presenter：初始状态与 revision、`PushState`、事件入口、请求处理、失败释放。
9. 宿主把该 WBP 推入与 `DefaultLayerTag` 对应的 CommonUI 层。

新增一个 App，在上面之外还要：

1. 按脚手架建好 `<WebUIRoot>/<AppId>` 与 `UOrionWebUIAppDefinition`（`AppId` 等于目录名），挂好需要的 Sound / Font / Asset Manifest。
2. `packageId` 写成 `<AppId>`。
3. 共享 Runtime 输出存在且 `instant:runtime:check` 通过。
4. 目标 Runtime 在根布局里有对应的 Runtime Host，层 Tag 已注册，Engine ini 已配置 `LegacyTexture`。
5. Catalog 有明确的注册方，且注册早于首次 Show。
6. `dist`（含 `dist/instant`）与 `__instant__/dist/runtime` 进入打包，见 [构建与验证](build-validation.zh-CN.md)。

## 失败签名

| 签名 | 原因 | 处理 |
|---|---|---|
| `requires explicit LegacyTexture; session creation refused` | 渲染模式未显式配置为 `LegacyTexture` | 补 Engine ini 配置；不要改代码绕过 |
| `Rejected InstantScreen package ScreenId=...`（`Could not read JSON file`、`package header mismatch`、`Could not read package payload`） | 包未生成、被 App build 清掉，或 `packageId` / `screenId` / `route` / 协议版本与 Definition、插件不一致 | 按顺序重建；对齐配置与 Definition |
| `ShowScreen rejected ScreenId=... because no active Catalog registration provides its validated Package identity` | Show 早于 Catalog 注册，或注册失败后仍继续 | 先查更早的 `Rejected ...` 日志，修正注册时机 |
| `Controller presentation barrier for <ScreenId> timed out`，展示 ACK 与资源就绪都有，唯独缺 `state-committed`、`controller-visual-ready`、`prepared` | Show 传入的种子 revision 大于第一次 `PushState` 的 revision（常见于把展示 revision 当状态 revision），`PushState` 被拒；或页面在 DOM flush 后没有调用 `stateCommitted` | 对齐 Show 种子、第一次 `PushState` 的返回值与页面状态事件；不要把展示 ACK 当作状态已提交 |
| `Presentation commit rejected ... Reason=request-not-observed`（或 `stale-revision`、`future-revision`、`invalid-revision`） | 页面在观察到显式展示请求之前就回 ACK（通常从状态路径隐式入场），或 revision 不精确 | ACK 只在收到对应请求后、用同一 revision 发送 |
| `InstantScreen event ue:<x>.enterRequested at revision <n> was not acknowledged after <k> attempts` | 页面没有在输入就绪前注册该事件的监听，或没有按精确 revision 回 ACK；若新 Screen 连 `controller-host-installed` 都没有，则是同 Runtime 上一个页面的入场尚未 settle、占着准备槽 | 修页面监听与 ACK；后一种确认共享 Runtime 是当前构建、入场动画有限，不靠加大重试或重建 Browser |
| `InstantScreen presentation timed out Phase=<n> ...` | 读后面的谓词：`Geometry` / `Visible` 为假是槽没有排布或代理未激活；`StateAck`、`PresentationAck` 两侧不等是页面缺确认；`InputOwnershipRevision=0` 是输入租约未确认（被弹窗覆盖、被抑制，或 `InputPolicy` 与层不符） | 按缺失的谓词定位，不延长超时 |
| 展示失败后底层 HUD 一直不恢复、输入卡在弹窗 | 宿主没有消费 Endpoint 的失败事件，自己的抑制令牌没有释放 | 在失活与失败路径对称释放，fail-open |
| 首次显示先闪预览、字体或图片替换、动画像播两次 | 两个文档先后可见（`static` 策略用于动态页面，或自建了第二文档） | 改用 `controller`，保证唯一可见文档 |
| `Chromium DOM capture timed out after ... ms` | 捕获中页面不收敛：实时渲染层未按 `orionInstantBuild` 关闭、存在永久定时器 | 按“首帧捕获的确定性规则”修页面；不提高看门狗、不并发重试 |
| `capture is missing marker` / `did not contain a rendered #app` | Designer Preview 没有渲染出该路由（预览数据缺失、hash 或 `query` 不对），或标记文本与真实 DOM 不符 | 修预览数据或 `hash`、`query`、`captureMustContain` |
| 两轮构建 `first-frame.html` 哈希不同 | DOM 在动画结束时改变，或渲染了时间、随机内容 | 让 DOM 只随状态变化 |
