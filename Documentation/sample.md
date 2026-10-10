# Orion Station sample

The sample is a small offline station with three collectible energy cells and a world-space terminal. Its inventory, mission progress and saved preferences belong to Unreal Blueprint. The web app displays that state and submits action requests.

## Basic Sample

`Content/UI/WebUI/Sample` is an independent Vue/TypeScript/Vite basic sample, with source under `src`, its entry and npm configuration in the App root, and production files under `dist`. It demonstrates UE events, request responses, input prompts, localization and control sounds; its AppId remains `Sample`. It imports Bridge, lifecycle and WorldUI components from the plugin's shared `Content/UI/WebUI/Shared` runtime.

Run `Scripts/Build-OrionWebUI.ps1` from the plugin directory to build the sample; dependency installation uses the existing lock file. Alternatively, run `npm ci`, `npm run typecheck` and `npm run build` in `Content/UI/WebUI/Sample`. Each App's `.gitignore` excludes local dependencies and caches.

## Open the sample

Enable **Show Plugin Content** in the Content Browser, open `/OrionBrowser/Showcase/L_OrionBrowserOverview`, and run Play after companion-tool preparation completes. The independent `OrionBrowserTemplate` project starts in its own `/Game/OrionStation/L_OrionStation` map, which reuses the plugin sample assets. It has no project C++ module.

The sample uses the plugin's `LegacyTexture` default. The website needs an internet connection; the station UI, bundled fonts, three.js scenes, film and soundtrack use local production files.

The supplied Showcase widget forwards its events to `BP_OrionStationController`. To run the unchanged sample in another level, assign `BP_OrionStationGameMode` in World Settings so that the sample controller creates the UI and owns its state. Adding the unchanged Showcase widget to an unrelated controller does not initialize station state; for your own game, create your own host and wire its events to your own controller as [Tutorial 3](tutorial-3-blueprint-and-cpp.md) describes.

## What the interface shows

The web app is one page with five destinations and a mission HUD. A single surface at the top of the screen carries navigation, mission progress, messages and command search: it changes shape instead of being replaced.

The page is glass over the game. It has no background of its own: surfaces are translucent, the three.js rooms clear their canvas to transparent, and the level shows wherever nothing is drawn. Four themes share one set of design tokens: **Obsidian** (the dark default), **Nebula**, **Aurora** and the light **Paper**. Three backdrops choose what stands between the level and the interface: a translucent scrim, a solid page, or nothing. Both are changed in Settings or in command search, and the button beside the search field steps through the themes. They are the page's own business: it keeps them in the browser's local storage, not in the Blueprint save. A host that wants to own the choice can publish `theme` and `backdrop` in the state instead.

| Page | Content |
| --- | --- |
| Overview | What the sample is, the mission state published by Blueprint, and entry points to every other page |
| Showcase | Ten rooms, each built around one group of plugin features or one web technique |
| Inventory | Items owned by Blueprint. Selecting one sends an action; the detail view follows the state that comes back |
| Settings | A draft form beside the values Unreal last published. Nothing changes until Blueprint accepts **Apply**. Theme and backdrop are the exception: they belong to the page and apply at once |
| Guide | The mission in four steps, the controls for the active device, and how the sample is rebuilt |

| Showcase room | Demonstrates |
| --- | --- |
| Motion | "One shape": a 14-second, 28-beat loop in which one surface becomes a button, a loader, a music player, a slider, a chart and a command palette. Every frame is a pure function of time, so the same code runs live in the page and renders the bundled film. It is drawn as ink on paper; a dark theme shows the same drawing as its negative, on glass |
| Components | The buttons, switches, sliders, segmented controls, morphing surface and chart the interface is built from, all moved by one closed-form spring |
| Effects | Light as a material: holographic foil that turns with the pointer, a lens flare that follows it, borders with a flowing conic gradient, sheen crossing text and metal, laser beams with a neon sign, and glass from solid to clear. All of it is gradients and masks, and none of it reads the scene behind the page |
| Type | Twelve families as live specimens: the three bundled fonts and nine fonts Windows usually has, each marked when it is not installed. One editable line with weight, size and tracking; gradient, outline and glow fills; vertical setting |
| Pavilion | A hexagonal double-eave pavilion built entirely in code with three.js: sun and moon over a full day, soft shadows, a reflecting pool, lanterns and bloom. Its detail follows the **Quality** preference saved by Blueprint |
| Cosmos | Three views of space on a transparent canvas, with the level behind them: a solar system of procedurally shaded planets that the camera can ride along with, a spiral galaxy of up to 340,000 stars moved on the GPU, and a ray-marched black hole whose disk is bent over its own shadow |
| Benchmark | An instanced asteroid field whose cost you set: up to 60,000 rocks, up to 4,000 draw batches, triangles per rock, lighting model, shadow-map size, render resolution, and a per-rock animation done in script. It reads out frames per second, frame interval, script time, draw calls and triangles, with a graph of the last 120 frames |
| Media | Local video with sound: the bundled film (VP9 and Opus in WebM) with its own transport controls and a live level meter. On a dark theme a CSS filter plays the same file as its negative |
| Input | Control sounds played by Unreal, prompts that follow the active device, a key tester, IME text entry, selectable text, and what a CommonUI host adds |
| Unreal | Native surfaces, a runtime image, the state revision and bridge traffic, a timed bridge round trip, a WorldUI label and the separate website browser |

How the page uses the plugin:

- **Control sounds.** The root element carries `data-orion-sound-context="Station"` and every control a literal `data-orion-control-id`. The plugin reports hover and click to Unreal by itself, so the page never calls a sound function. `data-orion-sound-policy="none"` silences a region, and a disabled control stays silent. The Input room shows the id that was reported.
- **Presentation lifecycle.** Animation loops, WebGL and video run only while the page is in the `active` presentation phase. They stop when the page is covered or closing, and resume when it returns.
- **Video and audio.** Local files are served without range requests, so the Media room reads the film into memory once and plays it from a Blob URL, which makes it seekable. Use WebM with VP9 and Opus, or another format the bundled Chromium decodes.
- **Transparency.** The page is blended over the game by its own alpha, so a translucent colour is all a surface needs to let the level through. Light that is added on top of nothing, such as a glow or a star, writes alpha along with its colour. What lies behind the page cannot be blurred or read, because the game is not inside the page, and the app contract (`npm test`) rejects `backdrop-filter` and `mix-blend-mode` in any case. Loose text therefore lies on a soft patch of the page colour, and with no scrim the shell's controls turn to darker glass, so both stay readable over a bright level.
- **Measuring.** The Benchmark room measures the page's own frames. To see what a setting costs the game, change it and read Unreal's `stat fps` or `stat unit` at the same time.
- **CommonUI.** The sample hosts the page in a plain UMG widget driven by a Blueprint controller. The page also installs the shared CommonUI action router and listens for input prompts, so the same page can sit in an **Orion WebUI Activatable Widget** on a CommonUI stack; the Input room describes what that host adds.

## Assets and ownership

| Asset in `/OrionBrowser/Showcase` | Responsibility |
| --- | --- |
| `L_OrionBrowserOverview` | Original station assembly, three cells, terminal, gate, player start and scene capture |
| `BP_OrionStationGameMode` | Chooses the sample PlayerController and engine SpectatorPawn |
| `BP_OrionStationController` | Owns `StateJson`, validates intents, publishes revisions, saves the profile and creates the UI |
| `BP_OrionStationSave` | Stores the Blueprint-owned profile in the `OrionStationProfile` save slot |
| `WBP_OrionBrowserShowcase` | Hosts one Orion WebUI widget and forwards its events to the owning controller |
| `DA_OrionBrowserShowcase` | Resolves the local `Showcase` app and disables the development server |
| `BP_OrionEnergyCell` | Receives a validated world action and asks the controller to collect its unique `CellId` |
| `BP_OrionTerminal` | Asks the controller to deposit three collected cells |
| `DA_StationCell`, `DA_StationTerminal` | Opt into world interaction and declare allowed actions |
| `WBP_OrionWebsite` | Separate Orion Browser widget with loading, error, retry, back and close controls |
| `T_StationEmblem` | Original texture shown as a native surface and as a requested runtime image |
| `RT_StationCapture` | Render target displayed through the `station.capture` native surface |
| `S_StationHover`, `S_StationClick` | Original synthesized UE sound resources used by the control sound policy |

The map references only the plugin's sample assets and engine assets. It does not require a private game framework or project-level C++ Presenter.

## Blueprint flow

`BeginPlay → InitializeProfile → SetupUI` creates the widget, binds WorldUI, adds the widget to the viewport and publishes the current profile. A saved profile restores its preferences and mission progress; the first profile chooses Simplified Chinese for a Chinese system language and English otherwise.

The page sends `station.ready` once its bridge and presentation lifecycle are ready. It sends `station.action` with a JSON `action` field for navigation, settings, language, inventory selection, starting, returning, resetting and opening the website. `HandleWebEvent` parses the event and `HandleAction` validates the accepted values. `PublishState` increments `stateRevision` and posts `ue:station.stateChanged` through a retained latest event. The page acknowledges the committed revision after Vue updates the DOM.

Cell identity is an instance-editable `CellId`: `cell1`, `cell2` or `cell3`. Collecting the same cell twice does not grant another item. `RefreshWorldLabels` updates language, hides collected actors and refreshes the terminal and gate. `Deposit` requires three cells and an active, incomplete expedition before marking the mission complete. Web controls cannot directly change this state.

World buttons submit `world.interact`; the plugin checks the current world, live component, allowed action, visibility, distance and interaction generation before it broadcasts `OnInteraction`. The cell and terminal Blueprints still decide whether the requested game action is valid.

Navigation is stored in the controller's bounded `PageStack` Blueprint array. Returning restores the previous page. Resetting the expedition clears mission progress while retaining language, audio and display preferences; it reloads the current map.

`PublishState` constructs the sample control-sound policy from UE sound assets and the saved volume. The web controls use its named `Station` context. The Unreal room of the Showcase page binds the emblem texture and scene capture as native surfaces and requests a runtime image through `RequestTextureResource`; the completion event publishes `ue:station.image`. Closing the host releases texture requests, native surfaces and its active sound policy. These are Blueprint wiring examples; inspect the corresponding event graphs to adapt their lifetime to your own page.

## Keyboard and world input

Use **WASD** to move while an expedition is active on the world page. **E** activates a focused visible WorldUI control, or the visible control nearest the screen center. The native WorldUI checks still enforce identity, visibility and interaction range. **I** opens or returns from the inventory. **P** opens the menu or returns to the preceding page; **Escape** is also available as an app Back key when the host delivers it to the game. Unreal Editor may reserve Escape for Stop Play, so use P during PIE and verify Escape in Standalone or the packaged game.

The sample PlayerController consumes its keyboard shortcuts before the engine SpectatorPawn bindings, preventing E from also moving the pawn vertically. Web keyboard handlers prevent duplicate default dispatch, ignore repeat/composition where appropriate, and leave text editing to the input field. Menu pages block pawn movement and look input while the web controls remain active.

On menu pages the arrow keys move focus to the nearest control in that direction. The focused control is offered the key first, so a slider changes its value and a row of tabs its selection before focus leaves them. **Ctrl+K** opens command search, which is also on the search button; it lists every page, every Showcase room, the themes, the backdrops and the common actions, in both languages. Controller commands owned by Blueprint reach the page as `ue:station.input`.

## Editing the UI

The source lives in plugin `Content/UI/WebUI/Showcase/src`; production files are in `Content/UI/WebUI/Showcase/dist`.

| Path under `src` | Content |
| --- | --- |
| `App.vue` | The shell: bridge listeners, lifecycle, the navigation surface, keyboard and controller input. Its literal `state` object is the preview seed |
| `state.ts`, `text.ts` | The state shape published by Blueprint; the English and Chinese dictionary |
| `appearance.ts` | Themes and backdrops: set on the root element, kept in local storage, or followed from the host's state |
| `pages/`, `rooms/` | The five pages and the ten Showcase rooms |
| `components/`, `motion/`, `styles/` | The controls, the spring engine and frame loop they share, and the design tokens of the four themes |
| `reel/` | The "One shape" loop: a timeline and a pure `seek(t)` renderer |
| `scene/` | The three.js pavilion and the inventory item view. `scene/space/` holds the transparent stage and what the Cosmos and Benchmark rooms draw on it: solar system, galaxy, black hole and asteroid field |
| `shell/` | Command search, the confirmation dialog, the mission HUD, focus navigation, WorldUI cards, and the stand-in scene a browser without a host shows behind the page |
| `preview.ts` | The sample state for a browser without a host |

`webui-preview.json` declares twenty-four design views: every page, every Showcase room, the mission HUD, mission complete, Chinese, controller prompts, reduced motion, three themes and two backdrops. The controller view sends the input device and its prompts as host events, the way Unreal does. WebUI Studio's stand-in host does not answer `station.action`, so inside Studio the page imitates navigation and preferences itself; in the game only Blueprint changes state. The preview does not replace a game test.

The film and soundtrack in `src/assets` are generated, not recorded. `tools/make_soundtrack.py` synthesizes the soundtrack with NumPy. Given `--song`, it uses a track of your own instead: it measures the tempo, beat grid and downbeat, cuts seven bars starting on a downbeat and brings them to 120 BPM. `tools/render_film.mjs` bundles the loop into one self-contained 1440 × 1440 HTML file and renders it with Playwright: one frame per beat first (`--beats`), then four sub-frames for every frame, which FFmpeg blends and encodes. Neither is part of the build, and Playwright is not a dependency of the app; run them only after changing the loop. Their requirements and commands are at the top of each file.

Use `WBP_OrionBrowserShowcase` as an editable wiring example, then create your own AppDefinition and widget. Rename the AppId and event names together, and give AI both the state shape and the Blueprint intent contract. See [Tutorial 1: Build an interface with AI](tutorial-1-ai.md); the wiring itself is described step by step in [Tutorial 3](tutorial-3-blueprint-and-cpp.md).

The website uses a separate general browser widget. It is not the local Showcase document and does not receive the station's business bridge or state events.

## Rendering budget

The independent sample starts with a 60 FPS game limit in project `Config/DefaultGameUserSettings.ini`. This leaves GPU time for browser rendering, scene capture and the game. It is a sample-project preference; installing the plugin does not change another project's frame limit. Existing saved user settings take precedence over this default.

In your own Blueprint game, use Unreal **Get Game User Settings → Set Frame Rate Limit → Apply Non-Resolution Settings** to choose an appropriate limit, and save it only when the player confirms the preference. Test on your supported hardware. If an uncapped game saturates the GPU, the browser's GPU readback can stall even while native game state continues to change. Lower game rendering load or choose a sustainable frame limit; reducing only the browser frame target may not resolve GPU contention.

The Benchmark room of the Showcase is a way to try this on your own hardware: it loads the page's GPU and script time on purpose, one setting at a time.

## Verification status

The release acceptance report distinguishes asset creation and Blueprint compilation from an actual Unreal session, packaged Development/Shipping execution, physical gamepad input and Chinese IME input. Consult that report for the tested build; do not interpret Studio preview screenshots as proof of those other environments.
