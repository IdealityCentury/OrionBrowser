# Packaging and troubleshooting

Project-relative paths start at the `.uproject` directory. Plugin-relative paths start at `OrionBrowser.uplugin`. Keep a complete copy of the plugin and the same-version CEF SDK together.

## Standard packaging

Use Unreal's normal Win64 packaging workflow or Project Launcher. **Download the dependencies in the editor before packaging**; see [Installation](installation.md#download-the-dependencies). The plugin's editor Cook hook verifies Helper against the manifest and copies the verified file to project `Binaries/Win64/OrionBrowserHelper.exe`. Studio is not required for Cook.

Packaging downloads nothing. When Helper is missing or does not match the plugin version, Cook fails at once, requests a nonzero exit and logs the error below. Do what it says: open the editor, click the **WebUIStudio** button on the toolbar, click **Download** in the window, then package again.

```text
LogOrionBrowserPreparation: Error: OrionBrowser cannot be packaged (exit 1). OrionBrowserHelper.exe is missing. Nothing is downloaded automatically. Start Unreal Editor, click the WebUIStudio button on the toolbar and download the dependencies, then try again. See the documentation: https://orionue.com/orionbrowser/docs/en/installation/
```

A Blueprint-only project still needs a compiler to package. Enabling OrionBrowser, like any code plugin outside the engine's default set, makes Unreal generate a temporary target under project `Intermediate/Source`, then compile and link the game executable. Install the Visual Studio C++ toolchain and Windows SDK required by Unreal Engine 5.8 on the packaging machine. You write no C++. Opening the project, authoring and Play In Editor use the plugin's prebuilt editor binaries and need no compiler.

CEF DLLs, resources, language packs and notices are declared as NonUFS runtime dependencies. Helper is also NonUFS. App production outputs under project `Content/UI/WebUI/<AppId>/dist` and plugin `Content/UI/WebUI/<AppId>/dist` are declared as UFS resources. Authoring source, `node_modules`, Studio and unfinished downloads do not belong in a game package.

Always package the maps and assets your app actually references. Soft or dynamically chosen assets may need explicit asset management rules. Keep references to sounds, fonts, textures and App Definitions on cooked assets; a JSON string naming a missing asset is not a Cook dependency.

## Fixed command-line entry

The plugin provides `Scripts/Package-OrionBrowserProject.ps1`. It performs the same Helper verification before invoking its fixed `BuildCookRun` command: when Helper is missing or mismatched, the script prints the same reason and exits with code 1, without starting the package and without downloading anything. Supply your engine root, exact project file and archive directory as script parameters. From the plugin root:

```powershell
.\Scripts\Package-OrionBrowserProject.ps1 -EngineRoot $EngineRoot -ProjectFile $ProjectFile -ArchiveDirectory $ArchiveDirectory -Configuration Shipping
```

The sample project includes `Scripts/Package-Development.ps1` and `Scripts/Package-Shipping.ps1`, each taking `-EngineRoot`. For a re-stage of already cooked output, use the plugin entry with `-ReuseCooked`. This verifies Helper even though Cook and compilation are skipped. Reused Cook content must already match the current project, plugin and configuration; this option does not update stale cooked assets.

Compilation, `BuildPlugin`, Cook and packaging never download the dependencies. Do not put network downloads into `.Build.cs` constructors.

The plugin descriptor also declares an Editor post-build step: `Prepare-OrionCEFRuntime.ps1` copies the paired, already bundled CEF runtime into plugin `Binaries/Win64/OrionCEF3`. This is local file preparation only. It is needed when official plugin precompilation filters normal runtime-dependency copy actions; it never downloads companion executables.

## Packaged runtime

The packaged Development and Shipping games use the staged Helper beside the game binary. They do not perform EXE existence probes, hash/version checks, downloads or repairs. A missing/corrupt staged file can still cause a normal OS or CEF startup error. Repair the distributed package; do not expect a customer's game to install development tools.

Move the **whole** archive when testing portability, including the project directory, engine runtime files, prerequisites and loose browser dependencies. Copying only the top-level game launcher is insufficient. Internet is only needed for explicitly remote content, such as the website panel.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Packaging or Cook fails and the log contains `OrionBrowser cannot be packaged` | The dependencies have not been downloaded, or they do not match the plugin version. Open the editor, click the **WebUIStudio** button on the toolbar, click **Download** in the window, then package again; see [Installation](installation.md#download-the-dependencies). |
| The download reports 404 | For the executable that failed, check that the Release named by its `releaseTag` in `Config/OrionBrowserDistribution.json` exists and contains that asset name. Do not substitute `latest` or a different version. |
| Download interrupted | Leave `.part` and its receipt in place; retry. A full hash is checked after resume. |
| Same size but verification fails | Replace from the same immutable release. Size alone is not integrity proof. |
| Access denied or file in use | Correct directory access or close the owning process normally. The plugin does not elevate or kill it. |
| Blank local page | Confirm AppId, `dist/index.html`, production build and AppDefinition. Check On Web Error and browser console messages. |
| Works in Studio, no Unreal action | Check On Web Event/Request binding, event name spelling, payload types, and Blueprint validation. Preview fixtures do not perform native business actions. |
| Works in Editor, missing in package | Check cooked asset references, map list and UFS/NonUFS staging. Rebuild after changing production resources. |
| Wrong CEF startup behavior | Use the CEF DLLs and resources bundled with the plugin together with the Helper verified against its manifest; do not mix with another plugin or engine browser runtime. |
| Packaging a Blueprint-only project fails at the build step with a missing compiler or Visual Studio error | Install the Visual Studio C++ toolchain and Windows SDK required by Unreal Engine 5.8; see Standard packaging above. |
| Helper source build rejected | The installed engine may not support Program Targets. Use the distributed verified executable. Rebuilding Helper requires a compatible source-engine build that supports Program Targets. |

## Rebuilding Helper from source

The plugin includes its Helper source and `Scripts/BuildSupport/OrionBrowserHelper.Target.cs.template`. In a suitable source-engine host project, copy that template to the project's `Source/OrionBrowserHelper.Target.cs`, install this plugin, and build the Program Target with the matching Win64 toolchain. The template copies the result to the existing plugin binary path. Do not copy this target into the supplied pure Blueprint sample for normal use.

A Helper you rebuild has different bytes from the one the manifest pins, so the plugin treats it as the wrong version: interfaces are disabled in the editor, packaging fails, and the **WebUIStudio** button opens the window that offers a download, which would replace your file with the released one. To keep your own build, set the `size` and `sha256` of the Helper entry in `Config/OrionBrowserDistribution.json` to the values of your file; no download is offered while the manifest and the local file agree.
