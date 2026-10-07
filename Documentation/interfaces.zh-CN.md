# 蓝图与网页接口

UObject 接口及蓝图回调在游戏线程执行，浏览器在自己的子进程中运行。JavaScript 调用返回不表示游戏状态已经同步改变。`OrionWebUIWidget` 承载本地 App，`OrionBrowserWidget` 是不附带 App 业务 Bridge 的通用浏览器。

## 消息

| 网页操作 | 蓝图入口 | 用途 |
| --- | --- | --- |
| `api.emit(name, payload)` | WebUI **On Web Event**：EventName、PayloadJson | 异步操作意图 |
| `api.call(name, payload)` | **On Web Request**：Request、Response | 请求结果，由蓝图完成或拒绝 |
| `api.on(name, listener)` | **Post Event to Web** 或 **Post Retained Latest Event to Web** | 接收 Unreal 状态 |
| `api.stateCommitted(revision)` | 内置状态回执 | 表示消费了状态版本，不授权业务操作 |

用 **Get Json String/Number/Boolean** 读取字段，**Set Json String/Number/Boolean** 构造对象，并检查 `Valid`。Unreal 侧检查参数范围、Id、权限和目标生命周期。需要时以请求 Id / 状态版本拒绝重复或过期业务请求。不要把正式库存保存到网页 `localStorage`。

插件处理内置资源与生命周期通信，不要另写传输层或用定时器轮询就绪。先注册监听，再提交初始意图；卸载页面时解除监听。

## 输入与页面生命周期

使用 UMG 焦点与适当的 Player Controller 输入模式。CommonUI 工程可以使用插件页面栈接入。网页保持 button、input、select、label 等标准语义；网页禁用动作时，Unreal 处理函数也必须检查禁用条件。稳定控件 Id 用于焦点、音效和自动化，不随语言变化。

共享 `installCommonActionRouter` 处理 Unreal 发送的公共动作。必须真正配置输入映射并发送动作；网页显示“手柄”标签不能证明手柄已经接入。文本框保留选择与输入法行为，不把输入法 composition 当作游戏按键，不在组合输入中途抢走焦点。

用 **Set Presentation Lifecycle State** 表达准备、可见、覆盖暂停、关闭、销毁或失败。持久游戏状态放在页面实例之外。页面隐藏时停止自己的动画循环，销毁时释放 Three.js 几何体、材质、控制器、Observer 和 renderer。

## 声音与资源

- **控件音效**：在 WebUI 宿主上以拥有者 UObject 和 Context Id 激活 Control Sound Policy，设置默认悬停/点击音及单控件覆盖。网页调用 `playControlSound(controlId, interaction)`。拥有者离开时解除策略。策略中的 UE 声音引用保证 Cook 能发现资源。
- **文字与字体**：可以使用随网页生产产物提供的本地字体，或 UE Font Manifest。后者引用 Font Face 资产和稳定 CSS 字体名。保留字体许可。Text Catalog 将稳定 Key 映射到 FText；示例也展示由蓝图持有文化设置、网页使用本地双语字典投影的方式。
- **静态图片**：使用 App 相对 URL。Asset Manifest 将稳定 Id 映射到 UE 纹理或材质预览，并保留可 Cook 的资产引用。
- **运行时图片**：使用插件 Runtime Image 资源，页面退出时释放对应所有权。不要每帧把整张图片编码进 JSON。
- **场景捕获和持续变化的纹理**：蓝图调用 **Set Native Surface Texture** 绑定纹理或 Render Target；网页以同一个 Surface Id 调用 `api.bindNativeSurface(id, element)`。DOM 元素控制位置，不再使用时清除绑定。
- **Three.js**：库及素材都随产物提供，处理可见性、尺寸变化和销毁。GPU/浏览器能力需要在实际目标机器验收。

Control Sound 的 Definition、Style、Override 与 Policy 结构体支持蓝图 Make／Set Members 节点。音量变化时，用经过校验的音量构造悬停与点击声音定义，放入 Style 和 Policy，再为同一个拥有者重新激活策略。如果注册了 `Station` 等具名 Context，网页应调用 `playControlSound(controlId, interaction, "Station")`；省略 Context 时只会选择未命名的默认策略。

## WorldUI 交互

1. Actor 添加 **Orion Web UI World Element Component**，配置 World Element Definition、Element Key 和锚点偏移。
2. Definition 启用 `Interactive`，列出 `AllowedActions`，设置 `MaxInteractionDistance`，`0` 表示任意可见距离。默认不开启交互。
3. 通过 JSON Payload 提供文字和视觉状态；不可用目标调用 `Set Element Visible(false)`。
4. 在拥有者 LocalPlayer 的 **OrionWebUIWorldSubsystem** 调用 **Bind Overlay Widget**，传入实际 WebUI 子控件，也可绑定已有 InstantScreen endpoint。每个本地玩家只有一个宿主。
5. 网页挂载现有 `OrionWorldOverlayDOM`。默认交互渲染器使用 payload 的 `label`、`actionLabel` 和允许动作创建按钮。
6. 蓝图处理组件 **On Interaction**，取得本地 Player Controller、动作 Id、JSON。由游戏权威批准库存/任务变化，再发布新状态。
7. 宿主退出时解绑。隐藏元素、销毁组件、旧 World 和旧文档代次不能解析到当前有效目标。

子系统分发前检查注册关系、World、玩家可见性、投影可见性、允许动作与距离。这是本地展示验证；多人游戏仍需通过合适的服务器请求完成业务权限校验。

## 远程网站

使用单独的 **Orion Browser** 控件打开 `https://orionue.com`，通过 **On Load Started / Completed / Error** 实现加载和错误界面。可调用 **Go Back / Forward / Reload / Stop Load**。不要向远程页面暴露游戏对象或业务请求处理器；断网不应阻止本地菜单运行。
