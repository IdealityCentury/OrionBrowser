# Blueprint and web interface reference

All UObject-facing calls and Blueprint callbacks run on the game thread. The browser runs in its own subprocess; do not assume a JavaScript callback synchronously changes game state. `OrionWebUIWidget` owns a local app document. `OrionBrowserWidget` is a general browser without the app business bridge.

## Messaging

| Web operation | Blueprint entry | Purpose |
| --- | --- | --- |
| `api.emit(name, payload)` | WebUI **On Web Event** (`EventName`, `PayloadJson`) | Submit an asynchronous intent |
| `api.call(name, payload)` | **On Web Request** (`Request`, `Response`) | Request a result; Blueprint resolves/rejects the response |
| `api.on(name, listener)` | **Post Event to Web** or **Post Retained Latest Event to Web** | Receive Unreal-owned state |
| `api.stateCommitted(revision)` | Built-in state receipt | Acknowledge a consumed state version; never authorizes gameplay |

Use **Get Json String/Number/Boolean** to parse scalar fields and **Set Json String/Number/Boolean** to build an object. Check `Valid`. Validate field ranges, known Ids, authority and target lifetime in Unreal. Reject duplicate or stale business requests using your own request/state identity when required. A page must not persist authoritative inventory in `localStorage`.

The bridge automatically handles its built-in resource and lifecycle operations. Do not replace its transport or poll for readiness with a timer. Subscribe before sending initial intents and dispose web subscriptions when unmounting.

## Input and page lifetime

Use UMG focus and an appropriate Player Controller input mode. CommonUI integration is available for projects with CommonUI page stacks. Web controls should remain semantic buttons, inputs, selects and labels; disabled controls must also be disabled in Unreal's action handler. Stable control Ids allow focus, sounds and automation to refer to the same control across translations.

The shared `installCommonActionRouter` processes common-action events sent from Unreal. Ensure your input mapping actually sends those actions; a JavaScript gamepad label alone does not prove controller input is connected. Text fields preserve normal selection and IME behavior. Do not intercept composition events as gameplay input; avoid taking focus away while composition is active.

Use `Set Presentation Lifecycle State` to describe preparing, visible, covered/suspended, closing, destroyed or failed presentation. Keep persistent gameplay state outside the page instance. Stop requestAnimationFrame loops while hidden and release Three.js geometries, materials, controls, observers and renderer on destruction.

## Sound and resources

- **Control sounds:** Activate a Control Sound Policy on the WebUI host with an owning UObject and context Id. Configure the default hover/click sounds and per-control overrides. The web side uses `playControlSound(controlId, interaction)`. Deactivate the policy when its owner leaves. The policy's UE sound references keep the assets available for cooking.
- **Text and fonts:** Use local font files in your app's production output or a UE Font Manifest. Font Manifest entries reference UE Font Face assets and stable CSS family names. Include the font license. A Text Catalog maps stable keys to Unreal FText; an application may also project a Blueprint-owned culture and local bilingual dictionary, as the sample does.
- **Static images:** Use relative app URLs. An Asset Manifest maps stable resource Ids to UE textures/material previews and keeps the Unreal references discoverable by Cook.
- **Runtime images:** Use the plugin's runtime-image resources and release their ownership with the page. Do not encode a new full image in JSON every frame.
- **Scene capture and continuously changing textures:** Bind a UE texture/render target using **Set Native Surface Texture** and the same Surface Id passed to `api.bindNativeSurface(id, element)`. The DOM element determines placement. Clear the binding when no longer needed.
- **Three.js:** Bundle the dependency and assets locally. Respect visibility, resize and disposal. GPU/browser support must be tested on the target machine.

The control sound Definition, Style, Override and Policy structs support Blueprint Make/Set Members nodes. For a volume setting, construct the hover and click definitions with the validated volume, place them in a style and policy, then activate that policy again for the same owner. If you register a named context such as `Station`, use `playControlSound(controlId, interaction, "Station")`; an omitted context selects only the unnamed default policy.

## Interactive WorldUI

1. Add **Orion Web UI World Element Component** to an Actor. Assign a **World Element Definition**, a semantic Element Key and an anchor/offset.
2. Enable `Interactive` in the definition, enumerate `AllowedActions`, and set `MaxInteractionDistance` (`0` permits any visible distance). Interaction is disabled by default.
3. Set the component's JSON payload for its text and visual state. `Set Element Visible(false)` removes an unavailable target from the presentation.
4. On the owning local player's **OrionWebUIWorldSubsystem**, call **Bind Overlay Widget** with the actual WebUI child, or bind an existing InstantScreen endpoint. There is one host per local player.
5. Mount the supplied `OrionWorldOverlayDOM` in the page. The default interactive renderer uses payload `label` and `actionLabel` and the allowed actions to build buttons.
6. Handle the component's **On Interaction** in Blueprint. The callback includes the local Player Controller, action Id and payload JSON. Approve inventory/mission changes on the game authority before publishing new state.
7. Unbind the host on teardown. Hidden elements, destroyed components, old worlds and stale document generations cannot resolve to a current allowed target.

The subsystem checks current registration, world, player visibility, projected visibility, allowed action and configured distance before dispatch. This is local presentation validation, not multiplayer server authorization. Networked games must send an appropriate validated server request.

## Remote browsing

Use a separate **Orion Browser** control to open `https://orionue.com`. Its `On Load Started`, `On Load Completed` and `On Load Error` delegates support loading/error views. `Go Back`, `Go Forward`, `Reload` and `Stop Load` are available. Do not expose gameplay objects or native request handlers to a remote page. Internet failure must not prevent local menus from running.
