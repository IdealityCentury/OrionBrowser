---
name: orion-webui-creation
description: "Create or change an Unreal WebUI with OrionBrowser 1.0.0: connect Blueprint or C++ state, web intents, preview, input, resources and WorldUI. The Simplified Chinese edition is SKILL.md."
---

# Create an OrionBrowser interface

For UE 5.8 / Win64, with the default `DefaultWebUIRenderMode=LegacyTexture`. Locate the plugin root by `OrionBrowser.uplugin` and the project root by its `.uproject`. The plugin may be installed outside the project; do not write machine-local directories into what you produce. The host project's current instructions, test authorization and build entry points take precedence.

## State and boundaries

- Blueprint or C++ on the Unreal side owns game state, inventory, settings, saves and business authority; web code renders snapshots and submits intents. A Blueprint-only project does not need an extra game C++ presenter.
- Reuse OrionWebUIWidget, AppDefinition, the bridge and the existing lifecycle and resource APIs. Each local player owns its own host; local players do not share mutable game state or WorldUI target identities.
- The web page registers its state listener before it sends ready. Unreal publishes the full state with an increasing stateRevision; the page acknowledges it after consuming it. The business revision and the presentation revision are independent, and a web acknowledgement does not advance business success.
- A local app uses a stable Id. Project production resources are in `<ProjectRoot>/Content/UI/WebUI/AppId/dist` and plugin examples are in `<OrionBrowser>/Content/UI/WebUI/AppId/dist`; the Id in the AppDefinition must match.
- Remote web pages use a separate Orion Browser and do not connect to the game's business bridge.

## Implement what is required

1. Settle the state authority, the allowed actions, the parameters and the error handling before writing controls. Use Orion WebUI for an ordinary UMG area; where a CommonUI page stack already exists, reuse its input handling and its cover-and-resume flow.
2. Use the Showcase Vue/TypeScript/Vite project supplied with the plugin as a readable reference. After copying it into your own app, update the Id, the event prefix, the stable control Ids and the import paths. When creating or copying a WebUI/App directory, create or complete a `.gitignore` in the directory root before installing dependencies, excluding `node_modules`, Node/Vite caches, logs and TypeScript incremental files; leave these local artifacts out when copying. Keep the source, `package.json`, `package-lock.json` and the `dist` needed for runtime/packaging; the rule template is in [Web App scaffold](references/web-app-scaffold.en.md).
3. A Blueprint-only project receives operations through On Web Event/Request, checks Valid on the JSON getters/setters, and then validates the business rules; it publishes state with Post Retained Latest Event to Web. A request that needs a result is completed or rejected once through its Response Handle.
4. Keep standard button, input field and label semantics in the page; validate a disabled action again in Unreal. Verify keyboard and mouse, gamepad and IME input separately; showing a device label does not replace wiring up the input.
5. Bundle static resources locally and keep the licenses of fonts. Control sounds go through the UE policy; continuously changing textures and scene captures go through Native Surface; other runtime images use the plugin's resource APIs. Pause loops while hidden; on teardown, remove subscriptions and release GPU resources.
6. WorldUI uses the optional interaction of the Element Component and the Definition. Handle only targets that are currently valid, visible, allowed to act and within range; business authority is still validated by Unreal. Unbind the local player's host on exit.
7. Keep webui-preview.json in step with every page, language and key state view. A simple example can let Studio read a plain-literal top-level state in App.vue statically, so the first dist preview needs neither source execution nor a cache. For a complex app that uses a preview factory, complete a source preview first to produce the matching cache, then preview dist; do not fake ready or turn off the initial state commit requirement.
8. Install the locked dependencies, type-check and build dist, and compile the affected consumers as the host project prescribes. Run tests within the current authorization, and tell browser/Studio, Unreal, packaged-build and physical-device evidence apart.

## Read when you need the details

- [Blueprint and C++ integration tutorial](../../Documentation/tutorial-3-blueprint-and-cpp.md)
- [AI workflow and prompts](../../Documentation/tutorial-1-ai.md), [WebUIStudio tutorial](../../Documentation/tutorial-4-webui-studio.md)
- [Building an app from scratch, and messaging, input, sound, fonts, images and WorldUI](../../Documentation/tutorial-2-build-it-yourself.md)
- [Packaging and troubleshooting](../../Documentation/packaging.md)

Create, compile and precisely save assets only through Unreal's official APIs; do not modify uasset/umap files with a text or binary editor. In the handoff, state the assets actually saved, the event contracts, the checks run and what was not verified; do not treat a design draft or a static check as a successful run.
