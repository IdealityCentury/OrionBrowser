# 教程 3：蓝图与 C++ 接入

网页写好之后，Unreal 这一侧要做四件事：**承载页面、接收操作、发布状态、提供声音与资源**。这四件事可以全部用蓝图完成，也可以用 C++，或者由 C++ 写基类、蓝图做子类。本教程把三种做法都写完整。

[English](tutorial-3-blueprint-and-cpp.md) · [手册目录](README.zh-CN.md) · 网页由 AI 来写见[教程 1](tutorial-1-ai.zh-CN.md)，人工编写见[教程 4](tutorial-4-write-by-hand.zh-CN.md)。

不变的原则只有一条：**游戏状态、规则和存档属于 Unreal，网页只显示状态并提交操作。** 网页发来的每个参数都要在 Unreal 里重新检查；网页说“成功”不算成功。

## 先选路线

| 路线 | 适合 | 特点 |
| --- | --- | --- |
| 纯蓝图 | 没有 C++ 模块的工程；状态是若干个数字、文字和开关 | 不需要编译器；JSON 用插件自带节点 |
| C++ | 已有 C++ 的工程；状态里有数组和嵌套结构；需要高频数据或可靠送达 | 直接使用 `FJsonObject`；可以用到全部接口 |
| C++ 基类加蓝图子类 | 程序定合同与校验，设计师在蓝图里配声音、资产和个别行为 | 两边各管各的，蓝图不会绕过校验 |

承载页面的控件也有三种：

| 形态 | 做法 | 何时用 |
| --- | --- | --- |
| 普通控件 | 在任意 Widget 蓝图里放一个 **Orion WebUI** | HUD、单个面板、把一块 UMG 换成网页 |
| CommonUI 页面 | Widget 蓝图的父类选 **Orion WebUI Activatable Widget** | 页面进入 CommonUI 页面栈，需要输入模式、返回键、动作路由、被覆盖后恢复 |
| InstantScreen | 见[文末](#instantscreen-概览) | 同一层的多个页面共用一个常驻浏览器 |

第一次接入请用“纯蓝图 + 普通控件”，其余都是在它之上增加的。

## 本教程用到的合同

沿用教程 1 和教程 4 的设置面板。AppId 为 `SettingsPanel`，生产文件位于工程 `Content/UI/WebUI/SettingsPanel/dist`。

| 方向 | 名称 | 参数 | 说明 |
| --- | --- | --- | --- |
| Unreal → 网页 | `ue:settingsPanel.state` | `{ stateRevision, volume, quality, culture }` | 完整状态 |
| 网页 → Unreal（emit） | `settingsPanel.ready` | `{}` | 网页开始监听 |
| 网页 → Unreal（emit） | `settingsPanel.setVolume` | `{ volume: 0–100 }` | 调音量 |
| 网页 → Unreal（emit） | `settingsPanel.setQuality` | `{ quality: "low" \| "medium" \| "high" }` | 选画质 |
| 网页 → Unreal（call） | `settingsPanel.resetDefaults` | `{}` | 还原默认，需要结果 |
| 网页 → Unreal（emit） | `settingsPanel.close` | `{}` | 关闭面板 |

网页用 `emit` 发来的消息到达 **On Web Event**；用 `call` 发来的到达 **On Web Request**，必须应答。

## 纯蓝图：从零接入

### 1. 建 App Definition

1. 内容浏览器里右键，选择 **Miscellaneous → Data Asset**，类选 `OrionWebUIAppDefinition`（在类列表里搜索 `Orion`），命名为 `DA_SettingsPanel`。
2. 打开它，设置：

| 属性 | 值 | 说明 |
| --- | --- | --- |
| `AppId` | `SettingsPanel` | 必须与目录名、网页 `package.json` 里的 `orionWebUI.appId` 完全一致 |
| `EntryHtml` | `index.html` | 默认值 |
| **Use Dev Server in Editor** | 取消勾选 | 默认勾选。勾选时 UMG Designer 会优先连接本机开发服务器 |

其余属性保持默认。全部属性见[教程 4](tutorial-4-write-by-hand.zh-CN.md#app-definition-全部属性)。

### 2. 建承载页面的 Widget

1. 新建 **User Widget** 蓝图 `WBP_SettingsPanel`。
2. 在 Designer 的控件面板搜索 **Orion WebUI** 并拖入，命名为 `WebUI`，勾选 **Is Variable**，让它铺满父级。
3. 在 Details 里把 **App Definition** 设为 `DA_SettingsPanel`。Helper 就绪后，Designer 里会直接显示页面。

### 3. 显示出来

在 Player Controller（或你管理界面的蓝图）里：

1. **Create Widget**（Class 选 `WBP_SettingsPanel`，Owning Player 接 `Self`），把返回值保存为变量。
2. **Add to Viewport**。
3. **Set Input Mode Game And UI**：**Player Controller** 接 `Self`，再把这个 Widget 里的 `WebUI` 接到 **In Widget to Focus**，键盘输入才会进入网页。**Player Controller** 引脚不会自动取 `Self`，空着时这个节点不起作用：在编辑器里运行会在 Message Log 里报一条错误，打包后的游戏没有任何提示。
4. **Set Show Mouse Cursor** 设为 `true`。

关闭界面时反过来：**Remove from Parent**，**Set Input Mode Game Only**（它的 **Player Controller** 同样要接；在 Widget 蓝图里执行时接 **Get Owning Player**），隐藏鼠标。同一个界面只创建一次，不要每帧创建。

### 4. 接收操作：On Web Event

在 Designer 里选中 `WebUI`，在 Details 底部的 **Events** 里点击 **On Web Event** 右边的加号。事件给出 `Event Name` 和 `Payload Json`。接一个 **Switch on Name**，为每个事件名添加一个输出（选中节点，在 Details 的 **Pin Names** 里填写）。编辑器会把引脚名显示成带空格的样子，`settingsPanel.setVolume` 显示为 `Settings Panel.set Volume`；这只是显示，比较时用的仍是你填的名字。各个输出这样处理：

**`settingsPanel.ready`**：直接调用下一节的 `PublishState`。

**`settingsPanel.setVolume`**：

1. **Get Json Number**：`Json` 接 `Payload Json`，`Field` 填 `volume`。
2. **Branch** 判断 `Valid`。为 `false` 说明字段缺失或类型不对，不处理。
3. **Branch** 判断数值在 0 到 100 之间。
4. 通过后：**Round** 成整数，存入变量 `Volume`，应用到游戏的音量设置，调用 `PublishState`。
5. 没通过也调用一次 `PublishState`，把正确的状态推回去，网页上的显示会被纠正。

**`settingsPanel.setQuality`**：用 **Get Json String** 读 `quality`，检查 `Valid`，再用 **Switch on String** 只接受 `low`、`medium`、`high`，通过后存入变量并调用 `PublishState`。

**`settingsPanel.close`**：执行第 3 步里的关闭流程。

**Default 输出**不要接业务逻辑。你没有登记的事件名一律不处理。

网页上被禁用的操作，蓝图里也要检查同样的条件：网页的禁用只是显示。需要防止重复提交或过期操作时，让网页在参数里带上请求编号或它看到的 `stateRevision`，由蓝图判断是否接受。

> 插件自己的通知也会到达这个事件，例如 `__orion.inputReady`、`__orion.stateCommitted`（页面每应用一次状态发一次）和 `webUI.presentationReady`，让它们落到 **Default** 即可。没有被控件音效策略接住的悬停和点击也会到这里，名字是 `webUI.hoverSoundRequested` 或 `webUI.clickSoundRequested`，参数里带 `controlId`。策略为这次交互配了声音，或者有一条取消了 **Enabled** 的定义，才算接住，见[控件音效](#控件音效)。

### 5. 发布状态

新建函数 `PublishState`，变量 `StateRevision`（Integer64）、`Volume`（Integer）、`Quality`（String）、`Culture`（String）：

1. `StateRevision` 加一。
2. **Set Json Number**：`Json` 填 `{}`，`Field` 填 `stateRevision`，`Value` 接 `StateRevision`。
3. 把上一个节点的返回值接到下一个 **Set Json Number** 的 `Json`，`Field` 填 `volume`。
4. 同样接两个 **Set Json String**，分别写入 `quality` 和 `culture`。
5. 对 `WebUI` 调用 **Post Retained Latest Event to Web**：`Event Name` 填 `ue:settingsPanel.state`，`Payload Json` 接最后一个节点的返回值。

每次都发**完整状态**，不发“只改了哪一项”。`stateRevision` 只增不减，网页用它丢弃迟到的旧状态。**Retained** 的意思是：页面在事件发出之后才开始监听，也能收到最近的一条。页面重新加载后会再发一次 `settingsPanel.ready`，所以收到它时一定要重新发布。

### 6. 需要结果的请求：On Web Request

为 `WebUI` 添加 **On Web Request** 事件。它给出 `Request` 和 `Response`。拆开 `Request`（**Break**）取 `Name` 和 `Payload Json`：**Break** 节点起初只列出 `Id` 和 `Api Version`，点击节点底部的箭头展开，才能看到 `Name`、`Payload Json` 和其余成员。然后同样接 **Switch on Name**：

**`settingsPanel.resetDefaults`**：

- 允许时：把变量改回默认值并应用，调用 `PublishState`，然后对 `Response` 调用 **Resolve Json**，`Data Json` 填 `{}`。
- 不允许时：对 `Response` 调用 **Reject**，`Error Code` 填你自己的错误码（例如 `E_LOCKED`），`Error Message` 填给玩家看的原因。

**Default 输出**：对 `Response` 调用 **Reject**，错误码写 `E_UNKNOWN_REQUEST`。

规则：

- 每个请求只应答一次，第二次调用会被忽略。
- Unreal 确实接受了操作之后才 **Resolve Json**。
- 结果要等一会儿才有（例如等存档写完）时，先对 `Response` 调用 **Defer**，把 `Response` 存成变量，之后再应答。超过 App Definition 的 `BridgeCallTimeoutSeconds`（默认 15 秒）没有应答，网页会收到 `E_TIMEOUT`。
- 事件结束时既没应答也没 **Defer**：`WebUI` 的 **Auto Resolve Unhandled Requests** 勾选时（默认）自动以 `{}` 成功应答，取消勾选时以 `E_UNHANDLED` 失败。所以 Default 输出一定要显式 **Reject**。

### 7. 就绪与错误

| 事件 | 触发时机 | 用途 |
| --- | --- | --- |
| **On Web Ready** | 页面与 Unreal 的通信建立 | 可以在这里发布首个状态；页面重新加载后会再次触发 |
| **On Web Error** | 通信出错、导航被拦截、消息队列已满等 | 打印出来，排查时最先看它 |
| **On Web Local Resources Ready** | 页面确认自己的样式、字体、图片已就绪 | 需要“准备好再显示”时使用 |
| **On Route Changed** | 页面通知路由变化 | 多页面 App |
| **On Browser Load Started / Completed** | 文档开始加载、加载完成 | 显示加载提示 |

调试阶段把 **On Web Error** 接到 **Print String**。

### 8. 显示状态与清理

`WebUI` 的 **Set Presentation Lifecycle State** 告诉页面和浏览器“现在处于什么显示阶段”：

| 状态 | 页面阶段 | 控件与浏览器 |
| --- | --- | --- |
| **Visible** | `active`：可以播放动画、接收输入 | 控件可以绘制。它不会唤醒已停驻的浏览器，也不会解除显示闸门 |
| **Covered Suspended** | `covered` | 控件停止绘制，浏览器被停驻：页面冻结，不出帧，不接收输入 |
| **Closing** | `closing` | 与 **Covered Suspended** 一样停驻 |
| **Destroyed** | `suspended` | 关闭浏览器会话并释放页面 |
| **Preparing** | `preparing` | 唤醒已停驻的浏览器，并用显示闸门把控件隐藏起来，直到调用 **Release Native Presentation Gate** 或一次呈现事务完成 |

纯蓝图的界面只需要 **Visible**，`Presentation Revision` 填 `0`：页面显示出来之后调用一次（随附示例只用到这一个状态）；完全不调用也可以，页面就绪后会自己进入可见状态。要暂时隐藏这样的界面，改 Widget 的可见性或把它移除。不要把 **Covered Suspended** 和 **Visible** 当成一对来用：只调用 **Visible** 时浏览器仍然停驻着。“被遮挡再恢复”由 CommonUI 基类替你完成，它每次激活都会经过 **Preparing** 和一次带新版本号的呈现事务。`Presentation Revision` 属于这些事务；比当前值小的正数会被忽略。

Widget 销毁时在 **Event Destruct** 里清理你用过的东西：

- **Deactivate Control Sound Policy**（`Policy Owner` 接 `Self`）
- **Clear Native Surfaces**、**Release Texture Resources**（用过才需要）
- WorldUI 的 **Unbind Overlay Widget**（用过才需要）
- 你自己设置的定时器

## 蓝图里的 JSON

插件在 **Orion WebUI | JSON** 分类下提供六个节点：

| 节点 | 作用 |
| --- | --- |
| **Get Json String / Number / Boolean** | 读取对象顶层的一个字段。字段缺失、类型不符或 JSON 无效时 `Valid` 为 `false` |
| **Set Json String / Number / Boolean** | 写入对象顶层的一个字段，返回新的 JSON。来源为空时从 `{}` 开始；来源无效时原样返回并且 `Valid` 为 `false` |

- 它们只处理**顶层**的字符串、数字和布尔。字段名里的点不代表层级。
- 输入最长 1,048,576 个字符。
- 节点会正确转义引号和换行，不要用 **Append** 手工拼接玩家输入的文字。
- 数字写入前必须是有限值，否则 `Valid` 为 `false`。

需要数组或嵌套对象（背包列表、排行榜）时有三种办法：

1. 把结构摊平成顶层字段，例如 `slot0Name`、`slot0Count`、`slotCount`。数量固定且不多时最简单。
2. 启用引擎自带的 **Json Blueprint Utilities** 插件，在蓝图里构造带数组的对象，再转成字符串交给 **Post Retained Latest Event to Web**。
3. 把这部分状态放进 C++，用 `FJsonObject` 构造，见下文。

## 蓝图里的常用功能

### 控件音效

悬停和点击的声音由 Unreal 播放。网页上每个可点击元素有一个稳定的控件 Id（`data-orion-control-id`），插件自动上报“哪个控件被悬停或点击”，蓝图里的策略决定播什么。

1. 在承载页面的 Widget 蓝图里新建变量 `ControlSounds`，类型 `OrionWebUIControlSoundPolicy`，编译。
2. 在变量默认值里填写：

| 字段 | 含义 |
| --- | --- |
| **Default Sounds → Hover Sound / Click Sound** | 所有控件的默认声音。每一项有 `Sound`、`Concurrency Settings`、`Volume Multiplier`、`Pitch Multiplier`、`Start Time` 和 `Enabled` |
| **Control Overrides** | 按控件 Id 覆盖。每项填 `Control Id`，勾选 **Override Hover Sound** 或 **Override Click Sound** 后填对应的声音 |

3. **Event Construct**：对 `WebUI` 调用 **Activate Control Sound Policy**，`Policy Owner` 接 `Self`，`Context Id` 留空，`Policy` 接 `ControlSounds`。
4. **Event Destruct**：对 `WebUI` 调用 **Deactivate Control Sound Policy**，`Policy Owner` 接 `Self`。

要点：

- 想让某个控件不出声：加一条覆盖，勾选对应的 Override，再取消该项的 **Enabled**。关闭的定义会“吃掉”这次交互，不会回退到默认声音。
- 音量随玩家设置变化时：用新的音量重新构造策略（**Make** 节点或 **Set Members**），对同一个 `Policy Owner` 再调用一次 **Activate Control Sound Policy**，新策略替换旧策略。
- `Context Id` 用于一个页面里有多块区域、各用各的策略的情况：网页在区域根元素上写 `data-orion-sound-context="Shop"`，蓝图用 `Shop` 作为 `Context Id`、并换一个对象作为 `Policy Owner` 激活另一份策略：一个 Owner 只持有一份策略，用同一个 Owner 再激活会替换掉前一份。带名字的请求找不到同名策略时，回退到 `Context Id` 留空的那一份。
- 禁用（`disabled`、`aria-disabled="true"`）和等待中（`aria-busy="true"`）的控件不出声。
- 手柄导航没有移动网页焦点时，可以由蓝图调用 **Play Control Sound**（`Control Id`、`Interaction`、`Context Id`）补上声音。
- 核对 Id：在 WebUIStudio 里用“控件”工具点一个控件（“检查”页签显示它的控件 Id），或在 Designer 里选中 `WebUI`，**Design Time Control Id Preview Mode** 选 **All Controls**。

### 有业务含义的声音

“保存成功”“余额不足”这类声音由网页在合适的时机请求，声音资产仍在 Unreal 里配置：

1. 新建 `OrionWebUISoundManifest` 数据资产，在 **Entries** 里登记：`StableId`（例如 `settings.saved`）、`Sound`，可选的并发设置、音量、音高。
2. 把它指定给 App Definition 的 **Sound Manifest**。`bAllowWebSoundPlayback`、`bPreloadSoundsOnLoad` 默认都开启。
3. 网页调用 `api.playSound("settings.saved")`。蓝图也可以对 `WebUI` 调用 **Play Sound by Id**。

需要在声音被请求时做点别的事（例如记录日志），绑定 **On Web Sound Requested**。

### 文字与语言

两种做法任选其一：

- **状态里带语言。** 蓝图在状态里发布 `culture`，网页用自己的双语字典显示。随附示例用的是这种，纯蓝图最省事。
- **Text Catalog。** 新建 `OrionWebUITextCatalog` 数据资产，在 **Texts** 里登记稳定的 Key（例如 `settingsPanel.title`）到 Unreal 的文本，指定给 App Definition 的 **Text Catalog**。文本走 Unreal 的本地化流程；网页用 Key 取字，语言切换时插件自动推送新的文字表。

### 运行时图片

把一张 `Texture2D`（头像、运行时生成的图标）交给网页显示：

1. 对 `WebUI` 调用 **Request Texture Resource**：`Stable Id` 填稳定的名字（例如 `player.avatar`），`Texture` 接贴图，`Options` 用 **Make** 节点构造，`Max Output Dimension` 按实际显示尺寸填写。返回值里有 `Url`。
2. 绑定 `WebUI` 的 **On Texture Resource Completed**。结果的 `Status` 为 **Ready** 时，把 `Handle` 里的 `Url` 写进状态并发布，或像示例那样单独发一个事件。
3. 网页把这个 `Url` 用在图片上。
4. 不再需要时调用 **Release Texture Resource**（单个）或 **Release Texture Resources**（全部）。

同一个 `Stable Id` 再次请求会得到新地址，旧地址随后失效，所以网页只使用状态里最新的地址。像素原地变化时增大 `Options` 里的 `Source Revision`。它不是视频通道：持续变化的画面用下一节的 Native Surface。虚拟纹理不支持。

### 实时画面：Native Surface

把 Render Target、场景捕获或 UI 材质直接画在网页的某个位置上，像素不经过网页：

1. 网页在目标位置放一个占位元素，并用一个稳定的名字绑定它（例如 `station.capture`）。
2. 蓝图对 `WebUI` 调用 **Set Native Surface Texture**（`Surface Id` 填同一个名字，`Texture` 接 Render Target），或 **Set Native Surface Material**。
3. 位置和大小跟随网页里的占位元素，蓝图不需要计算坐标。
4. 结束时调用 **Clear Native Surface** 或 **Clear Native Surfaces**。

| 节点 | 作用 |
| --- | --- |
| **Set Native Surface Tint** | 整体着色与透明度 |
| **Set Native Surface Composition Layer** | **Above Browser**（默认，画在网页上方）或 **Below Browser**（画在网页下方，需要 App Definition 开启透明） |
| **On Native Surface Layout Changed** | 位置、大小或可见性变化；`Visible` 为 `false` 时应暂停场景捕获 |
| **Has Native Surface / Get Native Surface Layout** | 查询 |

原生画面不接收鼠标；圆角、遮罩和淡出放进 UI 材质里做。也可以在 `WebUI` 的 **Native Surface Bindings** 数组里静态配置。

### WorldUI：跟随 Actor 的标签与交互

每个本地玩家只有一个网页承载所有世界标签，Actor 上只挂数据组件，不要给每个 Actor 建一个浏览器。

1. 新建 `OrionWebUIWorldElementDefinition` 数据资产：

| 属性 | 含义 |
| --- | --- |
| `ElementType` | 网页用它选择渲染方式，默认 `Default` |
| `Pivot`、`ScreenOffset` | 标签的对齐点与屏幕偏移 |
| `MaxVisibleDistance` | 超过后隐藏，`0` 表示不按距离隐藏 |
| `bCheckOcclusion` | 被场景挡住时隐藏 |
| `bClampToViewport` | 出屏时贴在屏幕边缘而不是隐藏 |
| `bScaleWithDistance` | 随距离缩小。需要 `MaxVisibleDistance` 大于 0 |
| `bInteractive` | 默认关闭。开启后才能点击 |
| `AllowedActions` | 允许的动作名，例如 `collect` |
| `MaxInteractionDistance` | 交互距离，默认 300，`0` 表示可见即可交互 |

2. 给 Actor 添加组件（搜索 `World Element`，类为 `OrionWebUIWorldElementComponent`）：指定 **Definition**，填 **Element Key**；需要时设置锚点组件、插槽和 **World Offset**。
3. 用 **Set Payload Json** 提供文字和状态。默认的网页渲染器读取 `label` 和 `actionLabel`。用 **Set Element Visible** 显示或隐藏。
4. 界面创建后，取得本地玩家子系统 `OrionWebUIWorldSubsystem`（在蓝图里搜索这个名字），调用 **Bind Overlay Widget**，传入 `WebUI`。
5. 绑定组件的 **On Interaction**：它给出 `Player`、`Action Id`、`Payload Json`。在这里判断游戏规则是否允许，再修改状态。
6. 界面销毁时调用 **Unbind Overlay Widget**。

插件在派发前检查当前世界、组件是否有效、动作是否在允许列表里、是否可见、距离是否足够。这是本地显示层面的检查，不是服务器授权：联网游戏要再发一次经过校验的服务器请求。

### 远程网站

外部网站用单独的 **Orion Browser** 控件，它没有游戏通信接口，不要把它和 **Orion WebUI** 混用。

| 节点或事件 | 作用 |
| --- | --- |
| **Initial URL**（属性）、**Load URL** | 打开地址 |
| **Go Back / Go Forward / Reload / Stop Load** | 导航 |
| **On Load Started / On Load Completed / On Load Error** | 显示加载中、完成、失败 |
| **On Url Changed / On Title Changed** | 地址与标题变化 |
| **On Before Popup** | 页面要打开新窗口 |
| **Get Url / Get Title Text** | 查询 |

断网时只影响这个控件，本地界面照常工作。做一个带重试按钮的失败画面，参考示例的 `WBP_OrionWebsite`。

### 用 CommonUI 承载，不写 C++

需要 CommonUI 的输入模式、返回键和动作路由时：

1. 新建 Widget 蓝图时父类选 **Orion WebUI Activatable Widget**。
2. 放入 **Orion WebUI** 子控件，**名字必须是 `WebUI`**。
3. 在 Class Defaults 里设置：**App Definition**；**Control Sound Policy**（不需要再手动激活）；**Input Config**（`Menu` 为默认值，另有 `Game And Menu`、`Game`、`Default`）；可选的 **Input Manifest**。
4. 在事件图里重写（Override）`HandleWebUIEvent`、`HandleWebUIRequest`、`HandleWebUIReady`，逻辑与前面的 On Web Event、On Web Request 完全相同。
5. 把它推入你的 CommonUI 页面栈。激活时自动加载页面、注册动作、请求显示；停用时自动挂起。

| 属性或事件 | 作用 |
| --- | --- |
| **Input Manifest** | `OrionWebUIInputManifest` 数据资产，每个动作有 `ActionId` 和输入动作。触发后向网页发 `ue:commonAction`，并调用 `HandleCommonAction` |
| **Forward Back Action to Web** | 返回键先以 `ue:backAction` 通知网页 |
| `HandleWebUIBackAction` | 返回 `true` 表示已处理，不执行默认关闭 |
| **Deactivate on Back Action** | 没被处理时是否关闭这个页面 |
| **On Input Prompts Changed** | 输入设备或按键提示变化 |

同一个动作只选一个业务入口：网页已经为它提交操作时，蓝图不要在 `HandleCommonAction` 里再执行一遍。

## 蓝图节点速查

以下节点都在 `WebUI`（**Orion WebUI**）上，搜索时输入关键词即可。

| 分类 | 节点 |
| --- | --- |
| 加载 | **Load App**、**Reload App**、**Set Initial Route Override**、**Get Current Route**、**Get App Id**、**Get App Definition** |
| 发消息 | **Post Event to Web**（一次性，页面没在监听就丢失）、**Post Latest Event to Web**（通信未就绪时只保留最新一条）、**Post Retained Latest Event to Web**（保留最新一条并补发给之后的监听者） |
| 调用网页 | **Call Web**（返回请求 Id，结果从 **On Web Call Completed** 回来）、**Cancel Web Call**、**Get Pending Web Call Count** |
| 请求应答 | `Response` 上的 **Resolve Json**、**Reject**、**Defer**、**Has Responded**、**Is Deferred**、**Get Request Id** |
| 显示阶段 | **Set Presentation Lifecycle State**、**Get Presentation Lifecycle State**、**Get Presentation Lifecycle Revision**、**Begin Native Presentation Gate**、**Release Native Presentation Gate** |
| 就绪查询 | **Is Web Bridge Ready**、**Is Browser Available**、**Is Browser Frame Ready**、**Is Web Presentation Ready**、**Is Web Local Resources Ready**、**Is Web Page Loading**、**Has Requested App Load**、**Get Readiness Snapshot** |
| 声音 | **Activate / Deactivate Control Sound Policy**、**Play Control Sound**、**Play Sound by Id**、**Preload Sounds** |
| 原生画面 | **Set Native Surface Texture / Material / Tint / Composition Layer**、**Clear Native Surface(s)**、**Has Native Surface**、**Get Native Surface Layout** |
| 运行时图片 | **Request Texture Resource**、**Cancel Texture Resource**、**Release Texture Resource(s)**、**Has Texture Resource**、**Is Texture Resource Ready**、**Invalidate Texture Resource**、**Get Texture Resource Stats** |
| 进阶送达 | **Post Flow Controlled Latest Event to Web**、**Post Reliable Retained Latest Event to Web**、**Post Reliable Presentation Event to Web** 及对应的 Cancel 节点，含义见 [C++ 的发布通道](#发布状态的四种通道) |
| 调试 | **Execute Javascript for Debug** |

**Call Web** 是反方向的请求：Unreal 调用网页用 `api.handle(name, handler)` 注册的处理函数，结果里有 `Ok`、`Payload Json`、`Error Code`、`Error Message`。它用来向页面查询显示层面的信息，不要用它驱动游戏逻辑。

## C++：从零接入

### 模块依赖

插件的浏览器模块只支持 Win64，并且不参与 Server 构建。把承载界面的代码放在只为客户端构建的模块里：

```csharp
// MyGameUI.Build.cs
PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "UMG", "OrionWebUI", "OrionWebUIWidget" });
PrivateDependencyModuleNames.AddRange(new string[] { "Json" });
// 使用 CommonUI 页面时再加："CommonUI", "OrionWebUICommonUI"
// 使用 WorldUI 时再加："OrionWebUIWorld"（组件，Server 可用）、"OrionWebUIWorldWidget"（子系统）
```

工程有 Server Target 时，在 `.uproject` 或 `.uplugin` 的模块描述里给这个模块加上 `"TargetDenyList": ["Server"]` 和 `"PlatformAllowList": ["Win64"]`。反射类型不能用宏包起来，所以不要把派生自插件类的 `UCLASS` 放进 Server 会编译的模块。改完模块边界后，把 Server Target 也编译一遍。

| 模块 | 提供 |
| --- | --- |
| `OrionWebUI` | App Definition、各种 Manifest、`UOrionWebUIResponseHandle`、JSON 蓝图库 |
| `OrionWebUIWidget` | `UOrionWebUIWidget`、InstantScreen 的控件与子系统、诊断库 |
| `OrionWebUICommonUI` | `UOrionWebUIActivatableWidget`、`UOrionInstantScreenActivatableWidget`、`UOrionWebUIInputManifest` |
| `OrionWebUIWorld` | `UOrionWebUIWorldElementComponent`、`UOrionWebUIWorldElementDefinition` |
| `OrionWebUIWorldWidget` | `UOrionWebUIWorldSubsystem` |
| `OrionBrowserWidget` | `UOrionBrowserWidget`（远程网站） |

### 普通控件：UUserWidget 加 BindWidget

Widget 蓝图以这个类为父类，Designer 里放一个名为 `WebUI` 的 **Orion WebUI**。

```cpp
// SettingsPanelWidget.h
#pragma once

#include "Blueprint/UserWidget.h"
#include "OrionWebUIDefinitions.h"

#include "SettingsPanelWidget.generated.h"

class UOrionWebUIWidget;

/** 设置面板的宿主：校验网页操作，持有设置，发布完整状态。 */
UCLASS(Abstract, Blueprintable)
class MYGAMEUI_API USettingsPanelWidget : public UUserWidget
{
	GENERATED_BODY()

protected:
	virtual void NativeConstruct() override;
	virtual void NativeDestruct() override;

private:
	UFUNCTION()
	void HandleWebReady();

	UFUNCTION()
	void HandleWebEvent(FName EventName, const FString& PayloadJson);

	UFUNCTION()
	void HandleWebRequest(const FOrionWebUIBridgeRequest& Request, UOrionWebUIResponseHandle* Response);

	UFUNCTION()
	void HandleWebError(const FString& ErrorMessage);

	void PublishState();

protected:
	UPROPERTY(BlueprintReadOnly, meta=(BindWidget))
	TObjectPtr<UOrionWebUIWidget> WebUI;

	/** 在蓝图子类的 Class Defaults 里配置。 */
	UPROPERTY(EditDefaultsOnly, Category="Settings Panel")
	FOrionWebUIControlSoundPolicy ControlSounds;

private:
	int64 StateRevision = 0;
	int32 Volume = 80;
	FString Quality = TEXT("high");
	FString Culture = TEXT("en");
};
```

```cpp
// SettingsPanelWidget.cpp
#include "SettingsPanelWidget.h"

#include "Dom/JsonObject.h"
#include "OrionWebUIWidget.h"
#include "Policies/CondensedJsonPrintPolicy.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

namespace SettingsPanel
{
	static const FName StateEvent(TEXT("ue:settingsPanel.state"));
	static const FName ReadyEvent(TEXT("settingsPanel.ready"));
	static const FName SetVolumeEvent(TEXT("settingsPanel.setVolume"));
	static const FName SetQualityEvent(TEXT("settingsPanel.setQuality"));
	static const FName CloseEvent(TEXT("settingsPanel.close"));
	static const FName ResetDefaultsRequest(TEXT("settingsPanel.resetDefaults"));
}

void USettingsPanelWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (!WebUI)
	{
		return;
	}
	WebUI->OnWebReady.AddUniqueDynamic(this, &ThisClass::HandleWebReady);
	WebUI->OnWebEvent.AddUniqueDynamic(this, &ThisClass::HandleWebEvent);
	WebUI->OnWebRequest.AddUniqueDynamic(this, &ThisClass::HandleWebRequest);
	WebUI->OnWebError.AddUniqueDynamic(this, &ThisClass::HandleWebError);
	WebUI->ActivateControlSoundPolicy(this, NAME_None, ControlSounds);
}

void USettingsPanelWidget::NativeDestruct()
{
	if (WebUI)
	{
		WebUI->DeactivateControlSoundPolicy(this);
		WebUI->OnWebReady.RemoveDynamic(this, &ThisClass::HandleWebReady);
		WebUI->OnWebEvent.RemoveDynamic(this, &ThisClass::HandleWebEvent);
		WebUI->OnWebRequest.RemoveDynamic(this, &ThisClass::HandleWebRequest);
		WebUI->OnWebError.RemoveDynamic(this, &ThisClass::HandleWebError);
	}

	Super::NativeDestruct();
}

void USettingsPanelWidget::HandleWebReady()
{
	PublishState();
}

void USettingsPanelWidget::HandleWebEvent(FName EventName, const FString& PayloadJson)
{
	if (EventName == SettingsPanel::ReadyEvent)
	{
		PublishState();
		return;
	}
	if (EventName == SettingsPanel::CloseEvent)
	{
		RemoveFromParent();
		return;
	}

	TSharedPtr<FJsonObject> Payload;
	if (!FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(PayloadJson), Payload) || !Payload.IsValid())
	{
		return;
	}

	if (EventName == SettingsPanel::SetVolumeEvent)
	{
		double RequestedVolume = 0.0;
		if (Payload->TryGetNumberField(TEXT("volume"), RequestedVolume) && RequestedVolume >= 0.0 && RequestedVolume <= 100.0)
		{
			Volume = FMath::RoundToInt32(RequestedVolume);
			// 在这里把音量应用到游戏。
		}
		PublishState();	// 被拒绝时也推回权威状态，纠正网页上的显示
		return;
	}
	if (EventName == SettingsPanel::SetQualityEvent)
	{
		FString RequestedQuality;
		if (Payload->TryGetStringField(TEXT("quality"), RequestedQuality)
			&& (RequestedQuality == TEXT("low") || RequestedQuality == TEXT("medium") || RequestedQuality == TEXT("high")))
		{
			Quality = RequestedQuality;
		}
		PublishState();
	}
}

void USettingsPanelWidget::HandleWebRequest(const FOrionWebUIBridgeRequest& Request, UOrionWebUIResponseHandle* Response)
{
	if (!Response)
	{
		return;
	}
	if (Request.Name == SettingsPanel::ResetDefaultsRequest)
	{
		Volume = 80;
		Quality = TEXT("high");
		PublishState();
		Response->ResolveJson(TEXT("{}"));
		return;
	}
	Response->Reject(TEXT("E_UNKNOWN_REQUEST"), TEXT("Unknown settings panel request."));
}

void USettingsPanelWidget::HandleWebError(const FString& ErrorMessage)
{
	UE_LOG(LogTemp, Warning, TEXT("SettingsPanel WebUI error: %s"), *ErrorMessage);
}

void USettingsPanelWidget::PublishState()
{
	if (!WebUI)
	{
		return;
	}

	const TSharedRef<FJsonObject> State = MakeShared<FJsonObject>();
	State->SetNumberField(TEXT("stateRevision"), static_cast<double>(++StateRevision));
	State->SetNumberField(TEXT("volume"), Volume);
	State->SetStringField(TEXT("quality"), Quality);
	State->SetStringField(TEXT("culture"), Culture);

	FString Json;
	FJsonSerializer::Serialize(State, TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&Json));
	WebUI->PostRetainedLatestEventToWeb(SettingsPanel::StateEvent, Json);
}
```

要点：

- 所有委托和 `Handle*` 入口都在游戏线程触发，不要把它们挪到别的线程。
- `OnWebEvent` 给的是 JSON 字符串。不想自己解析时绑定原生委托 `OnWebEventParsed`（`AddUObject`），它直接给出只读的 `TSharedPtr<FJsonObject>`。`FOrionWebUIBridgeRequest` 的 `PayloadObject` 成员同理。
- `Response` 只能应答一次。要异步完成就先 `Response->Defer()`，保存指针，稍后再 `ResolveJson` 或 `Reject`。
- `FName` 比较不区分大小写，网页区分。事件名在整个工程里只用一种大小写写法。

### 另一种写法：派生 UOrionWebUIWidget

不想多一层 `UUserWidget` 时，直接派生控件并重写两个 `BlueprintNativeEvent`：

```cpp
UCLASS()
class MYGAMEUI_API USettingsWebUIWidget : public UOrionWebUIWidget
{
	GENERATED_BODY()

protected:
	virtual void HandleWebEvent_Implementation(FName EventName, const FString& PayloadJson) override;
	virtual void HandleWebRequest_Implementation(const FOrionWebUIBridgeRequest& Request, UOrionWebUIResponseHandle* Response) override;
};
```

每条消息的派发顺序是：`OnWebEventParsed` → `OnWebEvent` → `HandleWebEvent`；请求是 `OnWebRequest` → `HandleWebRequest`，之后才判断是否已应答。

### CommonUI 页面

页面进入 CommonUI 页面栈时，派生 `UOrionWebUIActivatableWidget`。基类负责加载 App、激活声音策略、注册输入动作、处理返回键，并在激活和停用时完成显示事务。

```cpp
// SettingsPanelScreen.h
#pragma once

#include "OrionWebUIActivatableWidget.h"

#include "SettingsPanelScreen.generated.h"

UCLASS(Abstract, Blueprintable)
class MYGAMEUI_API USettingsPanelScreen : public UOrionWebUIActivatableWidget
{
	GENERATED_BODY()

protected:
	virtual void NativeOnActivated() override;
	virtual void HandleWebUIReady_Implementation() override;
	virtual void HandleWebUIEvent_Implementation(FName EventName, const FString& PayloadJson) override;
	virtual void HandleWebUIRequest_Implementation(const FOrionWebUIBridgeRequest& Request, UOrionWebUIResponseHandle* Response) override;
	virtual bool HandleWebUIBackAction_Implementation() override;

private:
	void PublishState(bool bForceRepublish);

private:
	FString PublishedStateJson;
	int64 StateRevision = 0;
};
```

```cpp
// SettingsPanelScreen.cpp（节选）
void USettingsPanelScreen::NativeOnActivated()
{
	Super::NativeOnActivated();	// 加载 App、注册动作、分配本次显示的版本号
	PublishState(true);			// 停用期间状态可能变过，按当前数据重新发布
}

void USettingsPanelScreen::HandleWebUIReady_Implementation()
{
	Super::HandleWebUIReady_Implementation();
	PublishState(true);
}

void USettingsPanelScreen::HandleWebUIEvent_Implementation(FName EventName, const FString& PayloadJson)
{
	// 显示阶段和送达回执先返回，不进入业务分支
	if (EventName == StandardPresentationReadyEventName || EventName == StandardPresentationAppliedEventName)
	{
		return;
	}
	// 之后与普通控件的 HandleWebEvent 相同；用 GetWebUIWidget() 取得控件
}

bool USettingsPanelScreen::HandleWebUIBackAction_Implementation()
{
	return false;	// 返回 true 表示自己处理了返回键，不执行默认关闭
}
```

- Widget 蓝图里放一个名为 `WebUI` 的 **Orion WebUI** 子控件；在 Class Defaults 里配置 `AppDefinition`、`InputManifest`、`ControlSoundPolicy`、`InputConfig`。
- 页面只通过你的 CommonUI 页面栈推入，不要直接 `AddToViewport`。
- `InputManifest` 里的动作触发时，依次向网页发 `ue:commonAction`（或该项的 `WebEventName`）、广播 `OnCommonAction`、调用 `HandleCommonAction`。
- 输入设备变化时基类向网页发 `ue:inputModeChanged` 和 `ue:inputPromptsChanged`。

### 发布状态的四种通道

| 通道 | 函数 | 行为 | 何时用 |
| --- | --- | --- | --- |
| 保留最新 | `PostRetainedLatestEventToWeb` | 保留最新一条，之后注册的监听者也能收到 | 一般状态，默认选择 |
| 流控最新 | `PostFlowControlledLatestEventToWeb(Event, Json, AckEvent, RevisionField, Revision)` | 同一个回执名同时只有一条在途、一条待发，中间的版本被合并；网页回执并且浏览器又画出一帧之后才发下一条 | 每帧都可能变化的数据；权威快照 |
| 可靠保留 | `PostReliableRetainedLatestEventToWeb(..., RetryIntervalSeconds, MaxAttempts)` | 没收到精确版本的回执就重发，最多 `MaxAttempts` 次（默认 4 次），之后记一条警告并停止 | 必须送达的快照 |
| 呈现事务 | `PostReliablePresentationEventToWeb(...)` | 先隐藏控件，页面确认该版本并且新的一帧完成后才显示，超时则放行 | 进入画面时不想看到半成品；CommonUI 基类已经封装 |

- 回执只表示“这一版送到了”或“这一版显示了”，不代表业务成功，C++ 不要等回执才执行业务。
- 一个回执事件名只属于一条流。
- 版本号用 `UOrionWebUIWidget::AllocatePresentationRevision()` 分配，它在进程内唯一且递增。业务状态的 `stateRevision` 与显示用的 `presentationRevision` 是两套编号，不要互相比较。
- 内容没变就不要分配新版本：先比较序列化后的状态，变了才递增。
- 数据无效时直接返回，不要发一个空状态去占位。

### 资源接口

| 需求 | 接口 |
| --- | --- |
| `UTexture2D` 给网页显示 | `RequestTextureResource(StableId, Texture, Options)`，完成时触发 `OnTextureResourceCompleted` |
| 已有 CPU 像素 | `RequestPixelResource(StableId, FOrionWebUIPixelSource, Options)`，只有 C++ 可用 |
| 实时画面 | `SetNativeSurfaceTexture`、`SetNativeSurfaceMaterial` |
| 材质用到了临时资源 | `SetNativeSurfaceMaterialWithDependencies(SurfaceId, Material, Dependencies)`，让依赖项和画面一起退役 |
| 查询画面区域 | `TryGetNativeSurfaceLayoutState`、`TryGetNativeSurfaceAbsoluteRect` |

更换 Render Target 时新建动态材质实例再调用 `SetNativeSurfaceMaterial`，不要修改仍在绑定中的实例。退役顺序是：停止出帧 → 清除或替换绑定 → 释放业务侧引用 → 销毁 Render Target。

### WorldUI

```cpp
#include "OrionWebUIWorldSubsystem.h"

if (ULocalPlayer* LocalPlayer = GetOwningLocalPlayer())
{
	if (UOrionWebUIWorldSubsystem* WorldUI = LocalPlayer->GetSubsystem<UOrionWebUIWorldSubsystem>())
	{
		WorldUI->BindOverlayWidget(WebUI);
	}
}
```

组件的 `OnInteraction` 是动态多播委托 `(APlayerController* Player, FName ActionId, const FString& PayloadJson)`。只属于某个本地玩家的标签用组件的 `SetOwningLocalPlayer`。承载标签的页面是 InstantScreen 时，改用 `BindOverlayEndpoint`。全局预算在 `UOrionWebUIWorldSettings`（`MaxVisibleElements`、刷新率、遮挡检测数量）。

### 线程与生命周期

- 浏览器在独立进程里运行。网页的调用返回不代表游戏状态已经改变。
- 不要用固定延时、反复 `ReloadApp()` 或重建控件来掩盖时序问题；用 `OnWebReady`、`OnWebLocalResourcesReady` 和就绪查询等待。
- 委托、定时器、异步加载句柄、被 `Defer()` 的应答都要对称清理，覆盖停用、切换关卡和重复进入。
- 不可渲染的环境（例如带 `-nocef` 启动）不会创建浏览器，代码要能容忍控件为空。

## C++ 基类加蓝图子类

把“不能被绕过的事”写在 C++ 里，把“设计师要调的事”留给蓝图：

```cpp
UCLASS(Abstract, Blueprintable)
class MYGAMEUI_API USettingsPanelWidget : public UUserWidget
{
	GENERATED_BODY()

protected:
	/** 蓝图可以重写默认行为；校验在调用它之前已经完成。 */
	UFUNCTION(BlueprintNativeEvent, Category="Settings Panel")
	void OnVolumeAccepted(int32 NewVolume);

	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="Settings Panel")
	bool bResetEnabled = true;
};
```

- 校验写在 C++ 的派发处，通过后才调用 `BlueprintNativeEvent`，蓝图重写无法跳过校验。
- 每个固定按钮一个事件和一个启用开关，不要用“一个通用入口加字符串参数”。
- 启用开关随完整状态发布给网页，网页据此禁用按钮；真正的拦截仍在 C++。
- 声音策略、App Definition、Input Manifest 作为 `EditDefaultsOnly` 属性，在蓝图子类的 Class Defaults 里配置。
- 修改已有的类时，不要改名、改签名或删除蓝图已经重写的事件。

## InstantScreen 概览

InstantScreen 让同一层的多个界面共用一个常驻浏览器。每个界面带一份构建时生成的首帧包；显示由一次事务决定，状态、资源、输入和首帧都确认之后才露出画面。它适合正式进入页面栈、需要“加载完才显示”、被覆盖后恢复的菜单和 HUD。单个面板用普通控件就够了。

需要的东西比前面多：

| 部分 | 内容 |
| --- | --- |
| 网页 | App 根目录的 `instant-screen.config.ts`；构建后在插件 `Content/UI/WebUI/Shared` 目录运行 `npm run instant:build`、`npm run instant:validate` 生成并校验首帧包；业务操作改用 `requestIntent` |
| 资产 | `OrionInstantScreenDefinition`（每个界面）、`OrionInstantScreenCatalog`（一组界面）、`OrionInstantScreenRuntimeProfile`（层到浏览器的映射） |
| 根布局 | 放置 **Orion InstantScreen Runtime Host**，并对本地玩家的 `UOrionInstantScreenSubsystem` 调用 **Register Catalog** |
| 界面 | Widget 蓝图父类派生自 `UOrionInstantScreenActivatableWidget`，子控件 `WebUI` 的类型是 **Orion InstantScreen** |
| 配置 | 渲染模式必须是 `LegacyTexture`（默认值，不要改成其他模式） |

完整的合同、配置字段和排查方法见随插件分发的 [InstantScreen 参考](../Skills/orion-webui-creation/references/instant-screen.zh-CN.md)。

## 排查

| 现象 | 检查 |
| --- | --- |
| 页面空白 | `AppId`、目录名、`orionWebUI.appId` 三者是否一致；`dist/index.html` 是否存在；看 **On Web Error** |
| Designer 显示 `Orion WebUI dist entry is missing` | 没有构建，或 `AppId` 写错 |
| 点击没反应 | **On Web Event** 是否绑定在 `WebUI` 上；事件名是否逐字一致（看 **Pin Names** 里填的名字，节点上显示的带空格）；`Valid` 是否为 `false` |
| 网页一直停在旧数值 | 是否每次变化后都发布；`stateRevision` 是否递增 |
| 请求一直等到超时 | 调用了 **Defer** 却没有应答 |
| 请求总是“成功” | Default 分支没有 **Reject**，被自动应答了 |
| 键盘、手柄没反应 | 视口是否为 CommonGameViewportClient（见[安装](installation.zh-CN.md#commonui-视口)）；输入模式与焦点是否给了 `WebUI`；**Set Input Mode Game And UI** 的 **Player Controller** 引脚是否空着 |
| 调用 **Set Presentation Lifecycle State** 后页面消失或不再响应 | **Preparing** 把控件隐藏了，或者 **Covered Suspended**、**Closing** 把浏览器停驻了。**Visible** 对两者都不起作用：**Preparing** 之后要调用 **Release Native Presentation Gate**，停驻的浏览器要用 **Preparing** 唤醒。纯蓝图的页面只用 **Visible** |
| 没有声音 | 是否激活了策略；控件有没有 Id；`Context Id` 是否对得上；声音资产是否为空 |
| 运行时图片不显示 | 是否等到 **Ready** 才把地址给网页；是否是虚拟纹理 |
| 打包后页面空白 | 先构建 `dist` 再打包，见[打包与故障排查](packaging.zh-CN.md) |
