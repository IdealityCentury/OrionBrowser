# WebUI Studio preview contract

Make a new App fully discoverable in the WebUI Studio that ships with the plugin (`<OrionBrowser>/Binaries/Win64/WebUIStudio.exe`): every page and sub-interface is listed, and each opens with preview data. For the project skeleton, see [Web App scaffold](web-app-scaffold.en.md); for the route configuration, see [InstantScreen](instant-screen.en.md); for the build order, see [Build and validation](build-validation.en.md).

## How Studio discovers an App

Studio only reads files and runs no project code: during discovery it parses source and configuration statically. When something is written in a way it cannot read, the result is an App that does not appear, a missing page, or a page that opens and stays on an empty state, not an error.

| What Studio needs | Where it reads it | How it has to be written |
| --- | --- | --- |
| The App itself | Below a directory named `WebUI` at any depth in the project, the directory holding a `package.json` with an `orionWebUI` declaration (or an `index.html`, or a `dist/index.html`) | `orionWebUI.appId` is the AppId; `node_modules`, `dist`, `Saved`, `Intermediate`, `Binaries` and directory links are not searched |
| Source preview | `src/main.ts`, and the App's own `node_modules` (with Vite) | Without installed dependencies only `dist` can be previewed |
| Pages (routes) | `screens` in `instant-screen.config.ts`, and `dist/instant/routes/<route>/package.header` | The configuration is a pure literal `export default { ... } as const;`: only strings, numbers, booleans, arrays and objects with plain keys; no variable references, no spreads, no function calls, no computed property names. Every route has to be built into a `package.header`, with the same `screenId` in both places |
| State event, acknowledgement and revision field | `cpp.stateChangedEvent` and `cpp.stateAcknowledgementEvent` in `webui-button-contract.json`; without them, matched from literals in the source | Write event names as string literals (`"ue:<prefix>.stateChanged"`, `"<prefix>.stateApplied"`), not concatenated; the page acknowledges with `stateCommitted(<state>.stateRevision)` |
| Preview state | A preview state exported below `src`, or the export named in `webui-preview.json` | See "Preview state" |
| Views | `views` in `webui-preview.json` | See "Views" |

An App without `instant-screen.config.ts` has a single page whose route is the empty string.

## Preview state

Studio installs a simulated Bridge for the page: the `api` that `resolveOrionWebUIForMount()` returns exists, so the page takes its hosted branch and waits for the state event to deliver a snapshot. Preview data that is loaded only when `api` is `undefined` therefore never appears in Studio; Studio has to obtain that data itself and deliver it through the state event. Every App exports a preview state:

- Put it in a module of its own below `src`, for example `src/model/<interface-name>-preview.ts`. The page's host-less fallback branch loads the same module with dynamic `import()`, and the production entry does not import it statically; Studio loads the module straight from source, whether or not it ends up in `dist`.
- The export name contains both `preview` and `state` (case-insensitive), for example `create<AppId>PreviewState`. The export may be a constant or a function; a function may return a Promise.
- Its shape matches the full state snapshot C++ publishes, and it survives a `JSON.stringify` round trip: no functions, `Map`, `Set`, class instances or circular references. Studio rewrites the revision field, so any value will do.
- Every parameter of the function has a default. Studio does not know what to pass when it calls it: an export with a required parameter is skipped, and the page stays on an empty state. When arguments really are needed (a scenario name, for example), state them in `state.args` or in each view's `args` in `webui-preview.json`.
- In an App with several routes, take the current route from `window.location.hash` (`#/<route>`) in a default parameter and return the state for that route; Studio fetches the data with the page's route in place.
- Get the URLs of images, fonts and the like through Vite asset imports, from files below the App's `src` or `<WebUIRoot>/Shared/src`; when Studio previews `dist`, it replaces them with cached copies.

```ts
import type { SamplePanelState } from "./sample-panel-state";

/** Sample snapshot shared by the design preview and WebUI Studio; the page does not load this module when a native host exists. */
export function createSamplePanelPreviewState(view = "main"): SamplePanelState {
	return { stateRevision: 1, ready: true, view, title: "Sample Panel", rows: [] };
}
```

- When one App has several exports that fit the naming, Studio guesses one by name and says so. To settle which one is used, name it in `state` in `webui-preview.json`.
- Studio accepts two other sources as well, which only suit very small pages: a top-level variable named `state` in `App.vue` whose initial value is a pure literal (`ref({ ... })` and the like; an initial value with a function call in it cannot be read); or a preview Bridge adapter exported under a name of the form `create…Preview…WebUIApi`, which supplies the state and simulates the interaction itself.

## Views

There are two ways to build a sub-interface, and Studio treats them differently:

- A page of its own becomes a route: one entry each in `screens` in `instant-screen.config.ts`. Studio lists every route as a page, and nothing else has to be declared. Prefer this for a new interface.
- A sub-interface that is switched by state within one route (C++ publishes a field such as `view` in the same snapshot, and the page shows a loadout page, an options page or the states of a HUD accordingly). Routes do not reveal these. Studio calls them views, and each one has to be declared in `webui-preview.json` in the App root; otherwise the list shows only the routes and the sub-interfaces cannot be found.

`webui-preview.json` is pure data that Studio only reads and never executes; it does not go into `dist` and is not packaged with the game.

```json
{
	"schemaVersion": 1,
	"state": {
		"module": "src/model/sample-panel-preview.ts",
		"export": "createSamplePanelPreviewState"
	},
	"views": [
		{ "id": "main", "route": "panel", "title": "Main panel", "args": ["main"] },
		{
			"id": "detail",
			"route": "panel",
			"title": "Detail",
			"args": ["detail"],
			"enter": ["samplePanel.openDetailRequested"],
			"leave": ["samplePanel.detailBackRequested"]
		},
		{ "id": "options", "route": "panel", "title": "Options", "args": ["main"], "patch": { "view": "options" } },
		{
			"id": "confirm",
			"route": "panel",
			"title": "Confirmation dialog",
			"events": [
				{
					"name": "ue:samplePanel.confirmChanged",
					"payload": { "presentationRevision": "$presentationRevision", "title": "Leave now?" }
				},
				{
					"name": "ue:samplePanel.confirmEnterRequested",
					"at": "afterReady",
					"payload": { "presentationRevision": "$presentationRevision" }
				}
			]
		}
	],
	"intents": [
		{
			"match": { "name": "samplePanel.tabChangeRequested" },
			"response": { "status": "completed", "code": "preview.tabChanged" },
			"statePatch": { "activeTab": "$payload.tabId" }
		}
	]
}
```

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Always `1` |
| `state.module`, `state.export` | The module that holds the preview state (relative to the App root, a `.ts` or `.js` starting with `src/`, with forward slashes) and the export name. Optional; when omitted, the export is looked up by the naming rule in "Preview state" |
| `state.args` | The arguments the preview state is called with when no view says otherwise; a JSON array |
| `views[].id` | Identifier of the view: letters, digits, `_`, `-`, unique within the App |
| `views[].route` | The route the view belongs to; it has to be one of the routes this App declares |
| `views[].title` | The name shown in the list; write the name of the interface as the player sees it |
| `views[].args` | The arguments the preview state is called with for this view; `state.args` when omitted |
| `views[].patch` | An object merged over the preview state: objects merge level by level, arrays and other values are replaced whole. Use it when a view differs in only a field or two, instead of adding a parameter to the preview state for it |
| `views[].enter` | The page enters this view when it sends one of these Intents |
| `views[].leave` | The page returns to the view it came from when it sends one of these Intents in this view |
| `views[].events` | Events the host sends the page while this view is shown, for what is not part of the state snapshot. Each has an event `name`, a `payload` and an optional moment `at` |
| `intents` | Rules for answering Intents that hold for the whole interface, on every page and view |

- A view belongs to one route. The same sub-interface reachable from two routes is declared once for each, with different `id`s. The first view of a route is the default one when that page is opened.
- When a route has two or more views, Studio lists them under that page, and the scenario menu has them too; choosing a view reopens the preview with its state.
- Register only the Intents that switch views in `enter` and `leave` (the event names match the literals the page passes to `requestIntent`). When the page sends one, Studio answers `completed` and delivers the state of the target view, and the page switches through its normal state update; every other unregistered Intent is still rejected, and Studio does not fake success for business writes. A view that native input switches without the page sending an Intent (an options page opened with the back key, for example) has no `enter` and is opened from the list.
- `args` mean nothing when the preview state is a constant; tell the views apart with `patch`.

Some sub-interfaces are not decided by the state snapshot but driven by an event the host sends separately (the descriptor of a general confirmation dialog, an interaction progress ring in the world). Write the events of such a view out in `events`:

- An event without `at` is there for the page from the start, like the latest event a host retains, and the page receives it when it subscribes. An event with `at` is sent at that moment: `"afterReady"` (after the page has called `ready()`), `"afterPresented"` (after the presentation is complete), `"afterStateCommitted"` (after the page has acknowledged the initial state), or a number of milliseconds after `ready()`. Choose by the timing of the real host: leave `at` out for descriptor and data events, and use `"afterReady"` for events such as an entrance request that a page only gets once it is ready.
- The text `"$presentationRevision"` in a payload is replaced by the revision of the presentation the preview is showing. When the page checks presentation transactions by revision, use it for the revision in an event payload instead of a fixed number.
- Of several events without `at` that share a name only the last one is kept. When the page moves into a view with events from another view through `enter`, the events are sent at once in the order declared; they are not taken back when the view is left.

`intents` make actions in the page get an answer in the preview. A rule has three parts: `match` names the Intent (`name`, or an array `names`; `payload` can narrow it to payload fields and `controlId` to a control), `response` is the receipt the page gets (`status` is `completed` or `rejected`, plus a `code`), and `statePatch` is an object that is then merged into the current state and delivered again, in which `"$payload.<field>"` takes a field from the payload of the page's request.

- Write rules only for actions the page can be simulated faithfully for: switching a tab, selecting an entry, expanding and collapsing, where one field of the state follows the request. Do not make an Intent succeed when it stands for a business result such as accounts, inventory, matchmaking or purchases; leave it rejected.
- Rules are matched in the order declared and the first match applies; a custom scenario the user saves in Studio can carry rules of its own. An Intent with no rule that is not a view switch either is always rejected.
- Rules answer `requestIntent` only. Business events the page sends with `emit` or `call` do not pass through `intents`: the mock Bridge answers only lifecycle and acknowledgement events and rejects the rest with the error code `studio.unhandledCall`. The page has to catch that rejection; a page whose business channel is `emit` (the Showcase sample shipped with the plugin) switches to its own preview imitation when it receives that code, while in the game only the host changes state.

## Discovery check

The Studio program has a read-only check of its own. It opens no window, runs no project code, does not require the project to be trusted, and can run while Studio is open:

```powershell
$Studio = (Resolve-Path '<OrionBrowser>/Binaries/Win64/WebUIStudio.exe').Path
$Project = (Resolve-Path '<ProjectRoot>/<ProjectName>.uproject').Path
$Report = Join-Path (Split-Path $Project) 'Saved\OrionUE\WebUIStudio\checks\discovery\<AppId>'
$Arguments = @('--project', "`"$Project`"", '--check-discovery', '--app', '<AppId>', '--report', "`"$Report`"")
$Process = Start-Process -FilePath $Studio -ArgumentList $Arguments -Wait -PassThru
$Process.ExitCode
Get-Content -Raw -Encoding UTF8 (Join-Path $Report 'report.json')
```

- The program prints nothing to the console; the verdict is the exit code and the report file only: `0` passed; `3` the report has findings of level `error`; `1` it could not run. When the file `--project` points to does not exist, the program first shows a message box and waits for it to be confirmed, so obtain the path with `Resolve-Path`.
- `--app <AppId>` checks one App, and a misspelled name gives a report with the single finding that the app is not registered in the project; `--app all`, or no `--app`, checks every production App, and a problem in any other App of the project also turns the exit code into `3`. `--locale zh-CN` or `--locale en` sets the language of the report text. Without `--report` the report is written to `<ProjectRoot>/Saved/OrionUE/WebUIStudio/checks/discovery/<timestamp>/report.json`.
- Check the report item by item: whether `apps[].pages` lists every route, and whether the `views` of each page list every sub-interface (the `events` of each view and the `intents` of the interface are listed there too); `previewState.source` is `manifest` (named in `webui-preview.json`), `export` (found by name), `adapter` or `component`, and must not be `none`; `findings` has no `error`. A finding of level `note` is only an explanation, for example that the AppDefinition asset is not in the App directory.

| Finding in the report | Cause | What to do |
| --- | --- | --- |
| No preview state is available | No export below `src` fits the naming, and the initial state in `App.vue` is not a literal either | Export one as described in "Preview state" |
| The preview state export has required parameters | The export is a function with a required parameter | Give the parameters defaults, or write `state.args` and each view's `args` in `webui-preview.json` |
| `webui-preview.json` cannot be used | It is not valid JSON, or a field does not fit the table above | Correct the field the message names |
| The preview state module does not exist, or does not export a name | `state.module` or `state.export` is wrong | Change them to the real path and export name in the source |
| A view names a route this interface does not declare | `views[].route` differs from `route` in `instant-screen.config.ts` | Change it to a declared route; use the empty string for an App without that configuration file |
| Duplicate view id | Two views have the same name | Change them to unique `id`s |
| Views give `args`, but the preview state export is not a function | A constant takes no arguments, so every view gets the same state | Turn the export into a function, or use `patch` instead |
| `package.header` is missing, or source and build output disagree on the ScreenId | The Package was not rebuilt after `instant-screen.config.ts` changed | Run the production build, `instant:build` and `instant:validate` again |
| The config has an executable expression | `instant-screen.config.ts` is not a pure literal | Change it back to pure data |

The discovery check proves only that Studio can list the pages and views and can find the preview state. That a view really shows, and that a registered Intent really switches, is proved by the view check below; behavior in the game is verified separately.

## View check

The same program can also open every view for real. It runs the page's code and opens a window that does not take focus and closes by itself when done; a source preview needs the App's dependencies to be installed. It is a run-time verification, so whether to run it follows the host project's authorization.

```powershell
$Report = Join-Path (Split-Path $Project) 'Saved\OrionUE\WebUIStudio\checks\views\<AppId>'
$Arguments = @('--project', "`"$Project`"", '--check-views', '--app', '<AppId>', '--report', "`"$Report`"")
$Process = Start-Process -FilePath $Studio -ArgumentList $Arguments -Wait -PassThru
$Process.ExitCode
```

- It opens the preview page by page and view by view, waits for the page to be ready, saves a screenshot into the report directory, and records in `report.json` whether the page rendered content, the start of its text, and the page's errors. Page errors are uncaught exceptions, unhandled Promise rejections and `console.error` output; a single one fails that item. For a view with `enter`, it then has the page send that Intent itself and checks that the preview moves to the view; with `leave`, that it moves back. Exit code `0` means every item succeeded and the page reported no error; `1` means something failed, and the reason is in the item's `error` and `pageErrors`.
- With `--view <view id> --click-control <ControlId>` it does one thing only: it opens that view, presses the control with a real mouse click, and waits for `--expect-view <view id>` or `--expect-state <state path>=<value>` to hold. When several controls share a ControlId, pick one with `--click-index <index>` (from 0); in an App with several routes, name the page with `--route <route>`. Use it to confirm that the control behind an `enter` and the rules in `intents` are really wired up, for example `--expect-state activeTab=events` after pressing the second tab.
- Where a page paints nothing it is transparent; Studio shows the preview backdrop there, and the screenshots are put on the same backdrop. The default is a dark transparency grid. Add `--backdrop grid`, `--backdrop #RRGGBB` or `--backdrop <a PNG or JPG file>` to choose the backdrop for this one check, for example a screenshot of the game to see whether the text can be read on the real picture; it applies to this check only and does not change the choice saved in the project. The backdrop lies behind the page and never enters it: an interface drawn over the game stays transparent, and a page is not given a background just to be readable in Studio.
- Open the screenshots and look at them. The check only decides that the page rendered content and that the expected view or state holds, not that the picture is right.

## Checklist for a new App

1. The App is below a directory named `WebUI`, and `package.json` has `orionWebUI.appId`.
2. `instant-screen.config.ts` is a pure literal; every route has been built into a `package.header`.
3. There is a preview state export below `src`: its name contains `preview` and `state`, it has no required parameter, and it returns a full, serializable state; with several routes it takes the route from `location.hash`.
4. Every sub-interface switched by state within one route is in `views` in `webui-preview.json`; the Intents that switch them are registered in `enter` and `leave`. A sub-interface driven by a separate event is registered with `events`; an in-page action such as switching a tab has a rule in `intents`.
5. The discovery check exits with `0` for this App, and the pages and views in the report are the expected ones.
6. When authorized, run the view check; it exits with `0`, and every screenshot has been opened to confirm the view shows what is expected; for an interface drawn over the game, the backdrop shows in the screenshot wherever the page is transparent.
