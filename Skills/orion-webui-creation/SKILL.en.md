# Create an OrionBrowser interface

Use OrionBrowser 1.0.0 with UE 5.8 / Win64 and the default `DefaultWebUIRenderMode=LegacyTexture`. Resolve the plugin from its descriptor and the project from its uproject. Respect the host project's commands and test authorization. [简体中文](SKILL.md).

Unreal Blueprint or C++ owns business state, inventory, settings, saves and authority. Web code renders snapshots and submits intents. A Blueprint-only project does not need a C++ presenter. Reuse OrionWebUIWidget, AppDefinition, the bridge and lifecycle/resource APIs.

1. Define the state owner, allowed actions, parameter validation and failure behavior. Use a normal WebUI widget for an embedded area; reuse an existing CommonUI stack for page input and covering/resuming.
2. Use the supplied Showcase Vue/TypeScript/Vite source as a reference. Give each app unique Ids, event prefixes and stable control Ids. Project production resources belong in `Content/UI/WebUI/AppId/dist`; plugin examples use `WebUIApps/AppId/dist`. Resolve imports for the plugin's actual installation location.
3. Subscribe before announcing ready. Blueprint On Web Event/Request handlers parse JSON with Valid checks, validate authority and current targets, then publish a full state with an increasing stateRevision using Post Retained Latest Event to Web. Complete a response handle once. A web receipt does not authorize a business change.
4. Preserve semantic buttons/inputs, focus, disabled states and composition input. Test actual gamepad/keyboard routing; a device label is not proof. Keep persistent state outside page instances.
5. Bundle static images and licensed fonts locally. Use UE control-sound policies, Native Surface for scene capture/continuous textures and the plugin's runtime-image resources. Suspend hidden loops and dispose subscriptions, observers and GPU resources on teardown.
6. WorldUI interaction is opt-in through Element Component/Definition. Resolve current visible targets, allowed actions and range; Unreal still approves gameplay. Unbind each local-player host when it leaves.
7. Declare all preview views in webui-preview.json. A simple app can expose a literal top-level App.vue state, allowing its first dist preview without source dependencies or seed cache. Complex preview factories require a matching source-preview cache for dist mode. Never fake readiness or disable the initial state commit gate to hide a missing snapshot.
8. Install locked dependencies, type-check and build dist. Compile affected native consumers using host instructions. Run only authorized tests and separate Studio/browser, Unreal, packaged-game and physical-device evidence.

Keep remote sites in a separate Orion Browser widget without the game bridge. Create and save Unreal assets through official Unreal APIs, never by editing uasset/umap bytes.

Read the [Blueprint tutorial](../../Documentation/blueprint-quick-start.md), [AI/Studio workflow](../../Documentation/ai-workflow.md), [interface reference](../../Documentation/interfaces.md) and [packaging guide](../../Documentation/packaging.md) when those details are needed. Report actual saved assets, event contracts, executed checks and outstanding validation.
