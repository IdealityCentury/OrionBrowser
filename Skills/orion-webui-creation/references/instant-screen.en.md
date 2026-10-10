# InstantScreen integration

InstantScreen lets the interfaces on the same layer share one resident Runtime Browser. Each interface carries a first-frame package produced at build time, and a presentation transaction decides whether it is visible (Reveal happens only after state, resources, input and the first frame have all been confirmed exactly). Placeholders: `<OrionBrowser>` is the directory that contains `OrionBrowser.uplugin`, `<ProjectRoot>` is the directory that contains the `.uproject`, `<WebUIRoot>` is `<ProjectRoot>/Content/UI/WebUI`, and `<AppId>` is the PascalCase name of the App directory. The plugin's package validation, shared Runtime output and Scheme all resolve against `<WebUIRoot>/<AppId>`. For how the Runtime Builder finds the host project, see "Locating the host project" in [Build and validation](build-validation.en.md).

Adjacent topics are only pointed to here: for the Web project, see [Web App scaffold](web-app-scaffold.en.md); for the page-side Bridge, state channel, presentation ACK, and entrance and exit, see [Bridge and lifecycle](bridge-lifecycle.en.md); for hosts that do not use InstantScreen, see [UE-side host](native-host.en.md); for validation layers and the hand-off, see [Build and validation](build-validation.en.md).

## Choosing it, and the no-prewarm contract

- Use InstantScreen for: formal pages that enter the CommonUI layer stack (menus, settings, popups) and the resident HUD composition layer, when you need "show only after loading is complete", covering and restoring, an input lease, or sharing a Browser with other Web pages on the same layer.
- Use a plain WebUI Widget (a `UOrionWebUIWidget` that owns its Browser) for: an interface that does not enter the layer stack, has an independent lifecycle and does not need a presentation transaction.
- The no-prewarm contract is binding on every InstantScreen page:
	1. A Browser is created only by a real Show request. Catalog registration, Runtime Host construction, GameFeature activation and loading screens only register configuration. `AcquireRuntimeLease()` is retired and always returns `false`; Catalog validation rejects the `DedicatedResident` mode.
	2. While the target page is being prepared, keep the previous valid frame or the Native Cover (the host's loading mask). Do not create a hidden Browser, a hidden iframe or hidden route DOM, do not prefetch other routes, and do not run animations before the page is visible.
	3. The only exception is the startup Shell preparation `UOrionInstantScreenSubsystem::RequestStartupShellWarmup(Owner, RuntimeId)`. It is enabled explicitly by `[OrionBrowser] bEnableStartupShellWarmup` in the Engine ini or by the command line `-OrionWebUIStartupWarmup=1`. Each GameInstance accepts it only once, and only for the primary LocalPlayer. The Owner must be a `UUserWidget` that has registered a Catalog with that same object, and the selected Runtime must use `Shared` mode with `RetainUntilLayoutRelease` retention. It only prepares the Runtime Shell and creates no business Screen, and it yields immediately when a real Show arrives. A business interface must not build its own prewarm on this model.

## Layers, Runtime and root layout

Layer-to-Runtime mappings are supplied explicitly by the host's `UOrionInstantScreenCatalog.RuntimeProfile`. The plugin installs no game layers or default mappings. Each Screen's layer must be declared in its Profile. Registered Catalogs sharing a `RuntimeId` must agree on Mode, Host, retention policy and effective idle timeout.

The following is an optional configuration example. The host defines the LayerTags and may choose its own RuntimeId and RuntimeHostId values, keeping them consistent between the Profile and Runtime Host.

| LayerTag | RuntimeId | RuntimeMode | RuntimeHostId | RetentionPolicy | Typical composition |
|---|---|---|---|---|---|
| `<GameLayerTag>` | `GameRuntime` | `DedicatedOnDemand` | `GameRuntimeHost` | `OnDemand` | `Composite`, several HUD blocks coexist |
| `<MenuLayerTag>` | `SharedRuntime` | `Shared` | `SharedRuntimeHost` | `RetainUntilLayoutRelease` | `Exclusive` |
| `<ModalLayerTag>` | `SharedRuntime` | `Shared` | `SharedRuntimeHost` | `RetainUntilLayoutRelease` | Popup stack |

- The host registers its GameplayTags; the plugin does not look them up by fixed names. The Runtime uses the final Tag segment for input priority: `.Modal` takes precedence over `.Menu`, then `.GameMenu`, then other suffixes. Custom layer names without these suffixes use the lowest priority.
- `CompositionMode` is set on the Definition. When an `Exclusive` Screen is committed, it suspends the other Screens in the same layer stack as `CoveredSuspended`, and when it is removed the top of the stack is restored. A `Composite` Screen coexists with the other Screens on the same layer and is stacked by `ZOrder`. The popup layer is a stack of its own: while it covers the layers below, the page below keeps its frame and DOM and only hands over input.
- Each `RuntimeId` of each LocalPlayer has exactly one shared Browser, owned by the Subsystem. Business components do not create a Browser: at runtime the `UOrionInstantScreenWidget` in a WBP contains no Browser, it only publishes geometry and holds the Endpoint.
- The root layout is a UserWidget supplied by the host. Place one `UOrionInstantScreenRuntimeHost` for each Runtime in it (palette name "Orion InstantScreen Runtime Host") and fill in `RuntimeId` and `RuntimeHostId`. Place each Runtime Host according to your own layer stack. A native popup layer that must cover a Web Surface belongs above that Host. Web pages and popups sharing a Browser are composed within that Browser; the plugin requires no fixed game layer names or widget order. After the change, read back the real child order with an editor tool; do not just check that the widget names exist.
- To hide a Runtime temporarily (a menu covers the HUD, or during a loading mask), call `SetRuntimePresentationSuppressed(RuntimeId, bool)`. Do not Collapse the Runtime Host and do not change its Visibility by hand; the Subsystem sets Pointer hit-testing by aggregating the `InputPolicy` of the active Screens.
- The render mode must be `LegacyTexture`: write `[OrionBrowser] DefaultWebUIRenderMode=LegacyTexture` in the Engine ini (or use the command line `-OrionWebUIRenderMode=LegacyTexture` or the CVar `orion.WebUI.RenderMode`). When the key is absent, the mode already resolves to `LegacyTexture`. When the resolved mode is anything else (the key is set to `Auto`, `HybridIR` or `FullIR`, or the command line or CVar overrides it), Catalog registration and every Show are rejected, and there is no automatic fallback.

## Module responsibilities

| Location | Responsible for |
|---|---|
| Module `OrionWebUI` | The enums, Runtime Profile, Definition, Catalog, Show request and Handle in `OrionInstantScreenTypes.h`; the C++ package validator and protocol version in `OrionInstantScreenPackage.h`; the `orion-webui.local` Scheme and package byte registration |
| Module `OrionWebUIWidget` | `UOrionInstantScreenSubsystem` (Catalog, Runtime residency, presentation transaction, reliable delivery, input lease, diagnostics), `UOrionInstantScreenEndpoint`, `UOrionInstantScreenWidget`, `UOrionInstantScreenRuntimeHost` |
| Module `OrionWebUICommonUI` | `UOrionInstantScreenActivatableWidget`: CommonUI activation and deactivation, the standard presentation request, Back / common Action, input method and key prompts, control sound policy, automatic deactivation after a failure |
| `<OrionBrowser>/Content/UI/WebUI/Shared` | Runtime Shell source `src/instant-screen-runtime/`, optional module `src/runtime/orion-instant-screen-runtime-optional.js`, Package Builder and validator in `scripts/`, page-side helper `src/instant-screen/orion-instant-screen-vue.ts` |
| Host project | Layer Tags, root layout, Catalog registration timing, concrete Definition / WBP / Presenter and C++ authoritative state, loading mask |

## Assets and WBP

| Asset class (provided by the plugin, all PrimaryDataAsset) | Key fields | Rules |
|---|---|---|
| `UOrionInstantScreenRuntimeProfile` | `Entries[]`: `LayerTag`, `RuntimeId`, `RuntimeMode`, `RuntimeHostId`, `RetentionPolicy`, `IdleRetirementSeconds` | `RuntimeId` and `RuntimeHostId` must be non-empty; `IdleTimeout` needs a positive number of seconds; the configuration of each layer that uses the same `RuntimeId` must be equivalent; `RuntimeMode` describes how the Runtime is shared, and `RetentionPolicy` describes reclamation after the last real owner leaves, and neither replaces the other |
| `UOrionInstantScreenDefinition` | `ScreenId`, `AppDefinition`, `PackageId`, `DefaultLayerTag`, `InputPolicy`, `FocusPolicy`, `CompositionMode`, `ZOrder`, `CachePolicy`, `SecurityPolicy`, `InitialRoute`, `InitialVariant` | `ScreenId` equals the `screenId` in the configuration; when `PackageId` is empty, the `AppId` of the AppDefinition is used; when `InitialRoute` is empty, the `InitialRoute` of the AppDefinition is used, and if that is also empty the `default` package directory is used |
| `UOrionInstantScreenCatalog` | `RuntimeProfile`, `Screens[]` | `RuntimeProfile` is required; every Screen needs a `ScreenId` and an `AppDefinition`, and its layer must be mapped; `ScreenId` values must not repeat |

- `InputPolicy`: `Passthrough` and `Game` only draw, and clicks pass through to the game viewport; only `GameAndMenu`, `Menu` and `Modal` let the Runtime take part in Pointer hit-testing, and they require the input lease to be confirmed before the page counts as interactive.
- `RetentionPolicy`: `OnDemand` closes the Browser immediately after the last Screen is released; `IdleTimeout` parks first and closes when the time is up; `RetainUntilLayoutRelease` stays parked until the LocalPlayer Subsystem ends. `CachePolicy` defaults to `KeepDocument`: after a Screen is hidden, the Controller document is kept, and the next time the same Screen is shown it rebinds to a new instance identity.

Business WBP:

1. For the parent class, choose a host-supplied C++ class that ultimately inherits `UOrionInstantScreenActivatableWidget` (Abstract).
2. Keep one `UOrionInstantScreenWidget` named exactly `WebUI` in the widget tree (palette name "Orion InstantScreen"). The proxy looks it up by this name in `NativeConstruct`; if you rename it, the geometry and Endpoint binding are lost.
3. Configure `ScreenDefinition` on the proxy or on the `WebUI` slot, and the proxy takes precedence. `LayerOverride`, `RouteOverride` and `VariantOverride` on the slot take effect only when the slot's `ShowScreen()` is called directly (including `bAutoShowOnConstruct`); they are not read when the screen is shown through the proxy's `ShowInstantScreen()`.
4. A page that goes through CommonUI keeps `bAutoShowOnConstruct=false`; enable it only on a passive HUD slot that does not go through the proxy.
5. The slot must have a non-zero arranged size and must not be Collapsed / Hidden. Otherwise the geometry is invalid and the final visible frame waits forever. The proxy forces its own `SelfHitTestInvisible` and the slot's `HitTestInvisible`; do not change them by hand.
6. Proxy timing: `NativeOnActivated` calls `ShowInstantScreen()` (on failure, `DeactivateWidget()`), and then, when `bUseStandardPresentationLifecycle` is true, calls `RequestStandardWebUIPresentation()`. `NativeOnDeactivated` first makes the slot leave composition, and then decides whether to call `HideInstantScreen()` according to `ShouldKeepInstantScreenOnDeactivation()` (default `false`).
7. Overridable: `BuildInitialInstantScreenState()`, `HandleWebUIReady`, `HandleWebUIEvent`, `HandleWebUIRequest`, `HandleWebUIRouteChanged`, `HandleCommonAction`, `HandleWebUIBackAction`, `ShouldKeepInstantScreenOnDeactivation()`, `HandleInstantScreenDistinctVisualPresented()`, `HandleInstantScreenReplacementFailed()`. When a page uses its own entrance event, also override `ShouldRequestStandardWebUIPresentationOnActivation()` to turn off the standard request.

Catalog registration and unregistration:

- The interfaces on each LocalPlayer are `RegisterCatalog(UObject* RegistrationOwner, UOrionInstantScreenCatalog*)` and `UnregisterCatalog(Owner, Catalog)`. During registration, each Screen's package directory is validated and the package file bytes are read into memory. On failure it returns `false` and prints `Rejected InstantScreen ...`.
- Owner semantics: an Owner holds only one Catalog, and registering another Catalog with the same Owner first unregisters the old one; unregistering must pass the same Owner and Catalog pair; a package URL is readable only while a live Owner still exists; reusing the same `ScreenId` in different Definitions is rejected. After a package is rebuilt, register again to read the new bytes.
- Registration must happen before the first Show of any of its Screens, and registration itself does not create a Browser and does not load resources of non-current pages.
- The plugin does not provide the callers that register; the host must supply two kinds. The root layout registers the resident frontend Catalog in `NativeConstruct` and unregisters it in `NativeDestruct`. The object that registers the gameplay Catalog with the gameplay (for example a GameFeature Action) is responsible for loading the Catalog, registering it for every existing and later-added GameInstance and every LocalPlayer, and unregistering symmetrically on deactivation, LocalPlayer removal and GameInstance destruction. Do not register ad hoc in a Widget, Presenter or page.

## `instant-screen.config.ts`

Place it at `<WebUIRoot>/<AppId>/instant-screen.config.ts`. The file must be pure data of the form `export default { ... } as const;`. The Builder evaluates it in a sandbox, and the words `import`, `require`, `process`, `globalThis`, `Function` and `eval` are rejected when they appear in the source text (even inside a string or a selector).

```ts
export default {
	"packageId": "SamplePanel",
	"firstFramePolicy": "controller",
	"captureBudgetMilliseconds": 1800,
	"firstFrameLayout": {
		"mode": "fit-design-stage",
		"selector": ".sample-stage",
		"designWidth": 1920,
		"designHeight": 1080
	},
	"screens": [
		{
			"screenId": "SamplePanel",
			"route": "default",
			"captureMustContain": ["id=\"sample-panel-title\"", "data-orion-control-id=\"sample-panel-confirm\""],
			"bindings": [
				{ "selector": "#sample-panel-title", "path": "title" },
				{ "selector": ".sample-shell", "path": "tone", "mode": "class-equals", "className": "is-warning", "equals": "warning" }
			]
		}
	]
} as const;
```

| Field | Meaning and values |
|---|---|
| `packageId` | Required; only letters, digits, `_` and `-`. It must equal `<AppId>`: C++ looks for the package under `<WebUIRoot>/<PackageId>/dist/instant/routes/<Route>`, and the URL also uses it as the first segment |
| `screens` | Required and non-empty. Each item produces one package directory |
| `screens[].screenId` | Required, unique, equal to the `ScreenId` of the Definition |
| `screens[].route` | Route key; only letters, digits, `_` and `-`; unique. When omitted, the route in the package header is empty and the output directory is `default`. It must match the route resolved from the Definition (when the Definition route is empty, only empty or `default` is accepted) |
| `screens[].hash` | The hash of the capture URL; by default `#/<route>` is used when `route` is non-empty |
| `screens[].query` | An object of query parameters appended to the capture URL; the Builder additionally and always appends `orionDesignPreview=1` and `orionInstantBuild=1` |
| `screens[].captureMustContain` | An array of strings; each one requires that the literal text appear in the captured DOM, to prove that the target route and the key controls were really rendered |
| `screens[].bindings` | The static state-to-DOM binding table, see below |
| `firstFramePolicy` | `"controller"` (default) or `"static"`; can be written at the top level or on a single screen |
| `firstFrameLayout` | Can be written at the top level or on a single screen: `selector` (required), `mode` which is `fit-design-stage` (requires `designWidth` and `designHeight`) or `height-design-stage` (requires `designHeight`), and an optional non-negative `edgeOverscan`. Only a `static` first frame uses it at runtime to scale the stage to the viewport |
| `captureBudgetMilliseconds` | The virtual-time budget of Headless Chromium, default 2500; the watchdog is 8 times this value and not less than 30 seconds |

Common fields of a binding item: `selector` (required, `:scope` means the current root), `path` (required, a dotted path), `mode` (default `text`), `id` (optional; by default derived from `screenId`, `selector`, `path` and `mode`, and two bindings with the same four values are reported as duplicates), `all` (match all elements), `applyWhenUndefined`, `defaultEmptyArray`, `format` (`number`; `template` together with `{value}` in the `template` string; `array-length`; `array-index` together with `indexPath`; `remaining-duration` together with `otherPath`).

| `mode` | Effect | Extra fields |
|---|---|---|
| `text` | Writes `textContent` | `format` |
| `attribute` / `attribute-map` / `attribute-path-equals` | Writes an attribute; writes an attribute by mapping; writes whether the value equals another path | `attribute`, plus `removeWhenEmpty` / `map` / `otherPath` |
| `class-boolean` / `class-false` / `class-equals` | Toggles a class name by true, false, or equal to a constant | `className`; `class-equals` also needs `equals` |
| `class-path-equals` / `class-path-less` | Adds a class name when equal to, or less than, another path | `className`, `otherPath` |
| `disabled-false` / `aria-disabled-false` | Disables when the value is false | None |
| `visible` / `visible-map` / `visible-any` | Controls `hidden` | `map`; `predicatePath`, `predicateEquals` |
| `style-percent` / `style-value` | Writes a style property | `property` (default `width` for percent), `scale` (default 100) |
| `value` | Writes the form `value` | None |
| `repeat` | Clones template child elements according to an array | `itemSelector` (default `:scope > *`, must be a direct child of the binding root), `textSelector`, `textPath` (default `label`), `primaryClass` and `primaryPath`, `templates` and `templatePath`, child `bindings`, `orderPath` and `keyPath`, `filterPath` and `filterEquals`, `takeLast`, `maxItems`; paths inside an item can use `$item`, `$value`, `$index`, `$parent`, `$root` |

The Builder also collects every element in the captured DOM that has `data-orion-control-id` into `actions.bin`. The binding table and the action table take effect at runtime only under the `static` policy; under the `controller` policy they are still generated and validated, and `bindings` may be an empty array.

## `firstFramePolicy`

| | `controller` (default) | `static` |
|---|---|---|
| Visible document | Only the Controller iframe (`controller-host.html`). It completes mounting, state application, fonts, images and layout during Preparing and becomes the only visible document | `first-frame.html` is shown first (the initial state is applied from the binding table, and clicks are queued), and after Reveal it is hydrated in place within the same document |
| Requirements on the page | No extra requirements | Build the App with `createOrionWebUIApp()` (SSR Hydration inside the static first frame); the captured DOM plus the binding results must match the real render node by node, and any Hydration warning or replacement of the root node or a control counts as a failure; the capture must not contain development-server file-system URLs; when `repeat` is used, the Vue Fragment anchors must be reachable |
| Role of `first-frame.html` | Takes part only in package integrity and determinism validation and is never shown | The real first frame |

Choice: a page that needs a precise entrance animation, a font policy, dynamic images or a Native Surface always uses `controller`; consider `static` only for a page with a fixed layout and very little text.

Do not design a flow that reveals the static first frame first and then switches to another Controller document: the two documents each load fonts and images and each build their own layout and animation timeline, which shows up as a preview frame flashing first, a font or image suddenly being replaced, a size jump, and an entrance animation that looks as if it played twice. When you see these symptoms, first count the visible documents and check the policy; do not add pauses, replays or delays.

The Controller's static visual readiness (`controllerVisualReady(stateRevision)`, stage `controller-visual-ready`) and the presentation ACK (`webUI.presentationApplied`, stage `presentation-committed`) are two independent gates: the former means the authoritative state and localization have formed a complete static DOM, the latter means the entrance for this presentation request has been committed, and neither replaces the other. If the host's loading mask has to wait for the page, it may wait only for facts that do not depend on "visible" (state committed, static visual ready, resources ready). Waiting for facts that appear only after Reveal (`OnDistinctVisualPresented`, or the ACK of an entrance request that is sent only after the mask is removed) creates a loop in which the mask waits for the page and the page waits for the mask.

## Package 2.0 and URLs

- The current package format is `2.0` and the Runtime protocol is `8`. Three places must agree: `PACKAGE_VERSION` / `RUNTIME_PROTOCOL_VERSION` in `instant-screen-package-lib.mjs`, `runtimeProtocolVersion` in the Runtime Shell `runtime.js`, and `OrionInstantScreenPackage::RuntimeProtocolVersion` in C++. When a plugin upgrade changes the format or protocol, old packages are rejected and must be rebuilt.
- Each package directory `<WebUIRoot>/<AppId>/dist/instant/routes/<Route>/` must contain eight files: `package.header`, `first-frame.html`, `critical-style.css`, `bindings.bin`, `actions.bin`, `controller.mjs`, `controller-host.html`, `first-frame-runtime.mjs`. The package header stores only the format, protocol, `packageId`, `screenId`, `route`, the first-frame policy and the Hydration mode, and contains no build hash or file digest.
- The production URL is fixed as `https://orion-webui.local/<AppId>/instant/routes/<Route>/<PayloadRelativePath>`, and an empty route uses `default`. The Scheme looks only at packages and files registered by a Catalog and does not join the request path into a disk path; `/<AppId>/dist/...` and any other `/<AppId>/instant/...` are never readable.
- `controller-host.html` must not contain inline executable scripts. It may contain only one `<script data-orion-controller-host-bootstrap="true" type="module" src="./controller.mjs"></script>`. `controller.mjs` first obtains and installs the Scoped API of the current Screen, dispatches `orion:webui-installed`, and then dynamically imports the main entry located under this App's `dist/assets`. Both the Node validator and the C++ validator check this; do not relax the CSP to allow inline scripts.
- The App's `dist/index.html` must have exactly one module entry, and it must start with `./assets/` (the Vite `base` uses a relative path).

## Build and verification

```text
# In <WebUIRoot>/<AppId>: typecheck, existing tests, then the production build (clears dist, including dist/instant)
npm run build
# In <OrionBrowser>/Content/UI/WebUI/Shared: shared Runtime (build when the output does not exist or the Runtime source changed, then check)
npm run instant:runtime:build
npm run instant:runtime:check
# In <OrionBrowser>/Content/UI/WebUI/Shared: generate and validate the package last
npm run instant:build -- --app <WebUIRoot>/<AppId>
npm run instant:validate -- --package <WebUIRoot>/<AppId>/dist/instant/routes/<Route>
```

- The order is fixed: the App production build, the shared Runtime, and the Package last. Rerun `instant:build` after every App production build.
- `instant:build` accepts the optional `--config <path>` and `--chrome <path>`. The browser is looked up in this order: `--chrome`, the environment variable `ORION_INSTANT_SCREEN_CHROME`, then the default install locations of Chrome and Edge built into the script. A missing App directory raises a Usage error, which is not a Builder fault. The input of `instant:validate` is a concrete package directory, and `--package` can be repeated; passing the App root directory produces an `ENOENT` for a missing `package.header`.
- The two inputs of the Builder come from different sources and must not be mixed: the Controller entry and styles come from the built `dist`; the DOM of `first-frame.html` comes from the Designer Preview started with the App's own `vite.config.ts`. The page must be able to render a complete `#app` with preview data under `?orionDesignPreview=1`, without depending on the Bridge.
- The output directory of the shared Runtime is decided by the script and is the project-level `<WebUIRoot>/__instant__/dist/runtime/` (exactly four files: `index.html`, `runtime.css`, `runtime.js`, `runtime-optional.js`), not under the plugin directory. It is a generated output: do not edit it by hand, make changes only in `<OrionBrowser>/Content/UI/WebUI/Shared/src/instant-screen-runtime/`, and the source must be CRLF. When `instant:runtime:check` reports `Generated InstantScreen Runtime is stale`, it needs to be rebuilt.
- The hard limit of the main Runtime Bundle `runtime.js` is 48 KiB (counted in final CRLF bytes), and a build that exceeds it fails. There is only one remedy: move policy that does not have to finish within the first script task into the optional module, keeping in the main Runtime the Screen table, the synchronous parked switch and the Native ACK entry. Do not relax the budget, do not remove presentation gates, and do not edit the generated output by hand.
- Determinism requirement: build twice in a row, and the SHA-256 of every file under `dist/instant` must be identical file by file; any added file, missing file or different hash counts as a failure. Each round first clears the App's exact `dist/instant` (the Builder does not clean old routes itself), and the first round must not use leftovers from before the call. The plugin exports only `hashPackageDirectory()` and the two npm commands; the two-round procedure is run by a host script or by hand.
- Because `dist/instant` is deleted between the two rounds, the project's Editor must first exit normally. If cleaning reports that a file is in use, do not force-kill any process and do not retry without limit; wait until the holder is idle and rerun the whole round, and if it still fails, report it as blocked.
- Run the Package Builder, the Runtime Builder and the validator serially, and do not start a second Builder concurrently. The Builder starts a separate temporary Headless Chromium for each route in sequence, and a long period without new output can still be normal; judge a failure only when Node reports an explicit error or exits with a non-zero code. Before retrying, confirm that the previous Builder and its temporary Chromium have exited, and do not end the user's own browser by process name.

## Determinism rules for first-frame capture

These rules directly constrain how the page is written:

- Capture runs with `orionInstantBuild=1`, without a GPU, and in virtual time. A live WebGL, Canvas or rAF rendering layer must be turned off by this query parameter (for example, in the root component use `new URLSearchParams(location.search).get("orionInstantBuild") !== "1"` as the condition that enables the rendering layer). Otherwise it randomly hits the watchdog, and a canvas also ends up in the first-frame DOM. Do not relax the watchdog or add waits for this.
- The DOM must not change when an animation ends. Class-name switches, conditional unmounting or attribute changes triggered by `animationend`, `transitionend` or `getAnimations().finished` race with the moment of the DOM dump and cause the hashes of the two rounds to differ. Entrance-related class names change only with state; transition elements stay resident, use `backwards` fill, and return to the element's own style after the end; only logic that does not enter the DOM may wait for an animation to end. Temporarily lowering `captureBudgetMilliseconds` to a very small value reproduces the DOM in the middle of an entrance reliably, which you can use to confirm whether the problem is of this kind.
- The clock is fixed during capture; do not render the current time, random numbers or environment-dependent content into the first-frame DOM.
- Neither the page nor the capture preamble may leave a permanent timer or a looping timer, otherwise Headless Chromium may still not exit after the DOM is complete.
- The generated `first-frame.html` must not contain build-machine paths, trailing whitespace or debug attributes. The Builder is responsible for cleaning it and normalizing it to CRLF, and the validator treats trailing whitespace as a failure. When you find a problem, change the source or the Builder; do not edit the generated output by hand and then fix up the hash.

## Presenter and Endpoint

A Presenter (the host's C++ page class) holds only a `UOrionInstantScreenEndpoint*`, obtained from the proxy's `GetInstantScreenEndpoint()` or from the return value of the slot's `ShowScreen()`; it holds no Browser or `UOrionWebUIWidget` pointer. Browser rebuilds and Surface generation changes are handled at the Runtime boundary, and callbacks from an old generation are rejected by the Endpoint. After an Endpoint becomes invalid (`IsValidEndpoint()` is false), do not use it any more.

| Member | Semantics |
|---|---|
| `AllocateRevision()` | A static, monotonic, Web-safe source of revisions; both state and lifecycle messages take their numbers from it |
| `PushState(StateJson, StateRevision)` | Publishes a full authoritative snapshot. A revision lower than the current value returns `false`; the same revision may correspond only to byte-for-byte identical JSON, otherwise an error is reported through `OnError`. A replay of an identical snapshot reuses the original revision |
| `PostEventToWeb` / `PostLatestEventToWeb` / `PostRetainedLatestEventToWeb` | Three ordinary deliveries: immediate, keep only the latest, and retain the latest; none has ACK or retry |
| `PostReliablePresentationEventToWeb(EventName, PayloadJson, AcknowledgementEventName, RevisionFieldName, Revision, ...)` | A reliable presentation event, see below |
| `PostReliablePresentationRequestToWeb(...)` (same parameters as above) | A reliable presentation event that also declares this page-defined pair of event names as this Screen's presentation request and ACK, see below |
| `PostFlowControlledLatestEventToWeb(...)` | A flow-controlled channel with one in-flight value plus one replaceable latest value, suited to high-frequency state; the ACK only releases the slot. Call `CancelAllFlowControlledLatestEvents()` when leaving the page |
| `RequestStandardPresentation()` | For a passive C++ host that has no business entrance event: allocates a revision and reliably sends `ue:webUI.presentationRequested`, and the ACK is `webUI.presentationApplied` |
| `IsReliablePresentationFrameCertified(AcknowledgementEventName, Revision)` | True only when a new Runtime frame has been certified after the ACK of that exact positive revision |
| `IsDistinctVisualPresented()` | Indicates only that the Screen itself has completed one lifecycle presentation; it cannot prove that a later business commit has been drawn |
| `OnReady`, `OnLocalResourcesReady`, `OnEvent`, `OnRequest`, `OnRouteChanged`, `OnError`, `OnDistinctVisualPresented`, `OnReliablePresentationFrameCertified` | Event outputs; when going through the CommonUI proxy, the proxy binds them and forwards them to `HandleWebUI*` |

- The initial-state revision and the presentation revision are two separate namespaces. What `ShowScreen(InitialStateJson, StateRevision)` and `BuildInitialInstantScreenState()` output must be the current authoritative state revision, and every later `PushState` must be not lower than it; never pass a popup's presentation revision into it. `StateRevision == 0` means only a truly stateless Screen; any positive revision requires the page to explicitly call `stateCommitted(revision)`.
- Every Screen must have one presentation request, otherwise the transaction stays in the preparing stage: the proxy's standard lifecycle, `RequestStandardPresentation()`, or a custom reliable presentation event. The presentation requests the Runtime recognizes built in are `ue:webUI.presentationRequested`, `ue:webUI.presentationRestored` and events whose names end with `.enterRequested`, and the built-in presentation ACKs are `webUI.presentationApplied`, `webUI.presentationEnterApplied` and `webUI.presentationRestoreApplied`; the revision must be exactly equal.
- When a presentation request needs the page's own pair of event names (for example a HUD that commits only after composing several data sources), send it with `PostReliablePresentationRequestToWeb`: Native declares the ACK name in the envelope of that event, the Runtime records this revision as the expected presentation revision and lets through only the ACK whose revision is exactly equal, and stale and premature ACKs are rejected at the Runtime boundary. The Runtime does not know any page event by name; other events sent with `PostReliablePresentationEventToWeb` get only reliable delivery and frame certification and do not change the Screen's presentation milestones.
- The flow of a reliable presentation event: resend until Web returns an ACK whose `RevisionFieldName` field is exactly equal; the ACK only stops the resending; then the Subsystem requests a Runtime paint fence strictly later than the ACK; only after the fence is ready is a certificate established for `(AcknowledgementEventName, Revision)` and `OnReliablePresentationFrameCertified` broadcast. `Revision` must be positive. If ACK retries are exhausted or frame certification times out, the whole presentation fails and the Endpoint becomes invalid. An ACK consumed by reliable delivery no longer appears in `OnEvent`.
- A State snapshot does not implicitly create an Enter: even if the page's state handling sees a presentation revision in the snapshot, it may only update the Store, commit the exact state revision and report static visual readiness, and it must not play an entrance or send a presentation ACK because of it. An ACK with a zero, premature, old or future revision is rejected at the Runtime boundary.
- The host's event entry point is an override of `HandleWebUIEvent_Implementation()`. At the entry, handle lifecycle events first (presentation ACK, exit completion, resident page lifecycle acknowledgements and other conventions of the host itself), and `return` immediately after a match; it must not fall through into business Intent dispatch. Business operations enter through the page's `requestIntent()` via `HandleWebUIRequest`; a plain `call` is reserved for built-in bridge services, and using it to send a business request is rejected with `E_INSTANT_USE_INTENT`.

## Presentation transaction

The native phase enum `EOrionInstantScreenPresentationPhase` (`Phase=<n>` in the logs is the zero-based ordinal):

| Ordinal and phase | Condition to enter the next phase |
|---|---|
| 0 `AwaitingPrepared` | The Runtime reports `prepared` for the exact state revision, the Bridge, resources and input are ready, the state ACK equals the current revision, and the presentation ACK equals the required presentation revision |
| 1 `PreparedQueued` | The same Runtime advances only one presentation at a time, and the rest queue |
| 2 `AwaitingStagingPaint` | A new LegacyTexture frame strictly later than `prepared` arrives and the slot geometry is valid; it is recorded as the first-frame certification, and then `commit` is sent to the Runtime |
| 3 `AwaitingReveal` | The Runtime reports `revealed`, and the presentation revision matches exactly |
| 4 `AwaitingVisiblePaint` | A new frame after Reveal is ready, and the state ACK, the presentation ACK, input readiness and, when needed, the input ownership confirmation all hold |
| 5 `AwaitingBackBuffer` | That frame enters the BackBuffer; then it becomes 6 `Complete`, `OnDistinctVisualPresented` is broadcast, and the log shows `Presented InstantScreen` |
| 7 `Failed` | `FailPresentation()` is called: it aborts the transaction, removes the instance, invalidates the Endpoint, and finally broadcasts `OnError` |

- The milestone stage names on the page side (`Stage=<name>` in the logs): `controller-host-installed`, `controller-module-evaluated`, `controller-bridge-ready`, `state-committed`, `controller-local-resources-ready`, `controller-input-ready`, `controller-visual-ready`, `presentation-committed`, and only after those come `prepared` and `revealed`. Check whichever one is missing; do not infer from other facts.
- When the state keeps advancing after `prepared`, the old prepared is invalidated immediately: a transaction that has not yet committed staging returns to `AwaitingPrepared`, and a transaction after Reveal restarts the final visible frame. Do not assume that "already prepared" means it will certainly be shown.
- Each phase of a presentation in progress has a 5-second timeout (a source constant). The timer is paused while waiting for valid visible geometry, and in phases 3, 4 and 5 while the Runtime is suppressed or has just been unsuppressed and has not yet received the Web acknowledgement. An instance that has not yet left the queue is not governed by it; it is judged failed by the Runtime-side 15-second Controller barrier and by exhausted reliable-event retries.
- Covering suppression and restoration: `SetRuntimePresentationSuppressed` is sent down as a reliable absolute state with a monotonic revision, and the Runtime sets transparency and Pointer and then acknowledges the same revision. On release, the restore frame is requested only after the exact Web acknowledgement with `suppressed=false` has been received (log `InstantScreen Runtime presentation suppression applied by Web`), and a Screen still in phase 3, 4 or 5 goes back uniformly to `AwaitingReveal` to go through the final frame again. Do not substitute a longer timeout, removing the cover early, or collapsing the Host.
- Input lease: for a Screen with `GameAndMenu`, `Menu` or `Modal`, the Runtime requests a confirmation for each real ownership generation, and Native accepts only a request in which the instance, transaction, Surface, document, state and presentation all match. Suppression, a presentation version advance and a document change all clear the old confirmation. A covered page keeps its frame but immediately hands over focus and pointer, and requests again on restoration, without rebuilding the page and without replaying the animation of the resident shell.
- Park and Resume: after the last real Screen is released, a non-`OnDemand` Runtime first hides the Surface and then tells Web to park; Web hides all Screens and acknowledges, and after a transparent frame is certified the Browser is frozen and removed from the Host. The next real Show first restores and then sends Show only once, using a new instance, transaction and revision, and the Controller document may be reused. The page must therefore reset its own versions and asynchronous continuations according to the instance identity of `ue:webUI.lifecycleChanged`, and stop infinite animations, rAF and timers when it is hidden, covered or parked.
- Failure must fail open. When the Endpoint terminates with a failure and the proxy itself is still active, the proxy automatically calls `DeactivateWidget()`, and the page stack restores the previous layer and input. Other leases the host holds for that page (HUD suppression tokens, native masks, input mode) must be released symmetrically in the deactivation path or in `HandleInstantScreenReplacementFailed()`, and when needed, degraded to an interactive native prompt. A popup that does not go through the proxy and calls the slot's `ShowScreen()` directly must bind `Endpoint->OnError` itself. Do not forge an ACK, do not force an uncertified page to be shown, and do not rebuild the shared Browser.

## Animation contract

The Runtime guarantees the following behavior, and a new page only needs to follow it (for the page-side way of writing, see [Bridge and lifecycle](bridge-lifecycle.en.md)):

1. When the document lifecycle is not `Visible`, the style injected by the Runtime prevents animations from being created with `animation: none` and `transition: none`, so an entrance must be declared on the element with a CSS animation or transition and started naturally by the lifecycle switch.
2. Each time it goes from hidden to visible, the Runtime, within the same script task, first settles a static baseline and then switches to `Visible` exactly once; the first frame that may reach the screen is frame 0 of the entrance.
3. Each appearance gets a new appearance revision and plays from the start; covering and restoring, reopening and a route round trip are all the same. Neither the page nor C++ sends a second "start animation" command.
4. The page does not call `Element.animate()`, does not iterate over animation instances to pause / play / restart, and does not use rAF or delay timers to replay.
5. An entrance animation must be finite and must converge: the Runtime waits for all finite animations of the current appearance to end before it judges the presentation settled, and during that time it occupies the Runtime's only preparation slot, and later Screens queue and wait. Infinite looping animations are not counted, but they must stop when not visible.
6. The entrance root node does not run a full-screen opacity or filter animation (the atomic Reveal is Native's responsibility); finite animations land on content groups such as the panel, title and cards, preferring `opacity` plus `transform`. Styles must not contain `backdrop-filter`, `mix-blend-mode`, `prefers-reduced-motion` or a transition on `filter`, and `npm run animations:contract:check` under `<OrionBrowser>/Content/UI/WebUI/Shared` rejects them.
7. The shared shell of a multi-route App is not remounted when the internal route changes; a route module is loaded only on real access and may be cached, but must not create hidden DOM or run animations ahead of time.

## Page-level resources and sound routing

The authoritative routing key of a page instance is `ScreenInstanceId` → `ScreenDefinition` → `AppDefinition` → `SoundManifest` / `FontManifest` / `AssetManifest`. Do not use a WBP name, a DOM route or a temporary BrowserId as the long-term key of sound, fonts or images; sound events use stable literal ControlIds, and dynamic business IDs go only into the payload. Images take part in the readiness gate only when the real page requests them and the element exists, and you cannot "fix" the first frame by preloading through a hidden iframe; a dynamic image that will be replaced inside the same first-frame transaction is first loaded and decoded in a detached `Image`, and swapped in after it succeeds. For details, see [Controls and resources](controls-resources.en.md).

## Checklist for a new screen

Adding a Screen (the App already exists):

1. The page route and content are ready, with the state channel, presentation ACK and input handling wired up.
2. Add one item to `screens[]` in `instant-screen.config.ts`: a unique `screenId`, a unique `route`, and `captureMustContain`.
3. The Designer Preview can render the complete content on that route, and the live rendering layer is gated by `orionInstantBuild`.
4. Rerun the App build, `instant:build` and `instant:validate`, and do the two-round hash comparison.
5. Create a new `UOrionInstantScreenDefinition`: `ScreenId`, `AppDefinition`, `DefaultLayerTag`, `InputPolicy`, `CompositionMode`, `InitialRoute` (consistent with the configured `route`).
6. Add it to the `Screens` of a Catalog, and confirm that the Profile of that Catalog maps this layer.
7. Create the WBP: parent class, a slot named `WebUI`, `ScreenDefinition`.
8. Presenter: initial state and revision, `PushState`, event entry point, request handling, failure release.
9. The host pushes that WBP into the CommonUI layer that corresponds to `DefaultLayerTag`.

Adding an App requires the following in addition to the above:

1. Create `<WebUIRoot>/<AppId>` and a `UOrionWebUIAppDefinition` (`AppId` equals the directory name) according to the scaffold, and attach the Sound / Font / Asset Manifests that are needed.
2. Write `packageId` as `<AppId>`.
3. The shared Runtime output exists and `instant:runtime:check` passes.
4. The target Runtime has a corresponding Runtime Host in the root layout, the layer Tag is registered, and the Engine ini configures `LegacyTexture`.
5. The Catalog has a clear registering party, and registration happens before the first Show.
6. `dist` (including `dist/instant`) and `__instant__/dist/runtime` go into the packaged build; see [Build and validation](build-validation.en.md).

## Failure signatures

| Signature | Cause | Action |
|---|---|---|
| `requires explicit LegacyTexture; session creation refused` | The render mode is not explicitly configured as `LegacyTexture` | Add the Engine ini setting; do not change code to work around it |
| `Rejected InstantScreen package ScreenId=...` (`Could not read JSON file`, `package header mismatch`, `Could not read package payload`) | The package was not generated, was cleared by an App build, or `packageId` / `screenId` / `route` / protocol version does not match the Definition or the plugin | Rebuild in order; align the configuration and the Definition |
| `ShowScreen rejected ScreenId=... because no active Catalog registration provides its validated Package identity` | Show happened before Catalog registration, or the flow continued after registration failed | First look for an earlier `Rejected ...` log, and fix the registration timing |
| `Controller presentation barrier for <ScreenId> timed out`, with both the presentation ACK and resource readiness present, and only `state-committed`, `controller-visual-ready` and `prepared` missing | The seed revision passed to Show is greater than the revision of the first `PushState` (common when a presentation revision is used as the state revision), so `PushState` was rejected; or the page did not call `stateCommitted` after the DOM flush | Align the Show seed, the return value of the first `PushState` and the page's state event; do not treat the presentation ACK as the state having been committed |
| `Presentation commit rejected ... Reason=request-not-observed` (or `stale-revision`, `future-revision`, `invalid-revision`) | The page replied with an ACK before it observed an explicit presentation request (usually an implicit entrance from the state path), or the revision is not exact | Send the ACK only after the corresponding request is received, with the same revision |
| `InstantScreen event ue:<x>.enterRequested at revision <n> was not acknowledged after <k> attempts` | The page did not register a listener for that event before input readiness, or did not reply with an ACK at the exact revision; if the new Screen does not even reach `controller-host-installed`, the entrance of the previous page on the same Runtime has not settled and is holding the preparation slot | Fix the page listener and ACK; for the latter, confirm that the shared Runtime is the current build and the entrance animation is finite, and do not rely on more retries or rebuilding the Browser |
| `InstantScreen presentation timed out Phase=<n> ...` | Read the predicates that follow: `Geometry` / `Visible` false means the slot has no arrangement or the proxy is not activated; `StateAck` and `PresentationAck` unequal on the two sides means the page lacks a confirmation; `InputOwnershipRevision=0` means the input lease is not confirmed (covered by a popup, suppressed, or `InputPolicy` does not match the layer) | Locate it by the missing predicate; do not extend the timeout |
| After a presentation failure the underlying HUD never recovers and input is stuck in the popup | The host did not consume the Endpoint's failure event, so its own suppression token was not released | Release symmetrically in the deactivation and failure paths, fail open |
| The first display flashes a preview first, fonts or images get replaced, the animation looks as if it played twice | Two documents became visible one after the other (the `static` policy was used for a dynamic page, or a second document was built by hand) | Switch to `controller` and guarantee a single visible document |
| `Chromium DOM capture timed out after ... ms` | The page does not converge during capture: the live rendering layer was not turned off by `orionInstantBuild`, or a permanent timer exists | Fix the page according to "Determinism rules for first-frame capture"; do not raise the watchdog and do not retry concurrently |
| `capture is missing marker` / `did not contain a rendered #app` | The Designer Preview did not render that route (preview data is missing, or the hash or `query` is wrong), or the marker text does not match the real DOM | Fix the preview data, or `hash`, `query`, `captureMustContain` |
| The `first-frame.html` hashes of the two build rounds differ | The DOM changes when an animation ends, or time or random content was rendered | Let the DOM change only with state |
