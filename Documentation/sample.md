# Orion Station sample

The sample is a small offline station with three collectible energy cells and a world-space terminal. Its inventory, mission progress and saved preferences belong to Unreal Blueprint. The web app displays that state and submits action requests.

## Open the sample

Enable **Show Plugin Content** in the Content Browser, open `/OrionBrowser/Showcase/L_OrionBrowserOverview`, and run Play after companion-tool preparation completes. The independent `OrionBrowserTemplate` project starts in its own `/Game/OrionStation/L_OrionStation` map, which reuses the plugin sample assets. It has no project C++ module.

The sample uses the plugin's `LegacyTexture` default. The website needs an internet connection; the station UI, bundled font and three.js geometry use local production files.

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

`PublishState` constructs the sample control-sound policy from UE sound assets and the saved volume. The web controls use its named `Station` context. The lab binds the emblem texture and scene capture as native surfaces and requests a runtime image through `RequestTextureResource`; the completion event publishes `ue:station.image`. Closing the host releases texture requests, native surfaces and its active sound policy. These are Blueprint wiring examples; inspect the corresponding event graphs to adapt their lifetime to your own page.

## Editing the UI

The source lives in plugin `WebUIApps/Showcase/src`; production files are in `WebUIApps/Showcase/dist`. `state.ts` defines the web state and English/Chinese dictionary. `webui-preview.json` declares eight design views. The preview does not replace a game test.

Use `WBP_OrionBrowserShowcase` as an editable wiring example, then create your own AppDefinition and widget. Rename the AppId and event names together, and give AI both the state shape and the Blueprint intent contract. See [the AI workflow](ai-workflow.md).

The website uses a separate general browser widget. It is not the local Showcase document and does not receive the station's business bridge or state events.

## Verification status

The release acceptance report distinguishes asset creation and Blueprint compilation from an actual Unreal session, packaged Development/Shipping execution, physical gamepad input and Chinese IME input. Consult that report for the tested build; do not interpret Studio preview screenshots as proof of those other environments.
