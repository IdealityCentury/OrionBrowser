# Tutorial 3: Blueprint and C++ integration

Once the page exists, the Unreal side has four jobs: **host the page, receive actions, publish state, and provide sounds and resources**. All four can be done in Blueprint alone, in C++, or with a C++ base class and a Blueprint subclass. This tutorial covers all three completely.

[简体中文](tutorial-3-blueprint-and-cpp.zh-CN.md) · [Manual index](README.md) · To have AI write the page, see [Tutorial 1](tutorial-1-ai.md); to write it yourself, see [Tutorial 2](tutorial-2-build-it-yourself.md).

One principle never changes: **game state, rules and saved data belong to Unreal; the page renders state and submits actions.** Check every parameter from the page again in Unreal. A page saying "success" is not success.

## Choose a route

| Route | Suits | Characteristics |
| --- | --- | --- |
| Blueprint only | Projects without a C++ module; state made of a few numbers, strings and switches | No compiler needed; JSON through the plugin's nodes |
| C++ | Projects that already have C++; state with arrays and nesting; high-frequency data or guaranteed delivery | `FJsonObject` directly; every interface is available |
| C++ base class with a Blueprint subclass | Programmers fix the contract and validation; designers configure sounds, assets and individual behaviour in Blueprint | Each side keeps to its own part, and Blueprint cannot bypass validation |

There are also three forms of host:

| Form | How | When |
| --- | --- | --- |
| Plain widget | Put an **Orion WebUI** in any Widget Blueprint | A HUD, a single panel, replacing one UMG area with a page |
| CommonUI page | Choose **Orion WebUI Activatable Widget** as the Widget Blueprint's parent class | The page enters a CommonUI stack and needs input modes, back handling, action routing, and restoring after being covered |
| InstantScreen | See [the end](#instantscreen-overview) | Several pages on one layer share one resident browser |

For a first integration use "Blueprint only + plain widget". Everything else builds on it.

## The contract used here

The settings panel of Tutorials 1 and 2. The AppId is `SettingsPanel`, and the production files are in the project's `Content/UI/WebUI/SettingsPanel/dist`.

| Direction | Name | Parameters | Meaning |
| --- | --- | --- | --- |
| Unreal → page | `ue:settingsPanel.state` | `{ stateRevision, volume, quality, culture }` | Full state |
| Page → Unreal (emit) | `settingsPanel.ready` | `{}` | The page is listening |
| Page → Unreal (emit) | `settingsPanel.setVolume` | `{ volume: 0–100 }` | Change the volume |
| Page → Unreal (emit) | `settingsPanel.setQuality` | `{ quality: "low" \| "medium" \| "high" }` | Choose the quality |
| Page → Unreal (call) | `settingsPanel.resetDefaults` | `{}` | Restore defaults; needs a result |
| Page → Unreal (emit) | `settingsPanel.close` | `{}` | Close the panel |

A message the page sends with `emit` arrives in **On Web Event**. One sent with `call` arrives in **On Web Request** and must be answered.

## Blueprint only: from scratch

### 1. Create the App Definition

1. Right-click in the Content Browser, choose **Miscellaneous → Data Asset**, pick the class `OrionWebUIAppDefinition` (search for `Orion` in the class list), and name it `DA_SettingsPanel`.
2. Open it and set:

| Property | Value | Note |
| --- | --- | --- |
| `AppId` | `SettingsPanel` | Must be identical to the folder name and to `orionWebUI.appId` in the page's `package.json` |
| `EntryHtml` | `index.html` | The default |
| **Use Dev Server in Editor** | cleared | Enabled by default. When enabled, UMG Designer prefers a local development server |

Leave everything else at its default. All properties are listed in [Tutorial 2](tutorial-2-build-it-yourself.md#app-definition-properties).

### 2. Create the Widget that hosts the page

1. Create a **User Widget** Blueprint named `WBP_SettingsPanel`.
2. In Designer, find **Orion WebUI** in the palette, drag it in, name it `WebUI`, enable **Is Variable**, and let it fill its parent.
3. In Details, set **App Definition** to `DA_SettingsPanel`. Once Helper is ready, Designer shows the page.

### 3. Show it

In the Player Controller (or wherever you manage interfaces):

1. **Create Widget** (Class `WBP_SettingsPanel`, Owning Player `Self`) and store the result in a variable.
2. **Add to Viewport**.
3. **Set Input Mode Game And UI**, with the `WebUI` of this Widget connected to **In Widget to Focus**, so that keyboard input reaches the page.
4. **Set Show Mouse Cursor** to `true`.

To close, do the reverse: **Remove from Parent**, **Set Input Mode Game Only**, hide the cursor. Create an interface once; do not create it every frame.

### 4. Receive actions: On Web Event

Select `WebUI` in Designer and click the plus next to **On Web Event** under **Events** at the bottom of Details. The event gives `Event Name` and `Payload Json`. Connect a **Switch on Name** and add one output per event name:

**`settingsPanel.ready`**: call `PublishState` from the next section.

**`settingsPanel.setVolume`**:

1. **Get Json Number**: connect `Payload Json` to `Json`, and enter `volume` as `Field`.
2. **Branch** on `Valid`. `false` means the field is missing or has the wrong type; do nothing.
3. **Branch** on the value being between 0 and 100.
4. If it passes: **Round** it to an integer, store it in the variable `Volume`, apply it to the game's volume setting, and call `PublishState`.
5. If it does not pass, call `PublishState` anyway. The correct state is pushed back and the page's display is corrected.

**`settingsPanel.setQuality`**: read `quality` with **Get Json String**, check `Valid`, accept only `low`, `medium` and `high` with a **Switch on String**, then store it and call `PublishState`.

**`settingsPanel.close`**: run the closing steps of section 3.

Connect no business logic to the **Default** output. Event names you did not register are not handled.

An action that is disabled in the page must be checked against the same condition in Blueprint: disabling in the page is presentation only. To guard against duplicate or stale actions, have the page include a request number or the `stateRevision` it saw in the payload, and let Blueprint decide whether to accept it.

> The plugin's own notifications arrive at this event too, for example `__orion.inputReady`, `__orion.stateCommitted` (each time the page has applied a state) and `webUI.presentationReady`. Let them fall through to **Default**. A hover or click that no control sound policy answers also arrives here, as `webUI.hoverSoundRequested` or `webUI.clickSoundRequested` with `controlId` in the payload. A policy answers an interaction when it has a sound for it or an entry whose **Enabled** is cleared; see [Control sounds](#control-sounds).

### 5. Publish state

Create a function `PublishState`, with the variables `StateRevision` (Integer64), `Volume` (Integer), `Quality` (String) and `Culture` (String):

1. Add one to `StateRevision`.
2. **Set Json Number**: enter `{}` as `Json`, `stateRevision` as `Field`, and connect `StateRevision` to `Value`.
3. Connect the return value to `Json` of the next **Set Json Number**, with `Field` `volume`.
4. In the same way add two **Set Json String** nodes for `quality` and `culture`.
5. Call **Post Retained Latest Event to Web** on `WebUI`: `Event Name` is `ue:settingsPanel.state`, and `Payload Json` is the return value of the last node.

Always send the **full state**, never "what changed". `stateRevision` only increases, and the page uses it to drop late, older states. **Retained** means that a page which starts listening after the event was sent still receives the most recent one. A reloaded page sends `settingsPanel.ready` again, so always publish when you receive it.

### 6. Requests that need a result: On Web Request

Add the **On Web Request** event of `WebUI`. It gives `Request` and `Response`. Break `Request` to get `Name` and `Payload Json`, and connect a **Switch on Name** again:

**`settingsPanel.resetDefaults`**:

- When it is allowed: set the variables back to their defaults and apply them, call `PublishState`, then call **Resolve Json** on `Response` with `{}` as `Data Json`.
- When it is not: call **Reject** on `Response`, with your own error code as `Error Code` (for example `E_LOCKED`) and a reason for the player as `Error Message`.

**Default** output: call **Reject** on `Response` with the code `E_UNKNOWN_REQUEST`.

Rules:

- Each request is answered once. A second call is ignored.
- Call **Resolve Json** only after Unreal has really accepted the action.
- When the result takes a while (waiting for a save to finish, for example), first call **Defer** on `Response`, store `Response` in a variable, and answer later. If no answer arrives within `BridgeCallTimeoutSeconds` of the App Definition (15 seconds by default), the page receives `E_TIMEOUT`.
- When the event ends with neither an answer nor **Defer**: with **Auto Resolve Unhandled Requests** enabled on `WebUI` (the default) the request succeeds with `{}`; with it cleared, the request fails with `E_UNHANDLED`. So always **Reject** explicitly on the Default output.

### 7. Ready and errors

| Event | When | Use |
| --- | --- | --- |
| **On Web Ready** | The page and Unreal are connected | You can publish the first state here; it fires again after the page reloads |
| **On Web Error** | Bridge errors, blocked navigation, a full message queue and the like | Print it. Look here first when something is wrong |
| **On Web Local Resources Ready** | The page confirms that its styles, fonts and images are ready | When you want to show the page only once it is prepared |
| **On Route Changed** | The page reports a route change | Apps with several pages |
| **On Browser Load Started / Completed** | The document starts loading / finished loading | A loading indicator |

While developing, connect **On Web Error** to **Print String**.

### 8. Presentation state and cleanup

**Set Presentation Lifecycle State** on `WebUI` tells the page and the browser which presentation stage they are in:

| State | Page phase | Widget and browser |
| --- | --- | --- |
| **Visible** | `active`: animation and input | The widget may draw. It neither wakes a parked browser nor releases the presentation gate |
| **Covered Suspended** | `covered` | The widget stops drawing and the browser is parked: the page is frozen, produces no frames and takes no input |
| **Closing** | `closing` | Parked in the same way as **Covered Suspended** |
| **Destroyed** | `suspended` | Closes the browser session and releases the page |
| **Preparing** | `preparing` | Wakes a parked browser and hides the widget behind the presentation gate, until **Release Native Presentation Gate** is called or a presentation transaction completes |

A Blueprint-only interface needs **Visible** alone, with `0` as `Presentation Revision`: one call after the page is shown (the supplied sample uses only this state), or no call at all, because the page becomes visible by itself once it is ready. To hide such an interface for a while, change the Widget's visibility or remove it. Do not pair **Covered Suspended** with **Visible**: **Visible** alone leaves the browser parked. Covering and restoring is what the CommonUI base class does for you; on every activation it passes through **Preparing** and a presentation transaction with a new revision. `Presentation Revision` belongs to those transactions, and a positive value below the current one is ignored.

When the Widget is destroyed, clean up what you used in **Event Destruct**:

- **Deactivate Control Sound Policy** (with `Self` as `Policy Owner`)
- **Clear Native Surfaces** and **Release Texture Resources** (if you used them)
- **Unbind Overlay Widget** of WorldUI (if you used it)
- Your own timers

## JSON in Blueprint

The plugin provides six nodes in the **Orion WebUI | JSON** category:

| Node | Effect |
| --- | --- |
| **Get Json String / Number / Boolean** | Reads one top-level field of an object. `Valid` is `false` when the field is missing, has another type, or the JSON is invalid |
| **Set Json String / Number / Boolean** | Writes one top-level field and returns the new JSON. An empty source starts from `{}`; an invalid source is returned unchanged with `Valid` `false` |

- They handle **top-level** strings, numbers and booleans only. A dot in a field name does not mean nesting.
- The input can be at most 1,048,576 characters long.
- The nodes escape quotes and line breaks correctly. Do not concatenate text entered by the player with **Append**.
- A number must be finite before it is written; otherwise `Valid` is `false`.

For arrays or nested objects (an inventory list, a leaderboard) there are three ways:

1. Flatten the structure into top-level fields such as `slot0Name`, `slot0Count` and `slotCount`. The simplest when the count is fixed and small.
2. Enable the engine's **Json Blueprint Utilities** plugin, build an object with arrays in Blueprint, and pass it as a string to **Post Retained Latest Event to Web**.
3. Move that part of the state into C++ and build it with `FJsonObject`, as shown below.

## Common features in Blueprint

### Control sounds

Hover and click sounds are played by Unreal. Every clickable element of the page has a stable control Id (`data-orion-control-id`); the plugin reports which control was hovered or clicked, and a policy in Blueprint decides what to play.

1. In the Widget Blueprint that hosts the page, add a variable `ControlSounds` of type `OrionWebUIControlSoundPolicy` and compile.
2. Fill in its default value:

| Field | Meaning |
| --- | --- |
| **Default Sounds → Hover Sound / Click Sound** | The default sounds of every control. Each has `Sound`, `Concurrency Settings`, `Volume Multiplier`, `Pitch Multiplier`, `Start Time` and `Enabled` |
| **Control Overrides** | Overrides by control Id. Enter `Control Id`, enable **Override Hover Sound** or **Override Click Sound**, and fill in that sound |

3. **Event Construct**: call **Activate Control Sound Policy** on `WebUI` with `Self` as `Policy Owner`, an empty `Context Id`, and `ControlSounds` as `Policy`.
4. **Event Destruct**: call **Deactivate Control Sound Policy** on `WebUI` with `Self` as `Policy Owner`.

Notes:

- To silence one control, add an override, enable the matching Override switch, and clear **Enabled** of that sound. A disabled definition consumes the interaction and does not fall back to the default sound.
- When the volume follows a player setting, build the policy again with the new volume (a **Make** node or **Set Members**) and call **Activate Control Sound Policy** once more for the same `Policy Owner`. The new policy replaces the old one.
- `Context Id` is for a page with several areas that each use a policy of their own: the page writes `data-orion-sound-context="Shop"` on the root element of the area, and Blueprint activates another policy with `Shop` as `Context Id` and a different object as `Policy Owner`, because one owner holds one policy and a second activation with the same owner replaces the first. A request with a name that matches no policy falls back to the one with an empty `Context Id`.
- Disabled controls (`disabled`, `aria-disabled="true"`) and waiting controls (`aria-busy="true"`) make no sound.
- When gamepad navigation does not move the page's focus, Blueprint can call **Play Control Sound** (`Control Id`, `Interaction`, `Context Id`) to add the sound.
- To check the Ids, click a control with the Element tool in WebUIStudio (the "Inspect" tab shows its control Id), or select `WebUI` in Designer and set **Design Time Control Id Preview Mode** to **All Controls**.

### Sounds with a business meaning

Sounds such as "saved" or "not enough credit" are requested by the page at the right moment; the sound assets are still configured in Unreal:

1. Create an `OrionWebUISoundManifest` data asset and register entries in **Entries**: `StableId` (for example `settings.saved`), `Sound`, and optionally concurrency, volume and pitch.
2. Assign it to **Sound Manifest** of the App Definition. `bAllowWebSoundPlayback` and `bPreloadSoundsOnLoad` are both on by default.
3. The page calls `api.playSound("settings.saved")`. Blueprint can also call **Play Sound by Id** on `WebUI`.

Bind **On Web Sound Requested** if you want to do something else when a sound is requested, such as logging.

### Text and language

Choose one of two ways:

- **Language in the state.** Blueprint publishes `culture` in the state, and the page uses its own bilingual dictionary. The supplied sample does this, and it is the least work in a Blueprint-only project.
- **Text Catalog.** Create an `OrionWebUITextCatalog` data asset, register stable keys (for example `settingsPanel.title`) with Unreal text in **Texts**, and assign it to **Text Catalog** of the App Definition. The text goes through Unreal's localization pipeline; the page looks text up by key, and the plugin pushes a new text table when the language changes.

### Runtime images

To show a `Texture2D` (an avatar, an icon generated at run time) in the page:

1. Call **Request Texture Resource** on `WebUI`: a stable name as `Stable Id` (for example `player.avatar`), the texture as `Texture`, and `Options` built with a **Make** node, with `Max Output Dimension` set for the size actually displayed. The return value contains `Url`.
2. Bind **On Texture Resource Completed** of `WebUI`. When `Status` of the result is **Ready**, write `Url` from `Handle` into the state and publish it, or send a separate event as the sample does.
3. The page uses that `Url` for an image.
4. When it is no longer needed, call **Release Texture Resource** (one) or **Release Texture Resources** (all).

Requesting the same `Stable Id` again yields a new address, and the old one stops working soon after, so the page uses only the latest address in the state. When pixels change in place, raise `Source Revision` in `Options`. This is not a video channel: for continuously changing pictures use the Native Surface of the next section. Virtual textures are not supported.

### Live pictures: Native Surface

Draws a Render Target, a scene capture or a UI material directly at a position in the page; the pixels never pass through the page:

1. The page puts a placeholder element at the position and binds it under a stable name (for example `station.capture`).
2. Blueprint calls **Set Native Surface Texture** on `WebUI` (`Surface Id` is the same name, `Texture` is the Render Target), or **Set Native Surface Material**.
3. Position and size follow the placeholder element in the page. Blueprint computes no coordinates.
4. When finished, call **Clear Native Surface** or **Clear Native Surfaces**.

| Node | Effect |
| --- | --- |
| **Set Native Surface Tint** | Overall tint and opacity |
| **Set Native Surface Composition Layer** | **Above Browser** (the default, drawn over the page) or **Below Browser** (drawn under the page; needs transparency enabled on the App Definition) |
| **On Native Surface Layout Changed** | Position, size or visibility changed; pause the scene capture while `Visible` is `false` |
| **Has Native Surface / Get Native Surface Layout** | Queries |

The native picture receives no mouse input. Put rounded corners, masks and fades into the UI material. Bindings can also be configured statically in the **Native Surface Bindings** array of `WebUI`.

### WorldUI: labels and interaction that follow Actors

Each local player has one page that carries every world label. Actors carry a data component only; do not create a browser per Actor.

1. Create an `OrionWebUIWorldElementDefinition` data asset:

| Property | Meaning |
| --- | --- |
| `ElementType` | The page uses it to choose a renderer; `Default` by default |
| `Pivot`, `ScreenOffset` | The label's alignment point and screen offset |
| `MaxVisibleDistance` | Hidden beyond this distance; `0` disables distance culling |
| `bCheckOcclusion` | Hidden when the scene blocks the view |
| `bClampToViewport` | Stays at the screen edge instead of disappearing when off screen |
| `bScaleWithDistance` | Shrinks with distance. Needs `MaxVisibleDistance` above 0 |
| `bInteractive` | Off by default. Must be on for clicks |
| `AllowedActions` | The permitted action names, for example `collect` |
| `MaxInteractionDistance` | Interaction distance, 300 by default; `0` allows interaction wherever it is visible |

2. Add the component to the Actor (search for `World Element`; the class is `OrionWebUIWorldElementComponent`): assign **Definition** and enter **Element Key**; set the anchor component, socket and **World Offset** if needed.
3. Provide text and state with **Set Payload Json**. The default renderer in the page reads `label` and `actionLabel`. Show or hide with **Set Element Visible**.
4. After the interface is created, get the local player subsystem `OrionWebUIWorldSubsystem` (search for that name in Blueprint) and call **Bind Overlay Widget** with `WebUI`.
5. Bind **On Interaction** of the component. It gives `Player`, `Action Id` and `Payload Json`. Decide here whether the game rules allow it, then change state.
6. Call **Unbind Overlay Widget** when the interface is destroyed.

Before dispatching, the plugin checks the current world, that the component is valid, that the action is in the allowed list, visibility and distance. This is a check of the local presentation, not server authorisation: a networked game sends a validated server request as well.

### Remote websites

Use a separate **Orion Browser** widget for external websites. It has no game bridge; do not mix it with **Orion WebUI**.

| Node or event | Effect |
| --- | --- |
| **Initial URL** (property), **Load URL** | Open an address |
| **Go Back / Go Forward / Reload / Stop Load** | Navigation |
| **On Load Started / On Load Completed / On Load Error** | Loading, loaded and failed views |
| **On Url Changed / On Title Changed** | The address or title changed |
| **On Before Popup** | The page wants to open a new window |
| **Get Url / Get Title Text** | Queries |

A network failure affects only this widget; local interfaces keep working. Build a failed view with a retry button, as the sample's `WBP_OrionWebsite` does.

### Host it with CommonUI, without C++

When you need CommonUI's input modes, back handling and action routing:

1. Choose **Orion WebUI Activatable Widget** as the parent class when you create the Widget Blueprint.
2. Add an **Orion WebUI** child. **Its name must be `WebUI`.**
3. In Class Defaults set **App Definition**; **Control Sound Policy** (no manual activation needed); **Input Config** (`Menu` by default; also `Game And Menu`, `Game` and `Default`); and optionally **Input Manifest**.
4. In the event graph, override `HandleWebUIEvent`, `HandleWebUIRequest` and `HandleWebUIReady`. The logic is the same as for On Web Event and On Web Request above.
5. Push it onto your CommonUI stack. On activation it loads the page, registers actions and requests presentation; on deactivation it suspends.

| Property or event | Effect |
| --- | --- |
| **Input Manifest** | An `OrionWebUIInputManifest` data asset; each action has an `ActionId` and an input action. When it fires, `ue:commonAction` is sent to the page and `HandleCommonAction` is called |
| **Forward Back Action to Web** | Back first notifies the page with `ue:backAction` |
| `HandleWebUIBackAction` | Return `true` to say it was handled; the default close does not run |
| **Deactivate on Back Action** | Whether to close this page when nothing handled back |
| **On Input Prompts Changed** | The input device or key prompts changed |

Choose one business entry point per action: when the page already submits an action for it, Blueprint must not run it again in `HandleCommonAction`.

## Blueprint node reference

All of these are on `WebUI` (**Orion WebUI**). Search by keyword.

| Category | Nodes |
| --- | --- |
| Loading | **Load App**, **Reload App**, **Set Initial Route Override**, **Get Current Route**, **Get App Id**, **Get App Definition** |
| Sending | **Post Event to Web** (one-off; lost if the page is not listening), **Post Latest Event to Web** (keeps only the newest while the bridge is not ready), **Post Retained Latest Event to Web** (keeps the newest and replays it to later listeners) |
| Calling the page | **Call Web** (returns a request Id; the result arrives in **On Web Call Completed**), **Cancel Web Call**, **Get Pending Web Call Count** |
| Answering requests | On `Response`: **Resolve Json**, **Reject**, **Defer**, **Has Responded**, **Is Deferred**, **Get Request Id** |
| Presentation | **Set Presentation Lifecycle State**, **Get Presentation Lifecycle State**, **Get Presentation Lifecycle Revision**, **Begin Native Presentation Gate**, **Release Native Presentation Gate** |
| Readiness | **Is Web Bridge Ready**, **Is Browser Available**, **Is Browser Frame Ready**, **Is Web Presentation Ready**, **Is Web Local Resources Ready**, **Is Web Page Loading**, **Has Requested App Load**, **Get Readiness Snapshot** |
| Sound | **Activate / Deactivate Control Sound Policy**, **Play Control Sound**, **Play Sound by Id**, **Preload Sounds** |
| Native surfaces | **Set Native Surface Texture / Material / Tint / Composition Layer**, **Clear Native Surface(s)**, **Has Native Surface**, **Get Native Surface Layout** |
| Runtime images | **Request Texture Resource**, **Cancel Texture Resource**, **Release Texture Resource(s)**, **Has Texture Resource**, **Is Texture Resource Ready**, **Invalidate Texture Resource**, **Get Texture Resource Stats** |
| Advanced delivery | **Post Flow Controlled Latest Event to Web**, **Post Reliable Retained Latest Event to Web**, **Post Reliable Presentation Event to Web** and their Cancel nodes; see [the C++ channels](#four-channels-for-publishing-state) |
| Debugging | **Execute Javascript for Debug** |

**Call Web** is a request in the other direction: Unreal calls a handler the page registered with `api.handle(name, handler)`, and the result has `Ok`, `Payload Json`, `Error Code` and `Error Message`. Use it to ask the page about presentation, not to drive game logic.

## C++: from scratch

### Module dependencies

The plugin's browser modules support Win64 only and take no part in Server builds. Put the code that hosts interfaces into a module built for clients only:

```csharp
// MyGameUI.Build.cs
PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "UMG", "OrionWebUI", "OrionWebUIWidget" });
PrivateDependencyModuleNames.AddRange(new string[] { "Json" });
// For CommonUI pages add: "CommonUI", "OrionWebUICommonUI"
// For WorldUI add: "OrionWebUIWorld" (the component, available on Server) and "OrionWebUIWorldWidget" (the subsystem)
```

When the project has a Server target, give this module `"TargetDenyList": ["Server"]` and `"PlatformAllowList": ["Win64"]` in its descriptor in the `.uproject` or `.uplugin`. Reflected types cannot be wrapped in a macro, so do not put a `UCLASS` derived from a plugin class into a module the Server compiles. After changing module boundaries, compile the Server target as well.

| Module | Provides |
| --- | --- |
| `OrionWebUI` | App Definition, the manifests, `UOrionWebUIResponseHandle`, the JSON Blueprint library |
| `OrionWebUIWidget` | `UOrionWebUIWidget`, the InstantScreen widgets and subsystem, the diagnostics library |
| `OrionWebUICommonUI` | `UOrionWebUIActivatableWidget`, `UOrionInstantScreenActivatableWidget`, `UOrionWebUIInputManifest` |
| `OrionWebUIWorld` | `UOrionWebUIWorldElementComponent`, `UOrionWebUIWorldElementDefinition` |
| `OrionWebUIWorldWidget` | `UOrionWebUIWorldSubsystem` |
| `OrionBrowserWidget` | `UOrionBrowserWidget` (remote websites) |

### Plain widget: UUserWidget with BindWidget

A Widget Blueprint uses this class as its parent and has an **Orion WebUI** named `WebUI` in Designer.

```cpp
// SettingsPanelWidget.h
#pragma once

#include "Blueprint/UserWidget.h"
#include "OrionWebUIDefinitions.h"

#include "SettingsPanelWidget.generated.h"

class UOrionWebUIWidget;

/** Host of the settings panel: validates page actions, owns the settings, publishes the full state. */
UCLASS(Abstract, Blueprintable)
class MYGAMEUI_API USettingsPanelWidget : public UUserWidget
{
	GENERATED_BODY()

protected:
	virtual void NativeConstruct() override;
	virtual void NativeDestruct() override;

private:
	UFUNCTION()
	void HandleWebReady();

	UFUNCTION()
	void HandleWebEvent(FName EventName, const FString& PayloadJson);

	UFUNCTION()
	void HandleWebRequest(const FOrionWebUIBridgeRequest& Request, UOrionWebUIResponseHandle* Response);

	UFUNCTION()
	void HandleWebError(const FString& ErrorMessage);

	void PublishState();

protected:
	UPROPERTY(BlueprintReadOnly, meta=(BindWidget))
	TObjectPtr<UOrionWebUIWidget> WebUI;

	/** Configured in Class Defaults of the Blueprint subclass. */
	UPROPERTY(EditDefaultsOnly, Category="Settings Panel")
	FOrionWebUIControlSoundPolicy ControlSounds;

private:
	int64 StateRevision = 0;
	int32 Volume = 80;
	FString Quality = TEXT("high");
	FString Culture = TEXT("en");
};
```

```cpp
// SettingsPanelWidget.cpp
#include "SettingsPanelWidget.h"

#include "Dom/JsonObject.h"
#include "OrionWebUIWidget.h"
#include "Policies/CondensedJsonPrintPolicy.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

namespace SettingsPanel
{
	static const FName StateEvent(TEXT("ue:settingsPanel.state"));
	static const FName ReadyEvent(TEXT("settingsPanel.ready"));
	static const FName SetVolumeEvent(TEXT("settingsPanel.setVolume"));
	static const FName SetQualityEvent(TEXT("settingsPanel.setQuality"));
	static const FName CloseEvent(TEXT("settingsPanel.close"));
	static const FName ResetDefaultsRequest(TEXT("settingsPanel.resetDefaults"));
}

void USettingsPanelWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (!WebUI)
	{
		return;
	}
	WebUI->OnWebReady.AddUniqueDynamic(this, &ThisClass::HandleWebReady);
	WebUI->OnWebEvent.AddUniqueDynamic(this, &ThisClass::HandleWebEvent);
	WebUI->OnWebRequest.AddUniqueDynamic(this, &ThisClass::HandleWebRequest);
	WebUI->OnWebError.AddUniqueDynamic(this, &ThisClass::HandleWebError);
	WebUI->ActivateControlSoundPolicy(this, NAME_None, ControlSounds);
}

void USettingsPanelWidget::NativeDestruct()
{
	if (WebUI)
	{
		WebUI->DeactivateControlSoundPolicy(this);
		WebUI->OnWebReady.RemoveDynamic(this, &ThisClass::HandleWebReady);
		WebUI->OnWebEvent.RemoveDynamic(this, &ThisClass::HandleWebEvent);
		WebUI->OnWebRequest.RemoveDynamic(this, &ThisClass::HandleWebRequest);
		WebUI->OnWebError.RemoveDynamic(this, &ThisClass::HandleWebError);
	}

	Super::NativeDestruct();
}

void USettingsPanelWidget::HandleWebReady()
{
	PublishState();
}

void USettingsPanelWidget::HandleWebEvent(FName EventName, const FString& PayloadJson)
{
	if (EventName == SettingsPanel::ReadyEvent)
	{
		PublishState();
		return;
	}
	if (EventName == SettingsPanel::CloseEvent)
	{
		RemoveFromParent();
		return;
	}

	TSharedPtr<FJsonObject> Payload;
	if (!FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(PayloadJson), Payload) || !Payload.IsValid())
	{
		return;
	}

	if (EventName == SettingsPanel::SetVolumeEvent)
	{
		double RequestedVolume = 0.0;
		if (Payload->TryGetNumberField(TEXT("volume"), RequestedVolume) && RequestedVolume >= 0.0 && RequestedVolume <= 100.0)
		{
			Volume = FMath::RoundToInt32(RequestedVolume);
			// Apply the volume to the game here.
		}
		PublishState();	// Also after a rejection: push the authoritative state back to correct the page
		return;
	}
	if (EventName == SettingsPanel::SetQualityEvent)
	{
		FString RequestedQuality;
		if (Payload->TryGetStringField(TEXT("quality"), RequestedQuality)
			&& (RequestedQuality == TEXT("low") || RequestedQuality == TEXT("medium") || RequestedQuality == TEXT("high")))
		{
			Quality = RequestedQuality;
		}
		PublishState();
	}
}

void USettingsPanelWidget::HandleWebRequest(const FOrionWebUIBridgeRequest& Request, UOrionWebUIResponseHandle* Response)
{
	if (!Response)
	{
		return;
	}
	if (Request.Name == SettingsPanel::ResetDefaultsRequest)
	{
		Volume = 80;
		Quality = TEXT("high");
		PublishState();
		Response->ResolveJson(TEXT("{}"));
		return;
	}
	Response->Reject(TEXT("E_UNKNOWN_REQUEST"), TEXT("Unknown settings panel request."));
}

void USettingsPanelWidget::HandleWebError(const FString& ErrorMessage)
{
	UE_LOG(LogTemp, Warning, TEXT("SettingsPanel WebUI error: %s"), *ErrorMessage);
}

void USettingsPanelWidget::PublishState()
{
	if (!WebUI)
	{
		return;
	}

	const TSharedRef<FJsonObject> State = MakeShared<FJsonObject>();
	State->SetNumberField(TEXT("stateRevision"), static_cast<double>(++StateRevision));
	State->SetNumberField(TEXT("volume"), Volume);
	State->SetStringField(TEXT("quality"), Quality);
	State->SetStringField(TEXT("culture"), Culture);

	FString Json;
	FJsonSerializer::Serialize(State, TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&Json));
	WebUI->PostRetainedLatestEventToWeb(SettingsPanel::StateEvent, Json);
}
```

Notes:

- Every delegate and `Handle*` entry point fires on the game thread. Do not move them to another thread.
- `OnWebEvent` gives a JSON string. If you do not want to parse it, bind the native delegate `OnWebEventParsed` with `AddUObject`; it gives a read-only `TSharedPtr<FJsonObject>`. The `PayloadObject` member of `FOrionWebUIBridgeRequest` is the same.
- `Response` can be answered once. To finish asynchronously, call `Response->Defer()` first, keep the pointer, and call `ResolveJson` or `Reject` later.
- `FName` comparison ignores case; the page does not. Spell an event name one way throughout the project.

### Another way: derive from UOrionWebUIWidget

To avoid the extra `UUserWidget` layer, derive from the widget and override the two `BlueprintNativeEvent`s:

```cpp
UCLASS()
class MYGAMEUI_API USettingsWebUIWidget : public UOrionWebUIWidget
{
	GENERATED_BODY()

protected:
	virtual void HandleWebEvent_Implementation(FName EventName, const FString& PayloadJson) override;
	virtual void HandleWebRequest_Implementation(const FOrionWebUIBridgeRequest& Request, UOrionWebUIResponseHandle* Response) override;
};
```

Each message is dispatched in this order: `OnWebEventParsed` → `OnWebEvent` → `HandleWebEvent`. A request goes to `OnWebRequest` → `HandleWebRequest`, and only then is it checked for an answer.

### CommonUI pages

When the page enters a CommonUI stack, derive from `UOrionWebUIActivatableWidget`. The base class loads the app, activates the sound policy, registers input actions, handles back, and completes the presentation transaction on activation and deactivation.

```cpp
// SettingsPanelScreen.h
#pragma once

#include "OrionWebUIActivatableWidget.h"

#include "SettingsPanelScreen.generated.h"

UCLASS(Abstract, Blueprintable)
class MYGAMEUI_API USettingsPanelScreen : public UOrionWebUIActivatableWidget
{
	GENERATED_BODY()

protected:
	virtual void NativeOnActivated() override;
	virtual void HandleWebUIReady_Implementation() override;
	virtual void HandleWebUIEvent_Implementation(FName EventName, const FString& PayloadJson) override;
	virtual void HandleWebUIRequest_Implementation(const FOrionWebUIBridgeRequest& Request, UOrionWebUIResponseHandle* Response) override;
	virtual bool HandleWebUIBackAction_Implementation() override;

private:
	void PublishState(bool bForceRepublish);

private:
	FString PublishedStateJson;
	int64 StateRevision = 0;
};
```

```cpp
// SettingsPanelScreen.cpp (excerpt)
void USettingsPanelScreen::NativeOnActivated()
{
	Super::NativeOnActivated();	// Loads the app, registers actions, allocates the revision of this presentation
	PublishState(true);			// State may have changed while deactivated: publish from current data
}

void USettingsPanelScreen::HandleWebUIReady_Implementation()
{
	Super::HandleWebUIReady_Implementation();
	PublishState(true);
}

void USettingsPanelScreen::HandleWebUIEvent_Implementation(FName EventName, const FString& PayloadJson)
{
	// Presentation and delivery acknowledgements return first and never reach business branches
	if (EventName == StandardPresentationReadyEventName || EventName == StandardPresentationAppliedEventName)
	{
		return;
	}
	// The rest is the same as HandleWebEvent of the plain widget; get the widget with GetWebUIWidget()
}

bool USettingsPanelScreen::HandleWebUIBackAction_Implementation()
{
	return false;	// Return true when you handled back yourself; the default close does not run
}
```

- The Widget Blueprint contains an **Orion WebUI** child named `WebUI`. Configure `AppDefinition`, `InputManifest`, `ControlSoundPolicy` and `InputConfig` in Class Defaults.
- Push the page only through your CommonUI stack; do not call `AddToViewport` directly.
- When an action of `InputManifest` fires, the base class sends `ue:commonAction` (or the entry's `WebEventName`) to the page, broadcasts `OnCommonAction`, and calls `HandleCommonAction`, in that order.
- When the input device changes, the base class sends `ue:inputModeChanged` and `ue:inputPromptsChanged` to the page.

### Four channels for publishing state

| Channel | Function | Behaviour | When |
| --- | --- | --- | --- |
| Retained latest | `PostRetainedLatestEventToWeb` | Keeps the newest; a listener registered later still receives it | Ordinary state; the default choice |
| Flow-controlled latest | `PostFlowControlledLatestEventToWeb(Event, Json, AckEvent, RevisionField, Revision)` | For one acknowledgement name, one revision is in flight and one is waiting; revisions in between are merged; the next is sent after the page has acknowledged and the browser has painted a later frame | Data that may change every frame; authoritative snapshots |
| Reliable retained | `PostReliableRetainedLatestEventToWeb(..., RetryIntervalSeconds, MaxAttempts)` | Resends until the exact revision is acknowledged, at most `MaxAttempts` times (4 by default); then it logs a warning and stops | Snapshots that must arrive |
| Presentation transaction | `PostReliablePresentationEventToWeb(...)` | Hides the widget first; shows it only after the page confirms that revision and a new frame is complete, or after a timeout | Entering the screen without showing a half-built page; the CommonUI base class already wraps it |

- An acknowledgement only says "this revision arrived" or "this revision is shown". It does not mean business success, and C++ does not wait for it before running business logic.
- One acknowledgement event name belongs to one stream.
- Allocate revisions with `UOrionWebUIWidget::AllocatePresentationRevision()`; it is unique and increasing within the process. The `stateRevision` of business state and the `presentationRevision` of presentation are two number spaces; do not compare them.
- Do not allocate a new revision when the content did not change: compare the serialized state first and increase only when it differs.
- When the data is invalid, return. Do not send an empty state as a placeholder.

### Resource interfaces

| Need | Interface |
| --- | --- |
| Show a `UTexture2D` in the page | `RequestTextureResource(StableId, Texture, Options)`; `OnTextureResourceCompleted` fires on completion |
| CPU pixels you already have | `RequestPixelResource(StableId, FOrionWebUIPixelSource, Options)`, C++ only |
| Live pictures | `SetNativeSurfaceTexture`, `SetNativeSurfaceMaterial` |
| A material that samples transient resources | `SetNativeSurfaceMaterialWithDependencies(SurfaceId, Material, Dependencies)`, so that the dependencies retire with the surface |
| Query the surface area | `TryGetNativeSurfaceLayoutState`, `TryGetNativeSurfaceAbsoluteRect` |

When you change the Render Target, create a new dynamic material instance and call `SetNativeSurfaceMaterial`; do not modify an instance that is still bound. Retire in this order: stop producing frames → clear or replace the binding → release your own references → destroy the Render Target.

### WorldUI

```cpp
#include "OrionWebUIWorldSubsystem.h"

if (ULocalPlayer* LocalPlayer = GetOwningLocalPlayer())
{
	if (UOrionWebUIWorldSubsystem* WorldUI = LocalPlayer->GetSubsystem<UOrionWebUIWorldSubsystem>())
	{
		WorldUI->BindOverlayWidget(WebUI);
	}
}
```

`OnInteraction` of the component is a dynamic multicast delegate `(APlayerController* Player, FName ActionId, const FString& PayloadJson)`. For a label that belongs to one local player, use `SetOwningLocalPlayer` of the component. When the page that carries the labels is an InstantScreen, use `BindOverlayEndpoint` instead. Global budgets are in `UOrionWebUIWorldSettings` (`MaxVisibleElements`, refresh rate, the number of occlusion traces).

### Threads and lifetime

- The browser runs in a separate process. A call from the page returning does not mean the game state has changed.
- Do not hide timing problems with fixed delays, repeated `ReloadApp()` or rebuilding the widget. Wait with `OnWebReady`, `OnWebLocalResourcesReady` and the readiness queries.
- Clean up delegates, timers, async load handles and responses you `Defer()`red symmetrically; cover deactivation, level changes and repeated entry.
- An environment that cannot render (started with `-nocef`, for example) creates no browser, and code must tolerate a missing widget.

## A C++ base class with a Blueprint subclass

Write what must not be bypassed in C++, and leave what designers tune to Blueprint:

```cpp
UCLASS(Abstract, Blueprintable)
class MYGAMEUI_API USettingsPanelWidget : public UUserWidget
{
	GENERATED_BODY()

protected:
	/** Blueprint may override the default behaviour; validation is complete before this is called. */
	UFUNCTION(BlueprintNativeEvent, Category="Settings Panel")
	void OnVolumeAccepted(int32 NewVolume);

	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="Settings Panel")
	bool bResetEnabled = true;
};
```

- Validation is written where C++ dispatches, and the `BlueprintNativeEvent` is called only after it passes; a Blueprint override cannot skip it.
- Each fixed button has one event and one enable switch. Do not use "one generic entry point with a string parameter".
- The enable switches are published to the page with the full state, and the page disables its buttons accordingly; the real guard stays in C++.
- The sound policy, App Definition and Input Manifest are `EditDefaultsOnly` properties configured in Class Defaults of the Blueprint subclass.
- When changing an existing class, do not rename, change the signature of, or delete events that Blueprints already override.

## InstantScreen overview

InstantScreen lets several interfaces on one layer share one resident browser. Each interface carries a first-frame package produced at build time, and a transaction decides when it becomes visible: state, resources, input and the first frame are all confirmed before the picture is revealed. It suits menus and HUDs that formally enter a page stack, must be shown only when loaded, and are restored after being covered. For a single panel, a plain widget is enough.

It needs more than the forms above:

| Part | Content |
| --- | --- |
| Page | `instant-screen.config.ts` in the app root; after the build, run `npm run instant:build` and `npm run instant:validate` in the plugin's `Content/UI/WebUI/Shared` folder to produce and check the first-frame packages; business actions use `requestIntent` |
| Assets | `OrionInstantScreenDefinition` (per interface), `OrionInstantScreenCatalog` (a group of interfaces), `OrionInstantScreenRuntimeProfile` (the mapping from layers to browsers) |
| Root layout | Place an **Orion InstantScreen Runtime Host** and call **Register Catalog** on the local player's `UOrionInstantScreenSubsystem` |
| Interface | The Widget Blueprint's parent derives from `UOrionInstantScreenActivatableWidget`, and its child `WebUI` is of type **Orion InstantScreen** |
| Configuration | The render mode must be `LegacyTexture` (the default; do not change it to another mode) |

The complete contract, the configuration fields and troubleshooting are in the [InstantScreen reference](../Skills/orion-webui-creation/references/instant-screen.en.md) shipped with the plugin.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| The page is blank | Are `AppId`, the folder name and `orionWebUI.appId` identical? Does `dist/index.html` exist? Look at **On Web Error** |
| Designer shows `Orion WebUI dist entry is missing` | The app was not built, or `AppId` is wrong |
| Clicks do nothing | Is **On Web Event** bound on `WebUI`? Do the event names match character for character? Is `Valid` `false`? |
| The page keeps showing an old value | Do you publish after every change? Does `stateRevision` increase? |
| A request waits until it times out | **Defer** was called but no answer followed |
| A request always "succeeds" | The Default branch has no **Reject**, so the request was answered automatically |
| Keyboard and gamepad do nothing | Is the viewport a CommonGameViewportClient (see [installation](installation.md#commonui-viewport))? Did the input mode and focus go to `WebUI`? |
| The page disappears or stops responding after **Set Presentation Lifecycle State** | **Preparing** hid the widget, or **Covered Suspended** or **Closing** parked the browser. **Visible** undoes neither: call **Release Native Presentation Gate** after **Preparing**, and wake a parked browser with **Preparing**. A Blueprint-only page should use **Visible** alone |
| No sound | Is a policy active? Do the controls have Ids? Does `Context Id` match? Is the sound asset empty? |
| A runtime image does not show | Did you wait for **Ready** before giving the address to the page? Is it a virtual texture? |
| The page is blank after packaging | Build `dist` first, then package; see [Package and troubleshoot](packaging.md) |
