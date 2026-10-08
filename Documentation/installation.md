# Installation and automatic tool preparation

All plugin paths below are relative to the directory containing `OrionBrowser.uplugin`. Project paths are relative to your `.uproject` directory.

## Install

1. Use UE 5.8 on Win64. Close the project before replacing a plugin installation.
2. Install the plugin through Fab, or copy the complete supplied plugin directory to the project's `Plugins/OrionBrowser`. Do not install a second copy in the same engine/project combination.
3. Open the project, enable **OrionBrowser** in Plugins, and restart if Unreal requests it. The plugin uses engine-provided CommonUI and related engine modules; no private game framework is required.
4. After Editor initialization, OrionBrowser checks the two companion applications in the background. Wait for **Helper ready** before using a browser. WebUIStudio readiness is independent; downloading Studio does not stop a prepared browser.
5. In a blank project, configure the CommonUI viewport as described below. The supplied Orion Station project already includes this setting.
6. In the Content Browser, enable **Show Plugin Content**, open `OrionBrowser/Showcase/L_OrionBrowserOverview`, then Play.

Opening the project never launches WebUIStudio automatically. Use the Orion WebUIStudio toolbar action when you want to author or preview pages.

## CommonUI viewport

OrionBrowser enables the engine's CommonUI plugin. CommonUI input routing requires a game viewport derived from **CommonGameViewportClient**. In a blank Blueprint project, set **Game Viewport Client Class** in Project Settings to **CommonGameViewportClient**, then restart the editor. The corresponding project `Config/DefaultEngine.ini` setting is:

```ini
[/Script/Engine.Engine]
GameViewportClientClassName=/Script/CommonUI.CommonGameViewportClient
```

If your game already uses a custom viewport, retain that class and ensure it derives from CommonGameViewportClient; replacing it could remove your game's viewport behavior. The plugin does not overwrite a project's custom viewport. A page can display and receive a mouse click without this setup while CommonUI reports an input-router error, so first display alone is not proof that keyboard/controller routing is ready. Do not suppress the diagnostic to substitute for configuring the viewport.

## Exact versions and locations

| Component | Installed location | Purpose |
| --- | --- | --- |
| Helper | `Binaries/Win64/OrionBrowserHelper.exe` | Browser subprocess used by the editor and packaged game |
| WebUIStudio | `Binaries/Win64/WebUIStudio.exe` | Authoring and preview application; not shipped with the game |

`VersionName` in `OrionBrowser.uplugin` selects the GitHub Release tag exactly. For version `1.0.0`, the tag is `1.0.0`. Downloads never use `latest`. The size and SHA-256 of each executable are pinned in `Config/OrionBrowserDistribution.json` shipped with the plugin. CEF libraries and resources are supplied with the plugin and must stay paired with that release.

The first preparation needs HTTPS access to GitHub and its release-asset hosting endpoints. Public downloads require no GitHub account or access token. Already valid local files are reused without contacting GitHub. This is dependency preparation, not an automatic plugin updater: it does not install a newer plugin version.

## Progress, cancel and recovery

The native editor notification shows checking, downloading, verification, completion or failure, along with the component, transferred bytes and progress. You can cancel or retry. Cancelling leaves an `.exe.part` and `.exe.part.json` beside the final executable. The next preparation resumes when the server supports HTTP Range. If the server returns a full response, preparation safely restarts that file instead of appending it to the old bytes.

A final executable is installed only after its complete size and SHA-256 match the plugin manifest. A same-size corrupt file is invalid. A truncated existing executable may provide an initial resume candidate, but it is never trusted without complete verification. Preparation makes at most three automatic attempts per component per operation; failures remain visible and can be retried after fixing the cause.

Multiple editors and packaging processes coordinate through a named process lock. Allow a current preparation to finish. Do not manually launch or rename `.part` files.

## Offline import

On a connected machine, obtain the **same tag** from the [releases page](https://github.com/IdealityCentury/OrionBrowser/releases). Copy `OrionBrowserHelper.exe` and `WebUIStudio.exe` to the exact locations above. Preserve the manifest supplied with the plugin; do not generate a new checksum for an arbitrary executable. Restart the editor to validate the imported files. Alternatively, from the plugin root run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Scripts\Ensure-OrionBrowserTools.ps1 -Component All -CheckOnly
```

Exit `0` means both match. Exit `1` means invalid or unavailable; exit `2` is cancellation. Preparation scripts use Windows PowerShell and do not require Node or Python. Authoring a web application uses the tooling described in the AI workflow.

## Folder permissions

The plugin directory must be writable for automatic preparation. An engine installation under a protected directory may require the owner to grant appropriate write access or import the verified files offline. OrionBrowser does not elevate privileges, change directory permissions, kill a running executable or relocate the download. A locked EXE, full disk or unwritable directory produces a failure with a reason. Close the relevant application normally, free space or correct access, then retry.

For support, include the plugin version, engine version, preparation error and relevant log under project `Saved/OrionUE/OrionBrowser/Preparation`. Remove private paths and credentials before sharing logs.
