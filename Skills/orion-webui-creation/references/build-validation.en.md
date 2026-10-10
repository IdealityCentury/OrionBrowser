# Build, checks and validation

After you create or change a WebUI App, build it, check it and report the results by layer as described in this document. For the project skeleton, see [Web App scaffold](web-app-scaffold.en.md). For the configuration and troubleshooting of InstantScreen Packages, see [InstantScreen](instant-screen.en.md).

## Read the host's rules first

- First read the host project's instruction files (`AGENTS.md`, `CLAUDE.md` and similar, including files of the same kind under the `<WebUIRoot>` directory). The build command allowlist in them (the fixed arguments for Unreal compile, Cook and packaging), the test authorization (whether you may start the Editor, PIE, a packaged build or browser validation) and any additional gates (the host's own contract scripts, determinism checks, line ending and encoding requirements) take precedence over this document.
- This document describes only the tools the plugin provides and the general order of steps. Do not run a validation layer that is not authorized; in the hand-off, write "not run" for it, and do not substitute another layer.
- A documentation-only change does not trigger a Web build. Rerun a check that has already passed only when a later change affects its conclusion.

## End-to-end order

| Step | Working directory | Command | When needed |
| --- | --- | --- | --- |
| 1 Install dependencies | `<WebUIRoot>/<AppId>` | `npm ci` | First time or when the lock file changes; for a new App, run `npm install` the first time to generate the lock file |
| 2 Type check | Same as above | `npm run typecheck` | The App implementation changed |
| 3 Existing tests | Same as above | `npm test` | Same as above; to validate only part of the App, you can pass a single test file |
| 4 Production build | Same as above | `npm run build` | Same as above |
| 5 Shared Runtime | `<OrionBrowser>/Content/UI/WebUI/Shared` | `npm ci` (once), `npm run instant:runtime:syntax`, `npm run instant:runtime:build`, `npm run instant:runtime:check` | Only when the project uses InstantScreen; run `build` only when the plugin Runtime source changed or the generated directory does not exist; otherwise run only `check` |
| 6 InstantScreen Package | `<OrionBrowser>/Content/UI/WebUI/Shared` | `npm run instant:build -- --app <AppRoot>`, then for each route run `npm run instant:validate -- --package <AppRoot>/dist/instant/routes/<route>` | The App has `instant-screen.config.ts` |
| 7 Project-wide validation and per-App contract checkers | `<OrionBrowser>/Content/UI/WebUI/Shared`; the checkers run in `<ProjectRoot>` | See the third and fifth groups in "Plugin scripts" | Only when the host project uses these validations |
| 8 Unreal compile | `<ProjectRoot>` | The build command the host project specifies | You changed C++, a Blueprint-visible interface, asset wiring or configuration |
| 9 Studio discovery check | `<ProjectRoot>` | `WebUIStudio.exe --project … --check-discovery --app <AppId>`, see [WebUI Studio preview contract](studio-preview.en.md) | A new App, or a change to the routes, the preview state export or `webui-preview.json` |

- Step 4 must come before step 6: `vite build` empties `dist`, which also deletes `dist/instant`, and the Package builder needs to resolve the entry module from `dist/index.html`. After that, every time you build again, redo step 6.
- The type check and the build do not replace each other: Vite does not type-check, and `vue-tsc` does not produce a Bundle.
- The builder runs serially: do not start two Package builds at the same time, and do not rebuild the same App while the builder is running.
- The scripts in steps 5, 6 and 7 depend on the plugin directory's own `node_modules`, so first run `npm ci` once in `<OrionBrowser>/Content/UI/WebUI/Shared`. The contract script that `npm test` calls inside the App uses only Node built-in modules and does not need it.
- The package directory name for an empty route is `default`.

```powershell
function Invoke-Checked
{
	param([string]$Name, [scriptblock]$Command)
	& $Command
	if ($LASTEXITCODE -ne 0)
	{
		throw "$Name failed with exit code $LASTEXITCODE"
	}
}

$AppRoot = (Resolve-Path '<WebUIRoot>/<AppId>').Path
$BrowserWebUI = (Resolve-Path '<OrionBrowser>/Content/UI/WebUI/Shared').Path

Push-Location $AppRoot
try
{
	Invoke-Checked 'npm ci' { npm.cmd ci }
	Invoke-Checked 'typecheck' { npm.cmd run typecheck }
	Invoke-Checked 'test' { npm.cmd test }
	Invoke-Checked 'build' { npm.cmd run build }
}
finally
{
	Pop-Location
}

Push-Location $BrowserWebUI
try
{
	Invoke-Checked 'instant:build' { npm.cmd run instant:build -- --app $AppRoot }
	Invoke-Checked 'instant:validate' { npm.cmd run instant:validate -- --package (Join-Path $AppRoot 'dist\instant\routes\default') }
}
finally
{
	Pop-Location
}
```

## Plugin scripts

The following is what the scripts in `<OrionBrowser>/Content/UI/WebUI/Shared/package.json` actually do. In the tables, `scripts/…` and `src/…` are relative to `<OrionBrowser>/Content/UI/WebUI/Shared`; all commands run there except entries explicitly located in an App directory.

Group 1, App level, usable directly in any project:

| Entry | What it runs | Arguments and result |
| --- | --- | --- |
| `npm test` inside the App | `scripts/test-webui-app-contract.mjs`, with the current directory as the App root | No arguments. It checks the four `orionWebUI` fields, the two literal sections in `vite.config.ts`, that `src/App.vue` exists, and the forbidden styles and `<img decoding="async">` in `src`. On success it prints `Validated <AppId> WebUI app contract.` |
| `instant:build` | `scripts/build-instant-screen-package.mjs` | `--app <AppRoot>` is required (the first positional argument is also accepted); `--config <path>` defaults to `<AppRoot>/instant-screen.config.ts`; `--chrome <path>` specifies the browser. It starts a temporary dev server with the App's `vite.config.ts`, captures the DOM with headless Chrome or Edge, writes it to `<AppRoot>/dist/instant/routes/<route>/` and self-checks each package. On success it prints `InstantScreen built: <ScreenId> route=… path=…` |
| `instant:validate` | `scripts/validate-instant-screen-package.mjs` | `--package <PackageDir>` can be repeated (positional arguments are also accepted). The directory is a specific route package directory that contains `package.header`, not the App root. On success it prints `InstantScreen valid: <ScreenId> bindings=… actions=… path=…` |

Group 2, which handle only the plugin's own source and write the output to the host's `<WebUIRoot>`. The host location is determined as described in "Locating the host project" below:

| Entry | What it runs | Arguments and result |
| --- | --- | --- |
| `instant:runtime:syntax` | `node --check ./src/instant-screen-runtime/runtime.js` | Syntax check only |
| `instant:runtime:build` | `scripts/build-instant-screen-runtime.mjs` | Accepts no arguments other than the locating arguments. It bundles `src/instant-screen-runtime` and writes it to `<WebUIRoot>/__instant__/dist/runtime/` (`index.html`, `runtime.css`, `runtime.js`, `runtime-optional.js`), creating the directory if it does not exist, and prints the sha256 of each file. The source files must be CRLF; it fails if the startup script exceeds the size limit set in the script |
| `instant:runtime:check` | The same script with `--check` | Writes no files; it only compares the generated directory against the build result of the current source, and fails if the file set or the content does not match |

Group 3, project-wide validation, which scans all Apps under `<WebUIRoot>` in one pass. The location is likewise determined by "Locating the host project":

| Entry | What it runs | What it checks |
| --- | --- | --- |
| `contracts:project` | `scripts/validate-project-webui-contracts.mjs` | Every directory under `<WebUIRoot>` that contains a `package.json` (skipping `node_modules` and `dist`) must: have a `webui-button-contract.json` in which every Bridge call in the source is registered; have a valid `orionWebUI` declaration whose profile matches its lifecycle; already have `dist/assets/index-<interface-name>.js` built; have build output file names and contents that contain no preview or fixture signals, and a manifest and package header that contain no deprecated hash or digest fields; and have every `package.header` in `dist` pass package validation. In addition, `<WebUIRoot>/Shared/src` must not call the Bridge directly |
| `contracts:intents` | `scripts/validate-webui-intent-contracts.mjs` | Every first-level directory under `<WebUIRoot>` that contains a `package.json` must pass the Intent contract validation; when the host maintains an audit inventory, the discovered Apps must also match the inventory exactly |
| `images:decoding:check`, `images:decoding:fix` | `scripts/enforce-webui-image-decoding.mjs`; `fix` adds `--write` | Scans all `.vue` files and non-test `.ts` files under `<WebUIRoot>`, and fails if an `<img>` has no `decoding` attribute; `fix` rewrites the source directly and normalizes the changed files to CRLF |
| `animations:contract:check`, `animations:contract:fix` | `scripts/enforce-webui-animation-contract.mjs`; `fix` adds `--write` | Scans all `.css` and `.vue` files under `<WebUIRoot>`, rejects `prefers-reduced-motion`, `backdrop-filter:`, `mix-blend-mode:` and `filter` in `transition`, and also checks the plugin's own lifecycle source; `fix` deletes the matching declarations and rules, and rewrites every scanned file whose line endings are not all CRLF |

Group 4, which read only the plugin's own files and do not need a host project:

| Entry | What it runs | Notes |
| --- | --- | --- |
| The plugin's own `npm test` | `vitest run` with a fixed list of test files | Reads only the source and scripts under `<OrionBrowser>`. Tests that read host source, host configuration or the contracts of a named App belong to the host project, which maintains and runs them itself |
| `typecheck` under `<OrionBrowser>/Content/UI/WebUI/Shared` | Type-check shared frontend runtime source and build tools | Does not generate a sample page |
| `dev`, `build`, and `typecheck` under `<OrionBrowser>/Content/UI/WebUI/Sample`, and `<OrionBrowser>/Scripts/Build-OrionWebUI.ps1` | Develop, check or build the basic plugin sample | The build output is written to `<OrionBrowser>/Content/UI/WebUI/<AppId>/dist`, and AppId comes from the environment variable `ORION_WEBUI_APP_ID` (default `Sample`). This is not the build entry for a host App |

`scripts/test-webui-stable-packages.mjs` is not registered as an npm script: `--package <package directory>` is required, and you pass any built route package directory of the host (`<AppRoot>/dist/instant/routes/<route>`); it only reads and does not modify. It loads the plugin's TypeScript source, so it needs a Node that can run `.ts` directly (Node 22 with `--experimental-strip-types`).

Group 5, the per-App PowerShell checkers under `<OrionBrowser>/Scripts` (both Windows PowerShell 5.1 and PowerShell 7 work); the arguments are as defined by each script's own `param(...)`:

| Script | Arguments | Notes |
| --- | --- | --- |
| `check-webui-rendering-contract.ps1` | `-Path <AppRoot>` | Rendering contract: stable build output naming, literal ControlId on interactive elements, and so on. It accepts only `-Path` |
| `check-webui-button-interface-contract.ps1` | `-Path <AppRoot> -ProjectRoot <ProjectRoot>`, optionally with `-Check` or `-UpdateDocumentation` (choose one) | Based on `webui-button-contract.json`, it verifies the button markers, ControlId, click expressions and disabled conditions in the templates against the C++ dispatch, Native interfaces and guards. The source and documentation paths in the contract are all relative to `-ProjectRoot`. By default and with `-Check`, it also requires that the interface document referenced by `documentation` exists and is up to date; `-UpdateDocumentation` generates that document first and then validates. On success it prints `OK: …`; on failure it prints each `ERROR: …` and exits with 1 |

`check-component-button-contract.ps1` is loaded automatically by the button checker when the contract contains `componentControls`; it is not run on its own.

### Locating the host project

The group 2 and group 3 scripts determine the host project in the following order, regardless of where the plugin is installed:

1. The command-line argument `--project-root <dir>` (the WebUI root is taken as `<dir>/Content/UI/WebUI`) or `--webui-root <dir>`; the `--name=value` form is also accepted.
2. The environment variables `ORION_PROJECT_ROOT` and `ORION_WEBUI_ROOT`.
3. Search upward from the current working directory for the first directory that contains a `.uproject`; if none is found, search upward from the plugin directory.

- When the plugin is inside the project directory, no arguments are needed. When the plugin is installed in the engine directory, specify it explicitly: `npm.cmd run contracts:project -- --project-root <ProjectRoot>`, or set the environment variable first.
- Automatic discovery finds "the nearest ancestor directory that contains a `.uproject`". When you run inside a local workspace copy within the project directory (a draft or isolated validation directory that has no `.uproject` of its own), you must pass `--project-root <copy root>` explicitly; otherwise the validation checks the real outer project instead of the copy.
- If locating fails, the error is `Cannot locate the host project`. If a directory does not exist, the error is `Host project root was not found` or `Orion WebUI root was not found`. The message states which argument to pass.
- The App list is obtained by discovery: the first-level directories under `<WebUIRoot>` that contain a `package.json`. The host can maintain an audit inventory in `<WebUIRoot>/orion-webui-apps.json` (`{ "apps": ["<AppId>", …] }`). When the file exists, `contracts:intents` requires it to match the discovery result exactly; when it does not exist, validation uses only the discovery result. `--app-inventory <file>` can specify a different inventory, and in that case the file must exist.
- A root inventory can declare WebUI roots in other Content mounts with `additionalRoots`: each path must be relative to that inventory file. `contracts:intents` checks each root against its own local App inventory; project, image and animation checks cover every declared root. This field does not replace Unreal RuntimeDependencies: each gameplay module must stage its own dist.
- When an App's `vite.config.ts` calls `createOrionWebUIVueOptions(rootDir)`, it takes the parent of the App root directory as `<WebUIRoot>`. If the host keeps the WebUI root elsewhere, set `ORION_WEBUI_ROOT`. For components shared across Content mounts, pass their WebUI roots as the second argument array to retain the original CSS scope names.

When you add a new App:

- If the host project uses `contracts:project` or `contracts:intents`: the new App must have a `webui-button-contract.json` (see [Controls and resources](controls-resources.en.md)) and must already have completed a production build; otherwise the whole validation run fails. If the host maintains `orion-webui-apps.json`, add the new App to it.
- `images:*` and `animations:*` need no registration, but they do scan the new App. The two `fix` variants change the source of all Apps, so run them only when the user explicitly asks; normally run `check` and fix your own App by hand.
- If the host project does not use these validations, do not introduce them for the new App on your own; run only the group 1 commands.
- The host's own gates (the two-round determinism check of a Package, contract tests that read host source, npm wrapper scripts and so on) are not provided by the plugin; the entry points are as stated in the host's instruction files.

## PowerShell and command-line notes

- A failing external program does not stop a PowerShell script. After every npm / node command, check `$LASTEXITCODE`. A PowerShell script does not guarantee that it sets `$LASTEXITCODE`, so after calling a `.ps1`, check `$?` or let the failure throw; do not judge by the exit code left over from the previous native command.
- In PowerShell, write `npm.cmd`. A bare `npm` may resolve to a PowerShell shim, and `--` and the arguments after it are swallowed or interpreted by npm as its own configuration. If the arguments still do not reach the script, run the `node ./scripts/<script>.mjs …` that the script corresponds to, directly in the same directory.
- If the host wraps npm in its own `.ps1` and declares the parameter as `ValueFromRemainingArguments`, writing `& $Wrapper run instant:build -- --app …` directly swallows `--` as an argument boundary. Build a flat array first and then splat it: `$Arguments = @('run', 'instant:build', '--', '--app', $AppRoot)`, then `& $Wrapper @Arguments`. When validating several packages, append one `'--package'`, `<directory>` pair for each directory.
- To call a `.ps1` in the repository, first get the full path with `Resolve-Path` and then use `&`. Before `Push-Location`, resolve the log and evidence directories to absolute paths.
- To validate `package-lock.json`, use `Get-Content -Raw | ConvertFrom-Json -AsHashtable` (PowerShell 7 and later): `packages[""]` in the lock file is an empty-string key, and a plain `ConvertFrom-Json` reports an empty property name. On an older PowerShell, use Node's `JSON.parse` instead. Do not delete `packages[""]` for this reason.
- Vitest does not accept Jest's `--runInBand`. For a single file, use `npm.cmd test -- <relative test file>`; to reduce log output, use `--silent=true`, and do not write `--silent <file>`. Passing a file this way works only when the `test` script is `vitest run`.

## Failure signatures

| Symptom | Cause | What to do |
| --- | --- | --- |
| `typecheck` prints only `Version …`, followed by the `COMMON COMMANDS` and `COMMAND LINE FLAGS` help | `vue-tsc` did not find `tsconfig.json` in the current directory and checked no files | This is not a pass. Add `tsconfig.json`, or return to the App root and rerun |
| Vitest reports `Unknown option` | An argument the test runner does not recognize was passed | Fix the command and rerun; record it neither as a test failure nor as a pass |
| `Unknown cli config "--…"`, or the script throws `Usage: npm run instant:…` | The arguments after `--` did not reach the script | Use `npm.cmd`, or run `node ./scripts/<script>.mjs` directly |
| `ERR_MODULE_NOT_FOUND`, with `vite`, `esbuild` or `typescript` missing | Dependencies were not installed in `<OrionBrowser>/Content/UI/WebUI/Shared` | Run `npm ci` in that directory |
| `Chrome or Edge was not found; set ORION_INSTANT_SCREEN_CHROME` | There is no browser at the default install locations | Pass `--chrome <path>` or set that environment variable |
| `instant:build` reports `ENOENT` with the path pointing to `dist/index.html` | There is no production build yet | Complete step 4 first |
| `instant:validate` reports `ENOENT` with the path pointing to `package.header` | The App root was passed in | Pass `dist/instant/routes/<route>` |
| `Chromium capture did not contain a rendered #app` | In the host-less design preview, the page did not render any structure | See "Design preview" in [Web App scaffold](web-app-scaffold.en.md); do not fix it by adding waits or retries |
| `InstantScreen Runtime source must use CRLF` | The plugin Runtime source files were checked out with LF | Restore a CRLF checkout; do not change the script |
| `Generated InstantScreen Runtime is stale` or `output file set mismatch` | The generated directory is behind the plugin source | Run `instant:runtime:build`, then `check` |
| `Cannot locate the host project`, or `Orion WebUI root was not found` | The script is not run inside the project directory, or the project has no `Content/UI/WebUI` | Pass `--project-root` / `--webui-root` or set the environment variables, as described in "Locating the host project" |
| `WebUI Apps under … do not match …; update the audited inventory explicitly` | The host's `orion-webui-apps.json` does not match the Apps in the directory | Compare the two sets of names listed in the message and update the inventory |
| `declared event source was not found`, or `missing <object> = { ... } as const` | The file or object that `eventConstants` / `eventExpansions` of `intentTransport` point to does not exist | Correct `file` and `object` in the contract |
| `missing button/intent contract` | The project-wide validation found an App without `webui-button-contract.json` | Add the contract for that App |
| `vite build` reports `EPERM … unlink` or a file in use when it cleans `dist` | A file in `dist` is open in another process; commonly the preview log was written into `dist`, or an IDE or Git client is scanning it | Identify the process holding it; stop only the processes you started in this round and do not end the user's programs; rerun when it is idle |

On failure, keep the first meaningful error. Do not make a command pass by updating snapshots, skipping tests, weakening assertions, raising timeouts or editing `dist` by hand.

## Validation layers

| Layer | Method | What it can prove | What it cannot prove |
| --- | --- | --- | --- |
| Static | App contract script, project-wide validation, Studio discovery check, source and diff checks | Declarations, naming, forbidden styles, and control and Intent registration are consistent at the text level; Studio can list the pages and views and find the preview state | That the code compiles or that the page displays |
| Type check and build | `typecheck`, unit tests, production build, Package validation | The types are correct, the logic under test is correct, and the Bundle and package structure are valid and pass the build gates | Rendering, fonts, input and Bridge timing inside CEF |
| Browser preview | Vite dev or `vite preview`, plus DOM, computed styles, screenshots and console | Layout, styles and preview state switching in the host-less branch, with no script errors | The real Bridge and C++ state, presentation transactions, UE fonts and sound, Native Surface, UE input routing, off-screen transparent compositing |
| Editor designer | The WebUI control in UMG Designer | The load chain from AppDefinition through the local Scheme to `dist` or the dev server, and the CEF off-screen rendering result | Runtime behavior: Designer carries `orionDesignPreview=1`, the page does not wait for the host, and there is no authoritative state, presentation transaction or input routing of the game runtime |
| PIE | An authorized in-Editor run | The real Bridge, C++ authoritative state and Intent, presentation transactions, real keyboard, mouse and gamepad input, Native Surface, sound | Assets after Cook, whether `dist` goes into the package, and behavior and performance under the shipping configuration |
| Packaged build | An authorized packaged run | `dist` goes into the package and loads offline, and the actual behavior under the target configuration | Other platforms and configurations; pages and states that were not actually operated |

- A pass at one layer does not imply the next layer; draw a conclusion for each layer separately. A browser preview, a static DOM, a JS `.click()`, the existence of a screenshot file or a successful Web build is not evidence for Native Surface, real input or the packaged build inside Unreal.
- Use only evidence from this round: first confirm that what is being previewed or run is the `dist` you just built, and do not reuse old screenshots.
- When you rebuild the `dist` of the same App while the Editor is open, the document reloads automatically (`UOrionWebUIAppDefinition.bAutoReloadLocalDistInEditor`; the log contains `after stable local dist entry change`). This only shows that the new build output has been loaded.
- For a Web-only change, run the Web layers. When you also changed C++, a Blueprint-visible interface, assets or configuration, also compile the corresponding Unreal Target. Whether to start the Editor, PIE or a packaged build follows the host's authorization.

## Visual acceptance in a browser

1. Use this round's production `dist`: after the build, run `node .\node_modules\vite\bin\vite.js preview --host 127.0.0.1 --port <Port> --strictPort` in the App root. Do not assume a `preview` script exists, do not use `npm exec vite -- preview`, and do not modify `package.json` for one acceptance run. When you start it in the background, write both `vite.js` and the App root as absolute paths (`node <AppRoot>\node_modules\vite\bin\vite.js preview <AppRoot> …`); otherwise it may serve a different App. For handling an occupied port, see "Design preview" in [Web App scaffold](web-app-scaffold.en.md).
2. Before opening the page, request the home page first and confirm that the title and `index-<interface-name>.js` belong to the target App. If they belong to another App, stop; do not continue on the wrong page.
3. The production preview has no host, and the page takes only the host-less branch. If the preview data exists only in the DEV branch, the production preview can validate only the structure and the console; use the dev server for screens that need data, and state in the conclusion which one you used.
4. Fix the viewport to the page's design logical resolution and fix the device pixel ratio. Also take one aspect ratio other than the target and confirm that the whole page scales proportionally, with no scrollbars and no clipping.
5. Wait for the formal presentation flow to finish before taking the screenshot: use the page's own presentation state or the end of all finite animations as the criterion, and do not guess with a fixed delay. When you need an intermediate frame of a transition, label it separately.
6. Drive the screen state only through the page's preview inputs (query parameters, preview state). Do not inject CSS, change classes, or change `display` or `opacity` to force an element to be shown or hidden in order to get a screenshot.
7. Collect structured evidence with one read-only script: the bounds and computed styles of key nodes, `complete && naturalWidth > 0` for images, and console errors.
8. For text checks, use the longest copy, data with an optional field both present and absent, and the maximum number of list items: nothing may overflow, be truncated or overlap; the fixed footer and the action area stay inside the panel.
9. The computed background of `html`, `body` and `#app` is transparent, and the outermost document has no horizontal or vertical overflow.
10. Collect evidence separately for the two input devices: hover and pressed for keyboard and mouse, and focus highlight and key prompts for the gamepad. In a headless or hidden browser, moving the pointer may not trigger `:hover`; if you cannot capture it, leave it to a component test and label it honestly, and do not fake it.
11. Before clicking, confirm that the locator matches exactly one element; after clicking, read the actual state of the DOM and then take the screenshot. A JS `.click()` proves only that the handler exists, not that real input can reach it.
12. Actually open and look at the screenshot; do not only confirm that the file exists. Verify that it was generated in this round, that the extension matches the real format, and that the pixel size is correct. When you find a problem, go back to the source, change it and rebuild, and retake all the affected evidence.
13. Write screenshots and logs outside `dist` and the source directory, at the location the host specifies. When you finish, stop only the preview processes whose PID you recorded in this round, and confirm that the port has been released.

## Hand-off checklist

1. Changes: the source, `dist` and lock files you added and modified, and the UE-side C++, assets and configuration.
2. Commands: each command actually run, its working directory and its exit code; for a failure, give the first meaningful error.
3. Conclusion per layer: for each of the six layers (static, type check and build, browser preview, Editor designer, PIE, packaged build), write "verified (evidence location)", "not run (reason)" or "not applicable".
4. InstantScreen: whether the Package was regenerated after the last production build and validated package by package.
5. Project-wide validation: whether the host uses it, whether it was run, and whether the new App has completed registration (button contract, the host's App audit inventory). The exit code and report location of the Studio discovery check, and the pages and views the report lists.
6. Remaining items: states and risks that are not verified, and validation layers that need the user's authorization before you can continue; confirm that no preview process or temporary file is left behind, and that `node_modules` has not entered version control.
