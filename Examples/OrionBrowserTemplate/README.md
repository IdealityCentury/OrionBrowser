# Orion Station — Blueprint sample

Open `OrionBrowserTemplate.uproject` with **Unreal Engine 5.8 / Win64** after installing the complete OrionBrowser 1.0.0 plugin in project `Plugins/OrionBrowser`.

The public example does not include the commercial plugin. Its own game content is `/Game/OrionStation/L_OrionStation`; reusable station Blueprints, widget examples and web production files belong to the installed plugin. This project has no C++ game module.

Wait for Helper preparation in the editor, then Play. The station UI offers English and Simplified Chinese. Blueprint owns mission progress, inventory, preferences and the `OrionStationProfile` save slot; the web app submits intents and displays state. Use the lab page to explore fonts, text input, animation, local three.js, Unreal textures and scene capture. The website opens in a separate browser panel.

After starting an expedition, use **WASD** to move, **E** to activate a visible world control, **I** for inventory and **P** for the menu/back action. Escape also returns when the host passes it to the game; P remains available in PIE. Switch language with the top-right button or the settings page.

[English manual](https://github.com/IdealityCentury/OrionBrowser/blob/main/Documentation/README.md) · [中文说明](README.zh-CN.md) · [Companion tools](https://github.com/IdealityCentury/OrionBrowser/releases/tag/1.0.0)

To package, run `Scripts/Package-Development.ps1` or `Scripts/Package-Shipping.ps1` with the `-EngineRoot` parameter set to your engine root. The scripts use the plugin's fixed packaging entry and prepare Helper before Cook. Output is written under project `Builds/Development` or `Builds/Shipping`. Studio is not included in the game.

Keep the complete output directory when sharing or testing a packaged game. After preparation, local sample content is offline; only the external website needs a network connection. The game does not download or repair EXEs.

The corresponding release acceptance report identifies which environments and input devices were actually tested. Asset authoring, Studio previews and Blueprint compilation are distinct from an Unreal play session or a packaged game run.