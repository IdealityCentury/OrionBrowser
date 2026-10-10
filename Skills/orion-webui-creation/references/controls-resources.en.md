# Control contracts and resources

Every interactive control needs a stable identity and must be registered in the button contract. Sound, fonts, images, live frames and text each have exactly one integration channel. This document states only the rules and interface names that page authors must follow. For the Web lifecycle and Intent, see [Bridge and lifecycle](bridge-lifecycle.en.md). For the C++ Presenter and assets, see [UE-side host](native-host.en.md). For the first-frame package, see [InstantScreen](instant-screen.en.md). For how to import the plugin source, see [Web App scaffold](web-app-scaffold.en.md). For how to run the check commands, see [Build and validation](build-validation.en.md). Components, functions and inspectors marked "supplied by the host" are not in the plugin; the host project must implement them itself. All other symbols are inside `<OrionBrowser>`.

## A. Controls, button contract and sound

### A1. DOM marker attributes

| Attribute | Read by | Semantics |
| --- | --- | --- |
| `data-orion-control-id` | Plugin Runtime (control sound, Designer inspector, InstantScreen static action table) | The stable literal identity of a control, that is, its ControlId |
| `data-orion-fixed-button` / `data-orion-dynamic-button` | The plugin lists both as sound targets and ControlId compatibility candidates; the host contract checker maps their values to the contract's `buttons[].id` / `dynamicButtons[].id` | Fixed button (one DOM element per contract item) / dynamic button template (one template for many instances); mutually exclusive |
| `data-orion-sound-context` | Plugin Runtime | Written on the root container of a sub-interface; routes the sound of the controls inside it to the host policy with the same `ControlSoundContextId` |
| `data-orion-sound-policy` | Plugin Runtime | `manual` / `custom` / `none`: this node and its descendants skip automatic Hover/Click |
| `data-orion-action` | `installCommonActionRouter()` | When `ue:commonAction` is received, performs focus + click on the element whose value matches `actionId`; ignored if the element has `disabled` or `aria-disabled="true"` |
| `data-orion-event` | InstantScreen package build script | The event name recorded in the static first-frame action table; see [InstantScreen](instant-screen.en.md) |
| `data-focus-id` | Host navigation layer (supplied by the host); the plugin uses it only as a ControlId compatibility candidate | Instance / navigation identity; may be composed with a business ID |
| `data-orion-user-select` | Plugin Runtime | `text` / `all`: relaxes the default ban on text selection for that subtree; the page does not need to write `user-select: none` itself |
| `data-orion-font-policy` | Plugin Runtime | See B1 |

### A2. ControlId rules

- In templates, every native `button`, `input`, `select`, `textarea`, `a[href]`, `summary`, `role="button"` and every other clickable node must have a **literal** `data-orion-control-id`. Do not write it as `:data-orion-control-id="expr"` and do not concatenate variables.
- Use only letters, digits, `.`, `_` and `-`. Start with a letter or digit. At most 128 characters (the plugin truncates to 128 and rejects longer requests). The value `true` is treated as empty.
- Dynamic business IDs (item, player, message, index) go only into the Intent payload and into instance identities such as `data-focus-id`. Do not concatenate them into the ControlId or into a sound ID. All items of the same kind in a dynamic list share one ControlId:

```vue
<button
	type="button"
	data-orion-dynamic-button="sample-panel-items"
	data-orion-control-id="sample-panel-item"
	:data-focus-id="`sample-panel-item-${item.id}`"
	:disabled="!state.buttons.itemSelectEnabled || pendingSelection"
	@click="intents.itemSelectRequested(item.id)"
>{{ item.label }}</button>
```

- A control wrapped as a component: write one literal ControlId shared by all instances inside the component template, or have the call site pass a literal prop that is written unchanged to `data-orion-control-id` on the root DOM element (a focus-surface component supplied by the host should be implemented this way). The instance identity goes in a separate attribute.
- The plugin resolves the ControlId in this compatibility order: `data-orion-control-id` → `data-focus-id` → `data-orion-fixed-button` → `data-orion-dynamic-button` → DOM `id` → `name`. New pages must not rely on the fallbacks. A control without any stable ID can only play the default sound and cannot be overridden per control.
- The disabled state must be an expression, such as `:disabled="!state.buttons.confirmEnabled || pending"`. Business eligibility (`state.buttons.*`) is published by C++; the Web side only adds local draft, waiting and selection state. Do not write a literal `disabled` in templates.
- Pass the same literal as `controlId` in `requestIntent(name, payload, { controlId })`.

### A3. The button contract `webui-button-contract.json`

It lives at `<WebUIRoot>/<AppId>/webui-button-contract.json`, and every App must have one. Minimal template (`<HostModuleDir>` and `<HostDocsDir>` are host directories relative to `<ProjectRoot>`):

```json
{
	"version": 1,
	"appId": "SamplePanel",
	"cpp": {
		"header": "<HostModuleDir>/SamplePanelScreen.h",
		"source": "<HostModuleDir>/SamplePanelScreen.cpp",
		"dispatchFunction": "DispatchWebIntent",
		"stateBuilderFunction": "BuildStatePayload",
		"statePushFunction": "PushStateToWeb",
		"stateChangedEvent": "ue:samplePanel.stateChanged",
		"disabledGuardFunction": "RejectDisabledButtonIntent"
	},
	"documentation": "<HostDocsDir>/sample-panel-button-interfaces.md",
	"buttons": [
		{
			"id": "sample-panel-confirm", "controlId": "sample-panel-confirm", "page": "Sample Panel", "label": "Confirm",
			"webIntent": "intents.confirmRequested", "webEnabledState": "state.buttons.confirmEnabled",
			"webEvent": "samplePanel.confirmRequested", "stateKey": "confirmEnabled",
			"nativeEvent": "OnConfirmButtonClicked", "enabledProperty": "bConfirmEnabled",
			"defaultImplementation": "Validate the current selection, submit it, and publish the new state"
		}
	],
	"dynamicButtons": [
		{
			"id": "sample-panel-items", "controlId": "sample-panel-item", "page": "Sample Panel", "label": "List item (each)",
			"webIntent": "intents.itemSelectRequested", "webEvent": "samplePanel.itemSelectRequested",
			"cppEvent": "samplePanel.itemSelectRequested", "nativeEvent": "OnItemSelectRequested",
			"parameters": "FName ItemId", "enabledProperty": "bItemSelectEnabled", "validationSymbol": "TryResolveItem",
			"defaultImplementation": "Validate that ItemId belongs to the current list, then switch the selection"
		}
	],
	"intentTransport": {
		"runtimeProtocolVersion": 8,
		"api": "requestIntent",
		"requestEvents": ["samplePanel.confirmRequested", "samplePanel.itemSelectRequested"],
		"notificationEvents": ["samplePanel.stateApplied"],
		"dynamicForwarders": []
	}
}
```

**The plugin scripts read only `intentTransport`** (`validateIntentContract` in `<OrionBrowser>/Content/UI/WebUI/Shared/scripts/webui-intent-contract-lib.mjs`, run by `npm run contracts:project` in `<OrionBrowser>/Content/UI/WebUI/Shared` for every directory under `<WebUIRoot>` that has a `package.json`). It uses the TypeScript AST to scan the `.ts` / `.vue` files under the App's `src` (including template event expressions; files whose names contain `.test.ts`, `preview`, `fixture` or `mock` are skipped):

- `runtimeProtocolVersion` must equal `8`.
- `requestEvents`: every literal event name in all `requestIntent(...)` / `emitIntent(...)` calls must be in the list; every entry in the list must have a real call; an entry cannot also appear in `notificationEvents`.
- `notificationEvents`: the literal event names of all `x.emit(...)` and `emitContinuous(...)` calls. Any `.emit(` in property-call form counts as a Bridge notification; a bare `emit(...)` counts only if the file has no `defineEmits`. Business actions must not go through `emit`. Acknowledgement events sent on behalf of the page by the shared Runtime may be listed here; listing an event that has no call is not an error.
- `dynamicForwarders[]`: every call whose event name is not a literal must be registered one by one as `{ file, owner, expression, channel }`. `file` is relative to the App and uses `/`. `owner` is the name of the enclosing `function` declaration (arrow functions do not count; use an empty string if there is none). `expression` is the verbatim source text of the first argument (line breaks as LF). `channel` is `request` or `notification`. Do not use this if a literal can be written.
- `eventConstants[]` (optional): when event names are written in a protocol constant object, register `{ file, object }`. `file` is relative to the App, and the file must contain `<object> = { key: "event name", … } as const`. Once registered, arguments such as `requestIntent(<object>.<key>, …)` are validated as literal event names.
- `eventExpansions[]` (optional): when an argument is taken at run time from any entry of a protocol object, register `{ expression, sourceIncludes, file, object }`. `expression` is the verbatim source text of the argument, `sourceIncludes` is an identifier text that the file containing the call must include (may be omitted), and `file` may point to a shared protocol under `../Shared/src/…`. A matching call is validated against all events of that object one by one, and every event must be in `requestEvents` or `notificationEvents`.
- A registered file or object that does not exist is a failure; it is not treated as "no constants".
- If `<WebUIRoot>/Shared/src` exists, no Bridge call may appear in it. Shared components hand actions to the owning App through callbacks.

**The remaining fields are read by the button interface contract checker** (`<OrionBrowser>/Scripts/check-webui-button-interface-contract.ps1`, run per App; for its parameters see the script list in [Build and validation](build-validation.en.md)). Run it after changing a template, the contract or the Presenter, and use `-UpdateDocumentation` to generate `documentation`. The semantics below are also the only Web ↔ C++ mapping table.

| Field | Semantics |
| --- | --- |
| `cpp.header` / `cpp.source` | Presenter header / source file. If the implementation is split across several cpp files, use `version: 2` and register each one in `cpp.presenters[]` as `{ id, header, source }` |
| `cpp.dispatchFunction` | The function that receives Web events and dispatches them to the Native interfaces |
| `cpp.stateBuilderFunction` / `cpp.statePushFunction` | The function that builds the full state / the function that publishes the state to the Web side |
| `cpp.stateChangedEvent` | The state event name; the optional `stateChangedCppSymbol` points to the C++ constant that holds this name |
| `cpp.disabledGuardFunction` | Disabled guard: when eligibility is false, rejects the intent and pushes the authoritative state again |
| `documentation` | Path of the interface document generated from the contract (a generated file; do not write it by hand) |
| `web.componentHostFiles[]` | Generic control wrapper files (relative to the App) whose buttons are not marked one by one. Register only pure control wrappers, not business panels, otherwise the buttons inside the panel lose their checks |
| `intentTransport.api` | Always write `requestIntent` |

- `buttons[]` (fixed buttons): `id` equals the DOM `data-orion-fixed-button` and corresponds to exactly one DOM element; `controlId` equals the DOM literal; `webIntent` is the function called by the click expression, and `webEnabledState` must appear in the `:disabled` expression; `webEvent` uses a semantic `…Requested` suffix, and generic events such as `buttonClicked` are forbidden; `stateKey` is the eligibility key in the state, and `enabledProperty` is the corresponding C++ `bool` property (when eligibility is a computed value, write `enabledExpression` instead and do not invent a property); `nativeEvent` is the separate `BlueprintNativeEvent` of this button; `cppEvent` is optional, and when C++ keeps the event name in a constant, fill in the constant name.
- `dynamicButtons[]` (dynamic button templates): `id` equals `data-orion-dynamic-button` and corresponds to exactly one template; `cppEvent`, `parameters` (the Native interface parameters) and `validationSymbol` (the C++ function that validates the identity in the payload) are also required. `guardMode` defaults to `disabled-button`; when changed to `structured-request`, also fill in `structuredRejectionSymbol`.
- `componentControls[]` (buttons forwarded through child components, and local draft controls): common fields are `id`, `controlId`, `file` (relative to the App), `page`, `label`, `kind`, `activation` (the verbatim click expression in the template) and `defaultImplementation`. When the same semantic button appears repeatedly in several conditional branches, declare the number of templates with `occurrences`. When a disabled condition is declared, write `enabledExpression` (it must appear in `:disabled`).

```json
"componentControls": [
	{
		"id": "sample-panel-filter-toggle", "controlId": "sample-panel-filter-toggle",
		"file": "src/components/FilterBar.vue", "page": "Sample Panel", "label": "Filter toggle",
		"kind": "local", "activation": "toggleFilter()", "handler": "toggleFilter",
		"defaultImplementation": "Only toggles the local filter draft"
	},
	{
		"id": "sample-panel-apply", "controlId": "sample-panel-apply",
		"file": "src/components/FilterBar.vue", "page": "Sample Panel", "label": "Apply filter",
		"kind": "native", "activation": "$emit('apply')", "enabledExpression": "state.buttons.applyEnabled",
		"forwarding": { "file": "src/App.vue", "component": "FilterBar", "event": "apply", "handler": "applyFilter" },
		"operations": [
			{ "webEvent": "samplePanel.filterApplyRequested", "nativeEvent": "OnFilterApplyButtonClicked", "dispatchFunction": "DispatchWebIntent", "dispatchToken": "bFilterApply", "guardExpression": "CanApplyFilter()" }
		],
		"defaultImplementation": "Validate the filter conditions, rebuild the list, and publish the state"
	}
]
```

- `kind=local`: only draft toggling, candidate selection, scrolling, and cancelling a confirmation that has not been dispatched. `handler` is a plain function name, and the function body must not call `emit`, `requestIntent` or `requestCommand`. To submit business actions, change it to `kind=native`.
- `kind=native`: `forwarding` describes the real event binding of the parent component (`<FilterBar @apply="applyFilter">`); when the child component emits a camelCase event while the parent binds with kebab-case, add `forwarding.emittedEvent`. Register every native request in `operations[]`: `dispatchToken` is the name of the local variable in the dispatch function that stores the result of `EventName == TEXT("<webEvent>")`, and `guardExpression` is the expression passed to the disabled guard before `nativeEvent` is called. When you only reuse the intent of an already registered button, fill in `nativeReference` instead (its value is that button's `id`, and the parent component binds its `webIntent`), and do not add a duplicate Native interface.

### A4. Native interfaces and disabled guards of fixed buttons

- Each fixed button corresponds to one separate `UFUNCTION(BlueprintNativeEvent)` (such as `OnConfirmButtonClicked()`; the default implementation must not be empty) and one eligibility published by C++ (such as an `EditDefaultsOnly` `bool bConfirmEnabled`, or a computed expression). Do not use "one generic click interface + a button ID parameter".
- In the dispatch function, guard first and then call: `if (RejectDisabledButtonIntent(bConfirmEnabled, EventName)) { return; } OnConfirmButtonClicked();`. The guard is implemented by the host Presenter; when it rejects, it pushes the authoritative state again so that the page returns to the real eligibility.
- The state builder function serializes each eligibility to its `stateKey`; the page's disabled binding reads only this state. For intent acknowledgement and state publishing, see [UE-side host](native-host.en.md).
- When modifying an existing interface, keep the Blueprint overrides the user already has, and do not change interface names or parameters.

### A5. Sound

There are two channels. A single interaction goes through only one of them:

| Channel | Configuration owner | Trigger |
| --- | --- | --- |
| Control Hover / Click | Class Defaults of the Widget Blueprint that hosts the interface: `UOrionWebUIActivatableWidget.ControlSoundPolicy` or `UOrionInstantScreenActivatableWidget.ControlSoundPolicy`. Not in the AppDefinition, not in ini | The plugin delegates automatically at the document layer; the page writes no code |
| Business-semantic sound (confirm, back, error, slider tick) | `UOrionWebUIAppDefinition.SoundManifest` (`UOrionWebUISoundManifest.Entries[].StableId`) | The page calls `playSound` |

- `ControlSoundPolicy.DefaultSounds.HoverSound / ClickSound` are the default sounds. `ControlOverrides[]` overrides per `ControlId`, using `bOverrideHoverSound` / `bOverrideClickSound` separately. To mute an item, override it and set that item's `bEnabled` to false: it consumes the interaction and does not fall back to the default sound.
- Automatic targets: nodes with `data-orion-control-id`, `data-orion-fixed-button` or `data-orion-dynamic-button`, and `button`, `[role="button"]`, `a[href]`, non-hidden `input`, `select`, `textarea` and `summary`. Hover plays when the pointer first enters or DOM focus enters; Click plays on `click`.
- A disabled control stays silent according to `:disabled`, `aria-disabled="true"` and `aria-busy="true"`. A control that expresses disabled or loading only through a CSS class still makes sound, so disabled and waiting states must be expressed through one of these three attributes.
- When one Browser hosts several host Widgets, write `data-orion-sound-context="<ContextId>"` on the root container of the sub-interface, identical to the `ControlSoundContextId` of that Widget. It is only a policy routing key; it does not replace the ControlId and does not appear in the override table.
- When gamepad logical navigation does not move DOM focus, C++ calls `PlayControlSound(ControlId, Interaction, ContextId)` with the same stable ControlId (first resolve the navigation / focus ID back to the ControlId).
- Call `api.playControlSound(controlId, "hover" | "click", contextId?)` only for interaction areas that have no DOM events (for example a canvas hit area); an ordinary node with `data-orion-control-id` is already an automatic target.
- The plugin does not prescribe sound IDs: the `StableId` in `SoundManifest` is a stable literal defined by the host, and `ui.hover` and `ui.click` in the plugin template are only example values. The page calls `await api.playSound("sample.confirm")`, optionally with `{ volumeMultiplier, pitchMultiplier, startTime }`; or uses `playUISound(api, id, options)`, which silently returns `undefined` when `api` is missing or the request is rejected.
- Codes with which `playSound` is rejected: `E_SOUND_DISABLED` (`bAllowWebSoundPlayback` is off), `E_INVALID_ARG` (missing `soundId`), `E_SOUND_UNAVAILABLE` (no Manifest or no such ID, the entry is disabled, or no asset is configured).
- Boundaries: do not load or play audio files in the page; do not concatenate business IDs into sound IDs; do not use `playSound` to add a generic Hover/Click to standard controls (it would play twice together with the automatic delegation). The `@mouseenter` plus `playUISound` on buttons in the plugin template `App.vue` is only a Bridge demonstration; new interfaces must not copy it. A node or container that already has its own semantic sound gets `data-orion-sound-policy="manual"` so that the automatic policy skips it.

### A6. The ControlId inspector in UMG Designer

Provided by the plugin Editor module. In a Widget Blueprint, select `UOrionWebUIWidget` (category `Orion WebUI|Editor`) or `UOrionInstantScreenWidget` (category `Orion InstantScreen|Editor`) and set `DesignTimeControlIdPreviewMode`: `HoveredControl` (default, shown on hover), `AllControls` (marks all controls on the current page, with an upper limit on the count) or `Hidden`. This requires `bShowDesignTimePreview` to be true and the page to be loadable in Designer. A blue label is the resolved ControlId, and a red `<missing>` means the literal is absent. It is correct for several rows of a dynamic list to show the same value; a value that contains a business ID or index means concatenation was used. It shares the same selector and resolution order as the run-time sound policy: after writing a template, use it to check, and only then fill in `ControlOverrides`.

### A7. Custom context menus

- `UOrionWebUIWidget` always suppresses the native Chromium menu (there is no switch), so the context menu is implemented by the page: listen for `contextmenu` on the target element and call `preventDefault()`; alternatively, on the right-button `pointerdown`, first record the hit stable domain ID and open the menu.
- If `pointerdown` inserts a full-screen overlay, the `contextmenu` that then arrives from the same gesture hits the overlay. Consume this pair of events as one gesture, and do not let the overlay immediately close the menu that was just opened.
- A right click only opens the menu. Menu items are ordinary controls (with a ControlId, in the contract), their actions are handed to C++ for validation through `requestIntent`, and permissions come from C++ state. Do not override the existing semantics of Esc and the back action.

### A8. Continuous pointer sessions (drag, hold, rotate)

All "press - move - release / cancel" interactions use `createOrionPointerSession()` from `<OrionBrowser>/Content/UI/WebUI/Shared/src/input/orion-pointer-session.ts`. Do not register window-level move / up listeners yourself.

```ts
const session = createOrionPointerSession({
	allowedButtons: [0],
	allowedPointerTypes: ["mouse", "pen", "touch"],
	dragThreshold: 6,
	coalesceMovesWithAnimationFrame: true,
	accept: (event) => !dragDisabled.value && !(event.target as Element).closest("button"),
	onMove: (_event, snapshot) => previewDrag(snapshot.totalDeltaX, snapshot.totalDeltaY),
	onCommit: (_event, snapshot) => { if (snapshot.thresholdReached) intents.itemMoveRequested(buildMovePayload(snapshot)); },
	onCancel: () => clearDragPreview(),
});
// Template: @pointerdown="session.begin($event, $event.currentTarget)"; onBeforeUnmount(() => session.dispose())
```

- Only the `pointerup` with the same pointer ID triggers `onCommit`, exactly once. `pointercancel`, window blur, document hidden, the page being covered / suspended, leaving Active, and `dispose()` trigger only `onCancel`. The shared lifecycle automatically cancels all sessions in this document when the page is covered, suspended or destroyed.
- Write the presentation preview in `onMove`, the single business intent in `onCommit`, and cleanup in `onCancel`. For server-authoritative operations, send the intent only once in commit and wait for the authoritative state to be echoed; do not permanently change the state locally.
- Do not read `PointerEvent.buttons` to decide whether a button is still held, and do not treat `lostpointercapture` as a release (both are unreliable under off-screen rendering, and the session already degrades them); do not add Timers, polling or timeout compensation.
- State is read only from the `snapshot` in callbacks (`generation`, `pointerId`, start point, delta, `thresholdReached`, `captureOwned`); do not keep a separate `active / pointerId / startPosition`.
- A move can have only one owner: when a kind of pointer is already handled by a Native-side drag, exclude it in `allowedPointerTypes`. The Native Surface layer does not receive pointers and cannot be a drag target.

## B. Resources

### B1. Fonts

- All fonts come from UE: the `UOrionWebUIFontManifest` that the project-level `UOrionWebUIFontSettings.SystemFontManifest` points to, which new Apps inherit by default. Set `UOrionWebUIAppDefinition.FontManifest` or `bOverrideFontPolicy` only when an independent font is really needed. Pages do not declare their own `@font-face` and do not depend on system fonts.
- Before mounting, the entry calls `ensureOrionWebUIFontStylesheet("<AppId>")` (`<OrionBrowser>/Content/UI/WebUI/Shared/src/instant-screen/orion-instant-screen-vue.ts`). It creates `link#orion-webui-fonts` with the address `https://orion-webui.local/<AppId>/ue/fonts/orion-fonts.css`. The document may have only this one font stylesheet entry: the host adopts it by this id and replaces it atomically on language switch; creating another link without the id leaves a duplicate stylesheet.
- CSS consumes only Manifest variables and does not hard-code font families: for body text use `font-family: var(--orion-webui-body-font-family, var(--orion-webui-font-family, sans-serif))`, and for headings replace the first variable with `--orion-webui-heading-font-family`.
- The plugin automatically writes `data-orion-font-role` on elements with direct text and on form controls, and sets their `font-family` with `!important`: if the computed font size is greater than the policy threshold (`FontPolicy.HeadingFontSizeThresholdPx`, default 24), the heading font is used (only for languages the policy allows); otherwise the body font is used. It changes only `font-family`; font size, weight, line height and letter spacing are decided by the page CSS. Newly added or replaced text subtrees are assigned a role before they are painted, so the page does not need to compensate for dynamic text.
- `data-orion-font-policy` is written on a node or an ancestor, and the nearest one is used: `body` / `heading` forces a role, `none` means that subtree uses the page's own font declarations entirely; any other value, or no value, means automatic decision.
- Text inside `svg` and `canvas` does not take part in the automatic policy. For self-drawn text, get the font family with `api.getFontFamilyForSize(sizePx)` (or `resolveFontRoleForSize`).
- First-frame font identity: InstantScreen first-frame capture keeps only stylesheet links that point to `orion-webui.local/.../ue/fonts/`, and the Controller Host also references `/<AppId>/ue/fonts/orion-fonts.css` as a fixed path. `<AppId>` must be the App that is actually loaded at run time (consistent with the package identity); changing an App of the same name that is not loaded has no effect.
- The InstantScreen presentation gate runs `document.fonts.load()` and `check()` for each mounted real piece of text according to the family / style / weight in the Manifest; it does not wait for `document.fonts.ready` only once. Therefore: text that must appear in the first frame is mounted into the DOM when the state is committed; the page's own preparation logic does not treat `document.fonts.ready` as "fonts are ready" and does not use `requestAnimationFrame` to advance the wait in the preparation phase - the document is invisible during preparation, rAF is not guaranteed to fire, and it would end up waiting on the Reveal gate while the gate waits on it. Use a Promise chain or `MessageChannel`.
- When a new font is needed, the UE side provides, for each family + weight actually used, a complete WOFF2 `UOrionWebUIFontPayload` and fills it into `FOrionWebUIFontFaceEntry.WebPayload`; do not subset by characters, do not fill `UnicodeRangeCss`, and the same family + weight + style has only one Face. The generation tool is `<OrionBrowser>/Scripts/Fonts/generate-orion-webui-font-payload.py` (`--font`, `--output`, `--full-font`).

### B2. Images

| Image source | Channel |
| --- | --- |
| Static UI images (backgrounds, illustrations, icons, map previews, etc.) | Put them in the App directory so that they are packaged with the WebUI, WebP recommended; C++ publishes only a stable ID, and the page resolves it to a packaged URL |
| Low-frequency `UTexture2D` that must be produced by UE at run time (avatars, icons generated at run time) | Runtime Image |
| The producer already holds CPU pixels | `RequestPixelResource` (same lease and URL scheme) |
| Continuously updated frames (SceneCapture, RenderTarget, Media, dynamic materials) | Native Surface, see B3 |
| Immutable non-image bytes needed by InstantScreen (such as glTF) | `UOrionInstantScreenEndpoint::RegisterBinaryResource(StableId, Bytes, MimeType)` |

Do not create a new `UTexture2D` for a static image, and do not add entries to `UOrionWebUIAssetManifest`. The mapping from stable ID to URL is maintained by the page (supplied by the host, in the form):

```ts
import harborUrl from "../assets/maps/map-harbor.webp";
import quarryUrl from "../assets/maps/map-quarry.webp";

const previewUrls: Readonly<Record<string, string>> = Object.freeze({ "Map.Harbor": harborUrl, "Map.Quarry": quarryUrl });

// An unknown or empty ID returns ""; the page then shows an empty-state base image.
export function resolvePreviewUrl(previewId: unknown): string {
	return typeof previewId === "string" && Object.prototype.hasOwnProperty.call(previewUrls, previewId) ? previewUrls[previewId] : "";
}
```

- To convert to WebP, use `<OrionBrowser>/Scripts/Images/optimize-webui-image.py` (`--input`, `--output`, optional `--crop x,y,w,h`, `--size WxH`, `--fit contain|stretch`, `--quality`, `--lossless`).
- Every `<img>` tag in templates and in non-test `.ts` files carries the static attribute `decoding="async"`, placed first after `<img` (for how the App contract script matches it, see [Web App scaffold](web-app-scaffold.en.md)). `npm run images:decoding:check` in `<OrionBrowser>/Content/UI/WebUI/Shared` checks all Apps under `<WebUIRoot>`; `images:decoding:fix` rewrites the source of all Apps, so run it only when the user explicitly asks, and fill in your own App by hand.
- Keep the original aspect ratio of images: set `aspect-ratio` on the container, use `object-fit: contain` or `cover` for the image, and do not stretch width and height separately.
- Forbidden: encoding an image as Base64 into the state or passing bytes through the Bridge, writing temporary PNG files, per-frame Readback, and using a Runtime Image as a video stream.

Runtime Image essentials (for the C++ call details, see [UE-side host](native-host.en.md)):

- Both `UOrionWebUIWidget` and `UOrionInstantScreenEndpoint` provide `RequestTextureResource(StableId, Texture, Options)`, which returns `FOrionWebUITextureResourceHandle { RequestId, StableId, Url }` immediately and triggers `OnTextureResourceCompleted` on completion. The URL has the form `https://orion-webui.local/<AppId>/ue/runtime/<token>`, and `token` is opaque.
- One `StableId` is one lease. Requesting the same `StableId` again yields a new generation of URL, and the old URL is retired afterwards. Call `ReleaseTextureResource(StableId)` when the entry is removed, and `ReleaseTextureResources()` when the interface is destroyed. The page does not parse, concatenate or cache URLs; it uses only the value in the current state.
- When pixels change in place, increment `Options.SourceRevision` (or call `InvalidateTextureResource`); do not request the image again for pure data changes such as counts or selection state. Set `Options.MaxOutputDimension` according to the actual display size; for transparent item-style icons use `NormalizationPolicy = TransparentIcon`, and keep `None` for avatars and ordinary images. Virtual textures are not supported (`UnsupportedVirtualTexture`).
- Slots that take part in the first frame: C++ writes the URL into the state only after it receives a Ready result that matches both the current `RequestId` and the URL, and `IsTextureResourceReady(StableId)` is true. `HasTextureResource` is also true while Pending, so it must not be used as "displayable".
- The Web side needs an **in-memory image component (supplied by the host)**, and every run-time URL that may be replaced by a state refresh is displayed through it; do not write `<img :src="url">` directly. Required behavior: the candidate URL first completes `load` and `decode()` in a detached `Image`, and only after success atomically replaces the currently displayed node; while the candidate is Pending, fails, or is superseded by a newer value, keep the last-good; each use site gets its own cloned node and does not share one detached node; the latest request wins and late results are discarded.
- Reason: the InstantScreen presentation gate requires every visible `<img>` in the Controller document to load and decode pixels, and any single failure fails that presentation; a bare `<img>` bound to a retired candidate URL triggers `error`.

### B3. Native Surface

Composes a live texture or UI material held by UE directly into the page layout: Slate draws at the DOM anchor rectangle, and the pixels do not enter JavaScript.

- UE side (`UOrionWebUIWidget` or `UOrionInstantScreenEndpoint`): `SetNativeSurfaceTexture(SurfaceId, Texture)`, `SetNativeSurfaceMaterial`, `SetNativeSurfaceTint`, `SetNativeSurfaceCompositionLayer`, `ClearNativeSurface`, `ClearNativeSurfaces`. `OnNativeSurfaceLayoutChanged` fires when position, size or visibility changes, and when `bVisible` is false, frame production should be paused.
- On the Web side use `<OrionBrowser>/Content/UI/WebUI/Shared/src/components/OrionNativeSurface.vue`: `<OrionNativeSurface surface-id="SamplePreview" class="preview-anchor" />`. The only prop is `surfaceId`; the root node is a `div.orion-native-surface` carrying `data-orion-native-surface`, and there is a default slot. Without the component, use `const release = api.bindNativeSurface(surfaceId, element)` directly and call `release()` on unmount. `surfaceId` uses a stable literal and matches the UE binding character for character.
- The anchor must be in the real layout tree, and `getBoundingClientRect()` is the only source of position and size (CSS transforms are already included). Neither UE nor the Web side writes fixed coordinates separately, and the UE side no longer multiplies by DPI or render scale.
- The default composition layer is `AboveBrowser`: the web content inside the anchor rectangle is covered by the native picture. Draw the border on an outer container and inset the anchor with `position: absolute; inset: 1px`; the DOM in the slot is only a placeholder for browser preview or for a missing resource.
- Position, size, translate / scale, opacity and ancestor clipping are supported; rotate / skew and DOM rounded-corner clipping are not supported - put rounded corners, masks and fade-outs into the UE UI material.
- Use `BelowBrowser` only when the DOM must be on top of the picture. It requires `AppDefinition.bSupportsTransparency`; otherwise it is rejected and `OnWebError` fires.
- The native layer does not receive input, and pointer and focus still belong to the Browser. Layout measurement is driven by the plugin (every frame during Resize / Mutation / scrolling / ancestor animation); the page does not write its own rAF measurement or timed rebinding.
- At most 512 bindings per document. For many icons in a list, use Runtime Image and do not use one Surface per cell.
- Inside an InstantScreen Controller: the page writes a local `surfaceId`, the Runtime automatically scopes it to `<ScreenInstanceId>__<surfaceId>`, and C++ uses the same local ID through the Endpoint.
- The scoped API inside a Controller may become ready before the Native Surface API: `await api.waitForNativeSurfaceApi?.()` before binding. The plugin's own `OrionNativeSurface.vue` does not wait for this step and silently swallows binding exceptions (so that it can run in the browser preview), so in a Controller use a wrapper that waits (supplied by the host):

```ts
let generation = 0;
let release: (() => void) | undefined;
async function bind(api: OrionWebUIApi, element: HTMLElement, surfaceId: string): Promise<void> {
	const current = ++generation;
	release?.();
	release = undefined;
	await api.waitForNativeSurfaceApi?.();
	if (current === generation) {
		release = api.bindNativeSurface(surfaceId, element);
	}
}
// Unmount: ++generation; release?.(); release = undefined;
```

- When a keep-document page is rebound to a new Screen instance, the component is not remounted and the binding key is migrated by the Runtime. Do not treat `onMounted` as the only source of layout for a new instance, and do not retry with a Timer. When an active refresh is needed, call `api.requestNativeSurfaceLayoutSnapshot?.()` (the shared lifecycle already calls it every time the page enters Active).
- Realm: elements in a Controller document come from another JavaScript Realm, so `instanceof Element / HTMLElement / Node` of the outer Realm is always false for them. Any shared code that receives nodes across documents uses `nodeType === 1` to decide, and gets `getComputedStyle`, `MutationObserver` and so on from `element.ownerDocument.defaultView`.
- Resource retirement order (C++): first stop frame production or material parameter writes → `ClearNativeSurface`, or replace atomically with `SetNativeSurfaceTexture` / `SetNativeSurfaceMaterial` → release the business-side dynamic material references → finally destroy the RenderTarget, SceneCapture, Actor or player. When changing the RenderTarget, create a new dynamic material instance and then call `SetNativeSurfaceMaterial`; do not change texture parameters on an instance that is still bound. Do not use delays or forced Flush in place of this order.

### B4. Localization

- The text source is `UOrionWebUIAppDefinition.TextCatalog` (`UOrionWebUITextCatalog.Texts`, Key → `FText`). Keys use stable English dot-separated paths, such as `samplePanel.confirm`.
- The page writes only the Key and fallback text: `translate(table, "samplePanel.confirm", "Confirm")` (`<OrionBrowser>/Content/UI/WebUI/Shared/src/bridge/orion-webui.ts`). The initial table comes from `localization` (`{ culture, texts }`) in the bootstrap.
- Listen for `ue:localeChanged` and replace the whole text table. It is a retained event: a listener registered late immediately receives the latest value, the page does not need a refresh, and the font stylesheet is replaced automatically with the language.
- On a language switch, replace the text of **the same semantic node**; do not attach a separate node for each language, and do not hard-code two languages side by side on the interface.
- Finite enumerations that cross C++ / JSON / Web use fixed string wire tokens and do not depend on the display casing of `FName`.

### B5. WebGL and advanced visuals

- Business state is still published by C++, and the WebGL layer only does presentation. When the picture is hidden, covered or parked, stop the render loop and release GL resources: in the lifecycle `onPresentationCovered`, `onPresentationSuspended` and in component unmount, stop rAF and destroy the context and textures, and rebuild in `onPresentationRestored` (for the callbacks, see [Bridge and lifecycle](bridge-lifecycle.en.md)).
- Use dynamic `import()` for heavy modules such as three.js, and do module resolution and WebGL initialization after the entrance animation ends; initializing earlier occupies the render thread and makes the entrance animation stall.
- During InstantScreen first-frame capture (the URL carries `orionInstantBuild=1`), do not start the live rendering layer; otherwise the first-frame DOM gets a canvas mixed in and capture slows down.
- Render mode: an InstantScreen session requires `LegacyTexture`, and in other modes session creation is rejected. WebGL is not available in `FullIR` mode (`EOrionWebUIFallbackReason` lists WebGL and Canvas2D as fallback reasons, while strict FullIR does not fall back); for 3D pictures in a FullIR page, use Native Surface.
- CSS restrictions (`npm run animations:contract:check` in `<OrionBrowser>/Content/UI/WebUI/Shared`): do not use `backdrop-filter`, `mix-blend-mode` or `prefers-reduced-motion` rules, and do not apply `transition` to `filter`.

### B6. World-space overlays and resource routing

- A World overlay projects Actor-following markers and health bars onto the screen: each LocalPlayer shares one overlay (`OrionWorldOverlayDOM.vue`) in one Browser, the Actor side attaches only the pure-data `UOrionWebUIWorldElementComponent`, and `UOrionWebUIWorldSubsystem` batches them into one `ue:worldElements` event. Do not create a Browser or Widget for each Actor.
- The authoritative routing of page-level resources and sound is `ScreenInstanceId → ScreenDefinition → AppDefinition → SoundManifest / FontManifest / AssetManifest` (for a plain Widget, `UOrionWebUIWidget → AppDefinition`). Do not use a Widget Blueprint name, a DOM route or a BrowserId as the long-term key of sound, font or image resources; the keys of Runtime Image and Native Surface are the stable `StableId` / `SurfaceId` given by the caller.

## Failure signatures at a glance

| Signature | Cause | Handling |
| --- | --- | --- |
| `uncontracted request <event>; business actions must use requestIntent` | An event not registered in the contract was called | Add it to `requestEvents` or `notificationEvents` |
| `business emit bypasses requestIntent: <event>` | A business event listed in `requestEvents` was sent with `emit` | Use `requestIntent` instead |
| `unaudited dynamic <channel> forwarder <expr>` | The event name is not a literal and is not registered | Change it to a literal, or register `dynamicForwarders` |
| `contracted request has no production call: <event>` | It is in the contract but has no call in the source | Add the call or delete it from the contract |
| `WebUI <img> tags missing decoding="async":` | `<img>` lacks `decoding` | Add `decoding="async"` by hand on the reported tags, then rerun `check` |
| A disabled or loading button still makes sound; or one click sounds twice | Disabled is expressed only by a class; the automatic policy and a manual `playSound` coexist | Express it with `disabled` / `aria-disabled` / `aria-busy`; delete the manual call or mark `data-orion-sound-policy="manual"` |
| The page shows the browser default font | There is no `link#orion-webui-fonts`, `<AppId>` is not the App actually loaded, or CSS hard-codes a font family | Wire the entry and variables as described in B1 |
| `FontManifest face failed exact load/check: <descriptor>` | A Face in the Manifest cannot be loaded exactly by family / style / weight | Check the UE-side FontManifest and `WebPayload` |
| `Controller image <url> for <ScreenId> failed to load` | A visible bare `<img>` is bound to a retired or not-ready run-time URL | Display it through the in-memory image component; C++ publishes only Ready URLs |
| The Surface area is blank but the RenderTarget has pixels | `waitForNativeSurfaceApi()` was not awaited inside the Controller, or the `SurfaceId` differs between the two sides | Use the binding wrapper that waits; check the IDs |
| `InstantScreen Runtime=<id> requires explicit LegacyTexture; session creation refused` | The render mode is not `LegacyTexture` | Adjust the host render mode configuration |
