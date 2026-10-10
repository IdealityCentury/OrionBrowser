# Web App scaffold

Build an Orion WebUI App from scratch that passes the production build. This document covers only the Web project skeleton: for how a page uses the Bridge, see [Bridge and lifecycle](bridge-lifecycle.en.md); for UE-side assets, see [UE-side host](native-host.en.md); for command order and validation, see [Build and validation](build-validation.en.md).

## Layout assumptions

- The App root directory is fixed as `<WebUIRoot>/<AppId>`, where `<WebUIRoot>` is `<ProjectRoot>/Content/UI/WebUI`, and the directory name matches `AppId` character for character. This is not a habit you may change: the plugin runtime looks for the build output under `<ProjectRoot>/Content/UI/WebUI/<AppId>/dist` (and falls back to the plugin's own `<OrionBrowser>/Content/UI/WebUI/<AppId>/dist` only if it is not found), and the build rules of the `OrionWebUI` module also collect packaging dependencies from `<WebUIRoot>/*/dist/**`; an App placed anywhere else is neither loaded nor included in the package.
- `<OrionBrowser>/Content/UI/WebUI/Shared` provides shared runtime source and build tools, imported by each App through relative paths; this SDK directory is excluded from the App inventory. The basic sample's source, independent npm project and `dist` are under `<OrionBrowser>/Content/UI/WebUI/Sample`; the complete sample is in the adjacent `Showcase` directory. Host pages belong in their own App directories.
- The plugin's Web scripts determine `<ProjectRoot>` by looking for a `.uproject` first in the current directory and then upward from the plugin directory. They also accept `--project-root`, `--webui-root` and the corresponding environment variables (see "Locating the host project" in [Build and validation](build-validation.en.md)). An App's relative imports of plugin files still depend on the actual location of the plugin. When the plugin is not at `<ProjectRoot>/Plugins/OrionBrowser`, first read "When the plugin is not in the project's Plugins folder" at the end of this document.
- Use npm only. Each App has its own `package.json`, `package-lock.json` and `node_modules`. Do not create a workspace, do not generate yarn / pnpm lock files, and do not rely on dependencies that happen to exist in a sibling App or a parent directory. Configure the `.gitignore` below before installing dependencies so local dependencies, caches and logs stay out of Git.

## Files and responsibilities

| File | Responsibility |
| --- | --- |
| `package.json` | The `orionWebUI` declaration, standard scripts, dependencies |
| `package-lock.json` | This App's lock file; the first `npm install` of a new App generates it and it is committed, after which always use `npm ci` |
| `.gitignore` | Created before installing dependencies; excludes local dependencies, caches, logs and incremental files while keeping source, lock files and required runtime output |
| `tsconfig.json` | Project configuration for `vue-tsc` |
| `vite.config.ts` | Stable naming, Vue scope identifiers, manifest, dev server |
| `index.html` | Vite entry document |
| `src/main.ts` | Installs the UE font stylesheet, resolves the Bridge, mounts the root component |
| `src/App.vue` | Root component, holds the lifecycle root node |
| `src/bridge/orion-webui.ts` | The only Bridge import point of this App |
| `dist/` | Production build output, read directly by the runtime and by packaging; it is generated only by the build and never edited by hand |
| `instant-screen.config.ts`, `webui-button-contract.json` | Optional; the former is needed when connecting to [InstantScreen](instant-screen.en.md), and the latter is the control and Intent contract (see [Controls and resources](controls-resources.en.md)) |
| `src/model/<interface-name>-preview.ts` | The preview state export, shared by the page's host-less fallback and WebUI Studio; see [WebUI Studio preview contract](studio-preview.en.md) |
| `webui-preview.json` | Optional; declared when one route has sub-interfaces that are switched by state, or when the preview state needs arguments; see the same reference |

When importing plugin files, compute the relative path from the actual location of the current file to `<OrionBrowser>`. When the App is at `<WebUIRoot>/<AppId>` and the plugin is at `<ProjectRoot>/Plugins/OrionBrowser`, the prefix at the App root (the scripts in `package.json`, `vite.config.ts`) is `../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/`; files under `src/` need one more `../`, and files under `src/<subdirectory>/` need one more again. The templates below are all written for this layout.

## .gitignore

When creating or copying a WebUI root or an independent App directory, create or merge the following root `.gitignore`, preserving existing rules. The same applies to plugin example Apps; omit these ignored local artifacts when copying an App.

```gitignore
**/node_modules/
**/.npm/
**/.vite/
**/.cache/
*.tsbuildinfo
npm-debug.log*
```

Keep `.gitignore` itself, source, `package.json`, `package-lock.json`, build configuration and the `dist` required for runtime/packaging in version control. Do not copy a generic frontend template's `dist/` ignore rule.

Ignore rules do not untrack existing files. Before delivery, inspect the WebUI/App Git index and status; if dependencies are already tracked, untrack only those paths within the host's Git authorization and keep the local files.

## package.json

```json
{
	"private": true,
	"name": "sample-webui-sample-panel",
	"version": "1.0.0",
	"type": "module",
	"orionWebUI": { "appId": "SamplePanel", "interfaceName": "sample-panel", "performanceProfile": "transactional-screen", "lifecyclePolicy": "transactional" },
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

Dependency version ranges follow `<OrionBrowser>/Content/UI/WebUI/Shared/package.json`; stay on the same major version as the plugin template. The four script names are fixed entry points and are not renamed.

| `orionWebUI` field | Value | Must match |
| --- | --- | --- |
| `appId` | PascalCase, non-empty | The directory name; the `appId` that `vite.config.ts` writes into the manifest; the value that `main.ts` passes to `ensureOrionWebUIFontStylesheet`; the UE-side `UOrionWebUIAppDefinition.AppId` |
| `interfaceName` | Lowercase kebab-case (`^[a-z0-9]+(?:-[a-z0-9]+)*$`), unique within the project | The first argument of `createOrionWebUIBuildOutput` |
| `performanceProfile` | One of the three in the table below | The `performanceProfile` in the second argument of `createOrionWebUIBuildOutput` |
| `lifecyclePolicy` | Determined uniquely by the profile | The table below |

| `performanceProfile` | `lifecyclePolicy` | Applies to |
| --- | --- | --- |
| `transactional-screen` | `transactional` | Menus, popups and interactive pages: every appearance and disappearance goes through a presentation transaction. Choose this when unsure |
| `continuous-passive` | `continuous-passive` | A passive HUD that is displayed continuously; the root node declares `data-orion-presentation-mode="continuous"`, and on that basis the build gate lets through a Bundle that contains no presentation transaction |
| `resident-shell` | `resident-shell` | A shared Shell in which one document hosts multiple routes; route components and styles are loaded on demand |

A profile describes only the page structure and lifecycle. The build only checks that the declarations are consistent and sets no entry size limit. Whether a Browser stays resident is decided by the UE-side policy and cannot be obtained by choosing a profile.

`test` calls the plugin's App contract script by default (see "Dependencies, resources and animation" for what it checks). When an App needs unit tests, add `vitest` to this App's `devDependencies` and write `test` as `node <same script as above> && vitest run`; do not let the contract check be replaced.

## tsconfig.json

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

- `paths.vue` must not be omitted: the shared source in `<OrionBrowser>/Content/UI/WebUI/Shared/src` does `import "vue"`, and type checking by default searches for dependencies upward from the directory of that file. Mapping it back to this App's `node_modules` means the check does not depend on whether dependencies were installed in the plugin directory. At bundling time, `@vitejs/plugin-vue` deduplicates `vue` to the App root, so no extra alias is needed.
- Add `"node"` only when it is actually needed: when `include` contains build helper files such as `vite.config.ts` that import `node:*` or read `process`, or when test code uses Node APIs. In that case, also declare `@types/node` in this App's `devDependencies` and put `"node"` in `types`. Do not widen the type scope of page code unconditionally for the sake of configuration files.

## vite.config.ts

```ts
import path from "node:path";
import { fileURLToPath } from "node:url";

import vue from "@vitejs/plugin-vue";
import { defineConfig } from "vite";

import { createOrionWebUIBuildOutput, createOrionWebUIVueOptions } from "../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/vite-output-naming";

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const browserWebUISourceDir = path.resolve(rootDir, "../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src");
const appId = "SamplePanel";

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
		...createOrionWebUIBuildOutput("sample-panel", { performanceProfile: "transactional-screen" }),
	},
	server: {
		host: "127.0.0.1",
		port: 5180,
		strictPort: false,
		fs: { allow: [rootDir, browserWebUISourceDir] },
	},
});
```

- `createOrionWebUIBuildOutput("<interface-name>", {` and `performanceProfile: "<profile>"` must be string literals written in the source: the App contract script matches these two pieces of text, and extracting them into variables makes `npm test` fail.
- The function returns `cssCodeSplit` and `rollupOptions` (output naming plus three build gate plugins). When you need extra Rollup configuration such as `manualChunks`, first store the return value in a variable and then spread and merge it layer by layer; overriding `rollupOptions` as a whole loses the naming rules and the gates. A multi-route App passes `cssCodeSplit: true`, so that each route's CSS stays out of the entry.
- The manifest has only the four fields `appId`, `entry`, `apiVersion` and `localOnly`, and the file name is fixed as the root-level `orion-webui.manifest.json`. Do not add a build hash, a package hash or a file digest table.
- `base: "./"` makes `index.html`, dynamic imports and CSS `url()` all use relative paths, so that the build output can load under `https://orion-webui.local/<AppId>/`.
- `server.fs.allow` must include the App root and `<OrionBrowser>/Content/UI/WebUI/Shared/src` (and any other source directories outside the root that the App references); otherwise the dev server refuses to serve modules outside the root directory.
- Each App uses a different `server.port`, which must match the UE-side `UOrionWebUIAppDefinition.DevServerUrl`.

## Stable names

- `dist` is read directly by the runtime and is usually committed with the project, so file names must be deterministic, so that an update shows up as a content change in a file of the same name. The entries are `assets/index-<interface-name>.js` and `assets/index-<interface-name>.css`; async chunks are `assets/<interface-name>-<name>.js`; images, fonts and so on are `assets/<interface-name>-<name><ext>`.
- `[hash]`, random IDs and timestamps are forbidden. When two source files produce the same output name, rename a source file; do not bring back content hashes. A custom plugin that calls `emitFile()` uses only a deterministic `fileName`.
- The line endings of the build output text are normalized to CRLF by the output plugin that `createOrionWebUIBuildOutput` attaches; do not post-process `dist`.
- `vue(createOrionWebUIVueOptions(rootDir))` changes the `data-v-*` of `<style scoped>` into stable names generated from the source path (for example `data-v-sample-panel-app`), with no content hash. Moving or renaming a component file changes the identifier and requires a rebuild; if names collide after normalization, the build fails (`CSS scope name collision`), and renaming the file resolves it. `.vue` files must be located under `<WebUIRoot>` or `<OrionBrowser>/Content/UI/WebUI/Shared`; here `<WebUIRoot>` is taken as the parent of `rootDir`, and when the host puts the WebUI root elsewhere, set the environment variable `ORION_WEBUI_ROOT`.

| Build-time error fragment (thrown by `vite-output-naming.ts`) | Cause and handling |
| --- | --- |
| `interface name must use kebab-case` | The interface name contains uppercase letters, underscores, or a leading or trailing hyphen; change it to lowercase kebab-case |
| `requires package.json orionWebUI appId, interfaceName, performanceProfile=…, and lifecyclePolicy=…` | The `package.json` declaration is missing or inconsistent with `vite.config.ts`; align it with the expected values given in the error |
| `must bundle the shared presentation transaction or explicitly declare data-orion-presentation-mode="continuous"` | The Bundle contains no shared presentation transaction: connect the lifecycle controller in `App.vue` as shown below; only a passive HUD should switch to the continuous declaration |
| `component is outside the supported source directories` | The `.vue` file is not in an allowed directory, or the plugin is not in the standard location |

## Entry files

`index.html` (fill in `lang` according to the project's default language):

```html
<!doctype html>
<html lang="en">
	<head>
		<meta charset="UTF-8" />
		<meta name="viewport" content="width=device-width, initial-scale=1.0" />
		<title>Sample Panel</title>
	</head>
	<body>
		<div id="app"></div>
		<script type="module" src="/src/main.ts"></script>
	</body>
</html>
```

Do not add `<meta name="color-scheme" content="dark">`: it turns the document canvas into an opaque dark color, so a page that needs to let the UE scene show through covers the whole screen, and this is not visible in an ordinary browser. Write the dark theme in component styles.

`src/bridge/orion-webui.ts` (this gathers the deep relative paths into this one file; page-specific state and event types are also added here, and components import only from here):

```ts
export type {
	OrionJsonPayload,
	OrionLocalizationTable,
	OrionWebUIApi,
	OrionWebUIBootstrap,
} from "../../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/bridge/orion-webui";
export {
	playUISound,
	resolveOrionWebUIForMount,
	waitForOrionWebUI,
} from "../../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/bridge/orion-webui";
```

`src/main.ts`:

```ts
import App from "./App.vue";
import { resolveOrionWebUIForMount } from "./bridge/orion-webui";
import {
	createOrionWebUIApp,
	ensureOrionWebUIFontStylesheet,
} from "../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/instant-screen/orion-instant-screen-vue";

ensureOrionWebUIFontStylesheet("SamplePanel");

async function mountSamplePanel(): Promise<void> {
	const api = await resolveOrionWebUIForMount();
	createOrionWebUIApp(App, { api }).mount("#app");
}

void mountSamplePanel().catch((error: unknown) => {
	console.error("SamplePanel failed to connect to the Orion WebUI host bridge.", error);
});
```

- `resolveOrionWebUIForMount()`: under `orion-webui.local`, it waits until the host has installed the Bridge before it returns; in an ordinary browser or in a design preview with `orionDesignPreview=1`, it returns immediately (`undefined` when there is no host). Whether you are in a preview is determined only by this return value; do not probe on your own whether `window.OrionWebUI` is temporarily empty.
- `createOrionWebUIApp()` replaces `createApp()`: when a static first-frame package needs hydration it switches to an SSR app, and in all other cases it is equivalent to `createApp()`; `api` is passed in as a prop of the root component. `ensureOrionWebUIFontStylesheet(appId)` mounts the font stylesheet provided by UE; the App ships no font files of its own.

`src/App.vue` (the minimal root component that builds and passes the presentation contract):

```vue
<template>
	<main ref="rootElement">
		<h1>Sample Panel</h1>
	</main>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";
import type { OrionWebUIApi } from "./bridge/orion-webui";
import {
	type OrionWebUILifecycleController,
	createOrionWebUILifecycle,
} from "../../../../../Plugins/OrionBrowser/Content/UI/WebUI/Shared/src/runtime/orion-webui-lifecycle";

const props = defineProps<{ api?: OrionWebUIApi }>();
const rootElement = ref<HTMLElement | null>(null);
let lifecycle: OrionWebUILifecycleController | null = null;

onMounted(async () => {
	if (!props.api || !rootElement.value) {
		return;
	}
	lifecycle = createOrionWebUILifecycle({ api: props.api, root: rootElement.value });
	// Register business event listeners here; this must happen before initialize().
	await lifecycle.initialize();
});

onBeforeUnmount(() => {
	lifecycle?.dispose();
	lifecycle = null;
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
</style>
```

Keep `html`, `body` and `#app` at full size, with `overflow: hidden` and a transparent background. An interface with a fixed composition builds a design-resolution stage and scales it uniformly as a whole, without web-style narrow-screen reflow. The lifecycle controller writes `data-orion-presentation` on the root node; for the per-phase styles, the state channel and Intent, see [Bridge and lifecycle](bridge-lifecycle.en.md).

## Dependencies, resources and animation

The static dependency closure of a production entry must not contain `*.test.*` / `*.spec.*`, preview / mock / fixture data, implementations and styles of routes that are not requested, whole icon libraries, or font files privately copied by the App. For icons, use only tree-shakable single-icon entries; load route components with dynamic `import()`; put heavy modules such as WebGL into async chunks and load them after the entrance has completed.

`npm test` (the App contract script) scans each `.css`, `.ts` and `.vue` file under `src` and fails on any hit:

| Check | Handling |
| --- | --- |
| `prefers-reduced-motion` appears | Do not read the system motion preference directly; if reduced motion is truly needed, make the switch a state field sent down from C++ |
| `backdrop-filter:` appears (including the `-webkit-` prefix) | Express depth with opacity, gradients or pre-baked images |
| `mix-blend-mode:` appears | Use plain overlay or pre-composited images instead |
| An `<img>` tag lacks the literal `decoding="async"` | Write it as a static attribute and put it first after `<img`; the script matches only up to the first `>` inside the tag, so writing it after an attribute that contains `>` (such as an arrow function) is judged missing |
| `src/App.vue` is missing, the four `orionWebUI` fields are incomplete, or the two literals above cannot be found in `vite.config.ts` | Fill them in following the templates in this document |

If the host enables project-wide animation validation, it also rejects transitions of `filter` inside `transition`. The script does not check the following, but they must still be obeyed: keep the presentation root node static, and put entrance animation on bounded child nodes such as panels, titles and cards; stop your own rAF and Timers when the page is hidden or covered; do not avoid the gate by using extremely short animations or lowering quality. For image formats, fonts, sound and Native Surface, see [Controls and resources](controls-resources.en.md).

## Design preview

A page runs in three environments that have no game host, and none of them can obtain real Bridge state:

| Environment | Entry | Description |
| --- | --- | --- |
| Browser development preview | `npm run dev` | The host name is not `orion-webui.local`, and `api` is `undefined` |
| UMG Designer | `bUseDevServerInEditor` and `DevServerUrl` of `UOrionWebUIAppDefinition` | If the design-time port is reachable, the dev server is loaded; otherwise `dist` is loaded; the URL carries `orionDesignPreview=1` |
| InstantScreen Package build | The builder starts a temporary dev server with this App's `vite.config.ts` | It captures the first-frame DOM with `orionDesignPreview=1&orionInstantBuild=1`; the page must render the complete structure without a host |

- A fourth environment is the WebUI Studio that ships with the plugin, and it is the opposite of the three above: it installs a simulated Bridge for the page, so `api` exists, the page takes its hosted branch, and the host-less preview branch below does not run. Studio reads the preview state the App exports by itself and delivers it through the state event, so the preview data has to be in a module that can be imported on its own, and exported, as described in [WebUI Studio preview contract](studio-preview.en.md).
- Preview data is used only in the branch where `api` is `undefined`. A very small fallback state with no resources can be inlined in the component; a Preview Adapter with fixture data or images goes into a separate module and is loaded with dynamic `import()` only in `import.meta.env.DEV` or the design preview branch, and the production entry must not import it statically. In production code, do not fake `window.OrionWebUI`, fake `ready()` or skip waiting; when a host exists, the preview branch must not run.
- The Designer only probes whether the port of `DevServerUrl` is reachable and does not check whether the other end is this App. If the port is occupied by another App, or Vite automatically switches to another port because of the occupation, the Designer shows a wrong page or falls back to `dist`. When you need a deterministic port, run `node_modules/.bin/vite.cmd --host 127.0.0.1 --port <Port> --strictPort` directly in the App root, and do not rely on `npm run dev --` to forward arguments.
- On Windows, `listen EACCES: permission denied 127.0.0.1:<Port>` can appear when no listener exists. To decide, actually run `TcpListener.Start()` once on the same address: if it succeeds, the port is usable; if it throws `SocketException`, stop retrying that port, bind port `0` to get a system-assigned port instead, and start with `--strictPort`. When starting a preview in the background, record the exact PID of this run, treat the preview as available only after an HTTP 2xx is received, and at the end terminate only this PID. Do not terminate Node processes in bulk by process name, and do not write logs into `dist` (the next build that clears `dist` would fail because of file locks).

## Accepting the production build output

1. `dist/index.html` references the entries as `./assets/index-<interface-name>.js` and `./assets/index-<interface-name>.css`.
2. In `dist/orion-webui.manifest.json`, `appId`, `entry`, `apiVersion` and `localOnly` are correct, with no hash or digest fields.
3. The Web / UE event names used by this page can be found in the JS output; `dist/assets` contains no preview, mock or fixture modules, and no file names with hashes.
4. Build twice in a row; the set of file paths in `dist` and the content hash of each file are exactly identical.
5. The WebUI/App root has a `.gitignore`; local dependencies, caches, logs and incremental files are absent from the Git index and pending changes. `package-lock.json` is the unmodified content generated by npm (including `packages[""]`), and the `dist` required for runtime/packaging is not ignored.
6. When InstantScreen is connected, `dist/instant` was regenerated after the last production build.

## When the plugin is not in the project's Plugins folder

- When the plugin is installed in the engine directory or at a deeper level of `Plugins`, recompute the relative imports from the actual location. Page source can use Vite `resolve.alias` plus tsconfig `paths` to collapse them into one alias; the import of `vite-output-naming` in `vite.config.ts` itself happens before the alias takes effect, so it can only use the actual relative path or an absolute path resolved at run time; do not write machine-specific absolute paths into the repository.
- The plugin's tools do not depend on the install location: `createOrionWebUIVueOptions` takes the parent of the App root directory as `<WebUIRoot>`; the Runtime build and project-wide validation under `<OrionBrowser>/Content/UI/WebUI/Shared/scripts` locate the host as described in "Locating the host project" in [Build and validation](build-validation.en.md); when the plugin is not inside the project directory, pass `--project-root <ProjectRoot>` or set `ORION_PROJECT_ROOT`. The path in the App's `package.json` that points to `test-webui-app-contract.mjs` is likewise rewritten according to the actual location.
- Verified scope: the complete flow with the plugin at `<ProjectRoot>/Plugins/OrionBrowser`; and, with a copy of the plugin outside the project, the results of the scripts above after the project root is specified match those of the in-project layout. The App build (relative imports and aliases) with the plugin outside the project has not been verified together with the plugin; before adopting it, tell the user and run an actual build.
