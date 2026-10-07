# 猎户空间站示例

示例是一座包含三个能量单元和 WorldUI 终端的小型离线空间站。库存、任务进度和持久偏好由 Unreal 蓝图持有；网页显示状态并提交操作请求。

## 打开示例

在内容浏览器启用 **Show Plugin Content**，打开 `/OrionBrowser/Showcase/L_OrionBrowserOverview`，等待配套工具准备完成后运行 Play。独立 `OrionBrowserTemplate` 工程以自己的 `/Game/OrionStation/L_OrionStation` 为默认关卡，并复用插件示例资产；工程没有自己的 C++ 游戏模块。

示例使用插件默认的 `LegacyTexture`。官网访问需要联网，空间站界面、本地字体和 three.js 几何体使用本地生产文件。

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

`PublishState` 使用 UE 音效资产和已保存音量构造示例控件声音策略，网页控件使用命名为 `Station` 的声音上下文。实验室将徽记纹理和场景捕获绑定为 Native Surface，并通过 `RequestTextureResource` 请求运行时图片；完成事件发布 `ue:station.image`。关闭宿主时释放纹理请求、Native Surface 和活动声音策略。可以在相应事件图中查看接线，并按自己的页面生命周期调整。

## 修改界面

网页源码位于插件 `WebUIApps/Showcase/src`，生产文件位于 `WebUIApps/Showcase/dist`。`state.ts` 定义网页状态及中英文字典，`webui-preview.json` 登记八种设计视图。预览不能代替游戏测试。

将 `WBP_OrionBrowserShowcase` 作为可编辑接线示例，创建自己的 AppDefinition 和控件。同步修改 AppId 与事件名称，并将状态结构、允许操作和蓝图合同一起交给 AI。完整步骤见 [AI 制作流程](ai-workflow.zh-CN.md)。

官网使用独立的通用浏览器控件，不是本地 Showcase 文档，也不接收空间站业务 Bridge 和状态事件。

## 验证状态

发行验收报告分别记录资产创建与蓝图编译、真实 Unreal 会话、Development／Shipping 包体运行、实体手柄及中文输入法。请以对应构建的报告为准，不要将 Studio 预览截图理解为其他环境已通过。
