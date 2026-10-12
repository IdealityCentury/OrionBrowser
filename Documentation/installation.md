# Installation and downloading the dependencies

All plugin paths below are relative to the directory containing `OrionBrowser.uplugin`. Project paths are relative to your `.uproject` directory.

## Install

1. Use UE 5.8 on Win64. Close the project before replacing a plugin installation.
2. Install the plugin through Fab, or copy the complete supplied plugin directory to the project's `Plugins/OrionBrowser`. Do not install a second copy in the same engine/project combination.
3. Open the project, enable **OrionBrowser** in Plugins, and restart if Unreal requests it. The plugin uses engine-provided CommonUI and related engine modules; no private game framework is required.
4. **Download the dependencies.** Click the **WebUIStudio** button on the Level Editor toolbar, click **Download** in the **OrionBrowser Dependencies** window that opens, and wait for it to finish; see [Download the dependencies](#download-the-dependencies). The plugin never downloads them by itself; until this step is done, interfaces do not appear in the editor and the project cannot be packaged.
5. In a blank project, configure the CommonUI viewport as described below. The supplied Orion Station project already includes this setting.
6. In the Content Browser, enable **Show Plugin Content**, open `OrionBrowser/Showcase/L_OrionBrowserOverview`, then Play.

Opening the project never launches WebUIStudio automatically. Use the **WebUIStudio** button on the Level Editor toolbar when you want to author or preview pages; see [Tutorial 2](tutorial-2-webui-studio.md).

A host can read the default browser materials while constructing a widget before the Helper is ready. The plugin manages these synchronous defaults separately from CEF initialization. Once the Helper passes verification (it was already in place at startup, or its download has just finished), a waiting widget or a subsequent browser request initializes CEF through the same singleton entry point, without rebuilding the host widget or restarting the Editor. An actual CEF initialization failure is reported; subsequent singleton access does not repeatedly retry it.

## Download the dependencies

Fab does not distribute executables, so the plugin's two dependencies are hosted on public GitHub Releases and are downloaded once, about 160 MB in total:

| Dependency | Location inside the plugin | Purpose |
| --- | --- | --- |
| Helper | `Binaries/Win64/OrionBrowserHelper.exe` | Browser subprocess used by the editor and packaged game |
| WebUIStudio | `Binaries/Win64/WebUIStudio.exe` | Authoring and preview application; not shipped with the game |

**The plugin never downloads them by itself.** Opening the editor, Play, compiling, cooking and packaging do not use the network; a download starts only when you click **Download** in the window.

1. Click the **WebUIStudio** button on the Level Editor toolbar. The plugin checks the size and SHA-256 of both files against the manifest it ships with.
2. When a file is missing or does not match this plugin version, the **OrionBrowser Dependencies** window opens and lists each file as **Ready**, **Missing** or **Wrong version**.
3. Click **Download**. The window shows the current file, the bytes transferred and the progress; **Cancel** stops it.
4. When the download has been verified, the window reads `The OrionBrowser dependencies are ready.` Click **Open WebUIStudio**. Interfaces waiting in the editor refresh at that moment; no restart is needed.

When both files exist and match the plugin version, clicking the **WebUIStudio** button opens WebUIStudio directly, with no window. The window follows the editor language; in a Chinese editor its title is `OrionBrowser 依赖` and its buttons are `下载`, `取消`, `重试` and `打开 WebUIStudio`.

Until the dependencies have been downloaded:

| Where | What you see |
| --- | --- |
| An interface widget in the editor | `OrionBrowser dependencies are missing. Click the WebUIStudio button on the toolbar to download them.`; it refreshes when the download finishes |
| Output Log | One `LogOrionBrowserPreparation` warning saying that the Helper is missing or does not match the plugin version |
| Cook and packaging | They fail at once and state the reason; nothing is downloaded. See [Packaging](packaging.md#standard-packaging) |

When the editor starts, it checks the local files once in the background to decide whether browsers can be created. That check only reads local files: it does not use the network and opens no window.

## CommonUI viewport

OrionBrowser enables the engine's CommonUI plugin. CommonUI input routing requires a game viewport derived from **CommonGameViewportClient**. In a blank Blueprint project, set **Game Viewport Client Class** in Project Settings to **CommonGameViewportClient**, then restart the editor. The corresponding project `Config/DefaultEngine.ini` setting is:

```ini
[/Script/Engine.Engine]
GameViewportClientClassName=/Script/CommonUI.CommonGameViewportClient
```

If your game already uses a custom viewport, retain that class and ensure it derives from CommonGameViewportClient; replacing it could remove your game's viewport behavior. The plugin does not overwrite a project's custom viewport. A page can display and receive a mouse click without this setup while CommonUI reports an input-router error, so first display alone is not proof that keyboard/controller routing is ready. Do not suppress the diagnostic to substitute for configuring the viewport.

## Versions and the manifest

`Config/OrionBrowserDistribution.json`, shipped with the plugin, gives each executable its own `releaseTag`, the exact GitHub Release tag that hosts it, and pins its size and SHA-256. Downloads use only that tag and never `latest`. The two tags are independent: an executable that a plugin update leaves unchanged keeps its earlier tag, so plugin `1.0.1` can take Helper from tag `1.0.0` and WebUIStudio from tag `1.0.1`. The manifest `version` must equal `VersionName` in `OrionBrowser.uplugin`. CEF libraries and resources are supplied with the plugin and must stay paired with the Helper pinned by the manifest.

A download needs HTTPS access to GitHub and its release-asset hosting endpoints. Public downloads require no GitHub account or access token. A local file that is already complete and correct is not downloaded again when you click **Download**. This fetches the dependencies of the current version only: it does not install a newer plugin version.

After the plugin is updated through Fab or by hand, the new manifest arrives with it. An executable that still matches the new manifest is kept. One that differs is not replaced by itself, and while the Helper differs, interfaces are disabled in the editor. Click the **WebUIStudio** button again: the window lists the files that need updating, and **Download** replaces them. You do not need to delete the old files.

## Progress, cancel and recovery

The **OrionBrowser Dependencies** window shows checking, downloading, verification, completion or failure, along with the current file, transferred bytes and progress. When a download fails, including when there is no network, the window reads `OrionBrowser dependencies failed to download` (`OrionBrowser 依赖下载失败` in a Chinese editor), the reason stays below it and **Retry** is available. **Cancel**, or closing the window, stops the download and leaves an `.exe.part` and `.exe.part.json` beside the final executable. The next **Download** resumes when the server supports HTTP Range. If the server returns a full response, the download safely restarts that file instead of appending it to the old bytes.

A final executable is installed only after its complete size and SHA-256 match the plugin manifest. A same-size corrupt file is invalid. A truncated existing executable may provide an initial resume candidate, but it is never trusted without complete verification. A download makes at most three automatic attempts per component per operation; failures remain visible and can be retried after fixing the cause.

Multiple editors and packaging processes coordinate through a named process lock. Allow a current download to finish. Do not manually launch or rename `.part` files.

## Offline import

On a connected machine, open the [releases page](https://github.com/IdealityCentury/OrionBrowser/releases). Take each executable from the **tag** written as its `releaseTag` in the plugin's `Config/OrionBrowserDistribution.json`; the two tags can differ. Copy `OrionBrowserHelper.exe` and `WebUIStudio.exe` to the locations in the table above. Preserve the manifest supplied with the plugin; do not generate a new checksum for an arbitrary executable. Then click the **WebUIStudio** button: when the files match, no window opens and WebUIStudio starts. Alternatively, run the command below from the plugin root; it only checks and downloads nothing:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Scripts\Ensure-OrionBrowserTools.ps1 -Component All
```

Exit `0` means both match. Exit `1` means missing or mismatched, with the reason listed; exit `2` is cancellation. A build machine without a graphical session cannot click the button: append `-Download` to the same command to download the missing files explicitly. The script uses Windows PowerShell and does not require Node or Python. Authoring a web application needs Node.js; see [Tutorial 4](tutorial-4-write-by-hand.md#prepare).

## Folder permissions

The plugin directory must be writable to download the dependencies. An engine installation under a protected directory may require the owner to grant appropriate write access or import the verified files offline. OrionBrowser does not elevate privileges, change directory permissions, kill a running executable or relocate the download. A locked EXE, full disk or unwritable directory produces a failure with a reason. Close the relevant application normally, free space or correct access, then retry.

For support, include the plugin version, engine version, the error and the relevant log under project `Saved/OrionUE/OrionBrowser/Preparation`. Remove private paths and credentials before sharing logs.
