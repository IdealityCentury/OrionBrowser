# Packaging and troubleshooting

Project-relative paths start at the `.uproject` directory. Plugin-relative paths start at `OrionBrowser.uplugin`. Keep a complete copy of the plugin and the same-version CEF SDK together.

## Standard packaging

Use Unreal's normal Win64 packaging workflow or Project Launcher. The plugin's editor Cook hook verifies Helper, downloads it if necessary, and copies the verified file to project `Binaries/Win64/OrionBrowserHelper.exe`. A failed preparation reports an error and requests a nonzero Cook exit. Studio is not required for Cook.

CEF DLLs, resources, language packs and notices are declared as NonUFS runtime dependencies. Helper is also NonUFS. App production outputs under project `Content/UI/WebUI/<AppId>/dist` and plugin `WebUIApps/<AppId>/dist` are declared as UFS resources. Authoring source, `node_modules`, Studio and unfinished downloads do not belong in a game package.

Always package the maps and assets your app actually references. Soft or dynamically chosen assets may need explicit asset management rules. Keep references to sounds, fonts, textures and App Definitions on cooked assets; a JSON string naming a missing asset is not a Cook dependency.

## Fixed command-line entry

The plugin provides `Scripts/Package-OrionBrowserProject.ps1`. It performs the same Helper preflight before invoking its fixed `BuildCookRun` command. Supply your engine root, exact project file and archive directory as script parameters. From the plugin root:

```powershell
.\Scripts\Package-OrionBrowserProject.ps1 -EngineRoot $EngineRoot -ProjectFile $ProjectFile -ArchiveDirectory $ArchiveDirectory -Configuration Shipping
```

The sample project includes `Scripts/Package-Development.ps1` and `Scripts/Package-Shipping.ps1`, each taking `-EngineRoot`. For a re-stage of already cooked output, use the plugin entry with `-ReuseCooked`. This runs Helper preparation even though Cook and compilation are skipped. Reused Cook content must already match the current project, plugin and configuration; this option does not update stale cooked assets.

Normal Unreal C++ compilation and `BuildPlugin` do not download tools. Do not put network downloads into `.Build.cs` constructors. `Scripts/Build-FabPlugin.ps1` invokes official `RunUAT BuildPlugin` against a new output directory and Win64.

The plugin descriptor also declares an Editor post-build step: `Prepare-OrionCEFRuntime.ps1` copies the paired, already bundled CEF runtime into plugin `Binaries/Win64/OrionCEF3`. This is local file preparation only. It is needed when official plugin precompilation filters normal runtime-dependency copy actions; it never downloads companion executables.

## Packaged runtime

The packaged Development and Shipping games use the staged Helper beside the game binary. They do not perform EXE existence probes, hash/version checks, downloads or repairs. A missing/corrupt staged file can still cause a normal OS or CEF startup error. Repair the distributed package; do not expect a customer's game to install development tools.

Move the **whole** archive when testing portability, including the project directory, engine runtime files, prerequisites and loose browser dependencies. Copying only the top-level game launcher is insufficient. Internet is only needed for explicitly remote content, such as the website panel.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Preparation reports 404 | Check exact plugin `VersionName`, Release tag and asset names. Do not substitute `latest` or a different version. |
| Download interrupted | Leave `.part` and its receipt in place; retry. A full hash is checked after resume. |
| Same size but verification fails | Replace from the same immutable release. Size alone is not integrity proof. |
| Access denied or file in use | Correct directory access or close the owning process normally. Preparation does not elevate or kill it. |
| Blank local page | Confirm AppId, `dist/index.html`, production build and AppDefinition. Check On Web Error and browser console messages. |
| Works in Studio, no Unreal action | Check On Web Event/Request binding, event name spelling, payload types, and Blueprint validation. Preview fixtures do not perform native business actions. |
| Works in Editor, missing in package | Check cooked asset references, map list and UFS/NonUFS staging. Rebuild after changing production resources. |
| Wrong CEF startup behavior | Use the CEF DLLs/resources and Helper from the same release; do not mix with another plugin or engine browser runtime. |
| Helper source build rejected | The installed engine may not support Program Targets. Use the distributed verified executable. Rebuilding Helper requires a compatible source-engine build that supports Program Targets. |

## Rebuilding Helper from source

The plugin includes its Helper source and `Scripts/BuildSupport/OrionBrowserHelper.Target.cs.template`. In a suitable source-engine host project, copy that template to the project's `Source/OrionBrowserHelper.Target.cs`, install this plugin, and build the Program Target with the matching Win64 toolchain. The template copies the result to the existing plugin binary path. Do not copy this target into the supplied pure Blueprint sample for normal use.

Changing a companion binary requires a new plugin version and a new matching release tag. Generate the distribution manifest from the final binaries and ship that same manifest in the plugin and Release. Never overwrite a published version's binary with different bytes.
