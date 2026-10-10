# Page integration: Bridge, lifecycle, state and Intent

This document covers only the script part of the Web-side `App.vue`. For the scaffold files see [Web App scaffold](web-app-scaffold.en.md); for how C++ publishes state and receives Intents see [UE-side host](native-host.en.md); for the first-frame package and the in-layer Runtime see [InstantScreen](instant-screen.en.md). Module paths in this document are relative to `<OrionBrowser>/Content/UI/WebUI/Shared/src/`; names and parameters follow the current source in that directory.

## Principles

- C++ owns business state, button availability and input gates. The page does only four things: render the full state snapshot, submit Intents, report the exact revision, and run layout and animation.
- The page keeps no second copy of business facts and does not do "succeed locally first, sync later". An Intent result only ends the transport wait; interface changes follow the authoritative snapshot that arrives afterwards.
- An acknowledgement (ACK) sent by the page has only two purposes: to make C++ stop resending, or to prove that a given revision has been committed / presented. It cannot advance, roll back or fake business success.
- An acknowledgement must carry the exact revision. Acknowledgements with a zero value, a stale value, a value ahead of the request, or no matching request are discarded; do not resend, change the value, or substitute a different acknowledgement.
- The page does not create a Browser, does not control Runtime visibility, and does not duplicate Ready polling, retry timers, fixed delays, hidden preloading or a self-built entrance/exit state machine; everything goes through the plugin entry points listed in this document.

## Getting the Bridge

| Entry point (`bridge/orion-webui.ts`) | Behavior |
| --- | --- |
| `waitForOrionWebUI(timeoutMs = 5000)` | Returns `Promise<OrionWebUIApi>`. Inside an `orion-webui.local` host it waits until the Bridge is installed; in a normal browser it rejects after the timeout; when the URL carries `?orionDesignPreview=1` it rejects immediately. The reject branch is the page's design-preview branch |
| `resolveOrionWebUIForMount(timeoutMs = 5000)` | Use before mounting: inside the host it waits for installation; in a normal browser and in design preview it returns the existing API or `undefined` directly |
| `getOrionWebUI()` | Reads `window.OrionWebUI` synchronously; may be `undefined` |

When the API is obtained through these entry points, the plugin also installs the document lifecycle policy (`runtime/orion-webui-document-lifecycle.ts`): it writes `<html data-orion-lifecycle-state>` according to `ue:webUI.lifecycleChanged`, and injects styles that disable animation and pointer input. Do not bypass the entry points and use `window.OrionWebUI` directly.

`OrionWebUIApi` has two providers. The interface has the same name but different capabilities: a plain `UOrionWebUIWidget` document gets it injected by C++; the Controller document of an InstantScreen gets an API that the Runtime isolates per Screen instance. `requestIntent`, `getIntentRequests`, `dismissIntentNotice` and `getInitialState` exist only in the latter, and the TypeScript types do not distinguish the two for you.

## API surface

| API | When to call | Returns | What it proves |
| --- | --- | --- | --- |
| `ready()` | After the key listeners are registered (called by the template) | `Promise<OrionWebUIBootstrap>`: `appId`, `apiVersion`, `route`, `localization`, `assets`, `sounds`, `fonts` | Only proves the Bridge can send and receive; it does not mean resources, state, input or presentation are ready |
| `inputReady()` | After input listeners such as keys, navigation and `ue:commonAction` are installed (called by the template) | `Promise` | Only proves the input handlers are installed; the Presenter of an InstantScreen receives Ready only after both the Bridge and Input are ready |
| `localResourcesReady()` | After the page resources are prepared (called by the template) | `Promise`; rejects on failure | The stylesheets, font policy, fonts and images of the current document are ready |
| `stateCommitted(rev)` | After the full snapshot is applied and the DOM is flushed (called by the state channel) | InstantScreen returns `{ accepted }`; `false` when `rev` is not the current authoritative revision | The DOM for that `stateRevision` is committed |
| `controllerVisualReady(rev)` | After the static visuals for that revision are complete (including localized text) | InstantScreen returns `{ accepted }` | Static visuals are ready; it only releases hidden preparation and does not mean the page has been revealed |
| `on(name, handler)` / `off` | Any time; key listeners must be registered before `ready()` | `on` returns a cancel function | Retained events replay the most recent payload at registration |
| `emit(name, payload?, meta?)` | Sending notifications and acknowledgements | `Promise` | Only proves delivery to the bridge, not the business outcome |
| `call(name, payload?, meta?)` | A request that needs a result in a plain Widget document | `Promise<TResult>`; rejects on failure, and `error.code` is readable | One bridge round trip; in an InstantScreen, business names are rejected with `E_INSTANT_USE_INTENT` |
| `handle(name, handler)`, `routeChanged(route)` | Answering calls initiated by C++; notifying the host after an in-page route change | A cancel function (the handler may return a value or a Promise); `Promise` | — |
| `requestIntent(name, payload?, { controlId? })` | Business buttons (InstantScreen Controller only) | `Promise<OrionIntentResult>` | The transport and acceptance result; see "Typed Intent" |
| `getInitialState?.()` | Read synchronously at mount (InstantScreen only) | The initial C++ snapshot of this presentation transaction | — |
| `playSound(soundId, options?)` | Plays a sound from the SoundManifest | `Promise<{ played, soundId }>` | — |

- `playUISound(api, soundId, options?)` is a wrapper that swallows failures; use it in click handlers instead of `await playSound`. For control hover / click sounds, the font policy and Native Surface binding see [Controls and resources](controls-resources.en.md).
- Replay rules: in a plain document, `ue:bootstrap`, `ue:localeChanged`, `ue:inputModeChanged`, `ue:inputPromptsChanged` and events that C++ sends in retained mode are replayed synchronously at `on()`; in an InstantScreen, retained events are replayed in the next microtask. Non-retained one-shot events dispatched before registration are lost, so state must not depend on them.

## Startup order (mandatory template)

1. Get `api` and the lifecycle root element; if no Bridge is available, take the preview branch and do not attach the lifecycle.
2. If the page keeps its own revision baseline, first register the instance identity listener (see "Document reuse and instance isolation").
3. Register the state channel, high-frequency channels, input listeners and business event listeners, and store the cancel functions in an array.
4. `createOrionWebUILifecycle({ api, root, ... })`. On construction it immediately sets the root node to `preparing`, and subscribes to `ue:webUI.lifecycleChanged`, the entrance request, `ue:webUI.presentationCovered`, `ue:webUI.presentationRestored` and `ue:webUI.presentationSuspended`.
5. `await lifecycle.initialize()`: starts `ready()`, `inputReady()` and page resource preparation in parallel (`localResourcesReady()` is called automatically when it finishes); after `ready()` returns it sends `webUI.presentationReady`, and finally returns the bootstrap. Repeated calls return the same Promise; if it is disposed during initialization, it rejects with `AbortError`.
6. After the `await`, first check that the component is not destroyed and still belongs to the current generation, then write the localization, and report readiness for the currently applied `stateRevision` (see the skeleton).
7. On unmount, call `lifecycle.dispose()`, then call the cancel functions one by one. `dispose()` aborts resource preparation and sets the root node to `suspended`.

| `createOrionWebUILifecycle` option | Purpose |
| --- | --- |
| `api`, `root` | The Bridge and the lifecycle root node; the template writes `data-orion-presentation` and `aria-hidden` on the root node |
| `presentationRequestedEventName` | The host uses its own reliable entrance event (such as `ue:samplePanel.enterRequested`) in place of `ue:webUI.presentationRequested` |
| `autoPresentWithoutRequest` | On by default: if the state is still `preparing` after `ready()`, it automatically enters with revision 1, for Designer preview and direct Widget hosts. Set it to `false` when the host guarantees that every real appearance sends an entrance event; otherwise there will be an extra acknowledgement that nobody claims, or a duplicate entrance |
| `onPresentationRequested(rev, payload)` | Before entrance, switch the page to its final static visible state; the template acknowledges only after the returned Promise completes |
| `onPresentationRestored(rev, payload)` | Restore after being covered; same requirement as above |
| `onPresentationCovered(rev, payload)` | Being covered; after it completes, the template replies with `webUI.presentationCoverageApplied` |
| `onPresentationSuspended(rev, payload)` | Called synchronously when covered, parked or rebound to another instance: clear local presentation state, stop rAF, timers and WebGL |
| `presentationAnimationName`, `localResourceTimeoutMs` | A hint for the entrance animation name; the page resource preparation timeout |

The entrance acknowledgements `webUI.presentationApplied` and `webUI.presentationEnterApplied`, the restore acknowledgement `webUI.presentationRestoreApplied`, and the covered acknowledgement are all sent by the template with the exact `presentationRevision`; the page must not send them again. `rootEntranceMotion` has only one value, `"none"`; root node motion is the responsibility of the page CSS. Covered / Restored events are sent by the host C++; if the host does not implement them, the page goes only through requested and suspended.

When you need only the readiness pipeline and the page handles presentation requests itself, use `startOrionWebUIReadiness(api, root, localResourceTimeoutMs?, prepareLocalResources?)` instead, which returns `{ bootstrap, dispose }`. The fourth parameter is a page-defined resource preparation callback, which `createOrionWebUILifecycle` does not expose. In that case use `createOrionExplicitPresentationRequestGate({ requireStateRevision })` (`runtime/orion-webui-explicit-presentation-request-gate.js`) to pair state with entrance requests: `request()` / `observeState()` start the entrance only when they return `start`, and when they return `ack` only resend the acknowledgement; call `complete()` or `cancel()` when the entrance ends, and `reset()` when parked.

## Lifecycle state machine and root node state

The host lifecycle is written to `<html data-orion-lifecycle-state>`: `Preparing` → `Visible` ⇄ `CoveredSuspended` → `Closing` → `Destroyed`; a failure at any stage enters `Failed`. The plugin styles enforce the following accordingly: under `Preparing` and `CoveredSuspended` the whole document has `animation: none` and `transition: none`; under `Preparing` the page root element stays layoutable but receives no pointer input; under `CoveredSuspended`, `Closing`, `Destroyed` and `Failed` the `body` receives no pointer input.

The page presentation phase is written to the root node's `data-orion-presentation`:

| Phase | Entry condition | What the page must guarantee |
| --- | --- | --- |
| `preparing` | After the template is constructed, while the host is `Preparing` | Not interactive; no CSS animation, no page-owned rAF, no timers; applying state, layout and decoding images are allowed |
| `entering` | An entrance or restore request is received | The root node already has its final static style (opaque, layout complete); still do not start rAF / WebGL |
| `active` | The entrance commit is complete and the host is `Visible` | Interactive; the finite entrance animation plays from frame 0; rAF / WebGL may be started only after the entrance ends |
| `covered` | Covered by an upper layer | Keep the DOM and business state; revoke pointer and focus; stop rAF, timers and WebGL |
| `suspended` | Parked, rebound to another instance, `dispose()` | Same as `covered`, and clear the local presentation revision |
| `closing` / `failed` | Host `Closing` / `Failed` | Not interactive; `closing` plays only the exit, and `failed` freezes and sends no more acknowledgements |

Except in `active`, the root node has `aria-hidden="true"`. The template also cancels pointer sessions created through `createOrionPointerSession` (`input/orion-pointer-session.ts`); drag state that the page attaches itself must be cleared in `onPresentationSuspended`. Minimal root node CSS: base style `opacity: 0; pointer-events: none`, `opacity: 1` under `[data-orion-presentation="entering"]` and `[data-orion-presentation="active"]`, and `pointer-events: auto` only under `active`. Do not hide the root node or content waiting to be displayed with `display: none`: the preparation phase decides by logical layout which images take part in the resource gate, so hidden content is not waited for.

Presentation readiness consists of seven independent gates, and the page is revealed only when all of them belong to the current instance, the current document and the current revision: Bridge (`ready()`), Input (`inputReady()`), Resources (`localResourcesReady()`), State DOM Commit (`stateCommitted(rev)`), Controller Visual (`controllerVisualReady(rev)`), Presentation Commit (the entrance / restore acknowledgement with the exact `presentationRevision`), and Paint / Reveal (a new frame that Native obtains after the acknowledgement; the page cannot report it on Native's behalf). When one is missing, check that one; no gate can substitute for another.

## Revision semantics and the authoritative state channel

| revision | Assigned by | What it governs | Where the page uses it |
| --- | --- | --- | --- |
| `stateRevision` | C++, independent and monotonically increasing for each business state stream | The version of one full business snapshot | State channel deduplication, `stateCommitted`, business state acknowledgements, `controllerVisualReady` |
| `presentationRevision` | C++, reassigned for each formal appearance | One entrance / restore / exit presentation transaction | Presentation acknowledgements only |
| Stream revision (the `revision` of a high-frequency stream, or a host-defined one such as `interactionRevision`) | C++, independent per stream | One continuous interaction or high-frequency data stream | Acknowledgements and anti-rollback of that stream only |

- The three kinds of revision are independent namespaces: do not compare them with each other and do not fill in one for another. When a snapshot carries both `stateRevision` and `presentationRevision`, read them separately; being covered and then restored advances only `presentationRevision`, and if the business content has not changed there is no new `stateRevision`.
- The state path does only three things: write to the Store, commit the exact `stateRevision`, and report static visual readiness. Even if the snapshot carries a `presentationRevision`, the state path must not implicitly create an entrance, play an animation or send a presentation acknowledgement.
- A presentation acknowledgement is valid only after an explicit entrance request (`*.enterRequested`, `ue:webUI.presentationRequested`) or `ue:webUI.presentationRestored` has been observed, and only when the revision equals the request exactly; early, stale and future values are rejected at the InstantScreen Runtime boundary and never reach C++.

`installAuthoritativeStateChannel(api, options)` (`runtime/orion-webui-lifecycle.ts`) is the only state receiving entry point and returns a cancel function:

- Fixed order: `apply(state)` → `commitDom(state)` → in parallel send `stateCommitted(rev)`, the business acknowledgement `emit(acknowledgementEventName, { ...acknowledgementMetadata, [revisionFieldName]: rev })`, and, when `isControllerVisualReady(state)` is true, `controllerVisualReady(rev)`. If any step throws, nothing is reported.
- `revisionFieldName` defaults to `stateRevision`. An old revision is discarded; a replay of an already applied revision only resends the acknowledgement and does not run `apply` again; the same revision that is being applied is ignored.
- `apply` keeps the state writes in its synchronous part. After an instance is rebound, the channel abandons old asynchronous continuations, but it cannot undo writes that the callback has already made.
- `stateEventName`, `acknowledgementEventName` and the revision field name must match the Presenter exactly. For the Presenter of an InstantScreen, snapshots pushed with `PushState` arrive as `ue:instantScreen.stateChanged`, and the real gate is `stateCommitted(rev)`.
- A newly created Controller document does not receive a `ue:instantScreen.stateChanged` that carries the first snapshot; the initial snapshot is read with `getInitialState?.()` at mount. The channel does not report on your behalf in two cases: the initial snapshot, and localization arriving later than the snapshot. After the Bridge is ready, report once for the current revision as shown at the end of the skeleton.

## Animation contract

- During `Preparing` and while covered, the plugin forbids creating animations. At each appearance the host first resolves the static style once, then switches to `Visible` once, and CSS animations therefore play once from frame 0; neither the page nor C++ sends a second "start animation" command.
- Declare entrance animations on a selector that matches both the `entering` and `active` phases, or on the page's own stable state class, with `backwards` / `both` fill. An animation attached only to `entering` is cancelled when the phase switches to `active`.
- Do not call `Element.animate()`; do not iterate animation instances to `pause` / `play` / restart them; do not use rAF or timers to replay; do not read the system's reduced-motion preference.
- Entrance-related DOM must not change when an animation ends: class name switches, `v-if` unmounts and attribute changes triggered by `animationend`, `transitionend` or `getAnimations().finished` make the first-frame capture result nondeterministic. Class names change only with state; transition elements stay resident and return to their own style when done.
- Start live WebGL / rAF layers and heavy module resolution only after the page is really visible and the entrance has ended: `await waitForOrionWebUIPresentationSettled(root)` (`runtime/orion-webui-presentation-commit.ts`), and after it returns, check that `lifecycle.getPresentationPhase() === "active"` and that it is still the same appearance. When covered, parked or unmounted, stop the loops and release resources.
- The exit is the only transaction that uses the end of the animation as its signal. Hand it to `createOrionWebUIExitTransaction(api, { root, requestEventName, acknowledgementEventName, animationName, getExitRevision, beginExit, settleExit })`: after a request whose revision equals `getExitRevision()` is received, it calls `beginExit`; after an `animationend` whose name is exactly `animationName` arrives on the root node, it calls `settleExit` to commit the transparent final state, yields one browser task, and then acknowledges `{ presentationRevision }`. The root animation must end last, and the content and all full-screen overlays must reach transparency together. Call `reset()` in `onPresentationSuspended` and `dispose()` on unmount.

## Typed Intent

Business actions of an InstantScreen page go only through `requestIntent(name, payload, { controlId })` and do not fall back to `emit()`: an ordinary event is silently dropped when the page's state version is behind Native, and `call()` rejects business names. A plain `UOrionWebUIWidget` document has no `requestIntent`; business requests use `call()` (when a result is needed) or `emit()` (notification only), and are likewise validated by C++ and settled by the snapshot.

| `status` | Meaning | What the page does next |
| --- | --- | --- |
| `completed` | The synchronous business action is complete | End the wait, consume the authoritative snapshot |
| `accepted` | Handed to the business owner; always carries `authority`, may carry `operationId` | Busy and the final result are determined by that owner's snapshot |
| `rejected` | The business rejected it | End the wait, show `message` / `code` |
| `unknown` | The acknowledgement cannot be confirmed | Prompt the user to check the current state; automatic replay of write operations is forbidden |

- Result shape: `{ requestId, status, code, message?, authority?, operationId?, data? }`. A rejection at the business layer is a resolve; a deterministic failure at the bridge layer is a reject, and `error.code` looks like `E_INSTANT_INTENT_AUTHORITY` (not the current input owner, the presentation transaction has changed, or the state version is ahead), `E_INSTANT_INTENT_SCOPE` (old instance or old document), `E_INSTANT_INTENT_RESULT_MISSING` (the Presenter gave no result). Handle both paths.
- `payload` must be a plain object. Write the event name as a string literal at the call site; the contract check classifies by literal, and for how to register them see [Build and validation](build-validation.en.md).
- Deduplication: the control key defaults to the event name, and the same key reuses the same Promise until confirmed; the payload of a later call is ignored. When several independent controls share an event name, pass a stable `controlId`; for edits that happen one after another, such as search and drafts, give each edit its own key.
- Timeout: the bridge timeout is determined by `BridgeCallTimeoutSeconds` of the AppDefinition. A timeout, disconnect or abnormal acknowledgement triggers only one read-only state query; if it still cannot be confirmed, the request ends as `unknown`, with no loop and no resending of write operations.
- Lifecycle: being covered and a same-instance restore keep the wait; a new Screen instance, a new Controller document or document retirement clears the wait, and the old Promise rejects with `E_INSTANT_INTENT_INVALIDATED`. Clearing does not cancel business that was already accepted; the new page consumes the snapshot again.
- Wait and notice: `getIntentRequests()` returns `{ pending: [{ requestId, name, controlId, phase }], notice? }`, dispatches `ue:instantScreen.intentRequestsChanged` when it changes, and `dismissIntentNotice()` closes the notice. The component that projects this into a button wait state and a rejected / unknown notice is supplied by the host project; business Busy still comes from the snapshot and is not put here.
- Build strongly typed payloads with a named interface; when the host wrapper requires `Record<string, unknown>`, spread the object at the call site (`{ ...buildIntent() }`) and do not bypass the check with `as unknown as`.

When a Vue child component declares `defineEmits` with an event-signature map, mutually exclusive events must keep literal event names through explicit branches: write `if (cancelled) { emit("holdCancelled"); } else { emit("holdFinished"); }`, not `emit(cancelled ? "holdCancelled" : "holdFinished")`. vue-tsc cannot pick an overload from a union of event names, and a passing Vite build does not mean the type check passes.

When a finite enumeration crosses FName, JSON and Web, use a canonical wire token: the C++ serialization boundary outputs a token with a fixed spelling, and the Web side parses it at the consumption boundary with an explicit codec; do not depend on the display case of FName (FName comparison is case-insensitive, while JavaScript `Map` keys are case-sensitive). An unknown token takes an explicit unknown branch; it is not silently mapped to another business meaning, and no alias special cases are added in the page.

## High-frequency data

For streams where only the latest value matters, such as coordinates, poses and progress samples, use `installOrionFlowControlledLatestChannel<T>(api, { eventName, acknowledgementEventName, acknowledgementPhase?, revisionFieldName?, apply })` (`runtime/orion-webui-flow-controlled-latest.ts`), which returns a cancel function. Native keeps only one in-flight revision and one latest value; in one rAF the page applies only the largest revision. `revisionFieldName` defaults to `revision`.

- `committed` (default): acknowledges after `apply` (including `await nextTick()`) completes and one browser task boundary has passed. When you need "the page really finished something" as readiness evidence, use only this, or use the state channel or the presentation transaction; if `apply` throws, no acknowledgement is sent.
- `received`: acknowledges as soon as a valid revision is received, and only latches the latest value to wait for the next rAF. Use it only for replaceable coordinate-type presentation streams; it does not mean the DOM is committed, painted or revealed, and it must not take part in any readiness gate.
- One acknowledgement event name belongs to exactly one stream. Both kinds of acknowledgement are only transport facts and do not mean business success. The page adds no fixed delay, history frame queue, debounce or retry, and creates no resident sampler.

## Document reuse and instance isolation

A Controller document whose cache policy is keep-document is rebound to several Screen instances in turn, and the revision of each instance counts from the beginning on its own. The identity is published with `ue:webUI.lifecycleChanged`: `screenInstanceId`, `transactionId`, `surfaceGeneration`, `controllerDocumentGeneration`; on rebinding, the identity is sent first and then the state of that instance is handed over.

- The lifecycle template, the state channel and the high-frequency channel already use `createOrionWebUIInstanceScope` (`runtime/orion-webui-instance-scope.ts`) to reset deduplication and cancel pending frames when the identity changes. The identity consists of `screenInstanceId`, `surfaceGeneration` and `controllerDocumentGeneration`; a change of `transactionId` alone does not count as switching instances. A standalone page without identity fields keeps using the document-level lifecycle.
- An anti-rollback baseline that the page keeps itself must be reset in the same way, and the identity listener must be registered before the state channel:

```ts
const hintScope = createOrionWebUIInstanceScope(() => {
	lastHintRevision = 0;
});
releaseListeners.push(api.on<OrionWebUIInstanceIdentity>("ue:webUI.lifecycleChanged", (payload) => {
	hintScope.observe(payload);
}));
```

- Before an asynchronous continuation goes on to commit the DOM, send acknowledgements or clear markers, it must check the generation: record `scope.generation` before the `await`, and return directly if it is not equal afterwards.

## Resource preparation and cancellation

- Page resource preparation runs in parallel with the Bridge and Input and is the template's responsibility: it first runs the optional custom preparation callback, then waits for the mounted, currently displayable `<img>` elements inside the root node to load and decode, and finally calls `localResourcesReady()`. Images in hidden routes, without layout, or without `src` do not enter the gate.
- Establish readiness only for elements that really exist; do not pre-build hidden DOM or hidden iframes to "fix the first frame". Custom preparation must be bounded and cancellable, and must not wait for events that happen only after the reveal (rAF in a hidden document, `animationend`, visibility observation).
- Custom preparation that fails or times out reports `webUI.resourcePreparationFailed`, and `localResourcesReady()` is not called this time; a failed load of a content image only degrades. A failed required font is terminated by the host, and the page adds no rebuild, looping retry or fixed delay.
- For dynamic images whose identity or content changes within the first-frame transaction, do not bind the candidate address directly to the `src` of a visible `<img>`. The host project must supply a last-good image component: the candidate address is loaded and decoded in a detached `Image`, and the node being displayed is replaced only after success; on failure the previous image is kept, and the current presentation is not cancelled in reverse.
- `dispose()`, `pagehide` and rebinding to another instance all abort old tasks, and an old task cannot report Ready. For the attribute requirements of `<img>` and Runtime Image see [Controls and resources](controls-resources.en.md).

## Callback style (static contract)

The lifecycle contract check matches the source with static patterns (see [Build and validation](build-validation.en.md)), so a compressed form that is equivalent at runtime may also fail. The handlers for `onPresentationSuspended`, `onPresentationRequested`, `*.enterRequested` and `*.exitRequested` use explicit code blocks and statement terminators; an asynchronous handler explicitly `return`s the original Promise: the template acknowledges only after it `await`s that Promise, and dropping the Promise means acknowledging before the animation is committed. When the contract check fails, first confirm that the logic really exists; do not add dead code only to match the pattern.

## App.vue skeleton

Write import paths according to the basic plugin sample at `<OrionBrowser>/Content/UI/WebUI/Sample/src/App.vue`, with shared modules under `<OrionBrowser>/Content/UI/WebUI/Shared/src`; for how these modules resolve when the App is placed in `<WebUIRoot>/<AppId>` see [Web App scaffold](web-app-scaffold.en.md). The following is the content of `<script setup lang="ts">`, written for an InstantScreen page; in a plain Widget document, replace `requestIntent` with `call()` or `emit()`. Write the template root element as `<main ref="rootElement" class="sample-root">`, and for buttons use `:disabled="!state.canConfirm"` on top of the eligibility published by C++.

```ts
import { nextTick, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import { type OrionLocalizationTable, type OrionWebUIApi, installCommonActionRouter, waitForOrionWebUI } from "../../Shared/src/bridge/orion-webui";
import { type OrionWebUILifecycleController, createOrionWebUILifecycle, installAuthoritativeStateChannel } from "../../Shared/src/runtime/orion-webui-lifecycle";

interface SamplePanelState {
	stateRevision: number;
	title: string;
	canConfirm: boolean;
}

const props = defineProps<{ api?: OrionWebUIApi }>();
const rootElement = ref<HTMLElement | null>(null);
const bridge = ref<OrionWebUIApi | null>(null);
const localization = ref<OrionLocalizationTable>({ culture: "", texts: {} });
const state = reactive<SamplePanelState>({ stateRevision: 0, title: "", canConfirm: false });
const notice = ref("");
const releaseListeners: Array<() => void> = [];
let lifecycle: OrionWebUILifecycleController | null = null;
let localizationReady = false;
let disposed = false;

const isSamplePanelState = (value: unknown): value is SamplePanelState => !!value && typeof (value as SamplePanelState).stateRevision === "number";

function applyState(snapshot: SamplePanelState): void {
	// Write the full snapshot synchronously only: no await, no entrance trigger, no presentation acknowledgement.
	Object.assign(state, snapshot);
}

function suspendPresentation(): void {
	// Stop the page's own rAF, timer and WebGL loops, and clear local drag and presentation state.
}

async function confirm(): Promise<void> {
	const api = bridge.value;
	if (!api || !state.canConfirm) {
		return;
	}
	try {
		const result = await api.requestIntent("samplePanel.confirmRequested", { stateRevision: state.stateRevision }, { controlId: "sample-panel-confirm" });
		notice.value = result.status === "rejected" || result.status === "unknown" ? result.message ?? result.code : "";
	} catch (error) {
		// Bridge-layer failure: do not resend; the interface waits for the authoritative snapshot.
		notice.value = error instanceof Error ? error.message : String(error);
	}
}

onMounted(async () => {
	const root = rootElement.value;
	if (!root) {
		throw new Error("SamplePanel lifecycle root is unavailable.");
	}
	const api = props.api ?? await waitForOrionWebUI().catch(() => null);
	if (disposed) {
		return;
	}
	if (!api) {
		// Normal browser or design preview: show the sample state directly, without attaching the lifecycle.
		applyState({ stateRevision: 1, title: "Sample", canConfirm: false });
		root.dataset.orionPresentation = "active";
		return;
	}
	bridge.value = api;
	const initialState = api.getInitialState?.();
	if (isSamplePanelState(initialState)) {
		applyState(initialState);
	}
	releaseListeners.push(installAuthoritativeStateChannel<SamplePanelState>(api, {
		stateEventName: "ue:samplePanel.stateChanged",
		acknowledgementEventName: "samplePanel.stateApplied",
		apply: applyState,
		commitDom: () => nextTick(),
		isControllerVisualReady: () => localizationReady,
	}));
	releaseListeners.push(installCommonActionRouter(api, root));
	lifecycle = createOrionWebUILifecycle({
		api,
		root,
		onPresentationRequested: () => {
			return nextTick();
		},
		onPresentationRestored: () => {
			return nextTick();
		},
		onPresentationSuspended: () => {
			suspendPresentation();
		},
	});
	const bootstrap = await lifecycle.initialize().catch((error: unknown) => {
		if (error instanceof Error && error.name === "AbortError") {
			return null;
		}
		throw error;
	});
	if (!bootstrap || disposed) {
		return;
	}
	localization.value = bootstrap.localization;
	localizationReady = true;
	await nextTick();
	const committedRevision = state.stateRevision;
	if (disposed || committedRevision <= 0) {
		return;
	}
	// The state channel does not report the initial snapshot or late localization: report once for the current revision.
	await Promise.all([
		api.stateCommitted(committedRevision),
		api.emit("samplePanel.stateApplied", { stateRevision: committedRevision }),
	]);
	await api.controllerVisualReady(committedRevision);
});

onBeforeUnmount(() => {
	disposed = true;
	suspendPresentation();
	lifecycle?.dispose();
	lifecycle = null;
	for (const release of releaseListeners.splice(0)) {
		release();
	}
});
```

## Common failure signatures

| Symptom or log | Cause | Fix |
| --- | --- | --- |
| The page never shows; `Controller presentation barrier for <screen> timed out`, with `state-committed` or `controller-visual-ready` missing | The snapshot was not reported because it was not fully applied; `presentationRevision` was reported as `stateRevision`; the initial snapshot or late localization was not reported | Read the two revisions separately; after the Bridge is ready, report for the current revision |
| `presentation-commit-rejected`, with reason `request-not-observed`, `stale-revision` or `future-revision` | The first: a presentation acknowledgement was sent from the state path or the automatic entrance fallback while the host had not yet sent an explicit request; the latter two: the acknowledgement used a cached or self-made revision | Acknowledge only after an explicit request and with the exact value from the request; when the host uses a custom entrance event, set `presentationRequestedEventName` and turn off `autoPresentWithoutRequest` |
| `InstantScreen event ue:<x>.enterRequested at revision N was not acknowledged after K attempts` | The event is not listened to; the acknowledgement event name or revision field name does not match C++; the acknowledgement was rejected for the reasons in the previous row | Check event and field names character by character; make asynchronous handlers `return` the Promise |
| A button occasionally does nothing and there is no rejection log | In an InstantScreen a business action used `emit()`, and it was silently dropped when the state version was behind | Use `requestIntent` instead |
| `E_INSTANT_USE_INTENT`; or `requestIntent is not a function` | The former: `call()` was used for a business name in an InstantScreen; the latter: a plain Widget document has no `requestIntent` | Choose the right channel for the host form |
| `E_INSTANT_INTENT_AUTHORITY` | Submitted while the page was covered, input was not ready, or the presentation transaction had changed | Do not resend; do not submit outside the `active` phase |
| A page with a reused document stays on old state or does not update after being opened again | The revision baseline the page keeps itself is compared across instances | Reset it when the identity changes, and register the listener before the state channel |
| The entrance animation does not play, plays only the first time, or plays twice | The animation is attached only to `entering`; a script is used to replay it; the DOM is changed after `animationend` | Rewrite it according to "Animation contract"; do not add pauses, replays or delays |
| The resource gate does not pass; `webUI.resourcePreparationFailed` or `ORION_LOCAL_RESOURCE_ERROR:` | Custom preparation timed out, or waited for an event that happens only after the reveal; the `src` of a visible image was replaced directly within the first-frame transaction | Make the preparation logic bounded and cancellable; dynamic images use last-good replacement |
