# First interface in a Blueprint project

Use a blank UE 5.8 Blueprint project with OrionBrowser enabled and Helper ready. Your project does not need a C++ module. The plugin itself contains native modules, as other Unreal code plugins do.

Complete the [CommonUI viewport setup](installation.md#commonui-viewport) before testing input in a blank project. The supplied Orion Station project already sets CommonGameViewportClient; preserve a compatible custom viewport in an existing game.

## Display the supplied page

1. Enable **Show Plugin Content** in the Content Browser.
2. Open `OrionBrowser/Showcase/WBP_OrionBrowserShowcase`. Its WebUI component is a normal UMG **Orion WebUI** widget.
3. The component's App Definition refers to `DA_OrionBrowserShowcase`, with App Id `Showcase` and **Use Dev Server in Editor** disabled. The supplied production files are in plugin `WebUIApps/Showcase/dist`.
4. Open the supplied overview level and Play. Inspect the Blueprint events to see how web intents become Unreal state and return to the page.

The supplied Showcase widget forwards events to `BP_OrionStationController`. To run this unchanged sample in another level, assign `BP_OrionStationGameMode` in World Settings so the sample controller creates its UI and owns its state. For your own game, use the new-host steps below and wire events to your own controller; simply adding the unchanged Showcase widget to an unrelated controller does not initialize station state.

Create your own host on BeginPlay with the owning Player Controller and add it to the viewport. Show the mouse cursor and use **Set Input Mode Game and UI** while the menu is open. Restore your game's input mode when the menu closes. Do not recreate the widget every frame.

## Host a new local app

1. Create a Blueprint **User Widget** in your project. In Designer, add an **Orion WebUI** child named `WebUI`, enable **Is Variable**, and fill its parent slot.
2. Create a Data Asset of class **OrionWebUIAppDefinition**. Set `AppId` to a unique name such as `MyPanel`, `EntryHtml` to `index.html`, and disable **Use Dev Server in Editor** for an offline production page.
3. Place your built web files in project `Content/UI/WebUI/MyPanel/dist`. Keep all assets under this directory and use relative URLs. Project apps take precedence over a plugin app with the same Id.
4. Assign the asset to the WebUI child, or call `Load App` once with that asset.
5. Add the host Widget to the viewport. Bind **On Web Ready**, **On Web Event**, **On Web Request** and **On Web Error** as needed using Designer events or Blueprint delegates.

## Send an intent to Blueprint

Use the plugin bridge in your TypeScript app:

```ts
const api = await resolveOrionWebUIForMount();
if (api) {
    const removeState = api.on("ue:myPanel.state", applyState);
    await api.emit("myPanel.ready", {});
    // Called by the user's control, after registration and readiness:
    await api.emit("myPanel.select", { itemId: "energy" });
    // Call removeState() when the page is disposed.
}
```

In the WebUI child's **On Web Event**:

1. Switch on `Event Name`; only handle the events your app owns.
2. Call **Get Json String** with `Payload Json` and field `itemId`. Check `Valid` before using its output.
3. Check that the item exists, the user may select it, and the target is still valid. Update Blueprint state only after those checks.
4. Build the complete response using **Set Json String**, **Set Json Number** and **Set Json Boolean**, starting with `{}`. Check `Valid` if source data can be invalid. These nodes escape JSON text correctly; avoid concatenating user text into JSON.
5. Call **Post Retained Latest Event to Web** on the same child, using event `ue:myPanel.state` and the new JSON. Include an increasing `stateRevision`. Retained events replay when the page listener registers.

For an operation that needs a result or an error, use `api.call` and handle **On Web Request**. Use the provided Response Handle to **Resolve** a JSON result or **Reject** with a code and message. Resolve exactly once. Do not report success before Unreal has accepted the action.

The generic JSON nodes accept object input up to 1,048,576 UTF-16 code units (Unreal string length). Missing or wrongly typed fields return `Valid=false`. An empty source passed to a setter creates an object; malformed source is preserved with `Valid=false`.

## Lifecycle and cleanup

Register web event listeners before sending the initial ready intent. Publish the initial complete state from Unreal when ready. For common lifecycle support, use the supplied lifecycle controller and Blueprint **Set Presentation Lifecycle State**; the sample provides the reference wiring. Keep state revisions separate from presentation revisions.

When a screen is covered, suspend its work and input; resume with current state when uncovered. On destruction, release subscriptions, observers, Three.js resources and any WorldUI host binding. Unreal UObject-bound delegates are scoped to their owning object, but your own timers and external subscriptions still require explicit cleanup.

See [the interface reference](interfaces.md) for input, control sounds, textures and world-space interaction.
