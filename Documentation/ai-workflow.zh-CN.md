# 使用 AI 与 WebUIStudio 制作界面

从插件 `WebUIApps/Showcase` 的 Vue / TypeScript / Vite 源码开始。插件已提供生产 `dist`，在 Unreal 中打开内置页面不需要启动开发服务器。

## 制作闭环

1. 通过 Unreal 工具栏启动 WebUIStudio，按提示选择 `.uproject`。工具以当前 Windows 用户运行，工作数据放在工程 `Saved` 中。
2. 选择示例 App，查看页面与预览状态。App 在 `package.json` 的 `orionWebUI` 中声明 Id，`webui-preview.json` 登记视图及其状态覆盖值。
3. 创建工程自己的 App 时，将源码复制到工程 `Content/UI/WebUI/MyPanel`。修改 `name`、`orionWebUI.appId`、`interfaceName`、事件前缀和控件 Id；按实际插件位置调整相对导入。不要复制 `node_modules`、缓存，也不要以示例旧 `dist` 代替新源码构建。
4. 给 AI 提供[随插件分发的 Skill](../Skills/orion-webui-creation/SKILL.md)、状态结构、允许的操作、蓝图处理函数，以及视觉要求。要求 AI 保留 Bridge 与生命周期合同。
5. 在 App 目录安装锁文件对应依赖、类型检查、构建。示例命令为 `npm ci`、`npm run typecheck`、`npm run build`。通过 Studio 使用随工具提供的制作运行时；独立终端可使用兼容的 Node/npm。依赖固定版本，离线内容不引用远程 CDN。
6. 用 Studio 检查各页面和翻译，再在 Unreal 中核对真实输入、蓝图状态、音效、图片及 WorldUI。浏览器预览不代表原生接入验收。
7. 关闭 **Use Dev Server in Editor** 后 Unreal 使用 `dist`；Editor 可自动重载稳定变化的本地生产入口。发行网页资源变化后，需要重新打包游戏。

## 提示词示例

> 为 OrionBrowser 1.0.0 制作中英双语背包，使用 Vue/TypeScript 和插件现有 Bridge、生命周期控制器。Unreal 蓝图拥有库存和设置。监听 `ue:inventory.state`，结构为 `{stateRevision,culture,items,selectedItemId}`；选择物品时只发送 `inventory.select`，参数 `{itemId}`。不要在 JavaScript 中发放物品。保留稳定控件 Id、手柄焦点、键盘操作、禁用状态与资源清理。字体、图片和 three.js 都打包到本地。每个页面和弹窗都登记到 `webui-preview.json`。交付源码、对应的蓝图事件接线清单和生产构建。

明确允许哪些动作及如何处理错误。AI 生成的网页仍是应用代码，在允许它调用原生能力前需要审查。远程网站放入独立的 **Orion Browser** 控件，不接入游戏业务 Bridge。

## 预览合同

示例在 `src/App.vue` 中使用字面量 `reactive` 对象声明初始状态，Studio 因而可以直接发现首次生产预览所需的种子，无需事先生成源码预览缓存。根目录 `webui-preview.json` 为每个视图登记状态覆盖值；`src/preview.ts` 提供独立设计预览的回退数据。复杂 App 也可以声明无必填参数的预览状态工厂，此时先运行 Source 预览，为生产预览准备状态。预览状态只是设计用数据，不写正式库存、不调用生产服务。增加页面时同时更新状态类型和预览目录。

插件安装在工程外时，先解析真实插件目录，再设置网页导入与脚本位置。运行时会读取已启用插件的实际路径；自己构建配置中写死的工程 `Plugins` 路径不会自动适配。
