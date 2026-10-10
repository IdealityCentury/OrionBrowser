# Tutorial 2: Build it yourself

No AI: start from an empty folder, write the page, build it, put it in Unreal, connect the two sides, and then use input, sound, text, images, WorldUI and remote websites one by one. This tutorial covers every OrionBrowser operation, and each part can be read on its own.

[简体中文](tutorial-2-build-it-yourself.zh-CN.md) · [Manual index](README.md) · To let AI write the page, see [Tutorial 1](tutorial-1-ai.md). For the Unreal side in Blueprint and C++, see [Tutorial 3](tutorial-3-blueprint-and-cpp.md). For the preview tool, see [Tutorial 4](tutorial-4-webui-studio.md).

## How it works

```text
Blueprint / C++ ──── state (events) ────▶ Page (HTML / CSS / JavaScript)
       ▲                                   │
       └──── actions (emit / call) ────────┘
```

- The page runs in a separate browser process (Helper), and its picture is composited onto a UMG widget. Where the page is transparent, the game shows through.
- A local page always has the address `https://orion-webui.local/<AppId>/index.html`, and its files come from `Content/UI/WebUI/<AppId>/dist`. No web server and no network are needed.
- Unreal and the page exchange only JSON messages. **Unreal owns the state**: the page renders the state it receives and submits what the player does; Unreal decides whether to accept it.

The plugin provides three widgets:

| Widget | Purpose |
| --- | --- |
| **Orion WebUI** | Hosts one local app with the game bridge. The subject of this tutorial |
| **Orion Browser** | Opens a remote website; it has no game bridge |
| **Orion InstantScreen** | An advanced form in which several interfaces share one resident browser; see [Tutorial 3](tutorial-3-blueprint-and-cpp.md#instantscreen-overview) |

## Prepare

1. Complete [installation](installation.md) and wait until the tool preparation notification reports completion. In a blank project, also set the CommonUI viewport as described there; without it, keyboard and gamepad routing do not work.
2. Install Node.js 22 or a newer LTS release (npm is included). Only building the page needs it; running does not.
3. Put the plugin in the project's `Plugins/OrionBrowser`. Web projects import the plugin's shared runtime by relative path, and the files below are written for this layout. If the plugin is installed elsewhere, rewrite those relative paths for its actual location.
4. Run the supplied sample once (`OrionBrowser/Showcase/L_OrionBrowserOverview`) to confirm that the environment works.

## Part 1: Create a web app

The example used throughout is a settings panel: it shows volume, quality and language, and lets the player change the volume, choose the quality, restore defaults and close the panel.

### Folders

```text
<Project>/
├─ Plugins/OrionBrowser/                the plugin; its shared runtime is in Content/UI/WebUI/Shared
└─ Content/UI/WebUI/SettingsPanel/      your app; the folder name is the AppId
   ├─ .gitignore
   ├─ package.json
   ├─ tsconfig.json
   ├─ vite.config.ts
   ├─ index.html
   ├─ webui-preview.json                optional: the view list for WebUIStudio
   ├─ src/
   │  ├─ main.ts
   │  ├─ App.vue
   │  ├─ bridge/orion-webui.ts
   │  └─ model/
   │     ├─ settings-panel-state.ts
   │     └─ settings-panel-preview.ts
   └─ dist/                             build output; running and packaging read it
```

Three names must be identical: the **folder name**, **`orionWebUI.appId`** in `package.json`, and **`AppId`** of the App Definition in Unreal. The location is fixed too: an app of the project is read from `Content/UI/WebUI/<AppId>/dist`, and packaging collects only that folder.

### .gitignore

Create it before installing dependencies, so that dependencies and caches stay out of version control. Do not ignore `dist`: running and packaging need it.

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

| `orionWebUI` field | How to write it |
| --- | --- |
| `appId` | An English name starting with a capital letter, identical to the folder name |
| `interfaceName` | Lowercase with hyphens, unique in the project. It determines the file names of the build output |
| `performanceProfile` / `lifecyclePolicy` | Menus, dialogs and interactive pages use `transactional-screen` / `transactional`. A HUD that is always shown and takes no input uses `continuous-passive` / `continuous-passive` |

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

Do not omit `paths.vue`: the source of the plugin's shared runtime imports `vue` too, and this line makes the type check use the copy installed in your own app.

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

- The two values in `createOrionWebUIBuildOutput("settings-panel", { performanceProfile: "transactional-screen" })` must be written as string literals and must match `package.json`. The contract check matches them as text.
- Build output has fixed file names (`assets/index-settings-panel.js` and so on) without hashes. Do not add `[hash]`.
- `base: "./"` makes every resource use a relative path.
- Give each app a different `server.port`.

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

Do not add `<meta name="color-scheme" content="dark">`. It turns the page canvas into an opaque dark colour, and the game no longer shows through.

### src/bridge/orion-webui.ts

Keep the long paths into the plugin in this one file; every other file imports from here.

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

In Unreal, `resolveOrionWebUIForMount()` waits until the bridge is installed and returns it. In an ordinary browser and in UMG Designer it returns `undefined` at once. Whether there is a host is decided by this return value alone.

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

Preview data lives in a module of its own and is loaded only when there is no host. Because the export name contains both `preview` and `state`, WebUIStudio can find it.

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

What to remember from this file:

- **Listen first, then announce ready.** Register the state listener with `api.on`, create the lifecycle and call `initialize()`, and only then send `settingsPanel.ready`.
- **State replaces state.** `applyState` drops a state whose revision is not newer, writes the whole snapshot, and acknowledges it with `stateCommitted` after the view has updated.
- **The view follows the state.** The slider shows `volumeDraft`, which is reset to Unreal's value whenever a state arrives. If the player drags to a value Unreal does not accept, the slider returns to the real value as soon as the next state arrives.
- **Every call handles failure.** `emit` and `call` return a Promise; catch the rejection.
- **Without a host, show preview data.** The branch where `api` is missing loads the preview module dynamically and marks the root element `active`.
- **The presentation phase controls the root element's visibility.** The root starts with `opacity: 0` and no pointer input, becomes visible in `entering` and `active`, and accepts clicks only in `active`. Do not hide the root with `display: none`.

### Install, check, build

Run in the app folder:

```powershell
npm.cmd install          # first time: installs dependencies and creates package-lock.json. Use npm.cmd ci afterwards
npm.cmd run typecheck    # type check
npm.cmd test             # app contract check
npm.cmd run build        # produces dist
```

| Command | It passed when |
| --- | --- |
| `typecheck` | No error is printed. If only help text is printed, the current folder has no `tsconfig.json`; that is not a pass |
| `test` | It prints `Validated SettingsPanel WebUI app contract.` |
| `build` | `dist/index.html`, `dist/orion-webui.manifest.json`, `dist/assets/index-settings-panel.js` and `.css` exist |

The type check and the build do not replace each other: Vite does not type-check while building. Commit `package-lock.json`.

### Look at it in a browser

```powershell
npm.cmd run dev
```

Open the address printed in the terminal. There is no Unreal here, so the page takes its no-host branch and shows preview data. The console reports one failed load, the font stylesheet: that address exists only inside Unreal, and the message can be ignored.

## Part 2: Put it in Unreal

### App Definition properties

Right-click in the Content Browser, choose **Miscellaneous → Data Asset**, and pick the class `OrionWebUIAppDefinition`. Only `AppId` has to be filled in.

| Property | Default | Meaning |
| --- | --- | --- |
| `AppId` | `Sample` | Identical to the folder name |
| `InitialRoute` | empty | The initial route, appended as `#/<route>` when loading |
| `EntryHtml` | `index.html` | The entry file inside `dist` |
| `bUseDevServerInEditor` | on | Affects UMG Designer only: when the local development server is reachable it is loaded, otherwise `dist` |
| `DevServerUrl` | `http://127.0.0.1:5173/` | Local addresses only. Change it to the port in your `vite.config.ts` |
| `bAutoReloadLocalDistInEditor` | on | In the editor, reloads the page after `dist/index.html` has changed and settled |
| `DesignTimeBrowserFrameRate` | 30 | Designer only |
| `DesignTimeBrowserRenderScale` | 1.0 | Designer only |
| `TextCatalog` | empty | Text table; see [Text and language](#text-and-language) |
| `FontManifest` | empty | Empty uses the project-wide font manifest from Project Settings |
| `bOverrideFontPolicy` / `FontPolicyOverride` | off | A separate body and heading font rule for this app |
| `AssetManifest` | empty | A list of Unreal textures and material previews |
| `SoundManifest` | empty | A list of business sounds |
| `bAllowWebSoundPlayback` | on | When off, every `playSound` from the page is rejected |
| `bPreloadSoundsOnLoad` | on | Preloads the assets of the sound manifest when the page loads |
| `RequiredApiVersion` | `1.0.0` | The bridge API version. Keep the default; the web build writes the same value as `apiVersion` into `orion-webui.manifest.json` |
| `BridgeReadyTimeoutSeconds` | 60 | How long to wait for the page's handshake; `0` means no limit |
| `BridgeCallTimeoutSeconds` | 15 | Timeout for requests and deferred responses; `0` means no limit |
| `MaxQueuedBridgeMessages` | 128 | How many messages are held before the page is ready |
| `CursorPolicy` | `GameControlled` | Whether the game or the page controls the mouse cursor |
| `BrowserFrameRate` | 0 | Keep `0` to use the global frame-rate policy |
| `BrowserRenderScale` | 0 | `0` uses the global default. Raising it only adds sharpness and cost; layout does not change |
| `ViewportSizingMode` | `SlateLogicalSize` | The page lays out in UMG logical units, so UMG scaling does not reflow it. Keep the default |
| `AllowedFrameOrigins` / `AllowedImageOrigins` / `AllowedMediaOrigins` | empty | External origins the page may embed; see [Security](#part-10-security) |
| `bSupportsTransparency` | on | The game shows through where the page is transparent |
| `bRetainBrowserSessionAcrossSlateRebuilds` | off | Keeps the loaded page while the widget rebuilds its Slate |
| `StrictFullIRPresentationFrameFenceTimeoutSeconds` | 60 | Used only in the FullIR render mode |

### Orion WebUI widget properties

| Property | Default | Meaning |
| --- | --- | --- |
| **App Definition** | empty | The app to load |
| `InitialRouteOverride` | empty | Overrides the App Definition's initial route, so one app can open different pages in different widgets |
| `bLoadOnConstruct` | on | Loads when the widget is constructed. When off, **Load App** starts the load |
| `bAutoResolveUnhandledRequests` | on | A request nobody answered succeeds with `{}`. See [Tutorial 3](tutorial-3-blueprint-and-cpp.md#6-requests-that-need-a-result-on-web-request) |
| `NativeSurfaceBindings` | empty | Native surface bindings configured statically |
| **Show Design Time Preview** | on | Shows the real page in Designer |
| **Design Time Control Id Preview Mode** | **Hovered Control** | Shows control Ids in Designer |

### Show it, set the input mode, give it focus

1. Create a Widget Blueprint, add an **Orion WebUI** widget (search for `Orion` in the palette), name it `WebUI`, enable **Is Variable**, let it fill its parent, and assign the App Definition.
2. In the Player Controller, **Create Widget** and **Add to Viewport**.
3. **Set Input Mode Game And UI** with `Self` connected to **Player Controller** (the node does nothing while that pin is empty) and `WebUI` connected to **In Widget to Focus**; set **Set Show Mouse Cursor** to `true`.
4. To close: **Remove from Parent**, restore **Set Input Mode Game Only** (its **Player Controller** pin must be connected as well) and hide the cursor.

The Blueprint that receives actions and publishes state is in [Tutorial 3](tutorial-3-blueprint-and-cpp.md#blueprint-only-from-scratch).

### Preview in UMG Designer

The **Orion WebUI** widget renders the real page in Designer, without pressing Play.

| Text shown | Meaning |
| --- | --- |
| `Preparing OrionBrowser tools...` | The tools are still being prepared; it refreshes when they are ready |
| `Orion WebUI AppDefinition is not set.` | No App Definition is assigned |
| `Orion WebUI dist entry is missing: <path>` | The app was not built, or `AppId` differs from the folder name |

To see source edits as you make them, run `npm run dev` in the app folder, set **Dev Server Url** of the App Definition to that port (for example `http://127.0.0.1:5180/`), and keep **Use Dev Server in Editor** enabled. If you start the server after opening Designer, compile the Widget Blueprint once to refresh the preview.

The Designer preview is a design view only:

- The page address carries `?orionDesignPreview=1`, there is no bridge, and your Blueprint graph does not run. The page must be able to show its own preview data; otherwise it is blank.
- The development server is used in Designer only. PIE and packaged games always load `dist`, so run `npm run build` before PIE.
- Designer only probes whether the port is reachable; it does not check that the other end is this app. If another app holds the port, the wrong page appears.
- **Design Time Control Id Preview Mode** defaults to **Hovered Control**, which shows the Id of the control under the pointer. **All Controls** labels every control, and a red frame labelled `ControlId: <missing>` marks a control without an Id. **Hidden** turns the labels off.

The **Orion InstantScreen** widget has the same kind of settings under **Orion InstantScreen | Editor**; a frame rate or render scale of `0` there inherits the App Definition value.

### Where dist is read from

1. `UI/WebUI/<AppId>/dist` below the content root that holds the App Definition asset: the project's `Content` for a project asset, that plugin's `Content` for an asset inside a plugin.
2. The project's `Content/UI/WebUI/<AppId>/dist`.

When you rebuild while the editor is running, the page reloads once `dist/index.html` has settled. This works in Designer and in PIE, and the log contains `after stable local dist entry change`. Packaged games have no such mechanism.

## Part 3: Messages between the page and Unreal

### The interface at a glance

| Page | Unreal | Purpose |
| --- | --- | --- |
| `api.emit(name, payload)` | **On Web Event** | Submit an action that needs no result |
| `api.call(name, payload)` | **On Web Request** | Needs a result or an error. The Promise resolves on **Resolve Json** and rejects on **Reject**, with the code in `error.code` |
| `api.on(name, handler)` | **Post Event to Web**, **Post Latest Event to Web**, **Post Retained Latest Event to Web** | Receive events from Unreal. Returns a function that removes the listener |
| `api.handle(name, handler)` | **Call Web**, **On Web Call Completed** | Answer a call that Unreal starts |
| `api.stateCommitted(revision)` | Arrives in **On Web Event** as `__orion.stateCommitted`; needs no handling | Acknowledges that this revision of the state is on screen. It does not mean business success |
| `api.routeChanged(route)` | **On Route Changed** | The route changed inside the page |
| `api.playSound(id, options)` | **Sound Manifest** of the App Definition | Play a business sound |
| `api.playControlSound(id, "hover" \| "click", contextId)` | the control sound policy | Report an interaction by hand for an area without DOM events |
| `api.bindNativeSurface(id, element)` | **Set Native Surface Texture / Material** | Place an Unreal picture at a position in the page |

`requestIntent` exists only in InstantScreen pages. A page hosted by a plain widget uses `emit` and `call`.

### Startup order

1. `main.ts` obtains `api` with `resolveOrionWebUIForMount()` and passes it to the root component.
2. The root component registers the state listener and other listeners, keeping the functions they return.
3. `createOrionWebUILifecycle({ api, root })`, then `await lifecycle.initialize()`.
4. It sends its own ready event (`settingsPanel.ready`).
5. On unmount: `lifecycle.dispose()`, then every stored function.

Do not poll `window.OrionWebUI` with a timer, and do not write your own transport.

### State

- Unreal publishes the **full state** each time, with a `stateRevision` that only increases. The page drops a state that is not newer and replaces everything else.
- The page stores no game facts. Do not put progress, inventory or settings in `localStorage`. A preference that belongs to the page alone, such as a page theme, is fine.
- Publish with **Post Retained Latest Event to Web**: a listener registered later still receives the most recent state.
- Do not "assume success now and synchronise later". After submitting an action, the view waits for the next state.

### Actions

- Name events "prefix plus action", for example `settingsPanel.setVolume`, with a prefix unique in the project.
- Write event names as string literals at the call site; do not concatenate them.
- The payload is a plain object. Unreal checks every field again.
- Use `call` when you need to know the outcome. On rejection, `error.code` is the code Unreal gave; a timeout is `E_TIMEOUT`. A request Unreal did not answer succeeds with `{}` by default; it fails with `E_UNHANDLED` only when **Auto Resolve Unhandled Requests** of the widget is cleared.

### Unreal calls the page

```ts
releases.push(api.handle("settingsPanel.measure", () => {
	return { width: rootElement.value?.offsetWidth ?? 0 };
}));
```

In Blueprint, call **Call Web** on `WebUI` with `Name` set to `settingsPanel.measure`; the result arrives in **On Web Call Completed**. A name can have one handler; without one, Unreal receives `E_NOT_FOUND`. Use this only to ask the page about presentation.

### Built-in events

| Event | When | Content |
| --- | --- | --- |
| `ue:bootstrap` | After the bridge is established | `appId`, `apiVersion`, `route`, `localization`, `assets`, `sounds`, `fonts` |
| `ue:localeChanged` | The language changes | The new text table `{ culture, texts }` |
| `ue:inputModeChanged` | The input device changes (CommonUI page) | `{ inputType, gamepadName }` |
| `ue:inputPromptsChanged` | Key prompts change (CommonUI page) | `{ inputType, gamepadName, actions[] }` |
| `ue:commonAction` | A CommonUI action fires | `{ actionId, inputType, gamepadName }` |
| `ue:backAction` | CommonUI back | `{ inputType, gamepadName }` |
| `ue:webUI.lifecycleChanged` | Blueprint calls **Set Presentation Lifecycle State** | Handled by the lifecycle controller; the page does not listen to it itself |

The first four and `ue:webUI.lifecycleChanged` are retained: a listener registered late immediately receives the most recent one.

### Presentation phases

The lifecycle controller writes `data-orion-presentation` on the root element, and the page acts on it:

| Phase | Meaning | What the page does |
| --- | --- | --- |
| `preparing` | Being prepared, not shown yet | Layout, applying state and decoding images are fine. No animation, no frame loop |
| `entering` | About to be shown | The root element already has its final style |
| `active` | Shown | Interactive; animations may play. Frame loops and WebGL start only now |
| `covered` | Covered by another interface | Keep the content; stop frame loops, timers and WebGL |
| `suspended` | Parked or released | The same, and clear local presentation state |
| `closing` / `failed` | Closing / an error occurred | No interaction |

If Blueprint never calls **Set Presentation Lifecycle State**, the page enters `active` by itself once it is ready. For work of your own that has to start and stop with the presentation, pass callbacks to `createOrionWebUILifecycle`:

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

These callbacks follow presentation requests. A CommonUI host (`OrionWebUIActivatableWidget`) sends one on every activation and suspends the page on deactivation; it reveals the page once the Promise returned by `onPresentationRequested` has resolved, or when its own timeout runs out. **Set Presentation Lifecycle State** on a plain widget changes only the phase and calls neither of them. There, follow the phase itself: in CSS with `[data-orion-presentation="active"]`, or in script with a `MutationObserver` on that attribute of the root element.

Declare an entrance animation on a selector that matches both `entering` and `active`. An animation declared for `entering` alone is cancelled when the phase changes.

## Part 4: Rules for writing pages

| Rule | Reason |
| --- | --- |
| `html`, `body` and `#app` are transparent with `overflow: hidden` | The page lies over the game |
| No `backdrop-filter`, no `mix-blend-mode` | The game behind the page is not inside the page, so it cannot be blurred or blended. The contract check rejects both |
| No `prefers-reduced-motion` | Whether motion is reduced comes from Unreal's state, not from the system setting. The contract check rejects it |
| Every `<img>` has `decoding="async"` | The contract check rejects a tag without it. Write it before any attribute whose value contains `>` |
| Build output file names have no hash | `dist` is usually committed with the project; fixed names show content changes |
| Scripts, styles and fonts come from the app itself | The page's content security policy allows no inline or remote scripts, and the page must run offline |
| An interface with a fixed composition builds a stage at the design resolution and scales it as a whole | Game interfaces do not reflow like narrow web pages |
| The page does not write `user-select: none` | The plugin disables text selection by default. Where text should be selectable, write `data-orion-user-select="text"` or `"all"` on the element. Input fields are always selectable |
| Implement context menus yourself | **Orion WebUI** always suppresses the browser's native menu. Listen for `contextmenu` and call `preventDefault()` |
| Read a local video into memory and play it from a Blob URL | Local files are served without range requests, so direct playback cannot seek. Use WebM (VP9 with Opus) or another format the bundled Chromium decodes |
| Load heavy modules such as three.js with dynamic `import()` and initialise them after the entrance | Initialising earlier makes the entrance stutter |

### Control Ids

Every clickable element needs a `data-orion-control-id` **written as a literal**:

- Letters, digits, `.`, `_` and `-` only; start with a letter or digit; at most 128 characters.
- No `:data-orion-control-id="expression"`, no concatenated variables.
- Items of the same kind in a list share one Id; the item's own business identifier goes into the action's payload.
- Write disabled as an expression (`:disabled="..."`) and waiting as `aria-busy="true"`. A control that is disabled only by a style class still makes sound.

Control Ids serve sounds, the Designer inspector and automation, and they do not change with the language.

### data-orion-* attributes

| Attribute | Values | Effect |
| --- | --- | --- |
| `data-orion-control-id` | a stable literal | The identity of a control |
| `data-orion-action` | an action Id | When that CommonUI action fires, this element is focused and clicked |
| `data-orion-sound-context` | a context name | Control sounds inside this area are routed to the policy with the same name |
| `data-orion-sound-policy` | `none`, `manual`, `custom` | This element and its descendants make no automatic hover and click sounds |
| `data-orion-user-select` | `text`, `all` | Allows text selection |
| `data-orion-font-policy` | `body`, `heading`, `none` | Forces the body or heading font; `none` leaves this subtree to the page's own font declarations |
| `data-orion-presentation` | written by the plugin | The current presentation phase, see above |

## Part 5: Input

- **Mouse and touch**: the page receives pointer events like any web page.
- **Keyboard**: once `WebUI` has focus, the page receives keyboard events. Use standard `button`, `input`, `select` and `label` elements; they bring keyboard operation with them.
- **IME**: text fields keep normal selection and IME behaviour. In a key handler, return at once when `event.isComposing` is set, and do not move focus away during composition.
- **Gamepad**: there are two ways. With a plain widget, Blueprint handles gamepad input and sends commands to the page as events; the supplied sample does this (`ue:station.input`). A CommonUI page registers actions in an **Input Manifest**; when one fires, the page receives `ue:commonAction`, and if the page called `installCommonActionRouter(api, root)`, the element with `data-orion-action="<action Id>"` is focused and clicked. Disabled elements are skipped.
- **Key prompts**: listen for `ue:inputModeChanged` and `ue:inputPromptsChanged` and show key names or icons for the current device. A page that says "gamepad" does not prove a gamepad is connected to anything; try a real one.
- **Drag, hold, rotate**: use `createOrionPointerSession()` from the shared runtime (`Shared/src/input/orion-pointer-session.ts`) instead of attaching move and release listeners to `window`. It cancels a drag in progress when the page is covered or suspended.
- **Mouse cursor**: with `CursorPolicy` set to `GameControlled` on the App Definition, the game decides the cursor; with `PageControlled`, the page's CSS does.
- **Moving focus with arrow keys**: the shared runtime does not provide it; implement it yourself. The supplied sample's approach is in `Showcase/src/shell/focus.ts`.

## Part 6: Sound, text, fonts and images

### Sound

**Hover and click sounds of controls** are played by Unreal, and the page contains no code for them. Elements with `data-orion-control-id`, and `button`, `a[href]`, `input`, `select`, `textarea`, `summary` and `[role="button"]`, are reported automatically when the pointer enters, when they receive focus, and when they are clicked. The policy on the Blueprint side is described in [Tutorial 3](tutorial-3-blueprint-and-cpp.md#control-sounds).

**Sounds with a business meaning** are requested by the page:

```ts
await api.playSound("settings.saved", { volumeMultiplier: 0.8 });
```

The sound Id is a `StableId` in the **Sound Manifest** of the App Definition. Error codes on failure: `E_SOUND_DISABLED` (the app turned web sound off), `E_INVALID_ARG`, `E_SOUND_UNAVAILABLE` (not in the manifest, or the entry is disabled).

Do not stack the two channels: a button that already has an automatic click sound should not play another through `playSound`. Mark an area that plays its own sounds with `data-orion-sound-policy="manual"`. Do not load and play audio files in the page for interface sounds.

### Text and language

- **The simple way**: Unreal publishes the language in the state (`culture` in this tutorial), and the page uses its own dictionary.
- **Text Catalog**: create an `OrionWebUITextCatalog` in Unreal that maps stable keys to Unreal text, and assign it to the App Definition. In the page:

```ts
import { type OrionLocalizationTable, translate } from "../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/bridge/orion-webui";

const table = ref<OrionLocalizationTable>({ culture: "", texts: {} });
releases.push(api.on<OrionLocalizationTable>("ue:localeChanged", (next) => { table.value = next; }));
const bootstrap = await lifecycle.initialize();
table.value = bootstrap.localization;
// In the template: {{ translate(table, "settingsPanel.title", "Settings") }}
```

When the language changes, replace the text in the same element. Do not keep one element per language, and do not reload the page to switch.

### Fonts

| Approach | Steps |
| --- | --- |
| Bundle fonts with the app | Put the font files in `src/assets`, declare them with `@font-face` in CSS, and write `data-orion-font-policy="none"` on the area that uses them. Keep the font licence files |
| Use Unreal font assets | Create an `OrionWebUIFontManifest` data asset and register Font Face assets and CSS family names in **Entries**. Assign it to `SystemFontManifest` in **Project Settings → Game → Orion WebUI Font** for every app, or to `FontManifest` of one App Definition |

With Unreal fonts, `ensureOrionWebUIFontStylesheet("<AppId>")` in `main.ts` attaches the font stylesheet, and CSS takes the family from variables:

```css
font-family: var(--orion-webui-body-font-family, var(--orion-webui-font-family, sans-serif));
```

For headings, replace the first variable with `--orion-webui-heading-font-family`. The plugin assigns the body or heading font to text by its size; the boundary is `HeadingFontSizeThresholdPx` in `FontPolicy` of the font manifest, 24 pixels by default. The heading font is used only for the cultures listed in `HeadingFontCulturePrefixes` of the same policy; while that list is empty, every size uses the body font.

### Images

| Image source | Approach |
| --- | --- |
| Static images of the interface | Put them in the app's `src/assets` and reference them by relative path or `import`. WebP is recommended |
| A fixed set of Unreal textures or material previews | Register `StableId` with a texture or material in an `OrionWebUIAssetManifest` and assign it to the App Definition. The page takes `url` by `id` from `bootstrap.assets`. A texture gets its address at runtime. A material preview is a thumbnail that has to be exported in the editor: call `ExportWebUIAssets` of `OrionWebUIEditorLibrary` (from an Editor Utility Blueprint or editor Python) and save the manifest. It writes the picture into `dist`, so repeat it after every web build; until it has run, the `url` of a material is empty |
| Textures known only at run time (avatars, generated icons) | **Request Texture Resource** in Blueprint; when ready, put the address in the state. See [Tutorial 3](tutorial-3-blueprint-and-cpp.md#runtime-images) |
| Continuously changing pictures (scene capture, video, dynamic materials) | Native Surface, below |

Do not encode an image as Base64 into the state, and do not send images through messages every frame.

### Live pictures: Native Surface

Put a placeholder element in the page; Unreal draws the picture directly at its position:

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

Without the component: `const release = api.bindNativeSurface("station.capture", element)`, and call `release()` on unmount.

- `surface-id` matches `Surface Id` of **Set Native Surface Texture** in Blueprint character for character.
- Position and size are those of the placeholder element. Translation, scale, opacity and clipping by ancestors are supported; rotation, skew and rounded-corner clipping are not.
- By default the picture is drawn above the page and covers web content inside the placeholder. Draw the border on an outer container.
- The native picture receives no mouse input. A page can have at most 512 bindings; for many icons in a list, use runtime images.

## Part 7: WorldUI

Labels, health bars and interaction buttons that follow Actors are drawn in the same page. Mount the overlay component in the page:

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

On the Unreal side, add an `OrionWebUIWorldElementComponent` to the Actor (search for `World Element`), create a Definition, and call **Bind Overlay Widget**; the steps are in [Tutorial 3](tutorial-3-blueprint-and-cpp.md#worldui-labels-and-interaction-that-follow-actors).

The default appearance:

- When the Definition enables interaction and lists actions: `payload.label` is shown with one button per action, labelled `payload.actionLabel`. On a click, the plugin checks that the target is still valid and visible and that the action is allowed, and then fires **On Interaction** of the component.
- Otherwise a health bar is shown, reading `payload.health`, `payload.maxHealth`, `payload.label` and `payload.color`.

To draw it your own way, register a renderer for the Definition's `ElementType`:

```ts
worldOverlay.value?.registerRenderer("StationCell", ({ container, element }) => {
	container.textContent = String(element.payload.label ?? element.key);
});
```

Global budgets (how many elements a player sees at most, refresh rate, occlusion traces) are set in `[/Script/OrionWebUIWorldWidget.OrionWebUIWorldSettings]` in the project's `Config/DefaultGame.ini`, for example `MaxVisibleElements=512`.

## Part 8: Remote websites

Use the **Orion Browser** widget for external websites, in a Widget of its own:

1. Add an **Orion Browser**, enter the address in **Initial URL**, or call **Load URL** at run time.
2. Use **On Load Started**, **On Load Completed** and **On Load Error** for loading, loaded and failed views. Give the failed view a retry button (**Reload**).
3. Use **Go Back**, **Go Forward** and **Stop Load** for navigation buttons.

A remote page cannot reach the game bridge, and you should not try to give it one. A network failure affects only this widget. In Designer it shows placeholder text only.

## Part 9: Several pages and routes

One app can contain several pages, told apart by `#/<route>` in the address:

- `InitialRoute` of the App Definition is the default route.
- To open different pages of one app in different widgets, set `InitialRouteOverride` on the widget or call **Set Initial Route Override**.
- After changing the route inside the page, call `api.routeChanged("<route>")`. **On Route Changed** fires in Blueprint, and **Get Current Route** returns the current value.
- Load the component of each route with dynamic `import()`, so that opening one page does not load the code of all pages.

## Part 10: Security

- A page can navigate only below its own app address. Navigation elsewhere is blocked and reported through **On Web Error** as `Blocked Orion WebUI top-level navigation: <address>`.
- By default the page's content security policy allows scripts, styles, fonts, images and media from the app itself only. To embed external content, enter exact origins in the App Definition (the origin only, no path, no wildcard): `AllowedFrameOrigins` for `<iframe>`, `AllowedImageOrigins` for images, `AllowedMediaOrigins` for audio and video. The three do not cover each other.
- The page is application code, but treat everything it sends as untrusted input: check type, range, whether the object still exists, and whether the player may do this, in Unreal.
- Do not put keys or tokens into the page or the state.
- In a networked game, an action that reached the client's Unreal still needs to be authorised through your own server request.

## Part 11: Performance and configuration

When writing the page:

- Stop your frame loops, timers and WebGL whenever the page is not in the `active` phase.
- Do not send data that changes every frame with **Post Event to Web** every frame; use Native Surface for continuously changing pictures.
- When an uncapped game saturates the GPU, the browser's picture updates are crowded out. A sustainable frame limit for the game (**Get Game User Settings → Set Frame Rate Limit → Apply Non Resolution Settings**) helps more than lowering the browser frame rate.

Common settings in the `[OrionBrowser]` section of the project's `Config/DefaultEngine.ini`:

| Key | Default | Effect |
| --- | --- | --- |
| `DefaultWebUIRenderMode` | `LegacyTexture` | The render mode. Keep the default; it is the supported mode |
| `bEnabled` | `True` | When `False`, no browser is created |
| `bUseAdaptiveFrameRate` | `True` | The browser frame rate follows the game frame rate |
| `DefaultWebUIRenderScale` | `1.0` | Used when `BrowserRenderScale` of the App Definition is `0` |
| `MaxWebUIRenderScale` | `2.0` | The upper limit of the render scale |
| `HiddenBrowserFrameRate` | `0` | The frame rate of hidden browsers |
| `bCacheWebUIStaticResources` | `True` | Caches `dist` files in memory |
| `bEnableCEFFileLogging` | `True` | Writes the browser log to `Saved/Logs/cef3.log` (off in Shipping) |

Budgets for runtime images are in the `[OrionWebUI.RuntimeImage]` section, for example `MaxOutputDimension=2048` and `RequestTimeoutSeconds=15`.

## Part 12: Debugging

| Means | Use |
| --- | --- |
| **On Web Error** | Connect it to **Print String**. Bridge errors, blocked navigation and failed resource preparation arrive here |
| Output Log | Filter by `LogOrionWebUIWidget` (the widget), `LogOrionWebUI` (resources and addresses), `LogOrionBrowser` (the browser), `LogOrionBrowserPreparation` (tool preparation) |
| Browser log | `Saved/Logs/cef3.log` |
| Web developer tools | Start with `-cefdebug=9222` to open Chromium's remote debugging port, then connect Chrome to that port to inspect the page |
| **Execute Javascript for Debug** | Runs a script in the page; for debugging only |
| Diagnostics overlay | Console commands `OrionBrowser.Debug.Enable 1` and `OrionBrowser.Debug.Overlay 1` show frame rate, memory and the state of each app; `OrionBrowser.Debug.Dump` writes it to the log. Not available in Shipping |
| Blueprint diagnostics | **Set Diagnostics Enabled**, **Get Diagnostics Snapshot** and related nodes in the **Orion Browser \| Diagnostics** category |
| **Get Readiness Snapshot** | Reads in one call whether the browser exists, the bridge is ready and local resources are ready |
| Editor validation | Call `ValidateWebUIAppDefinition` from an Editor Utility Blueprint; it returns the configuration problems of an App Definition |

The page's own `console.log` does not appear in the Output Log. Use the developer tools or the Log tab of WebUIStudio.

## Part 13: Check and deliver

After every change, in this order:

1. `npm.cmd run typecheck`, `npm.cmd test`, `npm.cmd run build`.
2. Look at every view in [WebUIStudio](tutorial-4-webui-studio.md) or a browser.
3. Confirm in UMG Designer that the page loads, and check that every control has an Id (the "Inspect" tab of WebUIStudio, or the control Id preview in Designer).
4. Operate it in PIE: mouse, keyboard, gamepad, IME, both languages, sound, repeated opening and closing.
5. [Package](packaging.md) and go through it again in the packaged game. An up-to-date `dist` must exist before packaging.

Each layer proves only itself: working in a browser does not mean working in Unreal, and working in PIE does not mean the files are in the package.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| The build reports `requires package.json orionWebUI appId, interfaceName, ...` | The four fields in `package.json` and the two values in `vite.config.ts` disagree |
| The build reports `must bundle the shared presentation transaction ...` | The page does not use `createOrionWebUILifecycle` |
| The build reports `component is outside the supported source directories` | A `.vue` file is neither below the folder that holds your apps (the parent of the app folder) nor in the plugin's `Shared` folder |
| `npm test` reports a missing `decoding="async"` | Add it to the `<img>`. If it is there already, move it to the start of the tag: the check reads the tag only up to the first `>` |
| The page is blank in Unreal | Are the three names identical? Was it built? Look at **On Web Error** |
| Blank in Designer, fine in PIE | The page has no preview branch for the no-host case |
| Fine in a browser, an opaque full screen in Unreal | `index.html` has `color-scheme`, or the root element has an opaque background |
| Clicks do nothing | Is the root element in the `active` phase? Do the event names match on both sides? |
| The state does not update | Does the revision increase? Was the listener registered before `ready`? |
| Designer shows an old page after the dev server changed its port | **Dev Server Url** was not updated, or another app holds the port |
| The source changed but PIE did not | PIE reads `dist`; run `npm run build` again |
| External images, video or pages are blocked | Enter exact origins in the three `Allowed...Origins` of the App Definition |
