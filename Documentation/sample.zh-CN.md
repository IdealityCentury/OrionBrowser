# 猎户空间站示例

示例是一座包含三个能量单元和 WorldUI 终端的小型离线空间站。库存、任务进度和持久偏好由 Unreal 蓝图持有；网页显示状态并提交操作请求。

## 基础 Sample

`Content/UI/WebUI/Sample` 是独立的 Vue/TypeScript/Vite 基础示例，源码在 `src`，入口与 npm 配置在 App 根目录，生产文件在 `dist`。它展示 UE 事件、请求响应、输入提示、本地化和控件音效；AppId 保持 `Sample`。Bridge、生命周期和 WorldUI 组件从插件 `Content/UI/WebUI/Shared` 共享运行库导入。

从插件目录执行 `Scripts/Build-OrionWebUI.ps1` 构建该示例；安装依赖使用已有锁文件。也可在 `Content/UI/WebUI/Sample` 中执行 `npm ci`、`npm run typecheck`、`npm run build`。各 App 的本地依赖和缓存由 `.gitignore` 排除。

## 打开示例

在内容浏览器启用 **Show Plugin Content**，打开 `/OrionBrowser/Showcase/L_OrionBrowserOverview`，等待配套工具准备完成后运行 Play。独立 `OrionBrowserTemplate` 工程以自己的 `/Game/OrionStation/L_OrionStation` 为默认关卡，并复用插件示例资产；工程没有自己的 C++ 游戏模块。

示例使用插件默认的 `LegacyTexture`。官网访问需要联网，空间站界面、本地字体、three.js 场景、影片和配乐使用本地生产文件。

内置 Showcase 控件会将事件转交 `BP_OrionStationController`。要在另一个关卡原样运行此示例，在 World Settings 中指定 `BP_OrionStationGameMode`，由示例控制器创建界面并持有状态。只向无关控制器添加原样的 Showcase 控件，不会初始化空间站状态；接入自己的游戏时，按[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md) 创建自己的宿主，并将事件接到自己的控制器。

## 界面内容

网页是一个页面，包含五个目的地和一个任务 HUD。屏幕顶部只有一块表面，导航、任务进度、消息和命令搜索都由它承载：它改变形状，而不是被替换。

页面是盖在游戏上的一层玻璃。它没有自己的背景：表面是半透明的，three.js 展室把画布清为透明，没有内容的地方直接透出关卡。四套主题共用一组设计变量：**曜石**（默认的深色主题）、**星云**、**极光**和浅色的**纸墨**。三种背景决定关卡与界面之间隔着什么：半透明遮罩、实体页面，或者什么都不隔。两者都可以在设置页或命令搜索里切换，搜索框旁的按钮会依次切换主题。它们属于页面自己：保存在浏览器的本地存储里，不写入蓝图存档；宿主如果想接管这项选择，可以改为在状态里发布 `theme` 和 `backdrop`。

| 页面 | 内容 |
| --- | --- |
| 概览 | 示例是什么、蓝图发布的任务状态，以及通往其他页面的入口 |
| 展厅 | 十个展室，每个展室围绕一组插件能力或一种网页技术 |
| 背包 | 蓝图持有的物品。选中一件会发送操作请求，详情跟随返回的状态 |
| 设置 | 草稿表单与 Unreal 上一次发布的值并排显示。蓝图接受**应用**之前，任何值都不会改变。主题和背景是例外：它们属于页面，选中即生效 |
| 指南 | 四步完成任务、当前设备的操作方式，以及如何重新构建示例 |

| 展室 | 演示内容 |
| --- | --- |
| 动效 | “One shape”：一段 14 秒、28 拍的循环，同一块表面依次变成按钮、加载指示、音乐播放器、滑块、图表和命令面板。每一帧都是时间的纯函数，所以同一份代码既在页面里实时运行，也渲染出随附的影片。它按“纸上的墨”绘制；深色主题把同一幅画显示成负片，落在玻璃上 |
| 组件 | 界面用到的按钮、开关、滑块、分段控件、形变表面和图表，全部由同一个闭式弹簧驱动 |
| 光效 | 把光当作材质：随指针转动的全息箔、跟随指针的镜头眩光、锥形渐变流动的描边、扫过文字与金属的高光、镭射光束与霓虹招牌，以及从实体到全透明的玻璃。全部由渐变和遮罩绘制，没有一样需要读取页面背后的画面 |
| 字体 | 十二种字族的实时样张：随附的三种字体，加上 Windows 通常自带的九种，未安装的会标出。一行可编辑的样张，可调字重、字号和字距；渐变、描边和辉光填充；竖排 |
| 楼阁 | 完全用代码搭建的 three.js 六角重檐楼阁：一整天的日月光照、柔和阴影、倒影水面、灯笼与泛光。细节层级跟随蓝图保存的**画质**偏好 |
| 宇宙 | 透明画布上的三个太空场景，背后就是关卡：行星表面由着色器程序化生成、镜头可以跟随任一行星的太阳系；最多 34 万颗恒星、由 GPU 驱动的旋涡星系；逐像素光线步进、吸积盘被引力折到阴影上方的黑洞 |
| 性能 | 一片实例化的小行星带，代价由你设定：最多 6 万块碎石、最多 4000 个绘制批次、单体三角面数、光照模型、阴影贴图尺寸、渲染分辨率，以及在脚本里逐块计算的自转。读数包括每秒帧数、帧间隔、脚本耗时、绘制调用和三角面数，并画出最近 120 帧的帧时间曲线 |
| 影音 | 带声音的本地视频：随附影片（WebM 中的 VP9 与 Opus），使用自己的播放控件和实时电平表。深色主题下由 CSS 滤镜把同一个文件播放成负片 |
| 输入 | 由 Unreal 播放的控件音效、跟随当前设备的按键提示、按键测试、输入法文字输入、可选中文本，以及 CommonUI 宿主带来的能力 |
| 虚幻 | Native Surface、运行时图片、状态版本与桥接通信记录、桥接往返计时、WorldUI 标签和独立的官网浏览器 |

页面使用插件的方式：

- **控件音效。** 根元素带有 `data-orion-sound-context="Station"`，每个控件都有字面量的 `data-orion-control-id`。悬停和点击由插件自行上报给 Unreal，页面不调用任何播放函数。`data-orion-sound-policy="none"` 让一块区域保持安静，禁用的控件也不发声。输入展室会显示上报的标识。
- **显示生命周期。** 动画循环、WebGL 和视频只在页面处于 `active` 显示阶段时运行；页面被覆盖或正在关闭时停止，恢复显示后继续。
- **视频与音频。** 本地文件不支持范围请求，所以影音展室把影片一次读入内存，再通过 Blob URL 播放，这样才能拖动进度。请使用 VP9 与 Opus 的 WebM，或随附 Chromium 能解码的其他格式。
- **透明。** 页面按自身的 alpha 混合到游戏画面上，所以一块表面只需要半透明的颜色就能透出关卡。叠加在“空无一物”上的光（辉光、星点）要连同颜色一起写入 alpha。页面背后的画面无法被模糊，也无法被读取，因为游戏并不在页面里；应用契约（`npm test`）本来也不接受 `backdrop-filter` 和 `mix-blend-mode`。因此散落的文字下面垫着一片与页面同色的柔和雾化衬底；没有遮罩时，外壳的控件会换成更深的玻璃，两者在明亮的关卡上都保持可读。
- **测量。** 性能展室测的是页面自己的帧。想知道某项设置让游戏付出多少，调整它的同时看 Unreal 的 `stat fps` 或 `stat unit`。
- **CommonUI。** 示例用普通 UMG 控件承载页面，由蓝图控制器驱动。页面同时安装了共享的 CommonUI 动作路由并监听按键提示，所以同一张页面也可以放进 CommonUI 页面栈里的 **Orion WebUI Activatable Widget**；输入展室说明了这种宿主增加的能力。

## 资产与职责

| `/OrionBrowser/Showcase` 中的资产 | 职责 |
| --- | --- |
| `L_OrionBrowserOverview` | 原创空间站组合、三个能量单元、终端、出口、玩家起点与场景捕获 |
| `BP_OrionStationGameMode` | 选择示例 PlayerController 和引擎 SpectatorPawn |
| `BP_OrionStationController` | 持有 `StateJson`、校验操作、发布版本状态、保存资料并创建界面 |
| `BP_OrionStationSave` | 在 `OrionStationProfile` 存档槽保存蓝图资料 |
| `WBP_OrionBrowserShowcase` | 承载一个 Orion WebUI 控件，将其事件转交所属控制器 |
| `DA_OrionBrowserShowcase` | 定位本地 `Showcase` App，关闭开发服务器 |
| `BP_OrionEnergyCell` | 接收已校验的世界交互，要求控制器收集其唯一 `CellId` |
| `BP_OrionTerminal` | 要求控制器提交三个已收集的能量单元 |
| `DA_StationCell`、`DA_StationTerminal` | 启用世界交互并声明允许的动作 |
| `WBP_OrionWebsite` | 独立 Orion Browser，包含加载、错误、重试、返回和关闭控件 |
| `T_StationEmblem` | 原创纹理，通过 Native Surface 和运行时图片请求两种方式显示 |
| `RT_StationCapture` | 通过 `station.capture` Native Surface 显示的渲染目标 |
| `S_StationHover`、`S_StationClick` | 控件声音策略使用的原创合成 UE 音效 |

关卡仅引用插件示例资产和引擎资产，不依赖私有游戏框架或工程 C++ Presenter。

## 蓝图流程

`BeginPlay → InitializeProfile → SetupUI` 创建控件、绑定 WorldUI、添加界面并发布资料。已有存档恢复偏好与任务进度；首次资料根据系统语言选择简体中文或英文。

网页在 Bridge 和显示生命周期就绪后发送 `station.ready`。导航、设置、语言、物品选择、开始、返回、重置和官网访问使用带 JSON `action` 字段的 `station.action`。`HandleWebEvent` 解析事件，`HandleAction` 校验接受的值；`PublishState` 递增 `stateRevision`，通过 retained latest 事件发送 `ue:station.stateChanged`。Vue 完成 DOM 更新后，网页确认已提交的版本。

能量单元的身份来自实例可编辑的 `CellId`：`cell1`、`cell2`、`cell3`。重复收集同一个单元不会再次发放物品。`RefreshWorldLabels` 更新语言、隐藏已收集 Actor，并刷新终端和出口。`Deposit` 要求任务已开始、尚未完成且已收集三个单元，满足条件才完成任务。网页不能直接修改这些状态。

世界按钮发送 `world.interact`。插件检查当前 World、有效组件、允许动作、可见性、距离及交互代次后，才广播 `OnInteraction`。能量单元和终端蓝图仍负责决定游戏操作是否允许执行。

导航保存在控制器有容量限制的 `PageStack` 蓝图数组中，返回时恢复上一页面。重置任务只清理任务进度，保留语言、音量和显示偏好，并重新打开当前关卡。

`PublishState` 使用 UE 音效资产和已保存音量构造示例控件声音策略，网页控件使用命名为 `Station` 的声音上下文。展厅页面的虚幻展室将徽记纹理和场景捕获绑定为 Native Surface，并通过 `RequestTextureResource` 请求运行时图片；完成事件发布 `ue:station.image`。关闭宿主时释放纹理请求、Native Surface 和活动声音策略。可以在相应事件图中查看接线，并按自己的页面生命周期调整。

## 键盘与世界输入

在已开始任务的世界页面使用 **WASD** 移动。**E** 激活当前聚焦的可见 WorldUI 控件，或最靠近屏幕中心的可见控件；原生 WorldUI 仍检查身份、可见性与交互距离。**I** 打开或返回背包。**P** 打开菜单或返回上一页；宿主将按键交给游戏时，**Escape** 也作为界面返回键。Unreal Editor 可能把 Escape 保留为停止游玩，因此 PIE 中使用 P，并在 Standalone 或成品游戏中验收 Escape。

示例 PlayerController 会先消费自己的键盘快捷键，避免 E 同时触发引擎 SpectatorPawn 的竖直移动。网页键盘处理会防止重复的默认分发，按情况忽略重复及组合输入，并将文字编辑留给输入框。菜单页面阻止 Pawn 移动和视角输入，网页控件继续正常工作。

在菜单页面，方向键把焦点移到该方向上最近的控件。按键会先交给当前聚焦的控件，所以滑块先改变数值、一排页签先切换选中项，然后焦点才离开。**Ctrl+K** 打开命令搜索，搜索按钮也能打开它；其中列出每个页面、每个展室、各套主题与背景以及常用操作，中英文都可以搜索。由蓝图处理的手柄命令通过 `ue:station.input` 到达页面。

## 修改界面

网页源码位于插件 `Content/UI/WebUI/Showcase/src`，生产文件位于 `Content/UI/WebUI/Showcase/dist`。

| `src` 下的路径 | 内容 |
| --- | --- |
| `App.vue` | 外壳：桥接监听、生命周期、导航表面、键盘与手柄输入。其中字面量的 `state` 对象就是预览种子 |
| `state.ts`、`text.ts` | 蓝图发布的状态结构；中英文字典 |
| `appearance.ts` | 主题与背景：写到根元素上，保存在本地存储里，或者跟随宿主状态 |
| `pages/`、`rooms/` | 五个页面和十个展室 |
| `components/`、`motion/`、`styles/` | 控件、它们共用的弹簧引擎与帧循环，以及四套主题的设计变量 |
| `reel/` | “One shape” 循环：时间线和纯函数 `seek(t)` 渲染器 |
| `scene/` | three.js 楼阁和背包物品视图。`scene/space/` 是透明舞台，以及宇宙、性能两个展室画在上面的内容：太阳系、星系、黑洞和小行星带 |
| `shell/` | 命令搜索、确认对话框、任务 HUD、焦点导航、WorldUI 卡片，以及没有宿主的浏览器在页面背后显示的替身场景 |
| `preview.ts` | 没有宿主的浏览器使用的示例状态 |

`webui-preview.json` 登记二十四种设计视图：每个页面、每个展室、任务 HUD、任务完成、中文、手柄提示、减弱动效、三套主题和两种背景。手柄视图像 Unreal 一样，用宿主事件发送输入设备和按键提示。WebUI Studio 的替身宿主不应答 `station.action`，所以在 Studio 里由页面自己模拟导航和偏好；在游戏中只有蓝图能改变状态。预览不能代替游戏测试。

`src/assets` 中的影片和配乐是生成的，不是录制的。`tools/make_soundtrack.py` 用 NumPy 合成配乐。加上 `--song` 时改用你自己的曲目：测出速度、节拍网格和强拍，从强拍处截取七小节，并校准到 120 BPM。`tools/render_film.mjs` 把循环打包成一个自包含的 1440 × 1440 HTML 文件，再用 Playwright 渲染：先每拍出一帧（`--beats`），然后每帧渲染四个子帧，由 FFmpeg 混合并编码。两者都不属于构建流程，Playwright 也不是应用的依赖，只在修改循环之后运行；所需环境和命令写在各文件开头。

将 `WBP_OrionBrowserShowcase` 作为可编辑接线示例，创建自己的 AppDefinition 和控件。同步修改 AppId 与事件名称，并将状态结构、允许操作和蓝图合同一起交给 AI。做法见[教程 1：用 AI 制作界面](tutorial-1-ai.zh-CN.md)，接线本身的逐步说明见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md)。

官网使用独立的通用浏览器控件，不是本地 Showcase 文档，也不接收空间站业务 Bridge 和状态事件。

## 渲染预算

独立示例通过工程 `Config/DefaultGameUserSettings.ini` 将初始游戏帧率上限设为 60，为浏览器绘制、场景捕获和游戏留出 GPU 时间。这是示例工程的偏好设置；安装插件不会修改其他工程的帧率上限。已有用户保存的设置优先于这个默认值。

在自己的纯蓝图游戏中，可用 Unreal 的 **Get Game User Settings → Set Frame Rate Limit → Apply Non-Resolution Settings** 选择适合的帧率上限，仅在玩家确认偏好时保存，并在目标硬件验证。不限帧游戏占满 GPU 时，即使原生游戏状态仍变化，浏览器的 GPU 回读也可能停滞。应降低游戏渲染负载或选择可持续的帧率上限；只降低浏览器帧率目标不一定能解决 GPU 争用。

展厅的性能展室可以用来在自己的硬件上试这件事：它有意加重页面的 GPU 和脚本负担，一次只动一项设置。

## 验证状态

发行验收报告分别记录资产创建与蓝图编译、真实 Unreal 会话、Development／Shipping 包体运行、实体手柄及中文输入法。请以对应构建的报告为准，不要将 Studio 预览截图理解为其他环境已通过。
