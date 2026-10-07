# 纯蓝图工程的第一个界面

使用启用 OrionBrowser、Helper 已准备好的 UE 5.8 空白蓝图工程。工程无需自己的 C++ 模块；插件自身包含原生模块。

## 显示内置页面

1. 内容浏览器启用**显示插件内容**。
2. 打开 `OrionBrowser/Showcase/WBP_OrionBrowserShowcase`。其中 WebUI 是普通 UMG **Orion WebUI** 控件。
3. 控件使用 `DA_OrionBrowserShowcase`，App Id 为 `Showcase`，关闭 **Use Dev Server in Editor**。生产资源随插件保存在 `WebUIApps/Showcase/dist`。
4. 打开展示关卡并运行，查看蓝图事件如何接收网页意图、更新 Unreal 状态并回传页面。

内置 Showcase 控件会将事件转交 BP_OrionStationController。要在另一个关卡原样运行此示例，在 World Settings 中指定 BP_OrionStationGameMode，由示例控制器创建界面并持有状态。接入自己的游戏时，按下方步骤创建宿主并将事件接到自己的控制器；只向无关控制器添加原样的 Showcase 控件，不会初始化空间站状态。

自己的宿主可在 BeginPlay 中用拥有它的 Player Controller 创建，再 Add to Viewport。菜单打开时显示鼠标，设置 **Set Input Mode Game and UI**；关闭菜单时恢复游戏输入模式。不要每帧重新创建 Widget。

## 创建本地 App

1. 在工程中新建 **User Widget** 蓝图。Designer 中添加 **Orion WebUI** 子控件，命名为 `WebUI`，启用 **Is Variable**，使其填满父插槽。
2. 创建 **OrionWebUIAppDefinition** 类型的 Data Asset。设置唯一 AppId，例如 `MyPanel`；EntryHtml 为 `index.html`；离线生产页面关闭 **Use Dev Server in Editor**。
3. 把构建完成的网页放入工程 `Content/UI/WebUI/MyPanel/dist`。资源均位于该目录内，使用相对 URL。工程内同名 App 优先于插件自带 App。
4. 把定义资产赋给 WebUI 子控件，或以该资产调用一次 **Load App**。
5. 把宿主 Widget 加入视口，根据需要连接 **On Web Ready**、**On Web Event**、**On Web Request** 与 **On Web Error**。

## 网页意图 → 蓝图 → 状态回显

网页先取得插件 Bridge，注册 `ue:myPanel.state` 监听，再发送 `myPanel.ready`。用户点击控件时，通过 `api.emit("myPanel.select", { itemId: "energy" })` 提交意图。完整 TypeScript 写法见[英文同页](blueprint-quick-start.md)。

在 WebUI 子控件的 **On Web Event** 中：

1. 按 `Event Name` 分支，仅接受当前 App 定义的事件。
2. 使用 **Get Json String** 读取 `Payload Json` 中的 `itemId`，检查 `Valid`。
3. 检查物品存在、用户允许选择、目标仍然有效，通过后才更新蓝图状态。
4. 从 `{}` 开始，用 **Set Json String / Number / Boolean** 构造完整状态。节点会正确转义用户文本，不要手工拼接用户输入为 JSON。
5. 在同一个 WebUI 上调用 **Post Retained Latest Event to Web**，事件名 `ue:myPanel.state`，发送完整 JSON，并携带递增的 `stateRevision`。Retained 事件会在网页监听注册后重放最近状态。

需要操作结果和错误时，网页使用 `api.call`，蓝图处理 **On Web Request**，通过 Response Handle **Resolve** JSON 结果或 **Reject** 错误码与信息。每个请求只完成一次，Unreal 接受业务操作之后才能报告成功。

JSON 节点接受对象输入，长度最多为 1,048,576 个 UTF-16 代码单元（Unreal 字符串长度）。字段缺失、类型错误或 JSON 无效时 `Valid=false`。Setter 的空来源创建新对象；无效来源保持原样并返回失败。

## 生命周期

先注册网页监听，再发送 ready 意图；Unreal 就绪后发布完整初始状态。通用生命周期使用随插件提供的控制器，以及蓝图 **Set Presentation Lifecycle State**，参考示例接线。业务状态版本与界面展示版本分开维护。

页面被覆盖时暂停自己的工作和输入；恢复时使用当前状态。销毁页面时解除监听、Observer、Three.js 资源和 WorldUI 宿主绑定。自己创建的定时器及外部订阅仍须显式清理。

输入、音效、图片和世界空间交互见[接口说明](interfaces.zh-CN.md)。
