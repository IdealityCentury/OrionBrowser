# Tutorial 2: WebUIStudio

WebUIStudio is the desktop tool supplied with the plugin. It does not start the game. It loads the real web source or build output from your project, replaces Unreal with a stand-in host, and lets you look at an interface page by page and state by state, inspect its controls, annotate changes on the interface itself and hand them to Codex or Claude. It is an authoring tool only and is not part of a packaged game.

[简体中文](tutorial-2-webui-studio.zh-CN.md) · [Manual index](README.md) · Related: [Tutorial 1: Build an interface with AI](tutorial-1-ai.md), [Tutorial 4: Write the interface by hand](tutorial-4-write-by-hand.md).

Interface text in this document follows the English interface of version 1.0.0.

## Start

- **From Unreal (recommended)**: click the **WebUIStudio** button on the Level Editor's main toolbar, in the same group as Add and Blueprints. Studio opens the current project and marks it as trusted.
- **Directly**: double-click `Binaries/Win64/WebUIStudio.exe` in the plugin folder and choose a `.uproject` in the dialog. A project opened this way needs one click on "Trust project".

Starting the same project again returns to the window that is already open. The message `The plugin's WebUIStudio.exe is missing` means the tool has not been prepared yet; see [installation](installation.md).

All of Studio's data is under the project's `Saved/OrionUE/WebUIStudio`: settings, caches, annotations and reports. On first start its runtime files are extracted there too. It writes no configuration into the plugin folder. Outside that folder it writes one thing into the project: its hook entries in `.claude/settings.json` when you send a request to Claude, described under [Send](#send).

## Trust and environment

**Trust.** A project that was just opened is read statically only: Studio lists interfaces and reads configuration, and runs no project code. After you click "Trust project" on the banner, Studio runs previews, installs dependencies and sends requests. Do not trust a project of unknown origin.

**Environment.** Studio brings its own Node.js and npm, so this computer does not need them installed to preview. After opening a project it checks:

| Item | Used for | When missing |
| --- | --- | --- |
| App packages | Source preview. This concerns apps that have source but no installed packages | Click "Install environment" on the banner; each app is installed from its lock file (`npm ci`), or with `npm install` when it has none |
| Codex and Claude desktop apps | Receiving the annotations and new-app requests you send | Reported only. Install and sign in yourself |
| Codex and Claude command-line tools, Git | Producing and verifying isolated drafts | Reported only. Other features keep working |

"Later" hides the banner until the next start. Press `Ctrl+K` and type "Check the environment…" to check again at any time.

## The window

| Area | Content |
| --- | --- |
| Title bar | Project menu (Open project…), command search (`Ctrl+K`), language (中 / EN), appearance (System, Light, Dark), Settings |
| Left rail | The list of apps in two groups, "Production" and "Plugin samples"; "New app" is the first row; a search field for apps, pages and views; "Scenario", "Assets & tools" and "Settings" at the bottom, and above them "Discovery report" whenever discovery has something to report |
| Context bar | Four selectors, "Page", "Scenario", "Resolution" and "Source", and "Reload preview" |
| Stage | The real page at the chosen resolution |
| Tool dock | "Browse" and four annotation tools, plus annotation pins, adjustment preview, screenshot, preview backdrop, hand and zoom |
| Right panel | Four tabs: "Annotations", "Inspect", "Draft" and "Log" |

Both side panels can be resized or collapsed. Language, appearance, layout, resolution and the last opened app are remembered.

## Open an interface

1. Click an app in the left rail. Your project's apps are under "Production"; the plugin's Showcase and Sample are under "Plugin samples".
2. An app with several pages or views has an arrow at the end of its row. Expand it and click a page or a view to open it directly.
3. Choose "Source" in the context bar:

| Source | Reads | Needs | Characteristics |
| --- | --- | --- | --- |
| Source (live updates) | The app's `src` | App packages installed | The preview updates when you save; controls can be located in source |
| Build output | The app's `dist` | A build | Exactly the files Unreal will load; no source location |

How Studio finds apps: it looks for folders named `WebUI` at any depth in the project, and each subfolder with a `package.json` (containing `orionWebUI`), an `index.html` or a `dist/index.html` is an app. So a development-only app outside `Content`, such as `Tools/WebUI/UIStyleGuide`, is listed as well. `node_modules`, `dist`, `Saved`, `Intermediate` and `Binaries` are not searched. After adding or moving an app, click "Rescan project" in the left rail.

### Resolution and aspect ratio

- "Resolution" offers 1920 × 1080, 2560 × 1440, 3440 × 1440, 1280 × 720 and "Custom…". The page always lays out at the chosen logical resolution; the window size only changes the display scale.
- A stretch grip sits outside the bottom-right corner of the preview. Drag it to change the aspect ratio; the shorter side stays the same, and it snaps near 21:9, 16:9, 16:10, 4:3, 1:1 and similar ratios. Double-click to return to 1920 × 1080.

### Zoom, move and capture

| Operation | How |
| --- | --- |
| Zoom | `Ctrl` + wheel (around the pointer), the magnifiers and slider in the tool dock, `Ctrl+=`, `Ctrl+-` |
| Back to fit | Click the zoom figure, or `Ctrl+0` |
| Move a zoomed preview | Drag with the middle mouse button, or pick the hand in the tool dock and drag with the left button |
| Screenshot | "Capture and copy" in the tool dock; the picture goes to the clipboard |

Zooming changes only the display scale. The page keeps laying out at its logical resolution.

### Preview backdrop

A game interface is drawn over the game, and most of the page is transparent. "Preview backdrop" in the tool dock decides what shows where the page is transparent: the transparency grid (default), white, black, grey, a colour of your choice, or a picture. With a screenshot of your game as the backdrop you can see at once whether text is readable over the real picture. The backdrop only lies behind the page and never enters it; screenshots carry the same backdrop.

## Where preview data comes from

Studio installs a simulated bridge for the page, so the page takes its hosted branch and waits for a state event to deliver data. Studio reads the preview state the app provides and delivers it through the state event. The preview state is looked up in this order:

1. The module and export named in `state` of `webui-preview.json`.
2. An export below `src` whose name contains both `preview` and `state` (for example `createSettingsPanelPreviewState`). It may be a constant or a function without required parameters.
3. A top-level variable named `state` in `App.vue` whose initial value is a pure literal.

With none of the three, the page opens on an empty state, and "Discovery report" in the left rail states the reason.

An app can also export a preview adapter of its own: a function named like `create…Preview…WebUIApi` that returns a bridge object owning the business state. With the "Source" source Studio gives the page that adapter for its business data and keeps the host side itself. When the app has none of the three preview states above, the discovery report lists the state source as `adapter` instead of reporting an empty state.

To deliver the data correctly, Studio also has to recognise a few names in the source, so they must be written as literals:

| Studio looks for | Written in source as |
| --- | --- |
| The state event | `"ue:<prefix>.state"` or `"ue:<prefix>.stateChanged"` |
| The state acknowledgement | `api.stateCommitted(state.stateRevision)` |
| The ready event | `"<prefix>.ready"` |

How the stand-in host differs from Unreal:

- It completes the presentation handshake, so the page becomes visible normally.
- The input device is fixed to keyboard and mouse unless a view says otherwise with events.
- Business actions the page sends with `emit` and `call` are not executed; Studio rejects them with the error code `studio.unhandledCall`. The page must catch this rejection; the Log tab records each one. A page whose buttons should respond in Studio can, after catching this code, apply the change to its own preview data, as the supplied Showcase does.
- Sounds are not played. A Native Surface is shown as a placeholder frame with its name. Runtime images and Unreal assets are shown as placeholder images.
- Access to the external network is blocked.

The "Build output" source runs no source code. A preview state that is a literal in `App.vue` can be previewed directly. One that comes from an exported module, whether a constant or a function, needs the page to be opened once with the "Source" source first: Studio caches the computed state of each of its views, and only then does "Build output" have data. The cache is invalid after anything below `src` or `webui-preview.json` changes, so open it once more.

## Views: webui-preview.json

A page often has several appearances: another language, empty data, an open dialog. Put a `webui-preview.json` in the app root and register them as views, and each can be opened from the left rail. The file is pure data: Studio reads it and never executes it, and it does not go into `dist`.

For the settings panel the tutorials share:

```json
{
	"schemaVersion": 1,
	"views": [
		{ "id": "default", "route": "", "title": "Default" },
		{ "id": "chinese", "route": "", "title": "Chinese", "patch": { "culture": "zh-Hans" } },
		{ "id": "muted", "route": "", "title": "Volume 0", "patch": { "volume": 0 } }
	]
}
```

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Always `1` |
| `state.module`, `state.export`, `state.args` | Optional. The module below `src/` that holds the preview state, the export name, and the arguments to call it with |
| `views[].id` | Identifier of the view: letters, digits, `_`, `-`; unique within the app |
| `views[].route` | The route the view belongs to. An app without routes uses the empty string |
| `views[].title` | The name shown in the list |
| `views[].args` | The arguments the preview state is called with for this view |
| `views[].patch` | An object merged over the preview state. Objects merge level by level; arrays and other values are replaced |
| `views[].events` | Events the host sends the page while this view is shown: `name`, `payload`, and an optional moment `at` (`"afterReady"`, `"afterPresented"`, `"afterStateCommitted"` or a number of milliseconds) |
| `views[].enter`, `views[].leave` | Intent names, for InstantScreen pages. When the page requests one of them with `requestIntent`, the preview moves to this view or back to the view it came from. Actions sent with `emit` or `call` do not switch views |
| `intents` | Answer rules that hold for the whole interface, used by `requestIntent` of InstantScreen pages |

- The first view of a route is the default one when the page is opened.
- For a view that differs in a field or two, use `patch` instead of adding a parameter to the preview state.
- The supplied Showcase registers twenty-four views in its `webui-preview.json`; its gamepad view sends the input device and key prompts with `events`, and can serve as a reference.

For an app that does not use InstantScreen, also add an `instant-screen.config.ts` that only declares "no additional pages". Without it the [discovery check](#command-line-checks) reports that it cannot read this file:

```ts
export default {
	"screens": []
} as const;
```

## Scenarios

"Scenario" in the context bar defaults to "Live preview from project source": it is generated from the current source every time. A page with registered views has one such scenario per view, named after the view.

When you need a special state that the source does not provide, open "Scenario" at the bottom of the left rail and edit the JSON directly: the initial state, the answer rules for actions, and events sent on a timeline. After "Validate and save" it becomes a custom scenario stored under `Saved/OrionUE/WebUIStudio/scenarios`, selectable in the context bar. A custom scenario is an optional override and does not affect the live preview.

"Completed" and "rejected" in a scenario are simulated. They do not mean the game logic would answer that way.

## Inspect and Log

**Inspect tab.** Click a control with the Element tool. The right panel shows its control Id ("Not declared" when it has none), page, size, source file and line, component chain and matched style rules. "Open in editor" opens the source file with the system's default program. Source location is available with the "Source" source only.

**Log tab.** Every message between the page and the host, newest first, filterable by "All", "Warnings" and "Errors":

| Direction | Meaning |
| --- | --- |
| `UE→Web`, `Web→UE` | Events the host sends the page, and actions the page sends |
| `Result` | The answer to an action. An action that is not simulated appears here as an error |
| `Check` | Checks such as revisions, for example an acknowledgement whose revision differs from the one sent |
| `Console` | The page's `console` output |
| `Network` | Blocked external requests |
| `Vite`, `Host` | Information from the development server and from the host itself |

Uncaught errors, unhandled Promise rejections and `console.error` in the page count as errors, and so do rejected actions. The Log tab is then marked with a red dot, and the panel shows "Errors: N".

**Assets & tools.** "Assets & tools" at the bottom of the left rail shows the asset status of the current preview ("Assets in this preview"), the dependency versions of the app and the versions of Studio's own runtime. Its "Editor asset snapshot" can export the real fonts and text table from a running Editor. This needs a local MCP service on the Editor side that offers an `ExportRuntimeSnapshot` tool; the OrionBrowser plugin itself does not include that service. Without a snapshot the preview uses fallback fonts and placeholder images, and the context bar says "Fallback fonts and assets".

## Annotate and send to an agent

Studio can hand "this should change like so" to Codex or Claude together with the control's location, screenshots and source line, so you do not have to describe the place in words. Requirements: the project is trusted, and the desktop app of that service is installed and signed in.

### Annotate

Choose a tool in the tool dock, or press `Ctrl+.` to toggle the annotation tool you used last:

| Tool | Operation | Recorded |
| --- | --- | --- |
| Element | Click a control; press and drag to mark an area instead | The control and its source location |
| Pin | Click anywhere | A point and the control under it |
| Area | Drag a rectangle | The area and the controls inside it |
| Draw | Press and draw freely | The stroke and the controls within it |

A popover appears next to the target:

- Write "What should change here?", press `Enter` to save, `Shift+Enter` for a new line, `Esc` to cancel.
- While the comment is empty, the Element tool moves to the parent or the first child control with `↑` and `↓`.
- For a single control you can open "Adjust properties" and change text, colour, background, opacity, font, size, weight, line height, letter spacing, alignment, padding, margin, gap, width and height, corner radius and border directly. Changes take effect in the preview at once and are recorded as "property: old value → new value". **These adjustments apply to the preview only; Studio does not change source.** They travel with the annotation as target values for the agent.

Saved annotations show a number on the page. In the "Annotations" tab of the right panel you can show them on the page, edit them, give them a new target ("Re-anchor"), delete them and view their screenshots. One batch holds at most 30. After a page reload, a source change or the removal of the target, an annotation is marked "Needs re-anchoring", and you must choose the new target explicitly.

While an annotation tool is active, clicks do not reach the page. Switch back to "Browse" to operate the page.

### Send

1. Write the overall request for this batch at the bottom of the right panel.
2. Click "Send to" and choose the service (Codex or Claude) and the kind:

| Kind | Where changes are made | Note |
| --- | --- | --- |
| Continue Studio chat | Directly in the current project | Continues the chat Studio started last; a new one is created if there is none |
| New Studio chat | Directly in the current project | Opens a new chat for this project in the desktop app |
| Existing conversation | Directly in the current project | Pick a conversation that belongs to this project from the list |
| Isolated draft | A copy kept by Studio | A command-line tool produces a candidate, and you apply it after review; see [Isolated drafts](#isolated-drafts) |

3. Adjust if needed: model and reasoning effort; the scope of changes (styles only, shared components allowed, entry and bridge files allowed); "Plan mode" (this round only investigates and writes a plan, changing no files).
4. Click "Send annotations".

You can also send without annotations: the field becomes a request for this page and the button becomes "Send page request". This asks the agent to change the whole page on stage, and Studio attaches the page information and a screenshot. A page request cannot use an isolated draft.

A request sent to a chat automatically asks the receiver to read the creation Skill shipped with the plugin first, and states where the Skill is on this computer.

You can keep working after sending. The delivery records in the right panel show the state of each one: preparing, queued, submitted, in progress, plan awaiting confirmation, completed, failed and so on. When the receiver has changed the source, the preview shows the result through live updates. "Stop tracking" only ends Studio's wait for that record; **it does not stop a task the desktop app has already started**.

Two things to know:

- What was sent in each batch is frozen in `Saved/OrionUE/WebUIStudio/annotations/batches/<batch>/`: `context.json`, `annotations.md`, `prompt.md` and the screenshots. Changing annotations afterwards does not alter what was sent.
- Every time you send to Claude, Studio makes sure its own hooks are registered in the project's `.claude/settings.json`; it needs them to receive the reply. The file is written the first time and whenever those entries have to change. The previous file is backed up under `Saved/OrionUE/WebUIStudio/bridge/backups`, and other hooks are left as they are. `.claude/settings.json` is normally shared through version control, while the program these hooks start lives under `Saved`; look at this change before you commit it.

## New app

"New app" in the first row of the left rail (also in command search) opens a sheet:

1. Write the "Description": what to build, what it shows, what can be done in it. See [Tutorial 1](tutorial-1-ai.md#step-3-create-the-interface-with-a-prompt) for how to write it.
2. "App name" is optional: it starts with a capital letter and contains only letters and digits, is used as the AppId, and must not match an existing app. Left empty, the receiver names the app.
3. Choose Codex or Claude, and a new chat or the Studio chat.
4. Click "Send to …". Or click "Copy prompt" and paste the complete prompt into any conversation.

The prompt Studio builds has a fixed order: first the instruction to read the creation Skill completely, with its location; then your app name and description, the list of apps already in the project, and the delivery requirements. With "Plan mode" on, the delivery requirements become "write an implementation plan only; create or change no files".

When the receiver reports completion, Studio rescans the project and the new app appears in the left rail. Studio itself creates no files and no Unreal assets; the receiver lists the steps that remain to be done in the Editor.

## Isolated drafts

When you want to see a change before deciding on it, use an isolated draft:

1. Add annotations, choose "Isolated draft" of Codex or Claude under "Send to", and click "Generate isolated draft".
2. Studio copies the app to `Saved/OrionUE/WebUIStudio/drafts`, lets the command-line tool change the copy, and then runs the app's own type check, tests and build.
3. Review the differences in the "Draft" tab. You can preview the draft side by side with the original project.
4. When satisfied, click "Apply to project". Afterwards you can "Undo this apply". Both first check whether someone else changed the files, and neither overwrites on a conflict.
5. After applying, you can click "Rebuild this app's dist".

Limits:

- All annotations must belong to the same app and come from the "Source" source.
- A draft may change only the source files the annotations located, plus shared components and entry or bridge files when you allowed them. They must be `.vue`, `.ts`, `.js`, `.css` or `.json` files in a `src` folder below the project's `Content/UI/WebUI`. A draft that changes anything else is rejected as a whole, and a draft cannot be applied to an app stored elsewhere.
- The command-line tool of the service and Git are required.

## Command-line checks

The same program can run two checks without its editor interface, which suits agents and scripts. The discovery check opens no window. The view check opens a window that does not take focus and closes by itself; you can keep working while it runs, but do not minimise it. Both write their reports under `Saved/OrionUE/WebUIStudio/checks`.

**The discovery check** only reads files, runs no project code and does not need the project to be trusted:

```powershell
$Studio = (Resolve-Path 'Plugins/OrionBrowser/Binaries/Win64/WebUIStudio.exe').Path
$Project = (Resolve-Path 'MyGame.uproject').Path
$Arguments = @('--project', "`"$Project`"", '--check-discovery', '--app', 'SettingsPanel')
$Process = Start-Process -FilePath $Studio -ArgumentList $Arguments -Wait -PassThru
$Process.ExitCode
```

| Exit code | Meaning |
| --- | --- |
| `0` | The chosen app has no finding of level `error` |
| `3` | The report contains an `error` |
| `1` | It could not run |

The program prints nothing to the console; the verdict is the exit code and `report.json`. Check item by item: `apps[].pages` lists every page, the `views` of each page list every view, and `previewState.source` is not `none`. `--app all` checks every app in the "Production" group, `--locale zh-CN` or `en` sets the report language, and `--report <dir>` sets the report location.

**The view check** really runs the page, opening and capturing every view:

```powershell
$Arguments = @('--project', "`"$Project`"", '--check-views', '--app', 'SettingsPanel')
$Process = Start-Process -FilePath $Studio -ArgumentList $Arguments -Wait -PassThru
$Process.ExitCode
```

Exit code `0` means every view opened and the page reported no error; otherwise it is `1`. Common arguments:

| Argument | Effect |
| --- | --- |
| `--mode dist` | Checks the build output; source is the default |
| `--click-control <control Id>` | Does one thing instead of going through every view: opens one view, clicks that control with a real mouse click and waits for the expectation of the next row. `--click-index <n>` chooses among several controls with the same Id, counting from 0 |
| `--route <route>`, `--view <view id>` | With `--click-control`: the page and the view to open before the click. Without it they do not narrow the check |
| `--expect-view <view id>`, `--expect-state <path>=<value>` | The view the preview should move to after the click, or a value that should appear in the state. With neither, the check waits for a new state revision |
| `--backdrop grid`, `#RRGGBB` or a picture file | The preview backdrop for this one check |

A click check can only pass when the preview answers the click: an intent of an InstantScreen page that has an answer rule or moves between views. Business actions sent with `emit` or `call` are rejected in Studio, so their effect cannot be checked this way.

The check only decides that the page rendered content and that the expectation holds, not that it looks right. Open the screenshots and look at them.

## Shortcuts

| Keys | Effect |
| --- | --- |
| `Ctrl+K` | Command search: tools, apps, pages, views, language, appearance |
| `Ctrl+.` | Toggle the annotation tool used last |
| `Ctrl` + wheel, `Ctrl+=`, `Ctrl+-` | Zoom the preview |
| `Ctrl+0` | Fit the preview to the window |
| Middle-button drag | Move a zoomed preview |
| `Enter`, `Shift+Enter`, `Esc` | Save an annotation, new line, cancel |
| `↑`, `↓` | With the Element tool: select the parent or a child control |
| `Ctrl+Enter` | Send from the overall request or the app description |

## Data and cleanup

| Folder under `Saved/OrionUE/WebUIStudio` | Content |
| --- | --- |
| `settings.json`, `trust.json` | Settings and the trust record |
| `scenarios`, `seeds` | Custom scenarios and the preview state cache |
| `annotations`, `creations` | Annotations and sent batches; new-app requests |
| `drafts`, `jobs` | Isolated drafts and verification records |
| `checks` | Reports and screenshots of the command-line checks |
| `cache`, `screens`, `runtime` | Caches, screenshots and the extracted runtime files |

"Local data" in Settings first lists what can be removed and then removes it: only caches left by closed previews and screenshots older than a day that no annotation refers to. Annotations, delivery records, drafts and exports are not removed.

`Saved` is normally not in version control, so this data does not travel with the project. To delete the whole folder by hand, close Studio first. If you ever sent a request to Claude, the hooks in the project's `.claude/settings.json` whose `statusMessage` is `Orion WebUI Studio bridge` point to a program in the `runtime` folder; remove those hooks before deleting it.

## What Studio cannot prove

What you see in Studio is the page under a stand-in host. The following must be verified in Unreal:

- Blueprint or C++ logic, the state round trip and saved data
- Real keyboard and gamepad routing, and IME input
- Control sounds and business sounds
- Native Surface, runtime images, Unreal fonts and text tables
- WorldUI projection and interaction
- Readability where the transparent page lies over the real level (the preview backdrop is an approximation)
- Performance, and whether the package contains all files

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| My app is not in the left rail | Its folder is not below a folder named `WebUI`, or it has none of these: a `package.json` containing `orionWebUI`, an `index.html`, a `dist/index.html`. Correct that and click "Rescan project" |
| "Source" cannot be selected | The app's packages are not installed; use "Install environment" or run `npm ci` in the app folder |
| "Build output" cannot be selected | There is no `dist/index.html`; run `npm run build` |
| It opens on an empty state | No preview state is available; read "Discovery report" and add one as described in [Where preview data comes from](#where-preview-data-comes-from) |
| Data in a browser, none in Studio | The preview data exists only in the no-host branch; export it as a preview state |
| "Build output" has no data | The preview state comes from an exported module and no cache matches the current source; open the "Source" source once first |
| `studio.unhandledCall` appears in the log after clicking a button | Normal: business actions are not executed in Studio. The page should catch the rejection |
| The discovery check exits with 3 and reports that it cannot read `instant-screen.config.ts` | Add a file with empty `screens` as described under [Views](#views-webui-previewjson) |
| Sending is not possible | The project is not trusted, or the desktop app is not installed or not signed in. For an existing conversation, the receiver must be idle with an empty input field |
| An annotation says "Needs re-anchoring" | The page or the source changed; use "Re-anchor" to choose the target explicitly |
