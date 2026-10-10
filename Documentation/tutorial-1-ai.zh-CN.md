# 教程 1：用 AI 制作界面（推荐）

把想要的界面讲给 Codex 或 Claude，由它写网页、构建、列出蓝图接线清单；你负责定风格、确认数据与操作、在蓝图里指定声音，并在 Unreal 里验收。本教程只教一件事：**每一步该对 Agent 说什么**。

[English](tutorial-1-ai.md) · [手册目录](README.zh-CN.md) · 想自己写网页见[教程 2](tutorial-2-build-it-yourself.zh-CN.md)，蓝图与 C++ 接线细节见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md)，预览工具见[教程 4](tutorial-4-webui-studio.zh-CN.md)。

```text
准备 → ① 定 UI 设定集 → ② 定数据与操作 → ③ 写界面 → ④ 看效果、提修改 → ⑤ 蓝图接线 → ⑥ 蓝图指定声音 → ⑦ 测试
```

## 谁做什么

| 角色 | 负责 |
| --- | --- |
| 你 | 说清楚要什么；选定风格；确认数据与操作；在蓝图里接线、指定声音；在 Unreal 里看结果 |
| Agent | 阅读 Skill；写设定集和网页；构建并自查；交付接线清单与控件 Id；说明哪些层面没有验证 |
| 插件自带的 Skill | 规定**怎么做**：状态归 Unreal、网页只提交操作、目录与命名、预览、构建与验证 |

Skill 已经管住了“怎么做”，所以你的提示词不用教 Agent 写代码，只需要把**做什么**说完整：给谁用、显示哪些数据、能做哪些操作、长什么样、做到什么程度算完成。

## 准备

1. 完成[安装](installation.zh-CN.md)，等工具准备完成。制作自己的网页 App 时，建议把插件放在工程的 `Plugins/OrionBrowser`：网页工程用相对路径引用插件的共享运行库，这是已验证的目录布局。
2. 安装 Node.js 22 或更新的 LTS 版本（自带 npm）。Agent 在终端里构建网页需要它。
3. 用 Codex 或 Claude Code 打开**工程根目录**（`.uproject` 所在目录），让它同时读得到 `Plugins/OrionBrowser` 和 `Content/UI/WebUI`。
4. 把长期有效的要求写进指令文件。Codex 读取工程根目录的 `AGENTS.md`，Claude Code 读取 `CLAUDE.md`：

```markdown
- 制作或修改 OrionBrowser 界面前，先阅读 Plugins/OrionBrowser/Skills/orion-webui-creation/SKILL.md，需要细节时再读它指向的 references。
- 界面风格以 Docs/UI/ui-style.md 为准。
- 可以在网页 App 目录运行 npm ci、npm run typecheck、npm test、npm run build。
- 未经我同意，不要启动 Unreal Editor、PIE 或打包，也不要直接修改 .uasset 和 .umap 文件。
```

第二条提到的 `ui-style.md` 在第 1 步产生，现在可以先写上。然后用第一条提示词确认它读懂了：

```text
阅读 Plugins/OrionBrowser/Skills/orion-webui-creation/SKILL.md。先不要写代码，用几句话告诉我：
谁拥有游戏状态；网页怎样提交操作；生产文件放在哪里；你会用哪些命令验证；哪些事情你不会做。
```

回答里应该出现：状态归 Unreal（蓝图或 C++）、网页只显示状态并提交操作、`Content/UI/WebUI/<AppId>/dist`、类型检查与构建命令、不改 `.uasset`、未授权不运行 Unreal。缺了哪一条，就让它重读。

**对 Agent 说话有两个入口，本教程的提示词两边都能用：**

- **直接在 Codex 或 Claude 的对话里写。** 任何时候都可用。
- **从 WebUIStudio 发出。** 它的“新建界面”和标注会自动带上 Skill 的位置、工程里已有的界面、控件的源码位置和截图，你只写要求。需要已安装并登录 Codex 或 Claude 的桌面应用，见[教程 4](tutorial-4-webui-studio.zh-CN.md#标注并发给-agent)。

## 第 1 步：定 UI 设定集

设定集是所有界面共用的决定：气质、颜色各管什么、字体与字号、间距、形状、动效时长、版式骨架、每种控件的各个状态。先定下来再做界面，否则 Agent 每次交出来的风格都不一样，而且它不记得上一次对话。

设定集落成三样东西，都由 Agent 来写：

| 产物 | 建议位置 | 用途 |
| --- | --- | --- |
| 规则文档 | `Docs/UI/ui-style.md` | 规则正文和交付前自检清单。以后每次做界面，Agent 先读它 |
| 样式库 | `Content/UI/WebUI/Shared/src/game-ui/` | 设计令牌（CSS 变量）和控件样式，所有界面共用 |
| 参考集 App | `Tools/WebUI/UIStyleGuide` | 规范页和几张示例界面，用 WebUIStudio 或浏览器翻看。放在 `Content` 之外，不随游戏打包 |

**先出方向，不做正式界面：**

```text
我要为游戏定一套 UI 设定集，以后所有 OrionBrowser 界面都按它做。这一轮只出方向。

游戏：第三人称科幻生存，画面偏冷、偏暗。
想要的感觉：克制、硬朗、文字少；场景是主角，界面贴边摆放。
参考：Docs/UI/refs/ 里的 6 张截图。取它们的信息层级和留白，不要照搬配色和图标。
平台与输入：PC，键鼠和手柄都要能完整操作。
设计分辨率 1920×1080，其他分辨率整体等比缩放。语言：简体中文、英文。
必须遵守：页面背景透明；不用 backdrop-filter 和 mix-blend-mode；字体和图片随包提供，不引用远程地址。

请做一个只供开发查看的 WebUI App，放在 Tools/WebUI/UIStyleGuide，给出 3 个明显不同的方向。
每个方向一页：配色以及每种颜色管什么、字体与字号阶梯、按钮的默认/悬停/聚焦/按下/禁用/选中状态、一块示例面板、一条 HUD 示例。
在 webui-preview.json 里为每一页登记视图，方便我在 WebUIStudio 里逐页查看。完成后告诉我怎样打开。
```

**选定后固化下来：**

```text
选方向 B，改三处：主色换成更暖的橙色；去掉所有圆角；正文最小 14px。
把它固化成三样东西：
1. Docs/UI/ui-style.md：规则正文，末尾附交付前自检清单（层级是否清楚、对比度、文字不溢出、状态齐全、同类界面位置一致）。
2. Content/UI/WebUI/Shared/src/game-ui/：设计令牌（颜色、字号、间距、时长都是 CSS 变量）和控件样式。以后界面只取令牌里的值，需要新值先加进令牌。
3. 更新 UIStyleGuide：规范页（颜色、字体、控件、状态、动效），加两张示例界面（一张菜单、一张 HUD）；每张都有中文、英文、文字加长四成三种视图。
```

写风格提示词的要点：

- **说感觉和用途，不说 CSS。**“主行动最亮，每屏只有一个”比“按钮用某个色值”有用；手里有确切数值时再给数值。
- **参考图要说取什么、不取什么。**只丢一张图，Agent 会照搬。
- **把禁止的东西写出来。**圆角、渐变文字、到处发光，不说就可能出现。
- **要全状态、要最长文案。**悬停、聚焦、按下、禁用、选中、加载；最长的文字和另一种语言各出一张视图。
- **定稿就写进文档。**口头同意过的风格，下一次对话就不存在了。

在 WebUIStudio 里看设定集时，把“预览底色”换成一张游戏截图，直接判断文字和面板在真实画面上是否清楚。

## 第 2 步：定数据与操作

界面显示哪些数据、玩家能做哪些操作，要在写代码之前定成一张表。这张表就是之后蓝图接线的依据，两边的名字必须一字不差。下面以设置面板为例：

```text
按 ui-style.md 做一个设置面板。AppId：SettingsPanel，事件前缀：settingsPanel。宿主是纯蓝图。
蓝图持有的状态：音量 0–100、画质 low / medium / high、语言 zh-Hans / en。
玩家能做的事：调音量、选画质、还原默认、关闭面板。

先不要写代码，给我一张合同表：
- 蓝图发给网页的状态事件名和完整 JSON：顶层只用字符串、数字、布尔，带一个递增的 stateRevision；
- 每个操作的事件名、参数和取值范围，用 emit 还是 call，蓝图拒绝时网页怎样表现；
- 每个可点击控件的稳定 Id（data-orion-control-id）。
```

“顶层只用字符串、数字、布尔”是因为插件自带的蓝图 JSON 节点读写的是顶层标量字段；需要数组或嵌套对象时见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md#蓝图里的-json)。

Agent 应当交回类似这样的表：

| 方向 | 名称 | 参数 | 说明 |
| --- | --- | --- | --- |
| Unreal → 网页 | `ue:settingsPanel.state` | `{ stateRevision, volume, quality, culture }` | 完整状态，每次变化都重发 |
| 网页 → Unreal（emit） | `settingsPanel.ready` | `{}` | 网页已开始监听，请求首个状态 |
| 网页 → Unreal（emit） | `settingsPanel.setVolume` | `{ volume: 0–100 }` | 蓝图校验范围后保存 |
| 网页 → Unreal（emit） | `settingsPanel.setQuality` | `{ quality }` | 只接受三个取值 |
| 网页 → Unreal（call） | `settingsPanel.resetDefaults` | `{}` | 需要结果：成功返回 `{}`，失败返回错误码 |
| 网页 → Unreal（emit） | `settingsPanel.close` | `{}` | 由蓝图关闭面板 |

放行前核对三件事：名字是不是你愿意在蓝图里看到的；每个参数有没有范围；有没有哪个结果是网页自己说了算的（不应该有）。

## 第 3 步：让 Agent 写界面

```text
合同确认。现在实现 SettingsPanel：
- 位置：Content/UI/WebUI/SettingsPanel。样式只用 game-ui 的令牌和控件类。
- 中英双语，语言跟随状态里的 culture。
- 键鼠和手柄都能完整操作：方向键移动焦点，确认键触发，焦点样式清晰可见。
- 没有宿主时（浏览器、UMG Designer）用预览数据直接显示。在 webui-preview.json 里登记视图：默认、英文、音量为 0、最长文案。
- 完成后运行 npm ci、npm run typecheck、npm test、npm run build，全部通过再交付。

交付时给我：
1. 新增和修改的文件清单；
2. 一份可以照着做的蓝图接线清单（节点名、事件名、字段名），并写进 Content/UI/WebUI/SettingsPanel/README.md；
3. 全部控件 Id；
4. 哪些层面你没有验证。
```

从 WebUIStudio 发出时：点左栏第一行的“新建界面”，把上面这段贴进“界面描述”，“界面名”填 `SettingsPanel`，选择 Codex 或 Claude 后发送。Studio 会在你的描述前面自动加上“先完整阅读制作 Skill”及其位置，在后面加上工程里已有的界面清单和交付要求；点“复制提示词”可以拿到完整内容。

一条完整的提示词有八个部分，缺哪一部分，Agent 就会自己猜：

| 部分 | 例子 |
| --- | --- |
| 目标 | 做一个设置面板 |
| 身份与位置 | AppId、事件前缀、目录 |
| 风格 | 按 `ui-style.md`，只用样式库 |
| 数据与操作 | 第 2 步确认过的合同 |
| 要覆盖的情况 | 两种语言、空数据、最长文案、禁用状态 |
| 输入 | 键鼠、手柄、文字输入 |
| 预览 | 无宿主时的预览数据，`webui-preview.json` 的视图 |
| 完成标准 | 要通过的命令、要交付的清单、没有验证的范围 |

## 第 4 步：看效果、提修改

三个地方可以看：

- **WebUIStudio**：点击关卡编辑器工具栏上的 **WebUIStudio** 按钮，选择界面，逐个视图查看。用法见[教程 4](tutorial-4-webui-studio.zh-CN.md)。
- **UMG Designer**：完成第 5 步的资产后，Orion WebUI 控件会在 Designer 里直接显示页面。
- **浏览器**：在 App 目录运行 `npm run dev`，打开终端给出的地址。

**最省事的提修改方式是在 Studio 里标注：**用“控件”工具点中要改的控件，写下想怎么改；需要时展开“调整属性”，直接把颜色、字号、间距调到满意；保存后在右栏写整体要求，选择接收方并发送。位置、截图、源码行和你调出来的目标数值都会随标注交给 Agent。没有标注时，可以直接发送对整个页面的修改要求。

**自己写修改意见时，**要让 Agent 找得到位置、看得懂目标：

```text
视图“英文”：重置按钮（settings-reset）的文字被截断。应完整显示，按钮按内容定宽。
视图“默认”：音量滑块的聚焦样式和悬停样式分不出来。聚焦要更亮。
不要改合同和控件 Id。改完重新构建，并告诉我你检查了哪些视图。
```

- 每条写清：**哪个视图、哪个控件（用控件 Id）、现在是什么样、应该是什么样**。有截图就给出截图路径。
- “好看一点”“高级一点”没有用；说出你看到的问题，比如“主按钮不够突出”“这一屏有三个地方在抢视线”。
- 需求变了，先让它改合同表，再改代码；不要在修改意见里顺手加一个新操作。
- 风格问题反复出现，就让它把结论补进 `ui-style.md`，而不是每次都提醒。
- 改动大、拿不准时，先让它只写计划（Studio 的“计划模式”，或在提示词里写“先给计划，不改文件”）。

## 第 5 步：蓝图接线

照着 Agent 交付的接线清单做。最小接线只有六步，每一步的节点细节见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md#纯蓝图从零接入)：

1. 新建 `OrionWebUIAppDefinition` 数据资产：`AppId` 填 `SettingsPanel`，取消勾选 **Use Dev Server in Editor**。
2. 新建 Widget 蓝图，放入 **Orion WebUI** 控件，命名为 `WebUI`，勾选 **Is Variable**，指定上一步的资产。
3. `WebUI` 的 **On Web Event**：按 `Event Name` 分支。读取参数用 **Get Json Number / String / Boolean**，先检查 `Valid`，再检查取值范围，通过后才修改蓝图变量。
4. 写一个“发布状态”函数：版本号加一，用 **Set Json Number / String / Boolean** 从 `{}` 开始拼出完整状态，调用 **Post Retained Latest Event to Web**，事件名 `ue:settingsPanel.state`。收到 `settingsPanel.ready` 和每次状态变化后都调用它。
5. `WebUI` 的 **On Web Request**：处理 `settingsPanel.resetDefaults`，完成后对 `Response` 调用 **Resolve Json**，不允许时调用 **Reject**。
6. 在 Player Controller 里创建这个 Widget，**Add to Viewport**，显示鼠标并设置 **Set Input Mode Game And UI**。

Agent 能通过编辑器自动化工具操作 Unreal 时，可以让它来建资产和连节点，但必须走 Unreal 的正式接口；任何时候都不要让它用文本或二进制方式修改 `.uasset`。

## 第 6 步：在蓝图里指定声音

悬停和点击的声音由 Unreal 播放，网页不写任何播放代码：插件把“哪个控件被悬停或点击”连同控件 Id 报给蓝图，蓝图里的声音策略决定播什么。先让 Agent 把控件 Id 理清楚：

```text
列出 SettingsPanel 的全部控件 Id，并给每个 Id 标一个声音角色：默认、确认、返回、危险、滑块。
检查每个可点击元素都有字面量的 data-orion-control-id；禁用和等待状态用 disabled、aria-disabled 或 aria-busy 表达。
页面里不要自己播放悬停和点击声。
```

然后在承载界面的 Widget 蓝图里：

1. 新建变量 `ControlSounds`，类型选 `OrionWebUIControlSoundPolicy`（搜索 `Control Sound Policy`），编译。
2. 在变量默认值里填写：**Default Sounds** 下的 **Hover Sound** 与 **Click Sound** 是所有控件的默认声音；**Control Overrides** 里每加一项，填 **Control Id**，勾选 **Override Hover Sound** 或 **Override Click Sound**，再选声音。想让某个控件不出声，就加一条覆盖，勾选对应的 Override，再取消该项声音的 **Enabled**。
3. **Event Construct**：对 `WebUI` 调用 **Activate Control Sound Policy**，`Policy Owner` 接 `Self`，`Context Id` 留空，`Policy` 接 `ControlSounds`。
4. **Event Destruct**：对 `WebUI` 调用 **Deactivate Control Sound Policy**，`Policy Owner` 接 `Self`。
5. 核对 Id。在 WebUIStudio 里用“控件”工具点一个控件，“检查”页签显示的控件 Id 就是蓝图该填的 Id；显示“未声明”说明这个控件没有 Id，交给 Agent 补上。在 Widget Designer 里，把 `WebUI` 的 **Design Time Control Id Preview Mode** 设为 **All Controls** 也能给每个控件标出 Id，红框并标着 `ControlId: <missing>` 表示缺 Id。

“保存成功”“操作失败”这类有业务含义的声音不属于控件音效：在 `OrionWebUISoundManifest` 数据资产里登记声音 Id，指定给 App Definition 的 **Sound Manifest**，再让 Agent 在对应时机调用 `playSound`。声音资产仍然由你在 Unreal 里选。

## 第 7 步：测试

每一层只能证明自己那一层，不能互相代替：

| 层 | 怎么做 | 能证明 | 不能证明 |
| --- | --- | --- | --- |
| 构建 | Agent 运行类型检查、合同检查、构建 | 代码能编译，命名和禁用写法合规 | 页面长什么样 |
| 预览 | WebUIStudio、浏览器 | 布局、状态、两种语言、最长文案 | 蓝图逻辑、真实输入、声音 |
| Designer | Widget 蓝图的 Designer | 资产配置正确，页面能在引擎里加载 | 运行时行为 |
| PIE | 点击 Play | 蓝图状态往返、键鼠与手柄、输入法、声音 | 打包后的结果 |
| 打包 | 运行成品游戏 | 网页文件进了包体，可以离线运行 | 没有实际操作过的页面 |

PIE 里至少走一遍：每个控件用鼠标点一次，再只用键盘、只用手柄各完整操作一遍；切换语言；在文字框里用输入法输入；反复打开和关闭界面；确认每个控件的悬停和点击声。

出了问题，把**现象、所在层、日志**一起交给 Agent：

```text
PIE 里拖动音量滑块，界面上的数值不变。
蓝图的 settingsPanel.setVolume 分支执行了（断点命中）。On Web Error 没有输出。
Output Log 里相关的几行：（粘贴 LogOrionWebUIWidget 开头的日志）
先判断问题出在网页、合同还是蓝图，再给出修改。不要用加延时的办法解决。
```

打包见[打包与故障排查](packaging.zh-CN.md)。网页文件变化后要先重新构建 `dist`，再打包。

## 提示词速查

- 先让 Agent 读 Skill 和 `ui-style.md`，再说需求。
- 一次只做一个界面；先要合同表，确认后再让它写代码。
- 给名字：AppId、事件前缀、状态字段、控件 Id 的命名方式。
- 给边界：能改哪些目录、能运行哪些命令、不能做什么。
- 给完成标准：要通过的命令、要交付的清单、要说明的未验证范围。
- 说“状态归蓝图”：网页不保存进度，不自己判定成功。
- 修改意见写视图、控件 Id、现状、期望；能标注就标注。
- 结论写进文件（`ui-style.md`、App 目录下的 `README.md`），不要依赖对话记忆。
- 不让它猜：缺信息时要求它先提问。
- 不接受“应该可以”：要求它给出实际运行过的命令和结果。

## 常见问题

| 现象 | 原因 | 对 Agent 说 |
| --- | --- | --- |
| 每个界面风格都不一样 | 没有设定集，或没让它读 | “先读 `ui-style.md`，只用样式库里的令牌和控件类” |
| Studio 里空白，浏览器里正常 | 预览数据只写在“没有宿主”的分支里 | “按 Skill 的 Studio 预览合同导出预览状态，并登记视图” |
| Designer 里空白 | 页面等到 Unreal 状态才绘制 | “没有宿主时用预览数据直接显示” |
| 点了按钮，蓝图没反应 | 事件名或字段名两边不一致 | “对照合同表逐字检查事件名和字段名，列出不一致的地方” |
| 禁用的按钮还有声音 | 只用样式表示禁用 | “禁用和等待用 `disabled`、`aria-disabled`、`aria-busy` 表达” |
| 一次点击响两声 | 页面自己也播了悬停或点击声 | “删掉页面里的悬停和点击播放，交给控件音效策略” |
| 换了语言文字溢出 | 没有检查最长文案 | “补一张最长文案的视图，控件按内容定宽” |
| 它说做完了但没有构建 | 没有完成标准 | “运行类型检查、合同检查和构建，把每条命令的结果贴给我” |
