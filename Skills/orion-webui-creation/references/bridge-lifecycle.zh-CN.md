# 页面接入：Bridge、生命周期、状态与 Intent

本文只管 Web 侧 `App.vue` 的脚本部分。脚手架文件见 [Web App 脚手架](web-app-scaffold.zh-CN.md)；C++ 如何发状态、收 Intent 见 [UE 侧宿主](native-host.zh-CN.md)；首帧包与层内 Runtime 见 [InstantScreen](instant-screen.zh-CN.md)。文中模块路径相对 `<OrionBrowser>/Content/UI/WebUI/Shared/src/`，名字与参数以该目录当前源码为准。

## 总原则

- C++ 拥有业务状态、按钮可用性和输入门禁。页面只做四件事：渲染完整状态快照、提交 Intent、回报精确 revision、执行布局与动画。
- 页面不保存第二份业务事实，不做“先本地成功再同步”。Intent 结果只结束传输等待，界面变化以随后到达的权威快照为准。
- 页面发出的回执（ACK）只有两种作用：让 C++ 停止重发，或证明某个 revision 已经提交 / 展示。它不能推进、回滚或伪造业务成功。
- 回执必须带精确 revision。零值、旧值、超前值、没有对应请求的回执都会被丢弃；不要补发、改值或换一个回执顶替。
- 页面不创建 Browser、不控制 Runtime 可见性，不复制 Ready 轮询、重试定时器、固定延时、隐藏预加载或自建入退场状态机；全部走本文列出的插件入口。

## 取得 Bridge

| 入口（`bridge/orion-webui.ts`） | 行为 |
| --- | --- |
| `waitForOrionWebUI(timeoutMs = 5000)` | 返回 `Promise<OrionWebUIApi>`。在 `orion-webui.local` 宿主内一直等到 Bridge 安装；普通浏览器超时后 reject；URL 带 `?orionDesignPreview=1` 时立即 reject。reject 分支就是页面的设计预览分支 |
| `resolveOrionWebUIForMount(timeoutMs = 5000)` | 挂载前使用：宿主内等待安装，普通浏览器与设计预览直接返回已有 API 或 `undefined` |
| `getOrionWebUI()` | 同步读取 `window.OrionWebUI`，可能为 `undefined` |

经这些入口拿到 API 时，插件会同时安装文档生命周期策略（`runtime/orion-webui-document-lifecycle.ts`）：按 `ue:webUI.lifecycleChanged` 写入 `<html data-orion-lifecycle-state>`，并注入禁用动画和指针的样式。不要绕过入口直接用 `window.OrionWebUI`。

`OrionWebUIApi` 有两个提供者，接口同名、能力不同：普通 `UOrionWebUIWidget` 文档由 C++ 注入；InstantScreen 的 Controller 文档拿到的是 Runtime 按 Screen 实例隔离的 API。`requestIntent`、`getIntentRequests`、`dismissIntentNotice`、`getInitialState` 只存在于后者，TypeScript 类型不会替你区分。

## API 面

| API | 调用时机 | 返回 | 证明什么 |
| --- | --- | --- | --- |
| `ready()` | 关键监听注册完之后（模板调用） | `Promise<OrionWebUIBootstrap>`：`appId`、`apiVersion`、`route`、`localization`、`assets`、`sounds`、`fonts` | 只证明 Bridge 可收发，不代表资源、状态、输入或展示就绪 |
| `inputReady()` | 按键、导航、`ue:commonAction` 等输入监听装好之后（模板调用） | `Promise` | 只证明输入处理器已安装；InstantScreen 的 Presenter 在 Bridge 与 Input 都就绪后才收到 Ready |
| `localResourcesReady()` | 页面资源准备完之后（模板调用） | `Promise`，失败 reject | 当前文档的样式表、字体策略、字体和图片就绪 |
| `stateCommitted(rev)` | 完整应用快照并 flush DOM 之后（状态通道调用） | InstantScreen 返回 `{ accepted }`；`rev` 不是当前权威 revision 时为 `false` | 该 `stateRevision` 的 DOM 已提交 |
| `controllerVisualReady(rev)` | 该 revision 的静态画面完整（含本地化文字）之后 | InstantScreen 返回 `{ accepted }` | 静态视觉就绪，只放行隐藏准备，不代表已经揭示 |
| `on(name, handler)` / `off` | 随时；关键监听必须先于 `ready()` | `on` 返回取消函数 | 保留型事件在注册时重放最近一次 payload |
| `emit(name, payload?, meta?)` | 发通知和回执 | `Promise` | 只证明送到桥接，不证明业务 |
| `call(name, payload?, meta?)` | 普通 Widget 文档里需要结果的请求 | `Promise<TResult>`；失败 reject，`error.code` 可读 | 一次桥接往返；InstantScreen 中业务名会被 `E_INSTANT_USE_INTENT` 拒绝 |
| `handle(name, handler)`、`routeChanged(route)` | 回答 C++ 发起的调用；页面内部路由变化后通知宿主 | 取消函数（handler 可返回值或 Promise）；`Promise` | — |
| `requestIntent(name, payload?, { controlId? })` | 业务按钮（仅 InstantScreen Controller） | `Promise<OrionIntentResult>` | 传输与受理结果，见“类型化 Intent” |
| `getInitialState?.()` | 挂载时同步读取（仅 InstantScreen） | 本次展示事务的 C++ 初始快照 | — |
| `playSound(soundId, options?)` | 播放 SoundManifest 中的声音 | `Promise<{ played, soundId }>` | — |

- `playUISound(api, soundId, options?)` 是吞掉失败的包装，点击处理器里用它而不是 `await playSound`。控件悬停 / 点击音、字体策略、Native Surface 绑定见 [控件与资源](controls-resources.zh-CN.md)。
- 重放规则：普通文档里 `ue:bootstrap`、`ue:localeChanged`、`ue:inputModeChanged`、`ue:inputPromptsChanged` 和 C++ 以保留方式发送的事件在 `on()` 时同步重放；InstantScreen 里保留事件在下一个微任务重放。非保留的一次性事件在注册前派发就丢了，状态不要靠它们。

## 启动顺序（强制模板）

1. 取得 `api` 和生命周期根元素；拿不到 Bridge 走预览分支，不接生命周期。
2. 页面自存 revision 基线时，先注册实例身份监听（见“文档复用与实例隔离”）。
3. 注册状态通道、高频通道、输入监听和业务事件监听，取消函数存入数组。
4. `createOrionWebUILifecycle({ api, root, ... })`。构造时立即把根节点置为 `preparing`，并订阅 `ue:webUI.lifecycleChanged`、入场请求、`ue:webUI.presentationCovered`、`ue:webUI.presentationRestored`、`ue:webUI.presentationSuspended`。
5. `await lifecycle.initialize()`：并行发起 `ready()`、`inputReady()` 和页面资源准备（完成后自动 `localResourcesReady()`），`ready()` 返回后发 `webUI.presentationReady`，最后返回 bootstrap。重复调用返回同一个 Promise；初始化期间被销毁时 reject `AbortError`。
6. `await` 之后先核对组件未销毁、仍属当前 generation，再写入本地化，并为当前已应用的 `stateRevision` 补报就绪（见骨架）。
7. 卸载时 `lifecycle.dispose()`，再逐个调用取消函数。`dispose()` 会中止资源准备并把根节点置为 `suspended`。

| `createOrionWebUILifecycle` 选项 | 作用 |
| --- | --- |
| `api`、`root` | Bridge 与生命周期根节点；模板向根节点写 `data-orion-presentation` 和 `aria-hidden` |
| `presentationRequestedEventName` | 宿主用自己的可靠入场事件（如 `ue:samplePanel.enterRequested`）代替 `ue:webUI.presentationRequested` |
| `autoPresentWithoutRequest` | 默认开启：`ready()` 后仍是 `preparing` 就自动以 revision 1 入场，供 Designer 预览和直接 Widget 宿主使用。宿主保证每次真实出现都会发入场事件时设为 `false`，否则会多出一次无人认领的回执或重复入场 |
| `onPresentationRequested(rev, payload)` | 入场前把页面切到最终静态可见状态；返回的 Promise 完成后模板才回执 |
| `onPresentationRestored(rev, payload)` | 覆盖后恢复，要求同上 |
| `onPresentationCovered(rev, payload)` | 被覆盖；完成后模板回 `webUI.presentationCoverageApplied` |
| `onPresentationSuspended(rev, payload)` | 被覆盖、停放或换绑实例时同步调用：清本地展示状态，停 rAF、定时器、WebGL |
| `presentationAnimationName`、`localResourceTimeoutMs` | 入场动画名提示；页面资源准备超时 |

入场回执 `webUI.presentationApplied` 与 `webUI.presentationEnterApplied`、恢复回执 `webUI.presentationRestoreApplied`、覆盖回执都由模板按精确 `presentationRevision` 发出，页面不要再发一遍。`rootEntranceMotion` 只有 `"none"` 一个取值，根节点动效由页面 CSS 负责。Covered / Restored 事件由宿主 C++ 发送；宿主没有实现时页面只会经历 requested 与 suspended。

只要就绪管线、展示请求由页面自己处理时，改用 `startOrionWebUIReadiness(api, root, localResourceTimeoutMs?, prepareLocalResources?)`，返回 `{ bootstrap, dispose }`。第四个参数是页面自定义资源准备回调，`createOrionWebUILifecycle` 不暴露它。此时用 `createOrionExplicitPresentationRequestGate({ requireStateRevision })`（`runtime/orion-webui-explicit-presentation-request-gate.js`）配对状态与入场请求：`request()` / `observeState()` 返回 `start` 才开始入场，返回 `ack` 只重发回执，入场结束调用 `complete()` 或 `cancel()`，被停放时 `reset()`。

## 生命周期状态机与根节点状态

宿主生命周期写在 `<html data-orion-lifecycle-state>`：`Preparing` → `Visible` ⇄ `CoveredSuspended` → `Closing` → `Destroyed`，任何阶段失败进入 `Failed`。插件样式据此强制：`Preparing` 与 `CoveredSuspended` 下全文档 `animation: none`、`transition: none`；`Preparing` 下页面根元素保持可布局但无指针；`CoveredSuspended`、`Closing`、`Destroyed`、`Failed` 下 `body` 无指针。

页面展示阶段写在根节点 `data-orion-presentation`：

| 阶段 | 进入条件 | 页面必须保证 |
| --- | --- | --- |
| `preparing` | 模板构造后、宿主 `Preparing` | 不可交互；不跑 CSS 动画、页面自有 rAF、定时器；允许应用状态、布局、解码图片 |
| `entering` | 收到入场或恢复请求 | 根节点已是最终静态样式（不透明、布局完成）；仍不启动 rAF / WebGL |
| `active` | 入场提交完成且宿主 `Visible` | 可交互；有限入场动画从第 0 帧播放；入场结束后才允许启动 rAF / WebGL |
| `covered` | 被上层覆盖 | 保留 DOM 与业务状态；撤销指针和焦点；停 rAF、定时器、WebGL |
| `suspended` | 停放、换绑实例、`dispose()` | 同 `covered`，并清空本地展示 revision |
| `closing` / `failed` | 宿主 `Closing` / `Failed` | 不可交互；`closing` 只播退场，`failed` 冻结且不再发回执 |

除 `active` 外根节点 `aria-hidden="true"`，模板还会取消经 `createOrionPointerSession`（`input/orion-pointer-session.ts`）创建的指针会话；页面自己挂的拖拽状态要在 `onPresentationSuspended` 里清。根节点 CSS 的最小写法：基础样式 `opacity: 0; pointer-events: none`，`[data-orion-presentation="entering"]` 与 `[data-orion-presentation="active"]` 下 `opacity: 1`，仅 `active` 下 `pointer-events: auto`。不要用 `display: none` 隐藏根节点或待展示内容：准备阶段按逻辑布局判定哪些图片参与资源门，这样隐藏的内容不会被等待。

展示就绪是七道独立的门，全部属于当前实例、当前文档、当前 revision 才揭示：Bridge（`ready()`）、Input（`inputReady()`）、Resources（`localResourcesReady()`）、State DOM Commit（`stateCommitted(rev)`）、Controller Visual（`controllerVisualReady(rev)`）、Presentation Commit（精确 `presentationRevision` 的入场 / 恢复回执）、Paint / Reveal（Native 在回执之后取得的新一帧，页面无法代报）。缺哪道查哪道，任何一道都不能替代另一道。

## revision 语义与权威状态通道

| revision | 分配者 | 管什么 | 页面用在哪 |
| --- | --- | --- | --- |
| `stateRevision` | C++，每条业务状态流独立且单调递增 | 一份完整业务快照的版本 | 状态通道去重、`stateCommitted`、业务状态回执、`controllerVisualReady` |
| `presentationRevision` | C++，每次正式出现重新分配 | 一次入场 / 恢复 / 退场展示事务 | 只用于展示回执 |
| 流 revision（高频流的 `revision`，或宿主自定义的 `interactionRevision` 之类） | C++，按流独立 | 一条连续交互或高频数据流 | 只用于该流的回执与防回跳 |

- 三类 revision 是独立命名空间，不互相比较、不互相代填。快照同时带 `stateRevision` 与 `presentationRevision` 时分别读取；被覆盖再恢复只推进 `presentationRevision`，业务内容没变就没有新的 `stateRevision`。
- 状态路径只做三件事：写入 Store、提交精确 `stateRevision`、报告静态视觉就绪。即使快照里带着 `presentationRevision`，也不得从状态路径隐式创建入场、播放动画或发展示回执。
- 展示回执只有在观察到显式的入场请求（`*.enterRequested`、`ue:webUI.presentationRequested`）或 `ue:webUI.presentationRestored` 之后，且 revision 与请求精确相等时才有效；抢跑、旧值、未来值在 InstantScreen 的 Runtime 边界被拒绝，不会到达 C++。

`installAuthoritativeStateChannel(api, options)`（`runtime/orion-webui-lifecycle.ts`）是唯一的状态接收入口，返回取消函数：

- 固定顺序：`apply(state)` → `commitDom(state)` → 并行发出 `stateCommitted(rev)`、业务回执 `emit(acknowledgementEventName, { ...acknowledgementMetadata, [revisionFieldName]: rev })`，以及 `isControllerVisualReady(state)` 为真时的 `controllerVisualReady(rev)`。任何一步抛错都不回报。
- `revisionFieldName` 默认 `stateRevision`。旧 revision 丢弃；已应用的同 revision 重放只重发回执，不再执行 `apply`；正在应用的同 revision 忽略。
- `apply` 把状态写入放在同步部分。实例换绑后通道会放弃旧的异步延续，但无法撤销回调里已经发生的写入。
- `stateEventName`、`acknowledgementEventName`、revision 字段名必须与 Presenter 逐字一致。InstantScreen 的 Presenter 用 `PushState` 推送的快照以 `ue:instantScreen.stateChanged` 到达，真正的门是 `stateCommitted(rev)`。
- 新建的 Controller 文档不会收到携带首个快照的 `ue:instantScreen.stateChanged`，初始快照在挂载时用 `getInitialState?.()` 读取。初始快照和“本地化晚于快照到达”这两种情况，通道都不会替你补报，Bridge 就绪后要按骨架末尾的写法为当前 revision 补报一次。

## 动画契约

- `Preparing` 与被覆盖期间插件禁止创建动画。每次出现时宿主先解析一次静态样式，再切换一次 `Visible`，CSS 动画由此从第 0 帧播放一次；页面和 C++ 都不发第二条“开始动画”的命令。
- 入场动画声明挂在 `entering` 与 `active` 两个阶段共同匹配的选择器上，或挂在页面自己的稳定状态类上，用 `backwards` / `both` 填充。只挂 `entering` 的动画会在切到 `active` 时被取消。
- 不调用 `Element.animate()`；不遍历动画实例做 `pause` / `play` / 重启；不用 rAF 或定时器补播；不读取系统的减弱动效偏好。
- 入场相关的 DOM 不得在动画结束时改变：由 `animationend`、`transitionend` 或 `getAnimations().finished` 触发的类名切换、`v-if` 卸载、属性变化会让首帧捕获结果不确定。类名只随状态变化；过渡元素常驻，结束后回到自身样式。
- 实时 WebGL / rAF 层和重型模块解析等到真正可见且入场结束后再启动：`await waitForOrionWebUIPresentationSettled(root)`（`runtime/orion-webui-presentation-commit.ts`），返回后核对 `lifecycle.getPresentationPhase() === "active"` 且仍属同一次出现。被覆盖、停放、卸载时停止循环并释放资源。
- 退场是唯一以动画结束为信号的事务，交给 `createOrionWebUIExitTransaction(api, { root, requestEventName, acknowledgementEventName, animationName, getExitRevision, beginExit, settleExit })`：收到 revision 等于 `getExitRevision()` 的请求后调用 `beginExit`；根节点上名字精确为 `animationName` 的 `animationend` 到达后调用 `settleExit` 提交透明终态，让出一个浏览器任务，再回执 `{ presentationRevision }`。根动画必须最后结束，内容和所有全屏遮罩一起到达透明。在 `onPresentationSuspended` 里调用 `reset()`，卸载时 `dispose()`。

## 类型化 Intent

InstantScreen 页面的业务动作只走 `requestIntent(name, payload, { controlId })`，不回退到 `emit()`：普通事件在页面状态版本落后于 Native 时会被静默丢弃，`call()` 的业务名会被拒绝。普通 `UOrionWebUIWidget` 文档没有 `requestIntent`，业务请求用 `call()`（需要结果）或 `emit()`（只通知），同样由 C++ 校验并以快照为准。

| `status` | 含义 | 页面后续行为 |
| --- | --- | --- |
| `completed` | 同步业务动作已完成 | 结束等待，消费权威快照 |
| `accepted` | 已交给业务所有者，必带 `authority`，可带 `operationId` | Busy 与最终结果由该所有者的快照决定 |
| `rejected` | 业务拒绝 | 结束等待，展示 `message` / `code` |
| `unknown` | 回执无法确认 | 提示核对当前状态，禁止自动重放写操作 |

- 结果形状：`{ requestId, status, code, message?, authority?, operationId?, data? }`。业务层拒绝是 resolve；桥接层确定性失败是 reject，`error.code` 形如 `E_INSTANT_INTENT_AUTHORITY`（不是当前输入所有者、展示事务已变或状态版本超前）、`E_INSTANT_INTENT_SCOPE`（旧实例或旧文档）、`E_INSTANT_INTENT_RESULT_MISSING`（Presenter 没给结果）。两条路径都要处理。
- `payload` 必须是普通对象。事件名在调用点写字符串字面量，合同检查按字面量归类，登记方式见 [构建与验证](build-validation.zh-CN.md)。
- 去重：控件键默认是事件名，同一键在确认前复用同一个 Promise，后一次调用的载荷被忽略。多个独立控件共用事件名时传稳定的 `controlId`；搜索、草稿这类逐次编辑给每次编辑独立的键。
- 超时：桥接超时由 AppDefinition 的 `BridgeCallTimeoutSeconds` 决定。超时、断连或回执异常只触发一次只读状态查询，仍无法确认就以 `unknown` 结束，不循环、不重发写操作。
- 生命周期：覆盖与同实例恢复保留等待；新的 Screen 实例、新的 Controller 文档或文档退役会清空等待，旧 Promise 以 `E_INSTANT_INTENT_INVALIDATED` reject。清空不会取消已受理的业务，新页面重新消费快照。
- 等待与提示：`getIntentRequests()` 返回 `{ pending: [{ requestId, name, controlId, phase }], notice? }`，变化时派发 `ue:instantScreen.intentRequestsChanged`，`dismissIntentNotice()` 关闭提示。把它投影成按钮等待态和拒绝 / 未知提示的组件由宿主工程自备；业务 Busy 仍来自快照，不放进这里。
- 强类型载荷用具名 interface 构造；宿主封装要求 `Record<string, unknown>` 时在调用处展开对象（`{ ...buildIntent() }`），不要用 `as unknown as` 绕过检查。

Vue 子组件用事件签名映射声明 `defineEmits` 时，互斥事件用显式分支保留字面量事件名：写 `if (cancelled) { emit("holdCancelled"); } else { emit("holdFinished"); }`，不要写 `emit(cancelled ? "holdCancelled" : "holdFinished")`。vue-tsc 无法从联合事件名选择重载，而 Vite 构建通过不代表类型检查通过。

有限枚举跨 FName、JSON、Web 时使用规范 wire token：C++ 序列化边界输出固定拼写的 token，Web 在消费边界用显式 codec 解析；不依赖 FName 的显示大小写（FName 比较不区分大小写，JavaScript 的 `Map` 键区分）。未知 token 走明确的未知分支，不静默映射成另一种业务语义，也不在页面里加别名特判。

## 高频数据

坐标、姿态、进度采样这类只关心最新值的流用 `installOrionFlowControlledLatestChannel<T>(api, { eventName, acknowledgementEventName, acknowledgementPhase?, revisionFieldName?, apply })`（`runtime/orion-webui-flow-controlled-latest.ts`），返回取消函数。Native 只保持一个在途 revision 和一个最新值；页面在一次 rAF 里只应用最大的 revision。`revisionFieldName` 默认 `revision`。

- `committed`（默认）：`apply`（含 `await nextTick()`）完成并跨过一个浏览器任务边界后回执。需要“页面确实完成了某事”作为就绪证据时只能用它，或用状态通道、展示事务；`apply` 抛错就不回执。
- `received`：收到合法 revision 立即回执，只锁存最新值等下一次 rAF。只用于可被替换的坐标类表现流，不代表 DOM 已提交、已绘制或已揭示，不能参与任何就绪门。
- 一个回执事件名只属于一条流。两种回执都只是传输事实，不代表业务成功。页面不加固定延时、历史帧队列、debounce 或重试；不创建常驻采样器。

## 文档复用与实例隔离

缓存策略为 keep-document 的 Controller 文档会依次重绑到多个 Screen 实例，每个实例的 revision 各自从头计数。身份随 `ue:webUI.lifecycleChanged` 发布：`screenInstanceId`、`transactionId`、`surfaceGeneration`、`controllerDocumentGeneration`，重绑时先发身份、再交付该实例的状态。

- 生命周期模板、状态通道、高频通道已经用 `createOrionWebUIInstanceScope`（`runtime/orion-webui-instance-scope.ts`）在身份变化时清零去重、取消待执行帧。身份由 `screenInstanceId`、`surfaceGeneration`、`controllerDocumentGeneration` 组成；只有 `transactionId` 变化不算换实例。没有身份字段的独立页面沿用文档级生命周期。
- 页面自己保存的防回跳基线必须同样清零，并且身份监听先于状态通道注册：

```ts
const hintScope = createOrionWebUIInstanceScope(() => {
	lastHintRevision = 0;
});
releaseListeners.push(api.on<OrionWebUIInstanceIdentity>("ue:webUI.lifecycleChanged", (payload) => {
	hintScope.observe(payload);
}));
```

- 异步延续在继续提交 DOM、发回执、清理标记之前核对代次：`await` 前记下 `scope.generation`，之后不相等就直接返回。

## 资源准备与取消

- 页面资源准备与 Bridge、Input 并行，由模板负责：先执行可选的自定义准备回调，再等待根节点内已挂载、当前可展示的 `<img>` 加载并解码，最后调用 `localResourcesReady()`。隐藏路由、无布局或没有 `src` 的图片不进入门禁。
- 只为真实存在的元素建立 readiness，不为“修首帧”预建隐藏 DOM 或隐藏 iframe。自定义准备必须有界、可取消，且不得等待揭示之后才会发生的事件（隐藏文档里的 rAF、`animationend`、可见性观察）。
- 自定义准备失败或超时会上报 `webUI.resourcePreparationFailed`，本次不再调用 `localResourcesReady()`；内容图片加载失败只降级。必需字体失败由宿主终结，页面不加重建、循环重试或固定延时。
- 身份或内容会在首帧事务中变化的动态图片不要把候选地址直接绑到可见 `<img>` 的 `src`。宿主工程需要自备 last-good 图片组件：候选地址在脱离文档的 `Image` 中加载并解码，成功后才替换正在显示的节点；失败保留上一张，不反向取消当前展示。
- `dispose()`、`pagehide`、换绑实例都会中止旧任务，旧任务不能报告 Ready。`<img>` 的属性要求和 Runtime Image 见 [控件与资源](controls-resources.zh-CN.md)。

## 回调写法（静态合同）

生命周期合同检查用静态模式匹配源码（见 [构建与验证](build-validation.zh-CN.md)），运行时等价的压缩写法也可能不通过。`onPresentationSuspended`、`onPresentationRequested` 以及 `*.enterRequested`、`*.exitRequested` 的处理器使用显式代码块和语句结束符；异步处理器显式 `return` 原 Promise——模板 `await` 它之后才回执，丢掉 Promise 等于在动画提交前就回执。合同不通过时先确认逻辑真实存在，不要添加只为匹配模式的死代码。

## App.vue 骨架

导入路径按插件基础示例 `<OrionBrowser>/Content/UI/WebUI/Sample/src/App.vue` 的布局书写，共享模块位于 `<OrionBrowser>/Content/UI/WebUI/Shared/src`；App 放在 `<WebUIRoot>/<AppId>` 时这些模块如何解析见 [Web App 脚手架](web-app-scaffold.zh-CN.md)。下面是 `<script setup lang="ts">` 的内容，按 InstantScreen 页面编写；普通 Widget 文档把 `requestIntent` 换成 `call()` 或 `emit()`。模板根元素写 `<main ref="rootElement" class="sample-root">`，按钮用 `:disabled="!state.canConfirm"` 叠加 C++ 发布的资格。

```ts
import { nextTick, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { type OrionLocalizationTable, type OrionWebUIApi, installCommonActionRouter, waitForOrionWebUI } from "../../Shared/src/bridge/orion-webui";
import { type OrionWebUILifecycleController, createOrionWebUILifecycle, installAuthoritativeStateChannel } from "../../Shared/src/runtime/orion-webui-lifecycle";

interface SamplePanelState {
	stateRevision: number;
	title: string;
	canConfirm: boolean;
}

const props = defineProps<{ api?: OrionWebUIApi }>();
const rootElement = ref<HTMLElement | null>(null);
const bridge = ref<OrionWebUIApi | null>(null);
const localization = ref<OrionLocalizationTable>({ culture: "", texts: {} });
const state = reactive<SamplePanelState>({ stateRevision: 0, title: "", canConfirm: false });
const notice = ref("");
const releaseListeners: Array<() => void> = [];
let lifecycle: OrionWebUILifecycleController | null = null;
let localizationReady = false;
let disposed = false;

const isSamplePanelState = (value: unknown): value is SamplePanelState => !!value && typeof (value as SamplePanelState).stateRevision === "number";

function applyState(snapshot: SamplePanelState): void {
	// 只同步写入完整快照：不 await、不触发入场、不发展示回执。
	Object.assign(state, snapshot);
}

function suspendPresentation(): void {
	// 停止页面自有 rAF、定时器、WebGL 循环，清空本地拖拽与展示状态。
}

async function confirm(): Promise<void> {
	const api = bridge.value;
	if (!api || !state.canConfirm) {
		return;
	}
	try {
		const result = await api.requestIntent("samplePanel.confirmRequested", { stateRevision: state.stateRevision }, { controlId: "sample-panel-confirm" });
		notice.value = result.status === "rejected" || result.status === "unknown" ? result.message ?? result.code : "";
	} catch (error) {
		// 桥接层失败：不重发，界面等权威快照。
		notice.value = error instanceof Error ? error.message : String(error);
	}
}

onMounted(async () => {
	const root = rootElement.value;
	if (!root) {
		throw new Error("SamplePanel lifecycle root is unavailable.");
	}
	const api = props.api ?? await waitForOrionWebUI().catch(() => null);
	if (disposed) {
		return;
	}
	if (!api) {
		// 普通浏览器或设计预览：用样例状态直接显示，不接生命周期。
		applyState({ stateRevision: 1, title: "Sample", canConfirm: false });
		root.dataset.orionPresentation = "active";
		return;
	}
	bridge.value = api;
	const initialState = api.getInitialState?.();
	if (isSamplePanelState(initialState)) {
		applyState(initialState);
	}
	releaseListeners.push(installAuthoritativeStateChannel<SamplePanelState>(api, {
		stateEventName: "ue:samplePanel.stateChanged",
		acknowledgementEventName: "samplePanel.stateApplied",
		apply: applyState,
		commitDom: () => nextTick(),
		isControllerVisualReady: () => localizationReady,
	}));
	releaseListeners.push(installCommonActionRouter(api, root));
	lifecycle = createOrionWebUILifecycle({
		api,
		root,
		onPresentationRequested: () => {
			return nextTick();
		},
		onPresentationRestored: () => {
			return nextTick();
		},
		onPresentationSuspended: () => {
			suspendPresentation();
		},
	});
	const bootstrap = await lifecycle.initialize().catch((error: unknown) => {
		if (error instanceof Error && error.name === "AbortError") {
			return null;
		}
		throw error;
	});
	if (!bootstrap || disposed) {
		return;
	}
	localization.value = bootstrap.localization;
	localizationReady = true;
	await nextTick();
	const committedRevision = state.stateRevision;
	if (disposed || committedRevision <= 0) {
		return;
	}
	// 初始快照与晚到的本地化不会由状态通道补报：为当前 revision 补一次。
	await Promise.all([
		api.stateCommitted(committedRevision),
		api.emit("samplePanel.stateApplied", { stateRevision: committedRevision }),
	]);
	await api.controllerVisualReady(committedRevision);
});

onBeforeUnmount(() => {
	disposed = true;
	suspendPresentation();
	lifecycle?.dispose();
	lifecycle = null;
	for (const release of releaseListeners.splice(0)) {
		release();
	}
});
```

## 常见失败签名

| 现象或日志 | 原因 | 处理 |
| --- | --- | --- |
| 页面一直不显示；`Controller presentation barrier for <screen> timed out`，缺 `state-committed` 或 `controller-visual-ready` | 快照没完整应用就没回报；把 `presentationRevision` 当成 `stateRevision` 回报；初始快照或晚到的本地化没有补报 | 两个 revision 分别读取；Bridge 就绪后为当前 revision 补报 |
| `presentation-commit-rejected`，原因 `request-not-observed`、`stale-revision` 或 `future-revision` | 前者：从状态路径或自动入场兜底发了展示回执，宿主还没发显式请求；后两者：回执用了缓存或自造的 revision | 只在显式请求后回执并带请求里的精确值；宿主用自定义入场事件时设置 `presentationRequestedEventName` 并关闭 `autoPresentWithoutRequest` |
| `InstantScreen event ue:<x>.enterRequested at revision N was not acknowledged after K attempts` | 没监听该事件；回执事件名或 revision 字段名与 C++ 不一致；回执被上一行的原因拒绝 | 逐字核对事件名与字段名；异步处理器 `return` Promise |
| 按钮偶发无反应且没有拒绝日志 | InstantScreen 中业务动作用了 `emit()`，状态版本落后时被静默丢弃 | 改用 `requestIntent` |
| `E_INSTANT_USE_INTENT`；或 `requestIntent is not a function` | 前者：InstantScreen 中对业务名用了 `call()`；后者：普通 Widget 文档没有 `requestIntent` | 按宿主形态选对通道 |
| `E_INSTANT_INTENT_AUTHORITY` | 页面被覆盖、输入未就绪或展示事务已变时提交 | 不重发；非 `active` 阶段不提交 |
| 复用文档的页面再次打开后停在旧状态或不更新 | 页面自存的 revision 基线跨实例比较 | 身份变化时清零，监听先于状态通道注册 |
| 入场动画不播、只播第一次或播两次 | 动画只挂在 `entering`；用脚本补播；`animationend` 后改 DOM | 按“动画契约”改写，不加暂停、补播或延时 |
| 资源门不过；`webUI.resourcePreparationFailed` 或 `ORION_LOCAL_RESOURCE_ERROR:` | 自定义准备超时，或等待了揭示后才发生的事件；首帧事务中直接替换可见图片的 `src` | 准备逻辑有界、可取消；动态图片走 last-good 替换 |
