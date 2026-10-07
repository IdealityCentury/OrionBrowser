# Create interfaces with AI and WebUIStudio

Start from the supplied Showcase source in plugin `WebUIApps/Showcase`. It uses Vue, TypeScript and Vite. The production `dist` is already included; opening the supplied page in Unreal does not require a development server.

## Authoring loop

1. Launch WebUIStudio from the Unreal toolbar. Open your `.uproject` when prompted. The tool runs as your Windows user and stores its work under the project's `Saved` directory.
2. Select the sample app to inspect its pages and preview states. An app declares its Id in `package.json` under `orionWebUI`; `webui-preview.json` lists its views and state overrides.
3. For a project-specific app, copy the web source to project `Content/UI/WebUI/MyPanel`. Rename `name`, `orionWebUI.appId`, `interfaceName`, event prefixes and control Ids. Update relative imports to the actual plugin location. Do not copy `node_modules`, local caches or sample `dist` as a substitute for building your changed source.
4. Ask AI to change the layout, animation and controls while preserving the bridge/lifecycle contract. Give it [the distributed Skill](../Skills/orion-webui-creation/SKILL.en.md), the intended state shape, supported intents and the Blueprint handler names.
5. Install the app's locked dependencies, type-check, and build. In that app directory, the sample commands are `npm ci`, `npm run typecheck`, and `npm run build`. Use the bundled authoring runtime when launching through Studio; a standalone terminal can use a compatible Node/npm installation. Keep dependencies locked and do not add remote CDNs for offline content.
6. Use Studio preview to check layout variants and translations. Then run in Unreal to validate real input, Blueprint state, sounds, textures and WorldUI. Browser preview cannot prove native integration.
7. With **Use Dev Server in Editor** disabled, Unreal reads `dist`. The plugin can reload a stable changed local production entry in Editor. Rebuild the game when shipping changed web resources.

## Prompt example

> Create a bilingual English/Simplified Chinese inventory panel for OrionBrowser 1.0.0. Use Vue/TypeScript and the supplied bridge and lifecycle controller. Unreal Blueprint owns inventory and settings. Consume `ue:inventory.state` with `{stateRevision,culture,items,selectedItemId}` and emit `inventory.select` with `{itemId}`. Never grant items in JavaScript. Preserve stable control Ids, gamepad focus, keyboard activation, disabled states and cleanup. Bundle fonts/images/three.js locally. Register every page and modal preview in `webui-preview.json`. Produce the source, a matching Blueprint event-wiring list and production build.

Be explicit about the allowed actions and error behavior. AI-generated web code is application code: review it before allowing it to invoke native capabilities. Keep remote websites in a separate **Orion Browser** widget and do not attach your business bridge to them.

## Preview contract

The sample declares its initial state as a literal `reactive` object in `src/App.vue`, so Studio can discover its seed on the first production preview without a prior source-preview cache. The root `webui-preview.json` declares one entry per view and its state overrides. `src/preview.ts` supplies the standalone design fallback. Complex apps may instead declare a no-argument preview-state factory; run Source preview first to prepare its state for production preview. Preview state is a design fixture; it does not save inventory or call production services. When a page is added, update both the state type and preview catalog. Keep the preview and shipped app version aligned.

For plugins installed outside the project, resolve the real plugin directory before editing imports or invoking scripts. Runtime app discovery uses the enabled plugin's actual location; a hard-coded project `Plugins` path in your own build configuration does not automatically adapt.
