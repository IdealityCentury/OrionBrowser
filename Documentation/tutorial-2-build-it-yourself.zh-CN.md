# 教程 2：自己动手做界面

不借助 AI，从一个空目录开始：写网页、构建、放进 Unreal、接上通信，再逐项用上输入、声音、文字、图片、WorldUI 和远程网站。本教程覆盖 OrionBrowser 的全部操作，每一节都可以单独查阅。

[English](tutorial-2-build-it-yourself.md) · [手册目录](README.zh-CN.md) · 让 AI 来写见[教程 1](tutorial-1-ai.zh-CN.md)，Unreal 侧的蓝图与 C++ 写法见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md)，预览工具见[教程 4](tutorial-4-webui-studio.zh-CN.md)。

## 它是怎样工作的

```text
蓝图 / C++ ──── 状态（事件） ────▶ 网页（HTML / CSS / JavaScript）
     ▲                              │
     └──── 操作（emit / call） ──────┘
```

- 网页在独立的浏览器进程（Helper）里运行，画面合成到一个 UMG 控件上。页面背景透明时，下面的游戏画面会透出来。
- 本地页面的地址固定为 `https://orion-webui.local/<AppId>/index.html`，文件来自 `Content/UI/WebUI/<AppId>/dist`。不需要 Web 服务器，也不需要联网。
- Unreal 和网页之间只传 JSON 消息。**状态属于 Unreal**：网页把收到的状态显示出来，把玩家的操作提交回去，由 Unreal 决定接不接受。

插件提供三种控件：

| 控件 | 用途 |
| --- | --- |
| **Orion WebUI** | 承载一个本地 App，带游戏通信接口。本教程的主角 |
| **Orion Browser** | 打开远程网站，没有游戏通信接口 |
| **Orion InstantScreen** | 多个界面共用一个常驻浏览器的进阶形态，见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md#instantscreen-概览) |

## 准备

1. 完成[安装](installation.zh-CN.md)，等工具准备的通知显示完成。空白工程还要按其中的说明设置 CommonUI 视口，否则键盘和手柄路由不可用。
2. 安装 Node.js 22 或更新的 LTS 版本（自带 npm）。只有构建网页需要它，运行不需要。
3. 把插件放在工程的 `Plugins/OrionBrowser`。网页工程用相对路径引用插件的共享运行库，下面的文件都按这个布局写成；插件装在别处时，要按实际位置改写这些相对路径。
4. 先运行一次随附示例（`OrionBrowser/Showcase/L_OrionBrowserOverview`），确认环境正常。

## 第 1 部分：建一个网页 App

贯穿本教程的例子是一个设置面板：显示音量、画质和语言，可以调音量、选画质、还原默认、关闭。

### 目录

```text
<工程>/
├─ Plugins/OrionBrowser/                插件，共享运行库在 Content/UI/WebUI/Shared
└─ Content/UI/WebUI/SettingsPanel/      你的 App，目录名就是 AppId
   ├─ .gitignore
   ├─ package.json
   ├─ tsconfig.json
   ├─ vite.config.ts
   ├─ index.html
   ├─ webui-preview.json                可选，WebUIStudio 的视图清单
   ├─ src/
   │  ├─ main.ts
   │  ├─ App.vue
   │  ├─ bridge/orion-webui.ts
   │  └─ model/
   │     ├─ settings-panel-state.ts
   │     └─ settings-panel-preview.ts
   └─ dist/                             构建产物，运行和打包都读这里
```

有三个名字必须完全一致：**目录名**、`package.json` 里的 **`orionWebUI.appId`**、Unreal 里 App Definition 的 **`AppId`**。位置也不能换：工程里的 App 从 `Content/UI/WebUI/<AppId>/dist` 读取，打包也只收这里。

### .gitignore

在安装依赖之前创建，避免把依赖和缓存提交进版本库。`dist` 不要忽略，运行和打包需要它。

```gitignore
**/node_modules/
**/.npm/
**/.vite/
**/.cache/
*.tsbuildinfo
npm-debug.log*
```

### package.json

```json
{
	"private": true,
	"name": "settings-panel",
	"version": "1.0.0",
	"type": "module",
	"orionWebUI": { "appId": "SettingsPanel", "interfaceName": "settings-panel", "performanceProfile": "transactional-screen", "lifecyclePolicy": "transactional" },
	"scripts": {
		"dev": "vite --host 127.0.0.1",
		"build": "vite build",
		"test": "node ../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/scripts/test-webui-app-contract.mjs",
		"typecheck": "vue-tsc --noEmit"
	},
	"dependencies": {
		"@vitejs/plugin-vue": "^5.2.0",
		"typescript": "^5.8.0",
		"vite": "^6.3.0",
		"vue": "^3.5.0",
		"vue-tsc": "^2.2.0"
	}
}
```

| `orionWebUI` 字段 | 写法 |
| --- | --- |
| `appId` | 大写开头的英文名，与目录名一致 |
| `interfaceName` | 小写加短横线，工程内唯一。它决定构建产物的文件名 |
| `performanceProfile` / `lifecyclePolicy` | 菜单、弹窗和可交互页面用 `transactional-screen` / `transactional`。一直显示、不接收输入的 HUD 用 `continuous-passive` / `continuous-passive` |

### tsconfig.json

```json
{
	"compilerOptions": {
		"baseUrl": ".",
		"paths": { "vue": ["./node_modules/vue"] },
		"target": "ES2022",
		"useDefineForClassFields": true,
		"module": "ESNext",
		"moduleResolution": "Bundler",
		"strict": true,
		"jsx": "preserve",
		"resolveJsonModule": true,
		"isolatedModules": true,
		"noEmit": true,
		"lib": ["ES2022", "DOM", "DOM.Iterable"],
		"types": ["vite/client"]
	},
	"include": ["src/**/*.ts", "src/**/*.vue"]
}
```

`paths.vue` 不能省：插件共享运行库的源码也引用 `vue`，这一行让类型检查使用你自己 App 里安装的那一份。

### vite.config.ts

```ts
import path from "node:path";
import { fileURLToPath } from "node:url";

import vue from "@vitejs/plugin-vue";
import { defineConfig } from "vite";

import { createOrionWebUIBuildOutput, createOrionWebUIVueOptions } from "../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/vite-output-naming";

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const sharedSourceDir = path.resolve(rootDir, "../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src");
const appId = "SettingsPanel";

export default defineConfig({
	plugins: [
		vue(createOrionWebUIVueOptions(rootDir)),
		{
			name: "orion-webui-manifest",
			generateBundle() {
				this.emitFile({
					type: "asset",
					fileName: "orion-webui.manifest.json",
					source: JSON.stringify({ appId, entry: "index.html", apiVersion: "1.0.0", localOnly: true }, null, "\t") + "\n",
				});
			},
		},
	],
	base: "./",
	build: {
		outDir: path.resolve(rootDir, "dist"),
		emptyOutDir: true,
		sourcemap: false,
		...createOrionWebUIBuildOutput("settings-panel", { performanceProfile: "transactional-screen" }),
	},
	server: {
		host: "127.0.0.1",
		port: 5180,
		strictPort: false,
		fs: { allow: [rootDir, sharedSourceDir] },
	},
});
```

- `createOrionWebUIBuildOutput("settings-panel", { performanceProfile: "transactional-screen" })` 里的两个值必须是直接写出的字符串，并且与 `package.json` 一致。合同检查按文本匹配它们。
- 构建产物的文件名是固定的（`assets/index-settings-panel.js` 等），不带哈希。不要自己加 `[hash]`。
- `base: "./"` 让所有资源使用相对路径。
- 每个 App 用不同的 `server.port`。

### index.html

```html
<!doctype html>
<html lang="en">
	<head>
		<meta charset="UTF-8" />
		<meta name="viewport" content="width=device-width, initial-scale=1.0" />
		<title>Settings Panel</title>
	</head>
	<body>
		<div id="app"></div>
		<script type="module" src="/src/main.ts"></script>
	</body>
</html>
```

不要加 `<meta name="color-scheme" content="dark">`：它会把整个页面的底变成不透明的深色，游戏画面就透不出来了。

### src/bridge/orion-webui.ts

把指向插件的长路径集中在这一个文件里，其余文件只从这里导入。

```ts
export type { OrionWebUIApi } from "../../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/bridge/orion-webui";
export { installCommonActionRouter, resolveOrionWebUIForMount } from "../../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/bridge/orion-webui";
export { type OrionWebUILifecycleController, createOrionWebUILifecycle } from "../../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/runtime/orion-webui-lifecycle";
export { createOrionWebUIApp, ensureOrionWebUIFontStylesheet } from "../../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/instant-screen/orion-instant-screen-vue";
```

### src/main.ts

```ts
import App from "./App.vue";
import { createOrionWebUIApp, ensureOrionWebUIFontStylesheet, resolveOrionWebUIForMount } from "./bridge/orion-webui";

ensureOrionWebUIFontStylesheet("SettingsPanel");

async function mountSettingsPanel(): Promise<void> {
	const api = await resolveOrionWebUIForMount();
	createOrionWebUIApp(App, { api }).mount("#app");
}

void mountSettingsPanel().catch((error: unknown) => {
	console.error("SettingsPanel failed to connect to the Orion WebUI host bridge.", error);
});
```

`resolveOrionWebUIForMount()` 在 Unreal 里会等到通信接口装好再返回它；在普通浏览器和 UMG Designer 里立即返回 `undefined`。“有没有宿主”只看这个返回值。

### src/model

```ts
// src/model/settings-panel-state.ts
export type Quality = "low" | "medium" | "high";

export interface SettingsPanelState {
	stateRevision: number;
	volume: number;
	quality: Quality;
	culture: string;
}
```

```ts
// src/model/settings-panel-preview.ts
import type { SettingsPanelState } from "./settings-panel-state";

export function createSettingsPanelPreviewState(): SettingsPanelState {
	return { stateRevision: 1, volume: 80, quality: "high", culture: "en" };
}
```

预览数据放在单独的模块里，没有宿主时才加载。导出名里同时含有 `preview` 和 `state`，WebUIStudio 才能找到它。

### src/App.vue

```vue
<template>
	<main ref="rootElement" class="settings">
		<header class="settings__header">
			<h1>{{ text.title }}</h1>
			<button type="button" data-orion-control-id="settings-close" @click="close">{{ text.close }}</button>
		</header>

		<label class="settings__row" for="settings-volume">
			<span>{{ text.volume }}</span>
			<output>{{ volumeDraft }}</output>
		</label>
		<input
			id="settings-volume"
			v-model.number="volumeDraft"
			type="range"
			min="0"
			max="100"
			step="1"
			data-orion-control-id="settings-volume"
			@change="setVolume"
		/>

		<div class="settings__row" role="group" :aria-label="text.quality">
			<span>{{ text.quality }}</span>
			<button
				v-for="option in qualityOptions"
				:key="option"
				type="button"
				data-orion-control-id="settings-quality"
				:aria-pressed="state.quality === option"
				@click="setQuality(option)"
			>{{ text[option] }}</button>
		</div>

		<footer class="settings__footer">
			<button type="button" data-orion-control-id="settings-reset" :disabled="resetting" @click="resetDefaults">{{ text.reset }}</button>
			<p role="status">{{ notice }}</p>
		</footer>
	</main>
</template>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { type OrionWebUIApi, type OrionWebUILifecycleController, createOrionWebUILifecycle, installCommonActionRouter } from "./bridge/orion-webui";
import type { Quality, SettingsPanelState } from "./model/settings-panel-state";

const dictionary = {
	"en": { title: "Settings", volume: "Volume", quality: "Quality", low: "Low", medium: "Medium", high: "High", reset: "Restore defaults", close: "Close", restored: "Defaults restored." },
	"zh-Hans": { title: "设置", volume: "音量", quality: "画质", low: "低", medium: "中", high: "高", reset: "还原默认", close: "关闭", restored: "已还原默认设置。" },
} as const;
const qualityOptions: readonly Quality[] = ["low", "medium", "high"];

const props = defineProps<{ api?: OrionWebUIApi }>();
const rootElement = ref<HTMLElement | null>(null);
const state = reactive<SettingsPanelState>({ stateRevision: 0, volume: 0, quality: "medium", culture: "en" });
const volumeDraft = ref(0);
const resetting = ref(false);
const notice = ref("");
const text = computed(() => dictionary[state.culture === "zh-Hans" ? "zh-Hans" : "en"]);
const releases: Array<() => void> = [];
let lifecycle: OrionWebUILifecycleController | null = null;
let disposed = false;

function applyState(next: SettingsPanelState): void {
	if (next.stateRevision <= state.stateRevision) {
		return;
	}
	Object.assign(state, next);
	volumeDraft.value = state.volume;
	void nextTick(() => props.api?.stateCommitted(state.stateRevision).catch(report));
}

function report(error: unknown): void {
	notice.value = error instanceof Error ? error.message : String(error);
}

function setVolume(): void {
	props.api?.emit("settingsPanel.setVolume", { volume: volumeDraft.value }).catch(report);
}

function setQuality(quality: Quality): void {
	props.api?.emit("settingsPanel.setQuality", { quality }).catch(report);
}

function close(): void {
	props.api?.emit("settingsPanel.close", {}).catch(report);
}

async function resetDefaults(): Promise<void> {
	if (!props.api || resetting.value) {
		return;
	}
	resetting.value = true;
	try {
		await props.api.call("settingsPanel.resetDefaults", {});
		notice.value = text.value.restored;
	} catch (error) {
		report(error);
	} finally {
		resetting.value = false;
	}
}

onMounted(async () => {
	const root = rootElement.value;
	if (!root) {
		return;
	}
	const api = props.api;
	if (!api) {
		const preview = await import("./model/settings-panel-preview");
		applyState(preview.createSettingsPanelPreviewState());
		root.dataset.orionPresentation = "active";
		return;
	}

	releases.push(api.on<SettingsPanelState>("ue:settingsPanel.state", applyState));
	releases.push(installCommonActionRouter(api, root));
	lifecycle = createOrionWebUILifecycle({ api, root });
	const bootstrap = await lifecycle.initialize().catch((error: unknown) => {
		if (error instanceof Error && error.name === "AbortError") {
			return null;
		}
		throw error;
	});
	if (!bootstrap || disposed) {
		return;
	}
	await api.emit("settingsPanel.ready", {}).catch(report);
});

onBeforeUnmount(() => {
	disposed = true;
	lifecycle?.dispose();
	lifecycle = null;
	for (const release of releases.splice(0)) {
		release();
	}
});
</script>

<style scoped>
:global(html), :global(body), :global(#app) {
	width: 100%;
	height: 100%;
	margin: 0;
	overflow: hidden;
	background: transparent;
}

.settings {
	position: absolute;
	top: 50%;
	left: 50%;
	width: 520px;
	padding: 28px;
	transform: translate(-50%, -50%);
	color: #f2f4f8;
	background: rgba(12, 16, 24, 0.86);
	border: 1px solid rgba(255, 255, 255, 0.16);
	font-family: var(--orion-webui-body-font-family, var(--orion-webui-font-family, sans-serif));
	opacity: 0;
	pointer-events: none;
}

.settings[data-orion-presentation="entering"],
.settings[data-orion-presentation="active"] {
	opacity: 1;
}

.settings[data-orion-presentation="active"] {
	pointer-events: auto;
}

.settings__header,
.settings__row,
.settings__footer {
	display: flex;
	align-items: center;
	gap: 12px;
	margin-bottom: 16px;
}

.settings__header h1 {
	flex: 1;
	margin: 0;
	font-size: 28px;
}

.settings__row span {
	flex: 1;
}

input[type="range"] {
	width: 100%;
	margin-bottom: 20px;
}

button {
	padding: 8px 16px;
	color: inherit;
	background: rgba(255, 255, 255, 0.08);
	border: 1px solid rgba(255, 255, 255, 0.24);
	font: inherit;
}

button:hover,
button:focus-visible,
button[aria-pressed="true"] {
	background: rgba(255, 170, 60, 0.28);
	border-color: #ffaa3c;
	outline: none;
}

button:disabled {
	opacity: 0.4;
}
</style>
```

这个文件里值得记住的写法：

- **先监听，再就绪。** 先用 `api.on` 注册状态监听，再创建生命周期并 `initialize()`，最后发 `settingsPanel.ready`。
- **状态整份覆盖。** `applyState` 丢弃版本不更新的状态，然后整份写入，并在界面更新后调用 `stateCommitted` 回执。
- **界面跟随状态。** 滑块显示的是 `volumeDraft`，每次收到状态都被重置为 Unreal 的值。玩家拖到一个 Unreal 不接受的数值，下一份状态一到，滑块就回到真实数值。
- **每个调用都处理失败。** `emit` 和 `call` 都返回 Promise，被拒绝时要接住。
- **没有宿主时显示预览数据。** `api` 为空的分支里动态加载预览模块，并把根元素标为 `active`。
- **根元素由显示阶段控制可见性。** 默认 `opacity: 0`、不接收指针，`entering` 和 `active` 阶段才可见，`active` 才能点击。不要用 `display: none` 隐藏根元素。

### 安装、检查、构建

在 App 目录里运行：

```powershell
npm.cmd install          # 第一次：安装依赖并生成 package-lock.json。之后改用 npm.cmd ci
npm.cmd run typecheck    # 类型检查
npm.cmd test             # App 合同检查
npm.cmd run build        # 生成 dist
```

| 命令 | 通过的标志 |
| --- | --- |
| `typecheck` | 没有输出错误。如果只打印了帮助信息，说明当前目录没有 `tsconfig.json`，不算通过 |
| `test` | 打印 `Validated SettingsPanel WebUI app contract.` |
| `build` | `dist/index.html`、`dist/orion-webui.manifest.json`、`dist/assets/index-settings-panel.js` 和 `.css` 生成 |

类型检查和构建互不代替：Vite 构建时不做类型检查。`package-lock.json` 要提交进版本库。

### 在浏览器里看

```powershell
npm.cmd run dev
```

打开终端里显示的地址。这时没有 Unreal，页面走“没有宿主”的分支，显示预览数据。控制台里会有一条字体样式表加载失败的信息：那个地址只在 Unreal 里存在，可以忽略。

## 第 2 部分：放进 Unreal

### App Definition 全部属性

内容浏览器里右键，**Miscellaneous → Data Asset**，类选 `OrionWebUIAppDefinition`。最少只需要填 `AppId`。

| 属性 | 默认值 | 说明 |
| --- | --- | --- |
| `AppId` | `Sample` | 与目录名一致 |
| `InitialRoute` | 空 | 初始路由，加载时追加为 `#/<路由>` |
| `EntryHtml` | `index.html` | `dist` 内的入口文件 |
| `bUseDevServerInEditor` | 开 | 只影响 UMG Designer：本机开发服务器连得上时加载它，否则加载 `dist` |
| `DevServerUrl` | `http://127.0.0.1:5173/` | 只接受本机地址。改成你 `vite.config.ts` 里的端口 |
| `bAutoReloadLocalDistInEditor` | 开 | 编辑器里 `dist/index.html` 变化并稳定后自动重载页面 |
| `DesignTimeBrowserFrameRate` | 30 | 只用于 Designer |
| `DesignTimeBrowserRenderScale` | 1.0 | 只用于 Designer |
| `TextCatalog` | 空 | 文字表，见[文字与语言](#文字与语言) |
| `FontManifest` | 空 | 留空使用工程设置里的全局字体清单 |
| `bOverrideFontPolicy` / `FontPolicyOverride` | 关 | 只给这个 App 换一套正文与标题字体规则 |
| `AssetManifest` | 空 | Unreal 贴图与材质预览的清单 |
| `SoundManifest` | 空 | 业务声音的清单 |
| `bAllowWebSoundPlayback` | 开 | 关闭后网页的 `playSound` 一律被拒绝 |
| `bPreloadSoundsOnLoad` | 开 | 加载页面时预加载声音清单里的资产 |
| `RequiredApiVersion` | `1.0.0` | 通信接口的版本。保持默认值；网页构建会把同一个值作为 `apiVersion` 写进 `orion-webui.manifest.json` |
| `BridgeReadyTimeoutSeconds` | 60 | 等待页面完成握手的时间，`0` 表示不限 |
| `BridgeCallTimeoutSeconds` | 15 | 请求与延后应答的超时，`0` 表示不限 |
| `MaxQueuedBridgeMessages` | 128 | 页面就绪之前最多暂存的消息数 |
| `CursorPolicy` | `GameControlled` | 鼠标指针由游戏还是由页面控制 |
| `BrowserFrameRate` | 0 | 保持 `0`，使用全局帧率策略 |
| `BrowserRenderScale` | 0 | `0` 使用全局默认。调高只增加清晰度和开销，不改变布局 |
| `ViewportSizingMode` | `SlateLogicalSize` | 页面按 UMG 的逻辑尺寸排版，UMG 缩放不会引起网页重排。保持默认 |
| `AllowedFrameOrigins` / `AllowedImageOrigins` / `AllowedMediaOrigins` | 空 | 允许页面嵌入的外部来源，见[安全](#第-10-部分安全) |
| `bSupportsTransparency` | 开 | 页面透明处透出游戏画面 |
| `bRetainBrowserSessionAcrossSlateRebuilds` | 关 | 控件重建 Slate 时保留已加载的页面 |
| `StrictFullIRPresentationFrameFenceTimeoutSeconds` | 60 | 只在 FullIR 渲染模式下使用 |

### Orion WebUI 控件属性

| 属性 | 默认值 | 说明 |
| --- | --- | --- |
| **App Definition** | 空 | 要加载的 App |
| `InitialRouteOverride` | 空 | 覆盖 App Definition 的初始路由，同一个 App 可以在不同控件里打开不同页面 |
| `bLoadOnConstruct` | 开 | 控件构造时自动加载。关闭后由 **Load App** 触发 |
| `bAutoResolveUnhandledRequests` | 开 | 没人应答的请求自动以 `{}` 成功。见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md#6-需要结果的请求on-web-request) |
| `NativeSurfaceBindings` | 空 | 静态配置的原生画面绑定 |
| **Show Design Time Preview** | 开 | 在 Designer 里显示真实页面 |
| **Design Time Control Id Preview Mode** | **Hovered Control** | 在 Designer 里显示控件 Id |

### 显示、输入模式与焦点

1. 新建 Widget 蓝图，放入 **Orion WebUI**（控件面板里搜索 `Orion`），命名为 `WebUI`，勾选 **Is Variable**，铺满父级，指定 App Definition。
2. 在 Player Controller 里 **Create Widget**、**Add to Viewport**。
3. **Set Input Mode Game And UI**：**Player Controller** 接 `Self`（空着时这个节点不起作用），把 `WebUI` 接到 **In Widget to Focus**；**Set Show Mouse Cursor** 设为 `true`。
4. 关闭时 **Remove from Parent**，恢复 **Set Input Mode Game Only**（**Player Controller** 同样要接）并隐藏鼠标。

接收操作和发布状态的蓝图见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md#纯蓝图从零接入)。

### 在 UMG Designer 里预览

**Orion WebUI** 控件在 Designer 里直接渲染真实页面，不用点 Play。

| 看到的文字 | 含义 |
| --- | --- |
| `Preparing OrionBrowser tools...` | 工具还在准备，完成后自动刷新 |
| `Orion WebUI AppDefinition is not set.` | 没有指定 App Definition |
| `Orion WebUI dist entry is missing: <路径>` | 没有构建，或 `AppId` 与目录名不一致 |

边改源码边看：在 App 目录运行 `npm run dev`，把 App Definition 的 **Dev Server Url** 改成对应端口（例如 `http://127.0.0.1:5180/`），保持 **Use Dev Server in Editor** 勾选。Designer 打开之后才启动服务器时，编译一次 Widget 蓝图刷新预览。

Designer 预览只是设计用画面：

- 页面地址带 `?orionDesignPreview=1`，没有通信接口，蓝图事件图不执行。页面必须能用自己的预览数据显示，否则是空白。
- 开发服务器只在 Designer 里使用。PIE 和成品游戏永远加载 `dist`，所以 PIE 之前要 `npm run build`。
- Designer 只探测端口通不通，不检查对面是不是这个 App。端口被别的 App 占用时会显示错误的页面。
- **Design Time Control Id Preview Mode** 默认是 **Hovered Control**，鼠标指到哪个控件就显示它的 Id；设为 **All Controls** 会给每个控件都标出 Id，红框并标着 `ControlId: <missing>` 表示缺 Id；**Hidden** 关闭提示。

**Orion InstantScreen** 控件在 **Orion InstantScreen | Editor** 下有同类设置，其中帧率与渲染缩放填 `0` 时沿用 App Definition 的值。

### dist 从哪里读

1. App Definition 资产所在内容根下的 `UI/WebUI/<AppId>/dist`。资产在工程里就是工程 `Content`，资产在某个插件里就是那个插件的 `Content`。
2. 工程 `Content/UI/WebUI/<AppId>/dist`。

编辑器运行期间重新构建，页面会在 `dist/index.html` 稳定后自动重载（Designer 和 PIE 都生效，日志里有 `after stable local dist entry change`）。成品游戏没有这个机制。

## 第 3 部分：网页与 Unreal 通信

### 接口一览

| 网页 | Unreal | 用途 |
| --- | --- | --- |
| `api.emit(name, payload)` | **On Web Event** | 提交一个操作，不需要结果 |
| `api.call(name, payload)` | **On Web Request** | 需要结果或错误。蓝图 **Resolve Json** 时 Promise 成功，**Reject** 时失败，错误码在 `error.code` |
| `api.on(name, handler)` | **Post Event to Web**、**Post Latest Event to Web**、**Post Retained Latest Event to Web** | 接收 Unreal 发来的事件。返回取消监听的函数 |
| `api.handle(name, handler)` | **Call Web**、**On Web Call Completed** | 应答 Unreal 发起的调用 |
| `api.stateCommitted(revision)` | 以 `__orion.stateCommitted` 到达 **On Web Event**，不需要处理 | 回执“这一版状态已经显示”。不代表业务成功 |
| `api.routeChanged(route)` | **On Route Changed** | 页面内路由变化 |
| `api.playSound(id, options)` | App Definition 的 **Sound Manifest** | 播放业务声音 |
| `api.playControlSound(id, "hover" \| "click", contextId)` | 控件音效策略 | 没有 DOM 事件的交互区域手动上报 |
| `api.bindNativeSurface(id, element)` | **Set Native Surface Texture / Material** | 把 Unreal 画面放到页面的某个位置 |

`requestIntent` 只存在于 InstantScreen 页面。普通控件承载的页面用 `emit` 和 `call`。

### 启动顺序

1. `main.ts` 用 `resolveOrionWebUIForMount()` 取得 `api`，传给根组件。
2. 根组件注册状态监听和其他事件监听，保存返回的取消函数。
3. `createOrionWebUILifecycle({ api, root })`，然后 `await lifecycle.initialize()`。
4. 发出自己的就绪事件（`settingsPanel.ready`）。
5. 卸载时 `lifecycle.dispose()`，再逐个调用取消函数。

不要自己用定时器轮询 `window.OrionWebUI`，不要另写传输层。

### 状态

- Unreal 每次发布**完整状态**，带一个只增不减的 `stateRevision`。网页丢弃版本不更新的状态，整份覆盖。
- 网页不保存游戏事实。玩家的进度、库存、设置不要写进 `localStorage`。只属于页面自己的偏好（例如页面主题）可以。
- 用 **Post Retained Latest Event to Web** 发布：页面之后才注册监听也能收到最近的一条。
- 不在页面里“先当作成功，稍后再同步”。操作提交之后，界面等下一份状态。

### 操作

- 事件名用“前缀加动作”的形式，例如 `settingsPanel.setVolume`，前缀在工程内唯一。
- 事件名在调用处直接写字符串，不要拼接。
- 参数是普通对象。Unreal 侧会重新检查每个字段。
- 需要知道结果时用 `call`。被拒绝时 `error.code` 是 Unreal 给的错误码；超时是 `E_TIMEOUT`。Unreal 没有应答的请求默认以 `{}` 成功返回；只有取消了控件的 **Auto Resolve Unhandled Requests**，它才以 `E_UNHANDLED` 失败。

### Unreal 调用网页

```ts
releases.push(api.handle("settingsPanel.measure", () => {
	return { width: rootElement.value?.offsetWidth ?? 0 };
}));
```

蓝图对 `WebUI` 调用 **Call Web**（`Name` 填 `settingsPanel.measure`），结果从 **On Web Call Completed** 回来。每个名字只能注册一个处理函数；没有注册时 Unreal 收到 `E_NOT_FOUND`。只用它查询显示层面的信息。

### 内置事件

| 事件 | 何时收到 | 内容 |
| --- | --- | --- |
| `ue:bootstrap` | 通信建立后 | `appId`、`apiVersion`、`route`、`localization`、`assets`、`sounds`、`fonts` |
| `ue:localeChanged` | 语言切换 | 新的文字表 `{ culture, texts }` |
| `ue:inputModeChanged` | 输入设备变化（CommonUI 页面） | `{ inputType, gamepadName }` |
| `ue:inputPromptsChanged` | 按键提示变化（CommonUI 页面） | `{ inputType, gamepadName, actions[] }` |
| `ue:commonAction` | CommonUI 动作触发 | `{ actionId, inputType, gamepadName }` |
| `ue:backAction` | CommonUI 返回键 | `{ inputType, gamepadName }` |
| `ue:webUI.lifecycleChanged` | 蓝图调用 **Set Presentation Lifecycle State** | 由生命周期控制器处理，页面不需要自己监听 |

前四个和 `ue:webUI.lifecycleChanged` 是保留事件：监听注册得晚也会立即收到最近的一条。

### 显示阶段

生命周期控制器在根元素上写 `data-orion-presentation`，页面据此决定该做什么：

| 阶段 | 含义 | 页面该做什么 |
| --- | --- | --- |
| `preparing` | 正在准备，还没显示 | 可以排版、应用状态、解码图片。不播放动画，不启动帧循环 |
| `entering` | 即将显示 | 根元素已是最终样式 |
| `active` | 正在显示 | 可以交互，可以播放动画。帧循环和 WebGL 在这之后才启动 |
| `covered` | 被别的界面盖住 | 保留内容，停止帧循环、定时器和 WebGL |
| `suspended` | 被挂起或已释放 | 同上，并清掉本地的显示状态 |
| `closing` / `failed` | 正在关闭 / 出错 | 不再交互 |

蓝图不调用 **Set Presentation Lifecycle State** 时，页面在就绪后自动进入 `active`。自己的工作需要跟着显示开始和停止时，给 `createOrionWebUILifecycle` 传回调：

```ts
lifecycle = createOrionWebUILifecycle({
	api,
	root,
	onPresentationRequested: () => {
		startLoops();
		return nextTick();
	},
	onPresentationSuspended: () => {
		stopLoops();
	},
});
```

这两个回调跟随的是显示请求。CommonUI 宿主（`OrionWebUIActivatableWidget`）每次激活时发一次显示请求，停用时挂起页面；`onPresentationRequested` 返回的 Promise 完成后，或者宿主自己的超时到了，它才把页面露出来。普通控件上的 **Set Presentation Lifecycle State** 只改变阶段，不会调用这两个回调。这时直接跟随阶段本身：CSS 里用 `[data-orion-presentation="active"]`，脚本里用 `MutationObserver` 监听根元素的这个属性。

进场动画写在同时匹配 `entering` 和 `active` 的选择器上；只写在 `entering` 上的动画会在阶段切换时被取消。

## 第 4 部分：页面写法规则

| 规则 | 原因 |
| --- | --- |
| `html`、`body`、`#app` 背景透明、`overflow: hidden` | 页面叠在游戏画面上 |
| 不用 `backdrop-filter`、`mix-blend-mode` | 页面背后的游戏画面不在页面里，无法模糊或混合。合同检查会拒绝 |
| 不写 `prefers-reduced-motion` | 是否减弱动效由 Unreal 的状态决定，不读系统设置。合同检查会拒绝 |
| 每个 `<img>` 写 `decoding="async"` | 合同检查会拒绝缺少它的标签。把它写在任何取值含 `>` 的属性之前 |
| 构建产物文件名不带哈希 | `dist` 通常随工程提交，文件名固定才能看出内容变化 |
| 脚本、样式、字体都来自 App 自己 | 页面的内容安全策略不允许内联脚本和远程脚本；离线也要能运行 |
| 固定构图的界面按设计分辨率搭一个舞台，整体等比缩放 | 游戏界面不做网页式的窄屏重排 |
| 页面不写 `user-select: none` | 插件默认禁止选中文字；需要可选时在元素上写 `data-orion-user-select="text"` 或 `"all"`。输入框始终可选 |
| 右键菜单自己实现 | **Orion WebUI** 始终屏蔽浏览器原生菜单。监听 `contextmenu` 并 `preventDefault()` |
| 本地视频读入内存后用 Blob 地址播放 | 本地文件不支持范围请求，直接播放不能拖动进度。使用 WebM（VP9 与 Opus）等内置 Chromium 能解码的格式 |
| 重的模块（three.js 等）用动态 `import()`，进场完成后再初始化 | 提前初始化会让进场卡顿 |

### 控件 Id

每个可点击的元素都要有一个**直接写出的** `data-orion-control-id`：

- 只用字母、数字、`.`、`_`、`-`，以字母或数字开头，最长 128 个字符。
- 不用 `:data-orion-control-id="表达式"`，不拼接变量。
- 列表里同一类条目共用一个 Id；条目自己的业务编号放进操作的参数里。
- 禁用用表达式写（`:disabled="..."`），等待中用 `aria-busy="true"`。只用样式类表示禁用的控件仍然会发出声音。

控件 Id 用于音效、Designer 里的检查和自动化，不随语言变化。

### data-orion-* 属性速查

| 属性 | 取值 | 作用 |
| --- | --- | --- |
| `data-orion-control-id` | 稳定的字面量 | 控件身份 |
| `data-orion-action` | 动作 Id | CommonUI 动作触发时，聚焦并点击这个元素 |
| `data-orion-sound-context` | 上下文名 | 这个区域内的控件音效路由到同名策略 |
| `data-orion-sound-policy` | `none`、`manual`、`custom` | 这个元素及其后代不自动发出悬停和点击声 |
| `data-orion-user-select` | `text`、`all` | 允许选中文字 |
| `data-orion-font-policy` | `body`、`heading`、`none` | 强制正文或标题字体；`none` 表示这一块用页面自己的字体声明 |
| `data-orion-presentation` | 由插件写入 | 当前显示阶段，见上文 |

## 第 5 部分：输入

- **鼠标与触控**：页面像普通网页一样收到指针事件。
- **键盘**：`WebUI` 获得焦点后，页面收到键盘事件。使用标准的 `button`、`input`、`select`、`label`，它们自带键盘操作。
- **输入法**：文本框保留正常的选择与输入法行为。处理按键时遇到 `event.isComposing` 直接返回，不要在组合输入中途抢走焦点。
- **手柄**：有两种做法。普通控件由蓝图处理手柄输入，再把命令作为事件发给页面，随附示例用的是这种（`ue:station.input`）。CommonUI 页面在 **Input Manifest** 里登记动作，触发时页面收到 `ue:commonAction`；页面调用过 `installCommonActionRouter(api, root)` 后，带有 `data-orion-action="<动作 Id>"` 的元素会被聚焦并点击，禁用的元素会被跳过。
- **按键提示**：监听 `ue:inputModeChanged` 和 `ue:inputPromptsChanged`，按当前设备显示按键名或图标。页面上写着“手柄”不等于手柄已经接通，要用真手柄试。
- **拖拽、长按、旋转**：用共享运行库的 `createOrionPointerSession()`（`Shared/src/input/orion-pointer-session.ts`），不要自己在 `window` 上挂移动和抬起监听。页面被盖住或挂起时，它会自动取消进行中的拖拽。
- **鼠标指针**：App Definition 的 `CursorPolicy` 为 `GameControlled` 时指针样式由游戏决定，`PageControlled` 时由页面的 CSS 决定。
- **方向键移动焦点**：共享运行库不提供，需要自己实现。随附示例的做法在 `Showcase/src/shell/focus.ts`。

## 第 6 部分：声音、文字、字体与图片

### 声音

**控件的悬停与点击声**由 Unreal 播放，网页不写代码：带有 `data-orion-control-id` 的元素，以及 `button`、`a[href]`、`input`、`select`、`textarea`、`summary`、`[role="button"]`，在指针移入、获得焦点和点击时自动上报。蓝图侧的策略配置见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md#控件音效)。

**有业务含义的声音**由网页请求：

```ts
await api.playSound("settings.saved", { volumeMultiplier: 0.8 });
```

声音 Id 对应 App Definition 里 **Sound Manifest** 的 `StableId`。失败时的错误码：`E_SOUND_DISABLED`（App 关闭了网页声音）、`E_INVALID_ARG`、`E_SOUND_UNAVAILABLE`（清单里没有，或条目被禁用）。

两条通道不要叠加：已经有自动点击声的按钮，不要再用 `playSound` 播一遍。自己播声音的区域写上 `data-orion-sound-policy="manual"`。不要在页面里加载和播放音频文件来做界面音效。

### 文字与语言

- **简单做法**：Unreal 在状态里发布语言（本教程的 `culture`），页面用自己的字典显示。
- **Text Catalog**：在 Unreal 里建 `OrionWebUITextCatalog`，把稳定的 Key 映射到 Unreal 文本，指定给 App Definition。页面这样用：

```ts
import { type OrionLocalizationTable, translate } from "../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/bridge/orion-webui";

const table = ref<OrionLocalizationTable>({ culture: "", texts: {} });
releases.push(api.on<OrionLocalizationTable>("ue:localeChanged", (next) => { table.value = next; }));
const bootstrap = await lifecycle.initialize();
table.value = bootstrap.localization;
// 模板里：{{ translate(table, "settingsPanel.title", "Settings") }}
```

换语言时替换同一个元素里的文字，不要为每种语言各放一个元素，也不要靠重新加载页面来切换。

### 字体

| 做法 | 步骤 |
| --- | --- |
| 字体随 App 打包 | 把字体文件放进 `src/assets`，在 CSS 里用 `@font-face` 声明，并在使用它的区域写 `data-orion-font-policy="none"`。保留字体许可文件 |
| 使用 Unreal 的字体资产 | 建 `OrionWebUIFontManifest` 数据资产，在 **Entries** 里登记 Font Face 资产和 CSS 字体名。在 **Project Settings → Game → Orion WebUI Font** 的 `SystemFontManifest` 指定它，所有 App 共用；或者只指定给某个 App Definition 的 `FontManifest` |

使用 Unreal 字体时，`main.ts` 里的 `ensureOrionWebUIFontStylesheet("<AppId>")` 负责挂载字体样式表，CSS 里用变量取字体：

```css
font-family: var(--orion-webui-body-font-family, var(--orion-webui-font-family, sans-serif));
```

标题把第一个变量换成 `--orion-webui-heading-font-family`。插件会按字号自动给文字分配正文或标题字体，分界由字体清单 `FontPolicy` 里的 `HeadingFontSizeThresholdPx` 决定，默认 24 像素。只有同一策略的 `HeadingFontCulturePrefixes` 里列出的语言才使用标题字体；这个列表为空时，所有字号都用正文字体。

### 图片

| 图片来源 | 做法 |
| --- | --- |
| 界面自带的静态图 | 放进 App 的 `src/assets`，用相对路径或 `import` 引用，推荐 WebP |
| Unreal 的贴图或材质预览（固定的一批） | `OrionWebUIAssetManifest` 里登记 `StableId` 与贴图或材质，指定给 App Definition。页面从 `bootstrap.assets` 里按 `id` 取 `url`。贴图的地址在运行时生成。材质预览是一张缩略图，要先在编辑器里导出：调用 `OrionWebUIEditorLibrary` 的 `ExportWebUIAssets`（用 Editor Utility 蓝图或编辑器 Python），然后保存清单资产。图片写在 `dist` 里，所以每次网页构建之后要重新导出；导出之前，材质的 `url` 是空的 |
| 运行时才知道的贴图（头像、生成的图标） | 蓝图 **Request Texture Resource**，就绪后把地址放进状态，见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md#运行时图片) |
| 持续变化的画面（场景捕获、视频、动态材质） | Native Surface，见下 |

不要把图片编码成 Base64 塞进状态，也不要每帧通过消息传图。

### 实时画面：Native Surface

页面里放一个占位元素，Unreal 把画面直接画在它的位置上：

```vue
<script setup lang="ts">
import OrionNativeSurface from "../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/components/OrionNativeSurface.vue";
</script>

<template>
	<div class="capture-frame">
		<OrionNativeSurface surface-id="station.capture" class="capture-anchor" />
	</div>
</template>
```

不用组件时：`const release = api.bindNativeSurface("station.capture", element)`，卸载时调用 `release()`。

- `surface-id` 与蓝图 **Set Native Surface Texture** 的 `Surface Id` 逐字一致。
- 位置和大小就是占位元素的位置和大小。支持平移、缩放、不透明度和祖先元素的裁剪；不支持旋转、倾斜和圆角裁剪。
- 默认画在网页上方，会盖住占位元素里的网页内容。边框画在外层容器上。
- 原生画面不接收鼠标。一个页面最多 512 个绑定；列表里的大量图标用运行时图片。

## 第 7 部分：WorldUI

把跟随 Actor 的标签、血条和交互按钮画在同一个页面里。页面里挂一个覆盖层组件：

```vue
<script setup lang="ts">
import { ref } from "vue";
import OrionWorldOverlayDOM from "../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/components/OrionWorldOverlayDOM.vue";

const worldOverlay = ref<InstanceType<typeof OrionWorldOverlayDOM> | null>(null);
</script>

<template>
	<OrionWorldOverlayDOM ref="worldOverlay" />
</template>
```

Unreal 侧给 Actor 加 `OrionWebUIWorldElementComponent` 组件（搜索 `World Element`）、建 Definition、调用 **Bind Overlay Widget**，步骤见[教程 3](tutorial-3-blueprint-and-cpp.zh-CN.md#worldui跟随-actor-的标签与交互)。

默认的显示方式：

- Definition 开启了交互并列出了动作时：显示 `payload.label`，每个动作一个按钮，按钮文字取 `payload.actionLabel`。点击后插件检查目标仍然有效、可见、动作被允许，再触发组件的 **On Interaction**。
- 否则显示一条血条，读取 `payload.health`、`payload.maxHealth`、`payload.label`、`payload.color`。

想画成自己的样子，按 Definition 的 `ElementType` 注册渲染函数：

```ts
worldOverlay.value?.registerRenderer("StationCell", ({ container, element }) => {
	container.textContent = String(element.payload.label ?? element.key);
});
```

全局预算（每个玩家最多显示多少个、刷新率、遮挡检测数量）在工程 `Config/DefaultGame.ini` 的 `[/Script/OrionWebUIWorldWidget.OrionWebUIWorldSettings]` 里调整，例如 `MaxVisibleElements=512`。

## 第 8 部分：远程网站

外部网站用 **Orion Browser** 控件，单独放在一个 Widget 里：

1. 放入 **Orion Browser**，在 **Initial URL** 填地址，或运行时调用 **Load URL**。
2. 用 **On Load Started**、**On Load Completed**、**On Load Error** 做加载中、完成和失败三种画面，失败画面给一个重试按钮（**Reload**）。
3. **Go Back**、**Go Forward**、**Stop Load** 做导航按钮。

远程页面拿不到游戏通信接口，也不要想办法给它。断网只影响这个控件。Designer 里它只显示占位文字。

## 第 9 部分：多页面与路由

一个 App 可以包含多个页面，用地址里的 `#/<路由>` 区分：

- App Definition 的 `InitialRoute` 是默认路由。
- 同一个 App 在不同控件里打开不同页面：设置控件的 `InitialRouteOverride`，或调用 **Set Initial Route Override**。
- 页面内切换路由后调用 `api.routeChanged("<路由>")`，蓝图的 **On Route Changed** 会收到，**Get Current Route** 返回当前值。
- 各路由的组件用动态 `import()` 加载，避免打开一个页面时加载全部页面的代码。

## 第 10 部分：安全

- 页面只能在自己的 App 地址下导航。跳到别处会被拦截，并通过 **On Web Error** 报告 `Blocked Orion WebUI top-level navigation: <地址>`。
- 页面的内容安全策略默认只允许加载 App 自己的脚本、样式、字体、图片和媒体。要嵌入外部内容时，在 App Definition 里填写精确的来源（只写来源，不写路径，不用通配符）：`AllowedFrameOrigins` 给 `<iframe>`，`AllowedImageOrigins` 给图片，`AllowedMediaOrigins` 给音视频。三者互不通用。
- 网页是应用代码，但它发来的任何内容都要当作不可信输入：在 Unreal 里检查类型、范围、对象是否仍然存在、玩家是否有权这样做。
- 不要把密钥、令牌写进页面或状态。
- 联网游戏里，网页的操作到了客户端的 Unreal 之后，仍要通过你自己的服务器请求完成权限校验。

## 第 11 部分：性能与配置

写页面时：

- 页面不处于 `active` 阶段时停止自己的帧循环、定时器和 WebGL。
- 每帧都在变的数据不要用 **Post Event to Web** 每帧发；持续变化的画面用 Native Surface。
- 游戏不限帧并且占满 GPU 时，浏览器的画面更新会被挤掉。给游戏设一个可持续的帧率上限（**Get Game User Settings → Set Frame Rate Limit → Apply Non Resolution Settings**）比调低浏览器帧率更有效。

工程 `Config/DefaultEngine.ini` 的 `[OrionBrowser]` 段里常用的设置：

| 键 | 默认值 | 作用 |
| --- | --- | --- |
| `DefaultWebUIRenderMode` | `LegacyTexture` | 渲染模式。保持默认；这是当前支持的模式 |
| `bEnabled` | `True` | 设为 `False` 时不创建任何浏览器 |
| `bUseAdaptiveFrameRate` | `True` | 浏览器帧率跟随游戏帧率自动调整 |
| `DefaultWebUIRenderScale` | `1.0` | App Definition 的 `BrowserRenderScale` 为 `0` 时使用 |
| `MaxWebUIRenderScale` | `2.0` | 渲染缩放的上限 |
| `HiddenBrowserFrameRate` | `0` | 隐藏的浏览器的帧率 |
| `bCacheWebUIStaticResources` | `True` | 在内存里缓存 `dist` 文件 |
| `bEnableCEFFileLogging` | `True` | 把浏览器日志写到 `Saved/Logs/cef3.log`（Shipping 中关闭） |

运行时图片的预算在 `[OrionWebUI.RuntimeImage]` 段，例如 `MaxOutputDimension=2048`、`RequestTimeoutSeconds=15`。

## 第 12 部分：调试

| 手段 | 用法 |
| --- | --- |
| **On Web Error** | 接到 **Print String**。通信错误、被拦截的导航、资源准备失败都从这里出来 |
| Output Log | 过滤 `LogOrionWebUIWidget`（控件）、`LogOrionWebUI`（资源与地址）、`LogOrionBrowser`（浏览器）、`LogOrionBrowserPreparation`（工具准备） |
| 浏览器日志 | `Saved/Logs/cef3.log` |
| 网页开发者工具 | 用启动参数 `-cefdebug=9222` 打开 Chromium 的远程调试端口，再用 Chrome 连接这个端口检查页面 |
| **Execute Javascript for Debug** | 在页面里执行一段脚本，只用于调试 |
| 诊断浮层 | 控制台命令 `OrionBrowser.Debug.Enable 1` 和 `OrionBrowser.Debug.Overlay 1`，显示帧率、内存和每个 App 的状态；`OrionBrowser.Debug.Dump` 写入日志。Shipping 中不可用 |
| 蓝图诊断 | **Orion Browser \| Diagnostics** 分类下的 **Set Diagnostics Enabled**、**Get Diagnostics Snapshot** 等节点 |
| **Get Readiness Snapshot** | 一次读出浏览器是否创建、通信是否就绪、本地资源是否就绪 |
| 编辑器校验 | 编辑器工具蓝图里调用 `ValidateWebUIAppDefinition`，返回 App Definition 的配置问题列表 |

页面自己的 `console.log` 不会出现在 Output Log 里，用开发者工具或 WebUIStudio 的日志页看。

## 第 13 部分：检查与交付

每次修改后按顺序做：

1. `npm.cmd run typecheck`、`npm.cmd test`、`npm.cmd run build`。
2. 在 [WebUIStudio](tutorial-4-webui-studio.zh-CN.md) 或浏览器里看每个视图。
3. 在 UMG Designer 里确认页面能加载，并核对控件 Id 齐全（WebUIStudio 的“检查”页签，或 Designer 里的控件 Id 预览）。
4. 在 PIE 里实际操作：鼠标、键盘、手柄、输入法、两种语言、声音、反复打开关闭。
5. [打包](packaging.zh-CN.md)后在成品游戏里再走一遍。打包前必须先有最新的 `dist`。

每一层只证明它自己：浏览器里正常不代表 Unreal 里正常，PIE 里正常不代表包里有文件。

## 排查

| 现象 | 检查 |
| --- | --- |
| 构建报 `requires package.json orionWebUI appId, interfaceName, ...` | `package.json` 的四个字段与 `vite.config.ts` 里的两个值不一致 |
| 构建报 `must bundle the shared presentation transaction ...` | 页面没有使用 `createOrionWebUILifecycle` |
| 构建报 `component is outside the supported source directories` | `.vue` 文件既不在存放各个 App 的目录（App 目录的上一级）之下，也不在插件的 `Shared` 目录里 |
| `npm test` 报缺少 `decoding="async"` | 给 `<img>` 补上。已经写了还报错时，把它移到标签的最前面：检查只读到标签里的第一个 `>` 为止 |
| 页面在 Unreal 里空白 | 三个名字是否一致；是否构建；看 **On Web Error** |
| 页面在 Designer 里空白、PIE 里正常 | 页面没有“没有宿主”时的预览分支 |
| 浏览器里正常、Unreal 里整屏不透明 | `index.html` 加了 `color-scheme`，或根元素有不透明背景 |
| 点击没有反应 | 根元素是否处于 `active` 阶段；事件名两边是否一致 |
| 状态不更新 | 版本号是否递增；监听是否在 `ready` 之前注册 |
| 开发服务器改了端口后 Designer 显示旧页面 | **Dev Server Url** 没有同步，或端口被别的 App 占用 |
| 改了源码，PIE 里没变化 | PIE 读的是 `dist`，重新 `npm run build` |
| 外部图片、视频、网页被拦截 | 在 App Definition 的三个 `Allowed...Origins` 里填精确来源 |
