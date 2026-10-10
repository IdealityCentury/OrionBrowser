# Orion Station — Blueprint sample

Open `OrionBrowserTemplate.uproject` with **Unreal Engine 5.8 / Win64** after installing the complete OrionBrowser 1.0.1 plugin in project `Plugins/OrionBrowser`.

The public example does not include the commercial plugin. Its own game content is `/Game/OrionStation/L_OrionStation`; reusable station Blueprints, widget examples and web production files belong to the installed plugin. This project has no C++ game module.

Wait for Helper preparation in the editor, then Play. The station UI offers English and Simplified Chinese. Blueprint owns mission progress, inventory, preferences and the `OrionStationProfile` save slot; the web app submits intents and displays state.

The interface is drawn entirely with HTML, CSS and JavaScript, as glass over the level: its surfaces are translucent and the scene shows through them. Four themes, with the dark **Obsidian** as the default, and three backdrops are chosen in Settings. One island at the top of the screen is the navigation, the mission readout, the message toast and the command search (**Ctrl+K**); it changes shape instead of being replaced. The **Showcase** page has ten rooms:

| Room | What it shows |
| --- | --- |
| Motion | A fourteen-second reel in which one element becomes eleven controls on a 120 BPM grid. Every style is computed from the clock, so the timeline can be dragged anywhere |
| Components | Buttons, toggles, an elastic slider, liquid tabs, a self-drawing chart and a morphing surface, all driven by closed-form springs |
| Effects | Holographic foil, a lens flare that follows the pointer, flowing borders, sheen, laser beams and neon, and glass from solid to clear |
| Type | Twelve font families as live specimens, bundled and system, with an editable line, gradient, outline and glow fills, and vertical setting |
| Pavilion | The Stargazer Pavilion: a Chinese pavilion built in code with three.js, with soft shadows, bloom, a reflecting pond and a time-of-day slider |
| Cosmos | A solar system, a spiral galaxy and a ray-marched black hole in three.js, on a transparent canvas with the level behind them |
| Benchmark | A field of up to 60,000 instanced asteroids. Change the count, the draw batches, the triangles, the lighting, the shadows and the resolution, and read what each does to the frame rate |
| Media | A local VP9 film with an Opus soundtrack and live audio levels |
| Input | Control sounds played by Unreal, the active input device, CommonUI integration, a key tester and IME text entry |
| Unreal | A live scene capture and an Unreal texture as native surfaces, a runtime image, bridge traffic and a round-trip timer |

The website opens in a separate browser panel.

After starting an expedition, use **WASD** to move, **E** to activate a visible world control, **I** for inventory and **P** for the menu/back action. Escape also returns when the host passes it to the game; P remains available in PIE. Switch language with the top-right button or the settings page.

[English manual](https://github.com/IdealityCentury/OrionBrowser/blob/main/Documentation/README.md) · [中文说明](README.zh-CN.md) · [Companion tools](https://github.com/IdealityCentury/OrionBrowser/releases)

To package, run `Scripts/Package-Development.ps1` or `Scripts/Package-Shipping.ps1` with the `-EngineRoot` parameter set to your engine root. The scripts use the plugin's fixed packaging entry and prepare Helper before Cook. Output is written under project `Builds/Development` or `Builds/Shipping`. Studio is not included in the game.

Packaging compiles and links the game executable even though this project has no C++ of its own, because it enables a code plugin. Install the Visual Studio C++ toolchain and Windows SDK that Unreal Engine 5.8 requires on the packaging machine. Opening the project, authoring and Play In Editor use the plugin's prebuilt editor binaries and need no compiler.

Keep the complete output directory when sharing or testing a packaged game. After preparation, local sample content is offline; only the external website needs a network connection. The game does not download or repair EXEs.

The corresponding release acceptance report identifies which environments and input devices were actually tested. Asset authoring, Studio previews and Blueprint compilation are distinct from an Unreal play session or a packaged game run.

The independent sample defaults to a 60 FPS game limit through `Config/DefaultGameUserSettings.ini`, leaving GPU time for the local browser and scene capture. Existing saved user settings override this initial preference. The plugin does not impose this limit on other projects. See the manual's sample rendering-budget guidance when adapting the scene or targeting other hardware.
