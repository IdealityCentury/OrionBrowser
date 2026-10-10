# 控件合同与资源接入

每个可交互控件要有稳定身份并登记进按钮合同；声音、字体、图片、实时画面、文本各有唯一接入通道。本文只写页面作者必须遵守的规则与接口名。Web 生命周期与 Intent 见 [Bridge 与生命周期](bridge-lifecycle.zh-CN.md)，C++ Presenter 与资产见 [UE 侧宿主](native-host.zh-CN.md)，首帧包见 [InstantScreen](instant-screen.zh-CN.md)，插件源码的导入方式见 [Web App 脚手架](web-app-scaffold.zh-CN.md)，检查命令的运行方式见 [构建与验证](build-validation.zh-CN.md)。标注“宿主自备”的组件、函数与检查器不在插件里，需要宿主工程自己实现；其余符号都在 `<OrionBrowser>` 内。

## A. 控件、按钮合同与声音

### A1. DOM 标记属性

| 属性 | 读取方 | 语义 |
| --- | --- | --- |
| `data-orion-control-id` | 插件 Runtime（控件声音、Designer 检查器、InstantScreen 静态动作表） | 控件的稳定字面量身份，即 ControlId |
| `data-orion-fixed-button` / `data-orion-dynamic-button` | 插件把二者列为声音目标与 ControlId 兼容候选；宿主合同检查器用其值对应合同 `buttons[].id` / `dynamicButtons[].id` | 固定按钮（一个 DOM 对一个合同项）/ 动态按钮模板（一个模板对多个实例），互斥 |
| `data-orion-sound-context` | 插件 Runtime | 写在子界面根容器上，把其内控件声音路由到 `ControlSoundContextId` 相同的宿主策略 |
| `data-orion-sound-policy` | 插件 Runtime | `manual` / `custom` / `none`：该节点及后代跳过自动 Hover/Click |
| `data-orion-action` | `installCommonActionRouter()` | 收到 `ue:commonAction` 时对 `actionId` 匹配的元素执行 focus + click；带 `disabled` 或 `aria-disabled="true"` 时忽略 |
| `data-orion-event` | InstantScreen 包构建脚本 | 静态首帧动作表记录的事件名，见 [InstantScreen](instant-screen.zh-CN.md) |
| `data-focus-id` | 宿主导航层（宿主自备）；插件仅作 ControlId 兼容候选 | 实例 / 导航身份，可以拼业务 ID |
| `data-orion-user-select` | 插件 Runtime | `text` / `all`：对该子树放宽默认禁止的文本选择；页面不必自己写 `user-select: none` |
| `data-orion-font-policy` | 插件 Runtime | 见 B1 |

### A2. ControlId 规则

- 模板里每个原生 `button`、`input`、`select`、`textarea`、`a[href]`、`summary`、`role="button"` 以及其他可点击节点，都写**字面量** `data-orion-control-id`。不要写成 `:data-orion-control-id="expr"`，不要拼接变量。
- 取值只用字母、数字、`.`、`_`、`-`，以字母或数字开头，不超过 128 字符（插件按 128 截断并拒绝更长的请求）；值 `true` 被当作空。
- 动态业务 ID（物品、玩家、消息、索引）只进入 Intent payload 与 `data-focus-id` 这类实例身份，不拼进 ControlId，也不拼进声音 ID。动态列表所有同类项共用同一个 ControlId：

```vue
<button
	type="button"
	data-orion-dynamic-button="sample-panel-items"
	data-orion-control-id="sample-panel-item"
	:data-focus-id="`sample-panel-item-${item.id}`"
	:disabled="!state.buttons.itemSelectEnabled || pendingSelection"
	@click="intents.itemSelectRequested(item.id)"
>{{ item.label }}</button>
```

- 封装成组件的控件：组件模板内写一个所有实例共享的字面量 ControlId，或由调用处传入字面量 prop 并原样落到根 DOM 的 `data-orion-control-id`（宿主自备的焦点表面组件应这样实现）；实例身份走单独的属性。
- 插件解析 ControlId 的兼容顺序是 `data-orion-control-id` → `data-focus-id` → `data-orion-fixed-button` → `data-orion-dynamic-button` → DOM `id` → `name`。新页面不依赖回退；没有任何稳定 ID 的控件只能播放默认声音，无法逐控件覆写。
- 禁用态必须是表达式，如 `:disabled="!state.buttons.confirmEnabled || pending"`：业务资格（`state.buttons.*`）由 C++ 发布，Web 只叠加本地草稿、等待、选择状态；模板里不写字面量 `disabled`。
- `requestIntent(name, payload, { controlId })` 的 `controlId` 传同一个字面量。

### A3. 按钮合同 `webui-button-contract.json`

放在 `<WebUIRoot>/<AppId>/webui-button-contract.json`，每个 App 必须有。最小模板（`<HostModuleDir>`、`<HostDocsDir>` 是相对 `<ProjectRoot>` 的宿主目录）：

```json
{
	"version": 1,
	"appId": "SamplePanel",
	"cpp": {
		"header": "<HostModuleDir>/SamplePanelScreen.h",
		"source": "<HostModuleDir>/SamplePanelScreen.cpp",
		"dispatchFunction": "DispatchWebIntent",
		"stateBuilderFunction": "BuildStatePayload",
		"statePushFunction": "PushStateToWeb",
		"stateChangedEvent": "ue:samplePanel.stateChanged",
		"disabledGuardFunction": "RejectDisabledButtonIntent"
	},
	"documentation": "<HostDocsDir>/sample-panel-button-interfaces.md",
	"buttons": [
		{
			"id": "sample-panel-confirm", "controlId": "sample-panel-confirm", "page": "Sample Panel", "label": "确认",
			"webIntent": "intents.confirmRequested", "webEnabledState": "state.buttons.confirmEnabled",
			"webEvent": "samplePanel.confirmRequested", "stateKey": "confirmEnabled",
			"nativeEvent": "OnConfirmButtonClicked", "enabledProperty": "bConfirmEnabled",
			"defaultImplementation": "校验当前选择后提交，并发布新状态"
		}
	],
	"dynamicButtons": [
		{
			"id": "sample-panel-items", "controlId": "sample-panel-item", "page": "Sample Panel", "label": "列表项（每项）",
			"webIntent": "intents.itemSelectRequested", "webEvent": "samplePanel.itemSelectRequested",
			"cppEvent": "samplePanel.itemSelectRequested", "nativeEvent": "OnItemSelectRequested",
			"parameters": "FName ItemId", "enabledProperty": "bItemSelectEnabled", "validationSymbol": "TryResolveItem",
			"defaultImplementation": "校验 ItemId 属于当前列表后切换选择"
		}
	],
	"intentTransport": {
		"runtimeProtocolVersion": 8,
		"api": "requestIntent",
		"requestEvents": ["samplePanel.confirmRequested", "samplePanel.itemSelectRequested"],
		"notificationEvents": ["samplePanel.stateApplied"],
		"dynamicForwarders": []
	}
}
```

**插件脚本只读取 `intentTransport`**（`<OrionBrowser>/Content/UI/WebUI/Shared/scripts/webui-intent-contract-lib.mjs` 的 `validateIntentContract`，由 `<OrionBrowser>/Content/UI/WebUI/Shared` 的 `npm run contracts:project` 对 `<WebUIRoot>` 下每个带 `package.json` 的目录执行）。它用 TypeScript AST 扫描 App `src` 下的 `.ts` / `.vue`（含模板事件表达式；文件名含 `.test.ts`、`preview`、`fixture`、`mock` 的跳过）：

- `runtimeProtocolVersion` 必须等于 `8`。
- `requestEvents`：所有 `requestIntent(...)` / `emitIntent(...)` 的字面量事件名都要在表内；表内每一项都必须有真实调用；不能同时出现在 `notificationEvents`。
- `notificationEvents`：所有 `x.emit(...)`、`emitContinuous(...)` 的字面量事件名。任何属性调用形式的 `.emit(` 都算 Bridge 通知；裸 `emit(...)` 只在该文件没有 `defineEmits` 时才算。业务动作不得走 `emit`。由共享 Runtime 代发的回执事件可以列在这里，列了没有调用不报错。
- `dynamicForwarders[]`：事件名不是字面量的调用必须逐条登记 `{ file, owner, expression, channel }`——`file` 相对 App 且用 `/`；`owner` 是所在 `function` 声明的名字（箭头函数不算，没有则为空串）；`expression` 是第一个实参的源码原文（换行为 LF）；`channel` 为 `request` 或 `notification`。能写字面量就不要用它。
- `eventConstants[]`（可选）：事件名写在协议常量对象里时登记 `{ file, object }`，`file` 相对 App，文件里须有 `<object> = { key: "事件名", … } as const`。登记后 `requestIntent(<object>.<key>, …)` 这类实参按字面量事件名校验。
- `eventExpansions[]`（可选）：一个实参在运行时取自协议对象的任意一项时登记 `{ expression, sourceIncludes, file, object }`：`expression` 是实参的源码原文，`sourceIncludes` 是该调用所在文件必须包含的标识文本（可省略），`file` 可以指向 `../Shared/src/…` 下的共享协议。命中的调用按该对象的全部事件逐个校验，每个事件都要在 `requestEvents` 或 `notificationEvents` 里。
- 登记的文件或对象不存在即失败，不会被当成“没有常量”。
- `<WebUIRoot>/Shared/src` 若存在，其中不得出现任何 Bridge 调用；共享组件通过回调把动作交给所属 App。

**其余字段由按钮接口合同检查器读取**（`<OrionBrowser>/Scripts/check-webui-button-interface-contract.ps1`，按 App 运行，参数见 [构建与验证](build-validation.zh-CN.md) 的脚本清单）。改完模板、合同或 Presenter 后运行它，并用 `-UpdateDocumentation` 生成 `documentation`；下面的语义也是 Web ↔ C++ 的唯一对照表。

| 字段 | 语义 |
| --- | --- |
| `cpp.header` / `cpp.source` | Presenter 头 / 源文件；实现拆到多个 cpp 时用 `version: 2` 并在 `cpp.presenters[]` 逐个登记 `{ id, header, source }` |
| `cpp.dispatchFunction` | 接收 Web 事件并分发到各 Native 接口的函数 |
| `cpp.stateBuilderFunction` / `cpp.statePushFunction` | 构建完整状态 / 把状态发布给 Web 的函数 |
| `cpp.stateChangedEvent` | 状态事件名；可选 `stateChangedCppSymbol` 指向保存该名字的 C++ 常量 |
| `cpp.disabledGuardFunction` | 禁用 guard：资格为假时拒绝意图并重新推送权威状态 |
| `documentation` | 由合同生成的接口说明文档路径（生成物，不手写） |
| `web.componentHostFiles[]` | 不逐按钮标记的通用控件封装文件（相对 App）。只登记纯控件封装，不登记业务面板，否则面板内按钮失去检查 |
| `intentTransport.api` | 固定写 `requestIntent` |

- `buttons[]`（固定按钮）：`id` 等于 DOM 的 `data-orion-fixed-button`，恰好对应一个 DOM 元素；`controlId` 等于 DOM 字面量；`webIntent` 是点击表达式调用的函数，`webEnabledState` 必须出现在 `:disabled` 表达式里；`webEvent` 用语义化的 `…Requested` 后缀，禁止 `buttonClicked` 这类通用事件；`stateKey` 是状态里的资格键，`enabledProperty` 是对应的 C++ `bool` 属性（资格是计算值时另写 `enabledExpression`，不要虚构属性）；`nativeEvent` 是该按钮独立的 `BlueprintNativeEvent`；`cppEvent` 可选，C++ 用常量保存事件名时填常量名。
- `dynamicButtons[]`（动态按钮模板）：`id` 等于 `data-orion-dynamic-button`，恰好对应一个模板；另需 `cppEvent`、`parameters`（Native 接口参数）、`validationSymbol`（C++ 校验 payload 身份的函数）。`guardMode` 默认 `disabled-button`；改为 `structured-request` 时再填 `structuredRejectionSymbol`。
- `componentControls[]`（经子组件转发的按钮与本地草稿控件）：公共字段 `id`、`controlId`、`file`（相对 App）、`page`、`label`、`kind`、`activation`（模板里点击表达式的原文）、`defaultImplementation`；同一语义按钮在多个条件分支重复出现时用 `occurrences` 声明模板数量；声明了禁用条件时写 `enabledExpression`（必须出现在 `:disabled` 里）。

```json
"componentControls": [
	{
		"id": "sample-panel-filter-toggle", "controlId": "sample-panel-filter-toggle",
		"file": "src/components/FilterBar.vue", "page": "Sample Panel", "label": "筛选开关",
		"kind": "local", "activation": "toggleFilter()", "handler": "toggleFilter",
		"defaultImplementation": "只切换本地筛选草稿"
	},
	{
		"id": "sample-panel-apply", "controlId": "sample-panel-apply",
		"file": "src/components/FilterBar.vue", "page": "Sample Panel", "label": "应用筛选",
		"kind": "native", "activation": "$emit('apply')", "enabledExpression": "state.buttons.applyEnabled",
		"forwarding": { "file": "src/App.vue", "component": "FilterBar", "event": "apply", "handler": "applyFilter" },
		"operations": [
			{ "webEvent": "samplePanel.filterApplyRequested", "nativeEvent": "OnFilterApplyButtonClicked", "dispatchFunction": "DispatchWebIntent", "dispatchToken": "bFilterApply", "guardExpression": "CanApplyFilter()" }
		],
		"defaultImplementation": "校验筛选条件后重建列表并发布状态"
	}
]
```

- `kind=local`：只做草稿切换、候选选择、滚动、未派发确认的取消。`handler` 是普通函数名，函数体内不得调用 `emit`、`requestIntent`、`requestCommand`；要提交业务就改成 `kind=native`。
- `kind=native`：`forwarding` 描述父组件的真实事件绑定（`<FilterBar @apply="applyFilter">`）；子组件发出 camelCase 事件而父组件用 kebab-case 绑定时加 `forwarding.emittedEvent`。每个原生请求在 `operations[]` 登记：`dispatchToken` 是分发函数里保存 `EventName == TEXT("<webEvent>")` 结果的局部变量名，`guardExpression` 是调用 `nativeEvent` 之前传给禁用 guard 的表达式。只是复用已登记按钮的意图时改填 `nativeReference`（值为那个按钮的 `id`，父组件绑定其 `webIntent`），不新增重复的 Native 接口。

### A4. 固定按钮的 Native 接口与禁用 guard

- 每个固定按钮对应一个独立的 `UFUNCTION(BlueprintNativeEvent)`（如 `OnConfirmButtonClicked()`，默认实现不能为空）和一项由 C++ 发布的资格（如 `EditDefaultsOnly` 的 `bool bConfirmEnabled`，或一个计算表达式）。不做“一个通用点击接口 + 按钮 ID 参数”。
- 分发函数里先 guard 后调用：`if (RejectDisabledButtonIntent(bConfirmEnabled, EventName)) { return; } OnConfirmButtonClicked();`。guard 由宿主 Presenter 实现，拒绝时重新推送权威状态，让页面回到真实资格。
- 状态构建函数把每项资格序列化到 `stateKey`；页面的禁用绑定只读这份状态。意图回执与状态发布见 [UE 侧宿主](native-host.zh-CN.md)。
- 修改既有界面时保留用户已有的 Blueprint 覆写，不改接口名与参数。

### A5. 声音

两条通道，同一次交互只走其中一条：

| 通道 | 配置归属 | 触发 |
| --- | --- | --- |
| 控件 Hover / Click | 承载界面的 Widget Blueprint 的 Class Defaults：`UOrionWebUIActivatableWidget.ControlSoundPolicy` 或 `UOrionInstantScreenActivatableWidget.ControlSoundPolicy`。不在 AppDefinition，不在 ini | 插件在文档层自动委托，页面不写任何代码 |
| 业务语义声音（确认、返回、错误、滑条刻度） | `UOrionWebUIAppDefinition.SoundManifest`（`UOrionWebUISoundManifest.Entries[].StableId`） | 页面调用 `playSound` |

- `ControlSoundPolicy.DefaultSounds.HoverSound / ClickSound` 是默认声音；`ControlOverrides[]` 按 `ControlId` 用 `bOverrideHoverSound` / `bOverrideClickSound` 分别覆写。某项要静音时覆写并把该项 `bEnabled` 设为 false：它会消费这次交互，不回退到默认声音。
- 自动目标：带 `data-orion-control-id`、`data-orion-fixed-button`、`data-orion-dynamic-button` 的节点，以及 `button`、`[role="button"]`、`a[href]`、非 hidden 的 `input`、`select`、`textarea`、`summary`。指针首次进入或 DOM 焦点进入播 Hover，`click` 播 Click。
- 禁用控件不发声的判定是 `:disabled`、`aria-disabled="true"`、`aria-busy="true"`。只用 CSS class 表示禁用或加载中的控件仍会发声，所以禁用和等待必须落到这三个属性之一。
- 一个 Browser 承载多个宿主 Widget 时，子界面根容器写 `data-orion-sound-context="<ContextId>"`，与那个 Widget 的 `ControlSoundContextId` 一致；它只是策略路由键，不替代 ControlId，也不出现在覆写表里。
- 手柄逻辑导航不移动 DOM 焦点时由 C++ 调用 `PlayControlSound(ControlId, Interaction, ContextId)`，传同一个稳定 ControlId（先把导航 / 焦点 ID 解析回 ControlId）。
- 没有 DOM 事件的交互区域（例如画布命中区）才调用 `api.playControlSound(controlId, "hover" | "click", contextId?)`；普通节点加上 `data-orion-control-id` 就已经是自动目标。
- 声音 ID 不由插件规定：`SoundManifest` 的 `StableId` 是宿主自定的稳定字面量，插件模板里的 `ui.hover`、`ui.click` 只是示例值。页面调用 `await api.playSound("sample.confirm")`，可带 `{ volumeMultiplier, pitchMultiplier, startTime }`；或用 `playUISound(api, id, options)`，它在 `api` 缺失或请求被拒绝时静默返回 `undefined`。
- `playSound` 被拒绝的代码：`E_SOUND_DISABLED`（`bAllowWebSoundPlayback` 关闭）、`E_INVALID_ARG`（缺 `soundId`）、`E_SOUND_UNAVAILABLE`（没有 Manifest 或该 ID、条目禁用、未配置资产）。
- 边界：不在页面里加载或播放音频文件；不把业务 ID 拼进声音 ID；不用 `playSound` 给标准控件补通用 Hover/Click（会与自动委托双播）。插件模板 `App.vue` 里按钮上的 `@mouseenter` 加 `playUISound` 只是 Bridge 演示，新界面不要照抄。已有独立语义声音的节点或容器写 `data-orion-sound-policy="manual"`，让自动策略跳过。

### A6. UMG Designer 的 ControlId 检查器

插件 Editor 模块提供。在 Widget Blueprint 里选中 `UOrionWebUIWidget`（分类 `Orion WebUI|Editor`）或 `UOrionInstantScreenWidget`（分类 `Orion InstantScreen|Editor`），设置 `DesignTimeControlIdPreviewMode`：`HoveredControl`（默认，悬停显示）、`AllControls`（标出当前页全部控件，有数量上限）、`Hidden`。前提是 `bShowDesignTimePreview` 为 true 且页面能在 Designer 中加载。蓝色标签是解析出的 ControlId，红色 `<missing>` 表示缺字面量；动态列表多行显示同一个值是正确结果，出现带业务 ID 或索引的值说明拼接了。它与运行时声音策略共用同一选择器和解析顺序：写完模板后用它核对，再去填 `ControlOverrides`。

### A7. 自定义右键菜单

- `UOrionWebUIWidget` 始终抑制 Chromium 原生菜单（没有开关），右键菜单由页面实现：在目标元素监听 `contextmenu` 并 `preventDefault()`；也可以在右键 `pointerdown` 时先记录命中的稳定领域 ID 并打开菜单。
- 若 `pointerdown` 插入了全屏遮罩，同一次手势随后到达的 `contextmenu` 会命中遮罩：把这一对事件当作一次手势消费，不能让遮罩立刻关闭刚打开的菜单。
- 右键只负责打开菜单。菜单项是普通控件（有 ControlId、进合同），动作通过 `requestIntent` 交给 C++ 校验，权限来自 C++ 状态；不覆盖 Esc 与返回动作的既有语义。

### A8. 连续指针会话（拖拽、按住、旋转）

所有“按下—移动—抬起 / 取消”的交互统一使用 `<OrionBrowser>/Content/UI/WebUI/Shared/src/input/orion-pointer-session.ts` 的 `createOrionPointerSession()`，不要自己注册 window 级 move / up 监听。

```ts
const session = createOrionPointerSession({
	allowedButtons: [0],
	allowedPointerTypes: ["mouse", "pen", "touch"],
	dragThreshold: 6,
	coalesceMovesWithAnimationFrame: true,
	accept: (event) => !dragDisabled.value && !(event.target as Element).closest("button"),
	onMove: (_event, snapshot) => previewDrag(snapshot.totalDeltaX, snapshot.totalDeltaY),
	onCommit: (_event, snapshot) => { if (snapshot.thresholdReached) intents.itemMoveRequested(buildMovePayload(snapshot)); },
	onCancel: () => clearDragPreview(),
});
// 模板：@pointerdown="session.begin($event, $event.currentTarget)"；onBeforeUnmount(() => session.dispose())
```

- 只有同一 pointer ID 的 `pointerup` 触发 `onCommit`，且恰好一次。`pointercancel`、窗口失焦、文档隐藏、页面被覆盖 / 挂起、离开 Active、`dispose()` 都只触发 `onCancel`。共享生命周期会在覆盖、挂起和销毁时自动取消本文档内的全部会话。
- 表现预览写在 `onMove`，唯一的业务意图写在 `onCommit`，清理写在 `onCancel`。服务器权威的操作在 commit 里只发一次意图，等权威状态回显，不在本地永久改状态。
- 不读 `PointerEvent.buttons` 判断按键是否仍按下，不把 `lostpointercapture` 当作抬起（离屏渲染下二者都不可靠，会话已降级处理）；不加 Timer、轮询或超时补偿。
- 状态只读回调里的 `snapshot`（`generation`、`pointerId`、起点、增量、`thresholdReached`、`captureOwned`），不另存一套 `active / pointerId / startPosition`。
- 同一移动只能有一个所有者：某种指针已由 Native 侧拖拽处理时，在 `allowedPointerTypes` 里排除它。Native Surface 层不接收指针，不能当拖拽目标。

## B. 资源

### B1. 字体

- 字体全部来自 UE：项目级 `UOrionWebUIFontSettings.SystemFontManifest` 指向的 `UOrionWebUIFontManifest`，新 App 默认继承；只有确需独立字体时才设置 `UOrionWebUIAppDefinition.FontManifest` 或 `bOverrideFontPolicy`。页面不声明自己的 `@font-face`，不依赖系统字体。
- 入口在挂载前调用 `ensureOrionWebUIFontStylesheet("<AppId>")`（`<OrionBrowser>/Content/UI/WebUI/Shared/src/instant-screen/orion-instant-screen-vue.ts`）。它创建 `link#orion-webui-fonts`，地址为 `https://orion-webui.local/<AppId>/ue/fonts/orion-fonts.css`。文档里只能有这一个字体样式表入口：宿主按这个 id 收养它并在语言切换时原子替换；不带 id 另建一个 link 会留下重复样式表。
- CSS 只消费 Manifest 变量，不硬编码字体族：正文 `font-family: var(--orion-webui-body-font-family, var(--orion-webui-font-family, sans-serif))`，标题把第一个变量换成 `--orion-webui-heading-font-family`。
- 插件自动给有直接文本的元素和表单控件写 `data-orion-font-role`，并以 `!important` 设置其 `font-family`：计算字号大于策略阈值（`FontPolicy.HeadingFontSizeThresholdPx`，默认 24）的用标题字体（仅对策略允许的语言生效），否则用正文字体。它只改 `font-family`；字号、字重、行高、字距由页面 CSS 决定。新增或替换的文字子树在绘制前就会被分配角色，页面不需要为动态文字做补偿。
- `data-orion-font-policy` 写在节点或祖先上，取最近的一个：`body` / `heading` 强制角色，`none` 表示该子树完全使用页面自己的字体声明；其他值或不写即自动判定。
- `svg`、`canvas` 内的文字不参与自动策略。自绘文字用 `api.getFontFamilyForSize(sizePx)`（或 `resolveFontRoleForSize`）取字体族。
- 首帧字体身份：InstantScreen 首帧捕获只保留指向 `orion-webui.local/.../ue/fonts/` 的样式表 link，Controller Host 也固定引用 `/<AppId>/ue/fonts/orion-fonts.css`。`<AppId>` 必须是运行时真正加载的那个 App（与包身份一致）；改了同名但未加载的 App 不会生效。
- InstantScreen 的展示门禁按 Manifest 的 family / style / weight 对已挂载的真实文本逐个执行 `document.fonts.load()` 与 `check()`，不是只等一次 `document.fonts.ready`。因此：首帧要出现的文字在状态提交时就挂进 DOM；页面自己的准备逻辑不把 `document.fonts.ready` 当成“字体已就绪”，也不用 `requestAnimationFrame` 推进准备期等待——准备期文档不可见，rAF 不保证触发，会与 Reveal 门禁互相等待。用 Promise 链或 `MessageChannel`。
- 需要新字体时由 UE 侧为每个实际使用的 family + weight 提供一份完整 WOFF2 的 `UOrionWebUIFontPayload`，填到 `FOrionWebUIFontFaceEntry.WebPayload`；不做字符子集，不填 `UnicodeRangeCss`，同一 family + weight + style 只有一个 Face。生成工具是 `<OrionBrowser>/Content/Python/Fonts/generate-orion-webui-font-payload.py`（`--font`、`--output`、`--full-font`）。

### B2. 图片

| 图片来源 | 通道 |
| --- | --- |
| 静态 UI 图（背景、插画、图标、地图预览等） | 放在 App 目录内随 WebUI 打包，建议 WebP；C++ 只发布稳定 ID，页面解析成打包 URL |
| 必须由 UE 运行时产生的低频 `UTexture2D`（头像、运行时生成的图标） | Runtime Image |
| 生产方手里已是 CPU 像素 | `RequestPixelResource`（同一套租约与 URL） |
| 持续更新的画面（SceneCapture、RenderTarget、Media、动态材质） | Native Surface，见 B3 |
| InstantScreen 需要的非图片不可变字节（如 glTF） | `UOrionInstantScreenEndpoint::RegisterBinaryResource(StableId, Bytes, MimeType)` |

静态图不新建 `UTexture2D`，也不往 `UOrionWebUIAssetManifest` 里加条目。稳定 ID 到 URL 的映射由页面维护（宿主自备，形如）：

```ts
import harborUrl from "../assets/maps/map-harbor.webp";
import quarryUrl from "../assets/maps/map-quarry.webp";

const previewUrls: Readonly<Record<string, string>> = Object.freeze({ "Map.Harbor": harborUrl, "Map.Quarry": quarryUrl });

// 未知或空 ID 返回 ""，由页面显示空态底图。
export function resolvePreviewUrl(previewId: unknown): string {
	return typeof previewId === "string" && Object.prototype.hasOwnProperty.call(previewUrls, previewId) ? previewUrls[previewId] : "";
}
```

- 转 WebP 可用 `<OrionBrowser>/Content/Python/Images/optimize-webui-image.py`（`--input`、`--output`，可选 `--crop x,y,w,h`、`--size WxH`、`--fit contain|stretch`、`--quality`、`--lossless`）。
- 模板与非测试 `.ts` 里的每个 `<img>` 标签都写静态属性 `decoding="async"`，放在 `<img` 之后第一个（App 合同脚本的匹配方式见 [Web App 脚手架](web-app-scaffold.zh-CN.md)）。`<OrionBrowser>/Content/UI/WebUI/Shared` 的 `npm run images:decoding:check` 检查 `<WebUIRoot>` 下全部 App；`images:decoding:fix` 会改写所有 App 的源码，只在用户明确要求时运行，自己的 App 手工补齐。
- 图片保持原始比例：给容器定 `aspect-ratio`，图片用 `object-fit: contain` 或 `cover`，不分别拉伸宽高。
- 禁止：把图片编码成 Base64 放进状态或经 Bridge 传字节、写临时 PNG 文件、逐帧 Readback、把 Runtime Image 当视频流用。

Runtime Image 要点（C++ 调用细节见 [UE 侧宿主](native-host.zh-CN.md)）：

- `UOrionWebUIWidget` 与 `UOrionInstantScreenEndpoint` 都提供 `RequestTextureResource(StableId, Texture, Options)`，立即返回 `FOrionWebUITextureResourceHandle { RequestId, StableId, Url }`，完成时触发 `OnTextureResourceCompleted`。URL 形如 `https://orion-webui.local/<AppId>/ue/runtime/<token>`，`token` 不透明。
- 一个 `StableId` 是一份租约。同一 `StableId` 再次请求会得到新一代 URL，旧 URL 随后退役；条目移除时 `ReleaseTextureResource(StableId)`，界面销毁时 `ReleaseTextureResources()`。页面不解析、不拼接、不缓存 URL，只用当前状态里的值。
- 像素原地变化时递增 `Options.SourceRevision`（或 `InvalidateTextureResource`）；数量、选中态等纯数据变化不重新请求图片。`Options.MaxOutputDimension` 按实际显示尺寸设置；物品类透明图标用 `NormalizationPolicy = TransparentIcon`，头像和普通图片保持 `None`。虚拟纹理不支持（`UnsupportedVirtualTexture`）。
- 参与首帧的槽位：C++ 只在收到与当前 `RequestId`、URL 都匹配的 Ready 结果且 `IsTextureResourceReady(StableId)` 为 true 之后才把 URL 写进状态。`HasTextureResource` 在 Pending 时也为 true，不能当“可显示”用。
- Web 侧需要一个**内存图片组件（宿主自备）**，凡是会被状态刷新替换的运行时 URL 都经它显示，不直接写 `<img :src="url">`。行为要求：候选 URL 先在 detached `Image` 里完成 `load` 与 `decode()`，成功后才原子替换当前显示节点；候选 Pending、失败或被新值取代时保留 last-good；每个使用点拿到独立克隆的节点，不共用同一个 detached 节点；以最新请求为准，迟到结果丢弃。
- 原因：InstantScreen 的展示门禁要求 Controller 文档里每个可见 `<img>` 都加载并解码出像素，任何一个失败都会让这次展示失败；裸 `<img>` 绑定到已退役的候选 URL 会触发 `error`。

### B3. Native Surface

把 UE 持有的实时纹理或 UI 材质直接合成到页面布局里：Slate 在 DOM 锚点矩形处绘制，像素不进 JavaScript。

- UE 侧（`UOrionWebUIWidget` 或 `UOrionInstantScreenEndpoint`）：`SetNativeSurfaceTexture(SurfaceId, Texture)`、`SetNativeSurfaceMaterial`、`SetNativeSurfaceTint`、`SetNativeSurfaceCompositionLayer`、`ClearNativeSurface`、`ClearNativeSurfaces`；`OnNativeSurfaceLayoutChanged` 在位置、尺寸、可见性变化时触发，`bVisible` 为 false 时应暂停画面生产。
- Web 侧用 `<OrionBrowser>/Content/UI/WebUI/Shared/src/components/OrionNativeSurface.vue`：`<OrionNativeSurface surface-id="SamplePreview" class="preview-anchor" />`。唯一的 prop 是 `surfaceId`，根节点是带 `data-orion-native-surface` 的 `div.orion-native-surface`，有默认 slot。不用组件时直接 `const release = api.bindNativeSurface(surfaceId, element)`，卸载时调用 `release()`。`surfaceId` 用稳定字面量，与 UE 绑定逐字一致。
- 锚点必须在真实布局树里，`getBoundingClientRect()` 是位置与尺寸的唯一来源（已含 CSS transform）。UE 与 Web 都不另写固定坐标，UE 侧不再乘 DPI 或渲染缩放。
- 默认合成层 `AboveBrowser`：锚点矩形内部的网页内容会被原生画面盖住。边框画在外层容器上，锚点用 `position: absolute; inset: 1px` 内缩；slot 里的 DOM 只作浏览器预览或资源缺失时的占位。
- 支持位置、尺寸、平移 / 缩放、opacity 与祖先裁剪；不支持 rotate / skew 和 DOM 圆角裁剪——圆角、遮罩、渐隐放进 UE 的 UI 材质。
- 只有必须让 DOM 盖在画面之上时才用 `BelowBrowser`，它要求 `AppDefinition.bSupportsTransparency`，否则被拒绝并触发 `OnWebError`。
- 原生层不接收输入，指针与焦点仍归 Browser。布局测量由插件驱动（Resize / Mutation / 滚动 / 祖先动画期间逐帧），页面不写自己的 rAF 测量或定时重绑。
- 每个文档最多 512 个绑定。列表里的大量图标用 Runtime Image，不要每格一个 Surface。
- InstantScreen Controller 内：页面写本地 `surfaceId`，Runtime 自动作用域化为 `<ScreenInstanceId>__<surfaceId>`，C++ 通过 Endpoint 用同一个本地 ID。
- Controller 内作用域 API 可能先于 Native Surface API 就绪：绑定前先 `await api.waitForNativeSurfaceApi?.()`。插件自带的 `OrionNativeSurface.vue` 不等这一步，并且静默吞掉绑定异常（为了能在浏览器预览里运行），所以 Controller 里要用带等待的包装（宿主自备）：

```ts
let generation = 0;
let release: (() => void) | undefined;
async function bind(api: OrionWebUIApi, element: HTMLElement, surfaceId: string): Promise<void> {
	const current = ++generation;
	release?.();
	release = undefined;
	await api.waitForNativeSurfaceApi?.();
	if (current === generation) {
		release = api.bindNativeSurface(surfaceId, element);
	}
}
// 卸载：++generation; release?.(); release = undefined;
```

- keep-document 页面被重绑到新的 Screen 实例时组件不会重新挂载，绑定键由 Runtime 迁移；不要把 `onMounted` 当作新实例的唯一布局来源，也不要用 Timer 重试。需要主动刷新时调用 `api.requestNativeSurfaceLayoutSnapshot?.()`（共享生命周期每次进入 Active 已会调用）。
- Realm：Controller 文档里的元素来自另一个 JavaScript Realm，外层 Realm 的 `instanceof Element / HTMLElement / Node` 对它们恒为 false。任何跨文档接收节点的共享代码都用 `nodeType === 1` 判断，并从 `element.ownerDocument.defaultView` 取 `getComputedStyle`、`MutationObserver` 等。
- 资源退役顺序（C++）：先停止画面生产或材质参数写入 → `ClearNativeSurface`，或用 `SetNativeSurfaceTexture` / `SetNativeSurfaceMaterial` 原子替换 → 释放业务侧动态材质引用 → 最后销毁 RenderTarget、SceneCapture、Actor 或播放器。换 RenderTarget 时新建动态材质实例再 `SetNativeSurfaceMaterial`，不在仍绑定的实例上改纹理参数；不用延时或强制 Flush 代替这个顺序。

### B4. 本地化

- 文本源头是 `UOrionWebUIAppDefinition.TextCatalog`（`UOrionWebUITextCatalog.Texts`，Key → `FText`）。Key 用稳定的英文点分路径，如 `samplePanel.confirm`。
- 页面只写 Key 与兜底文本：`translate(table, "samplePanel.confirm", "确认")`（`<OrionBrowser>/Content/UI/WebUI/Shared/src/bridge/orion-webui.ts`）。初始表取自 bootstrap 的 `localization`（`{ culture, texts }`）。
- 监听 `ue:localeChanged` 并整体替换文本表。它是保留事件，晚注册的监听会立即收到最新值，页面不需要刷新；字体样式表随语言自动替换。
- 语言切换时替换**同一个语义节点**的文本，不为每种语言各挂一个节点，不在界面上并列硬编码两种语言。
- 跨 C++ / JSON / Web 的有限枚举用固定的字符串 wire token，不依赖 `FName` 的显示大小写。

### B5. WebGL 与高级视觉

- 业务状态仍由 C++ 发布，WebGL 层只做表现。画面隐藏、被覆盖或停放时停止渲染循环并释放 GL 资源：在生命周期的 `onPresentationCovered`、`onPresentationSuspended` 与组件卸载里停 rAF、销毁上下文与纹理，在 `onPresentationRestored` 里重建（回调见 [Bridge 与生命周期](bridge-lifecycle.zh-CN.md)）。
- three.js 这类重模块用动态 `import()`，模块解析与 WebGL 初始化放在入场动画结束之后；提前初始化会占住渲染线程，让入场动画停顿。
- InstantScreen 首帧捕获（URL 带 `orionInstantBuild=1`）期间不启动实时渲染层，否则首帧 DOM 会混入 canvas 并拖慢捕获。
- 渲染模式：InstantScreen 会话要求 `LegacyTexture`，其他模式下会话创建被拒绝。WebGL 在 `FullIR` 模式下不可用（`EOrionWebUIFallbackReason` 把 WebGL、Canvas2D 列为回退原因，而严格 FullIR 不回退）；FullIR 页面里的三维画面改用 Native Surface。
- CSS 限制（`<OrionBrowser>/Content/UI/WebUI/Shared` 的 `npm run animations:contract:check`）：不使用 `backdrop-filter`、`mix-blend-mode`、`prefers-reduced-motion` 规则，也不对 `filter` 做 `transition`。

### B6. World 空间叠层与资源路由

- World overlay 把跟随 Actor 的标记、血条投影到屏幕：每个 LocalPlayer 共用一个 Browser 里的一个叠层（`OrionWorldOverlayDOM.vue`），Actor 侧只挂纯数据的 `UOrionWebUIWorldElementComponent`，由 `UOrionWebUIWorldSubsystem` 合批成一个 `ue:worldElements` 事件。不为每个 Actor 创建 Browser 或 Widget。
- 页面级资源与声音的权威路由是 `ScreenInstanceId → ScreenDefinition → AppDefinition → SoundManifest / FontManifest / AssetManifest`（普通 Widget 为 `UOrionWebUIWidget → AppDefinition`）。不要用 Widget Blueprint 名、DOM 路由或 BrowserId 作为声音、字体、图片资源的长期键；Runtime Image 与 Native Surface 的键是调用方给的稳定 `StableId` / `SurfaceId`。

## 失败签名速查

| 签名 | 原因 | 处理 |
| --- | --- | --- |
| `uncontracted request <event>; business actions must use requestIntent` | 调用了合同未登记的事件 | 加入 `requestEvents` 或 `notificationEvents` |
| `business emit bypasses requestIntent: <event>` | 用 `emit` 发了 `requestEvents` 里的业务事件 | 改用 `requestIntent` |
| `unaudited dynamic <channel> forwarder <expr>` | 事件名不是字面量且未登记 | 改成字面量，或登记 `dynamicForwarders` |
| `contracted request has no production call: <event>` | 合同里有、源码里没有调用 | 接上调用或从合同删除 |
| `WebUI <img> tags missing decoding="async":` | `<img>` 缺 `decoding` | 在报出的标签上手工补 `decoding="async"` 后重跑 `check` |
| 禁用或加载中的按钮仍有声音；或同一次点击响两声 | 禁用只用 class 表达；自动策略与手动 `playSound` 并存 | 落到 `disabled` / `aria-disabled` / `aria-busy`；删掉手动调用或标 `data-orion-sound-policy="manual"` |
| 页面显示浏览器默认字体 | 没有 `link#orion-webui-fonts`、`<AppId>` 不是实际加载的 App、或 CSS 硬编码字体族 | 按 B1 接入口与变量 |
| `FontManifest face failed exact load/check: <descriptor>` | Manifest 的 Face 无法按 family / style / weight 精确加载 | 检查 UE 侧 FontManifest 与 `WebPayload` |
| `Controller image <url> for <ScreenId> failed to load` | 可见的裸 `<img>` 绑定了已退役或未就绪的运行时 URL | 经内存图片组件显示；C++ 只发布 Ready 的 URL |
| Surface 区域空白但 RenderTarget 有像素 | Controller 内未等 `waitForNativeSurfaceApi()`，或两侧 `SurfaceId` 不一致 | 用带等待的绑定包装；核对 ID |
| `InstantScreen Runtime=<id> requires explicit LegacyTexture; session creation refused` | 渲染模式不是 `LegacyTexture` | 调整宿主渲染模式配置 |
