---
name: orion-webui-creation
description: "使用 OrionBrowser 1.0.0 创建或修改 Unreal WebUI：连接蓝图或 C++ 状态、网页意图、预览、输入、资源和 WorldUI。英文版本见 SKILL.en.md。"
---

# OrionBrowser 界面制作

适用 UE 5.8 / Win64，默认 `DefaultWebUIRenderMode=LegacyTexture`。插件根目录以 `OrionBrowser.uplugin` 定位，工程根目录以 `.uproject` 定位。插件可以装在工程外，不把本机目录写入产物。宿主当前指令、测试授权和构建入口优先。

## 状态与边界

- Unreal 侧蓝图或 C++ 拥有游戏状态、库存、设置、存档和业务权限；网页显示快照并提交意图。纯蓝图工程不需要额外游戏 C++ Presenter。
- 复用 OrionWebUIWidget、AppDefinition、Bridge、现有生命周期与资源接口。多个本地玩家分别拥有宿主，不共享可变游戏状态或 WorldUI 目标身份。
- 网页先注册状态监听，再发送 ready。Unreal 发布带递增 stateRevision 的完整状态；网页消费后回执。业务版本与展示版本独立，网页回执不推进业务成功。
- 本地 App 使用稳定 Id。工程生产资源位于 `<ProjectRoot>/Content/UI/WebUI/AppId/dist`，插件示例位于 `<OrionBrowser>/Content/UI/WebUI/AppId/dist`，AppDefinition 的 Id 必须一致。
- 远程网页使用独立 Orion Browser，不连接游戏业务 Bridge。

## 按需求实施

1. 先确认状态权威、允许动作、参数和错误处理，再编写控件。一般 UMG 区域使用 Orion WebUI，已有 CommonUI 页面栈时复用它的输入与覆盖恢复流程。
2. 用随插件的 Showcase Vue/TypeScript/Vite 工程作为可读参考。复制到自己的 App 后更新 Id、事件前缀、稳定控件 Id 和导入路径。新建或复制 WebUI/App 目录时，安装依赖前在目录根创建或补全 `.gitignore`，排除 `node_modules`、Node/Vite 缓存、日志和 TypeScript 增量文件；复制时不带这些本地产物。保留源码、`package.json`、`package-lock.json` 与运行/打包所需的 `dist`，规则模板见 [Web App 脚手架](references/web-app-scaffold.zh-CN.md)。
3. 纯蓝图通过 On Web Event/Request 接收操作，JSON Getter/Setter 检查 Valid，再做业务校验；使用 Post Retained Latest Event to Web 发布状态。需要结果的请求通过 Response Handle 完成或拒绝一次。
4. 页面保持标准按钮、输入框与标签语义；禁用动作在 Unreal 再次校验。键鼠、手柄和输入法分别验证，不用显示设备标签代替输入接线。
5. 静态资源本地打包，字体保留许可证。控件音效走 UE 策略；持续变化纹理/场景捕获走 Native Surface；其他运行时图片使用插件资源接口。隐藏时暂停循环，销毁时解除订阅和释放 GPU 资源。
6. WorldUI 使用 Element Component 与 Definition 的可选交互。只处理当前有效、可见、允许动作和距离内的目标；业务权限仍由 Unreal 校验。退出时解绑本地玩家宿主。
7. 同步 webui-preview.json 的每个页面、语言及关键状态视图。简单示例可让 Studio 静态读取 App.vue 顶层纯字面量 state，这样首次预览 dist 不需要源码执行或缓存。使用预览工厂的复杂 App，先完成 source 预览生成匹配缓存，再预览 dist；不要伪造 ready 或关闭初始状态提交要求。
8. 安装锁定依赖、类型检查、构建 dist，按宿主规定编译受影响消费者。测试按当前授权执行，区分浏览器/Studio、Unreal、打包和实际设备证据。

## 需要细节时阅读

- [蓝图与 C++ 接入教程](../../Documentation/tutorial-3-blueprint-and-cpp.zh-CN.md)
- [AI 制作流程与提示词](../../Documentation/tutorial-1-ai.zh-CN.md)、[WebUIStudio 教程](../../Documentation/tutorial-2-webui-studio.zh-CN.md)
- [从零建 App，以及通信、输入、音效、字体、图片与 WorldUI](../../Documentation/tutorial-4-write-by-hand.zh-CN.md)
- [打包和故障排查](../../Documentation/packaging.zh-CN.md)

资产只通过 Unreal 正式接口创建、编译和精确保存，不以文本或二进制编辑器修改 uasset/umap。交付写明实际保存的资产、事件合同、运行检查和未验证项；不把设计稿或静态检查当作运行成功。
