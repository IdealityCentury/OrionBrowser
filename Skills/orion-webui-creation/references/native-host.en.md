# The UE-side host: assets, Widget, Presenter and event entry points

This document connects a new interface to the Unreal host: which modules to depend on, which assets to create, which parent class to choose, and how C++ receives Intents and publishes state. For the Web-side API see [Bridge and lifecycle](bridge-lifecycle.en.md); for first-frame packages, Catalog and Runtime Host see [InstantScreen](instant-screen.en.md); for the button contract file, sound, fonts, images and Native Surface see [Controls and resources](controls-resources.en.md). Class names and signatures follow the header files in `<OrionBrowser>/Source/*/Public`; read the matching header before writing code.

## Modules and dependencies

Source of truth: `<OrionBrowser>/OrionBrowser.uplugin` and the `*.Build.cs` of each module. All modules allow Win64 only.

| Module | Server | Responsibility | When the host depends on it |
| --- | --- | --- | --- |
| `OrionWebUI` | Denied | DataAsset types (AppDefinition, the Manifests, InstantScreen Definition / Catalog), `UOrionWebUIResponseHandle`, the local Scheme and resource registration `IOrionWebUIModule` | Modules that reference these types |
| `OrionWebUIWidget` | Denied | `UOrionWebUIWidget`, `UOrionInstantScreenWidget`, `UOrionInstantScreenRuntimeHost`, `UOrionInstantScreenEndpoint`, `UOrionInstantScreenSubsystem` | UI and Presenter modules that hold a Widget / Endpoint |
| `OrionWebUICommonUI` | Denied | `UOrionWebUIActivatableWidget`, `UOrionInstantScreenActivatableWidget`, `UOrionWebUIInputManifest` | CommonUI page modules |
| `OrionWebUIRuntimeImage` | Denied | `UTexture2D` / pixels → in-process image URL | When its types are used directly |
| `OrionWebUIWorld` | **Allowed** | The pure-data `UOrionWebUIWorldElementComponent`, `UOrionWebUIWorldElementDefinition` and the World registry | Gameplay modules that attach world UI anchors to Actors |
| `OrionWebUIWorldWidget` | Denied | `UOrionWebUIWorldOverlayHost` and `UOrionWebUIWorldSubsystem` (one per LocalPlayer) | UI modules that host the world UI overlay |
| `OrionBrowser`, `OrionBrowserWidget` | Denied | The CEF runtime, `SOrionBrowser`, the general web control `UOrionBrowserWidget` | A WebUI interface does not need to depend on them directly (`OrionWebUI` already exposes `OrionBrowser` publicly and transitively) |
| `OrionWebUIRender`, `OrionCEF3Utils`, `OrionBrowserHelper` | Denied | Render backend, CEF loading, CEF child process | Do not depend on them |
| `OrionWebUIEditor` | Editor only | `UOrionWebUIEditorLibrary` (validation, export) | Host Editor modules only |

```csharp
// A. UI module built only for the client: direct dependency
PublicDependencyModuleNames.AddRange(new string[] { "CommonUI", "OrionWebUI", "OrionWebUICommonUI", "OrionWebUIWidget", "UMG" });
PrivateDependencyModuleNames.AddRange(new string[] { "Json" });

// B. Module that the Server also compiles: conditional dependency + the host's own macro
bool bWithOrionWebUI = Target.Platform == UnrealTargetPlatform.Win64 && Target.Type != TargetType.Server;
if (bWithOrionWebUI)
{
	PrivateDependencyModuleNames.AddRange(new string[] { "OrionWebUI", "OrionWebUIWidget" });
}
PublicDefinitions.Add("SAMPLEGAME_WITH_ORION_WEBUI=" + (bWithOrionWebUI ? "1" : "0"));
```

- The host `.uproject` (or the host plugin `.uplugin` that carries the interface) enables `OrionBrowser`; `OrionBrowser` declares its own dependencies on `CommonUI` and `GeometryProcessing`.
- Put `UCLASS`es derived from plugin classes (Screen, page base class) into a category A module. If the project has a Server Target or platforms other than Win64, make this module and the plugin modules take part in the build only under the same conditions: use `"Type": "ClientOnly"` or `"TargetDenyList": ["Server"]` in the module descriptor and add `"PlatformAllowList": ["Win64"]`; if the host's existing UI modules are isolated in another way, follow that approach, and treat a successful compile of the Server Target as the standard. Reflected types cannot be wrapped in a custom macro, so do not use `#if` to hide Screen classes in a module that the Server can reach.
- In a category B module, write the plugin header includes and calls entirely inside the host macro; **keep a valid empty path outside the macro for public functions exposed to other code** (the function exists, can be called, and does nothing when there is no Browser), so callers do not write the macro; do not declare `UPROPERTY`s of plugin types. After a module boundary or macro changes, compile the Server Target as well.
- The plugin publishes `ORIONWEBUI_WITH_BROWSER`, `ORIONWEBUIWIDGET_WITH_BROWSER` and `ORIONWEBUICOMMONUI_WITH_BROWSER` under the same condition. When rendering is not possible (`FApp::CanEverRender()` is false) or `-nocef` is given, `UOrionInstantScreenSubsystem` does not create a Runtime, `ShowScreen` returns empty, and `UOrionInstantScreenActivatableWidget` deactivates itself after activation. The host must tolerate an empty Endpoint / empty Widget and must not assert.

## Assets and classes

| Asset / class | Module · parent class | Configuration notes |
| --- | --- | --- |
| `UOrionWebUIAppDefinition` | `OrionWebUI` · `UPrimaryDataAsset` | `AppId`, `EntryHtml`, `InitialRoute`, plus the references to the Manifests below and the browser parameters |
| `UOrionWebUITextCatalog` | `OrionWebUI` · `UDataAsset` | `Texts`: `TMap<FName, FText>` |
| `UOrionWebUIAssetManifest` | `OrionWebUI` · `UDataAsset` | `Entries`: `StableId` + `SourceTexture` / `SourceMaterial` |
| `UOrionWebUISoundManifest` | `OrionWebUI` · `UDataAsset` | `Entries`: `StableId` + `Sound`, `ConcurrencySettings`, volume and pitch |
| `UOrionWebUIFontManifest` | `OrionWebUI` · `UPrimaryDataAsset` | `Entries`, `CultureFonts`, `FontPolicy`, `DefaultFontFamilyOrder`; the project-level entry is `UOrionWebUIFontSettings.SystemFontManifest`, and leaving `FontManifest` of the AppDefinition empty inherits it |
| `UOrionWebUIInputManifest` | `OrionWebUICommonUI` · `UDataAsset` | `Actions`: `ActionId` + `InputAction` / `LegacyInputAction` |
| `UOrionInstantScreenDefinition`, `UOrionInstantScreenCatalog`, `UOrionInstantScreenRuntimeProfile` | `OrionWebUI` · `UPrimaryDataAsset` | Needed only for the InstantScreen form |
| Widget Blueprint | Parent class: see the next section | Place a host control named `WebUI` in the designer; configure `ControlSoundPolicy` in Class Defaults |

- **Three identical names**: `AppDefinition.AppId` = directory name `<WebUIRoot>/<AppId>` = `orionWebUI.appId` in the frontend `package.json`. At runtime the `dist` is read by AppId from `<ProjectRoot>/Content/UI/WebUI/<AppId>/dist`, and only if it is not found does it fall back to `<OrionBrowser>/Content/UI/WebUI/<AppId>/dist`. This root directory is hard-coded in the plugin (`OrionWebUI.Build.cs` also registers the `dist` of each App as a runtime dependency based on it) and cannot be moved elsewhere.
- The production entry is fixed as `https://orion-webui.local/<AppId>/index.html` (`GetProductionURL()`), and the initial route is appended as `#/<Route>`; `file://` is not used at runtime. Several Widgets can share one AppDefinition.
- Same-origin resources: `/<AppId>/assets/...` comes from dist; `/<AppId>/ue/localization.json`, `/ue/assets/manifest.json`, `/ue/assets/<StableId>`, `/ue/sounds/manifest.json`, `/ue/fonts/orion-fonts.css` and `/ue/fonts/<StableId>` are generated from the AppDefinition snapshot; `/<AppId>/instant/routes/<Route>/<Payload>` serves only packages registered in the Catalog.
- Top-level navigation is allowed only under the current App prefix; any other navigation is blocked and reported through `OnWebError` as `Blocked Orion WebUI top-level navigation: <url>`.

## Choosing the parent class

| Form | What to do | When to choose it |
| --- | --- | --- |
| Plain Widget | Place an `Orion WebUI` control (`UOrionWebUIWidget`) in any Widget Blueprint and bind `OnWebReady` / `OnWebEvent` / `OnWebRequest`, or derive from it and override `HandleWebEvent` / `HandleWebRequest` | You only replace a UMG area with Web rendering, and it does not enter the page stack |
| CommonUI page | The WBP parent class is the host C++ Screen (derived from `UOrionWebUIActivatableWidget`); the child control `WebUI` is a `UOrionWebUIWidget` with the variable checked; configure `AppDefinition` and `InputManifest` | The page enters the CommonUI layer stack and needs input mode, Back and action routing; it owns one Browser exclusively |
| InstantScreen page within a layer | The Screen derives from `UOrionInstantScreenActivatableWidget`, and the child control `WebUI` is a `UOrionInstantScreenWidget`; configure `ScreenDefinition` | Several pages on the same layer share one resident Runtime Browser and need a first-frame package or resident documents; for details see [InstantScreen](instant-screen.en.md) |

## Key properties and the DOM interaction policy

`UOrionWebUIAppDefinition` (only the properties that change an integration decision):

- `BridgeReadyTimeoutSeconds` (handshake) and `BridgeCallTimeoutSeconds` (business calls, deferred responses) are independent of each other: if cold start is slow, adjust only the former, and do not enlarge the latter. `MaxQueuedBridgeMessages` is the bounded queue before Ready.
- Keep `CursorPolicy` at `GameControlled`; keep `ViewportSizingMode` at `SlateLogicalSize` (UMG scaling does not trigger a web reflow); `BrowserFrameRate=0` and `BrowserRenderScale=0` mean the global policy is used.
- `AllowedFrameOrigins` / `AllowedImageOrigins` / `AllowedMediaOrigins`: allow exact origins for iframes, images, and audio and video respectively; all are empty by default; enter only the origin, not a path, and do not use wildcards.
- `bSupportsTransparency`, `bRetainBrowserSessionAcrossSlateRebuilds` (keeps the loaded document when a pooled Widget rebuilds its Slate), `bAllowWebSoundPlayback`, `bPreloadSoundsOnLoad`, `RequiredApiVersion`; and the Editor-only `bUseDevServerInEditor` / `DevServerUrl` (designer preview only) and `bAutoReloadLocalDistInEditor`.

`UOrionWebUIWidget`: `AppDefinition`, `InitialRouteOverride`, `bLoadOnConstruct` (when turned off, the app loads only on an explicit `LoadApp()`, and this load is restored after a Slate rebuild), `bAutoResolveUnhandledRequests`, `NativeSurfaceBindings`, `bShowDesignTimePreview`, `DesignTimeControlIdPreviewMode`.

The DOM interaction policy is injected uniformly by the host control when a document loads and when a session is restored; the page must not add `user-select: none` itself: text selection is disabled by default; `input`, `textarea`, a valid `contenteditable`, `data-orion-user-select="text"` and `data-orion-user-select="all"` can still be selected. The inside of a cross-origin iframe is governed by its own styles.

## Presenter contract

1. The Web sends only typed Intents and acknowledgements and does not hold business success. The C++ entry point revalidates availability, permission, platform and network with the **current** Native state, and then calls the business authority (Subsystem, server RPC).
2. Business results drive the publication of the **full** retained state through business callbacks, not incremental patches; the Web overwrites with the whole snapshot.
3. Each business state stream has its own monotonically increasing `stateRevision`, allocated a new value only when the semantic content really changes, and it does not share a variable with `presentationRevision`. The presentation revision must come from `UOrionInstantScreenEndpoint::AllocateRevision()` (`UOrionWebUIWidget::AllocatePresentationRevision()` uses the same sequence): if the standard presentation, covering and restoring each create their own counter, the restore sequence number can be smaller than the first presentation's sequence number and the Web discards it as a stale event. It is recommended to use it for the state revision too, so that it stays monotonic across Screen instances and Widget pool reuse.
4. A Web ACK only releases a transport slot or stops retrying; it does not change Native success, failure or rollback; Native does not wait for an ACK before executing or committing business.
5. Each activation uses a new `presentationRevision` (the two CommonUI base classes allocate it in `RequestStandardWebUIPresentation()` on activation). Restoring from covered only advances the presentation revision and keeps the business state and route; if the content has not changed, no new `stateRevision` is allocated.
6. After a real activation, a document reload, or an Endpoint replacement, rebuild and publish the snapshot from the current authoritative data; if the content has not changed, reuse the original revision.
7. When the business data (Descriptor, Provider snapshot) is invalid, return directly and do not send an empty placeholder: an empty snapshot satisfies the state gate and shows an empty page.

## Event entry points and publishing API

| Purpose | `UOrionWebUIWidget` | `UOrionInstantScreenEndpoint` |
| --- | --- | --- |
| Ready / presented | `OnWebReady`, `OnWebLocalResourcesReady` | `OnReady`, `OnLocalResourcesReady`, `OnDistinctVisualPresented` |
| Web → UE notification | `OnWebEvent` / `HandleWebEvent` | `OnEvent` |
| Web → UE request | `OnWebRequest` / `HandleWebRequest` | `OnRequest` (`requestIntent()` also arrives here) |
| Error | `OnWebError` | `OnError` (an invalid Endpoint is a terminal state; a Presenter that holds the Endpoint directly must bind it) |
| One-time event | `PostEventToWeb` | `SendEvent` / `PostEventToWeb` |
| Keep only the latest / retain and replay to late-registered listeners | `PostLatestEventToWeb` / `PostRetainedLatestEventToWeb` | Same name |
| Authoritative snapshot (one in flight + one pending) | `PostFlowControlledLatestEventToWeb` | `PushState` first, then `PostFlowControlledLatestEventToWeb` |
| Reliable retry until the exact ACK | `PostReliableRetainedLatestEventToWeb` | Same name |
| Presentation transaction (a new frame must be certified after the ACK) | `PostReliablePresentationEventToWeb` | Same name; `RequestStandardPresentation()` is its standard wrapper; when a page-defined custom event name is used as the presentation request, use `PostReliablePresentationRequestToWeb` instead |
| Query certification | `IsReliablePresentationFrameCertified(Ack, Revision)` | Same name, plus `OnReliablePresentationFrameCertified` |
| Cancel | `CancelFlowControlledLatestEvent`, `CancelReliableRetainedLatestEvent` and the matching `CancelAll…` | Same name |
| UE calls Web | `CallWeb` → `OnWebCallCompleted`; `CancelWebCall` | `CallWeb`, `CancelWebCall` |

The two CommonUI base classes combine the delegates above into the overridable `HandleWebUIReady`, `HandleWebUIEvent`, `HandleWebUIRequest`, `HandleWebUIRouteChanged`, `HandleCommonAction` and `HandleWebUIBackAction` (all `BlueprintNativeEvent`s), and the virtual function `HandleWebUILocalResourcesReady`.

- `PostFlowControlledLatestEventToWeb(EventName, PayloadJson, AcknowledgementEventName, RevisionFieldName, Revision, PresentationRevision = 0)`: the same acknowledgement name is one stream, with at most one in flight and one replaceable latest value at a time; on the same Widget / Endpoint, a call whose `Revision` is not greater than the published value is ignored; one acknowledgement name cannot also be bound to another event or to reliable delivery. The Endpoint version has two more parameters: `bRequirePresentationFrame=false` is for replaceable coordinates that only need the acknowledgement to be received (in this case `PresentationRevision` must be 0), and `bDeferDispatch` is used together with `FlushFlowControlledLatestEvent`.
- `PushState(StateJson, StateRevision)`: the Runtime state channel, which decides the state gate before the page becomes visible. A revision smaller than the current value returns false; the same revision with different content reports `StateRevision=<n> was reused with different snapshot content` through `OnError`; the same revision with the same content is replayed.
- `UOrionWebUIWidget` keeps the flow-controlled snapshot itself and replays it when a new document is Ready and each time it enters `Preparing`; the delivery table of the Endpoint is cleared when a Screen instance is created, so for InstantScreen the Presenter must push again on every real activation.
- **Lifecycle and transport acknowledgements are handled at the very start of the event entry point and returned**, and do not enter business Intent dispatch. `webUI.presentationReady` is always forwarded to `HandleWebUIEvent`; `webUI.presentationApplied` is forwarded on the plain Widget path; flow-control acknowledgements (such as `samplePanel.stateApplied`) are forwarded on the Endpoint path.
- A request entry point must call `ResolveJson()` / `Reject()` before it returns, or call `Defer()` first and respond asynchronously. When neither is done: the plain Widget path replies `{}` or `E_UNHANDLED` according to `bAutoResolveUnhandledRequests`, and a business request on InstantScreen replies `E_INSTANT_INTENT_RESULT_MISSING`; after `Defer()`, a request that is not answered within `BridgeCallTimeoutSeconds` ends with `E_TIMEOUT`.

## Minimal skeleton (CommonUI page)

```cpp
// SamplePanelScreen.h
#pragma once

#include "OrionWebUIActivatableWidget.h"

#include "SamplePanelScreen.generated.h"

class FJsonObject;

/** CommonUI host and Presenter of the sample panel: revalidates Intents, calls the business authority, and publishes the full snapshot. */
UCLASS(Abstract, Blueprintable)
class SAMPLEUI_API USamplePanelScreen : public UOrionWebUIActivatableWidget
{
	GENERATED_BODY()

	// CommonUI activation and WebUI event entry points
protected:
	virtual void NativeOnActivated() override;
	virtual void HandleWebUIReady_Implementation() override;
	virtual void HandleWebUIEvent_Implementation(FName EventName, const FString& PayloadJson) override;

	// Native interface of the fixed button
protected:
	UFUNCTION(BlueprintNativeEvent, Category="Sample Panel|Button")
	void OnSamplePanelConfirmButtonClicked();

	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="Sample Panel|Button")
	bool bConfirmButtonEnabled = true;

	// Authoritative state publication
private:
	bool HasValidModel() const;
	TSharedRef<FJsonObject> BuildStateObject() const;
	void PublishState(bool bForceRepublish);

private:
	FString PublishedSemanticStateJson;
	int64 StateRevision = 0;
};

// SamplePanelScreen.cpp (also needs these includes: Dom/JsonObject.h, Serialization/JsonSerializer.h, Policies/CondensedJsonPrintPolicy.h, OrionWebUIWidget.h, OrionInstantScreenEndpoint.h)
namespace SamplePanel
{
	static const FName StateChangedEvent(TEXT("ue:samplePanel.stateChanged"));
	static const FName StateAppliedEvent(TEXT("samplePanel.stateApplied"));
	static const FName ConfirmRequestedEvent(TEXT("samplePanel.confirmRequested"));
	static const FName StateRevisionField(TEXT("stateRevision"));

	static FString ToJson(const TSharedRef<FJsonObject>& Object)
	{
		FString Json;
		FJsonSerializer::Serialize(Object, TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&Json));
		return Json;
	}
}

void USamplePanelScreen::NativeOnActivated()
{
	Super::NativeOnActivated();	// Loads the App, registers actions, and allocates the presentationRevision of this activation
	// Bind the change delegate of the business authority here (call PublishState(false) in the callback), and unbind it symmetrically in NativeOnDeactivated
	PublishState(true);	// Business may have changed while deactivated: rebuild from the current data
}

void USamplePanelScreen::HandleWebUIReady_Implementation()
{
	Super::HandleWebUIReady_Implementation();
	PublishState(true);
}

void USamplePanelScreen::HandleWebUIEvent_Implementation(FName EventName, const FString& PayloadJson)
{
	// 1. Lifecycle and transport acknowledgements: return first, do not enter business dispatch
	if (EventName == StandardPresentationReadyEventName
		|| EventName == StandardPresentationAppliedEventName
		|| EventName == SamplePanel::StateAppliedEvent)
	{
		return;
	}

	// 2. Typed Intent: put the guard at the dispatch site so a Blueprint override cannot bypass it
	if (EventName == SamplePanel::ConfirmRequestedEvent)
	{
		if (!bConfirmButtonEnabled || !HasValidModel())
		{
			PublishState(true);	// On rejection, push the authoritative state back to correct the stale availability in the Web
			return;
		}
		OnSamplePanelConfirmButtonClicked();
	}
}

void USamplePanelScreen::OnSamplePanelConfirmButtonClicked_Implementation()
{
	// Call the business authority; success or failure drives PublishState(false) through the business callback, without waiting for a Web ACK
}

void USamplePanelScreen::PublishState(bool bForceRepublish)
{
	UOrionWebUIWidget* Host = GetWebUIWidget();
	if (!Host || !HasValidModel())
	{
		return;	// Invalid data: do not send an empty placeholder; the business callback enters again when the data arrives
	}

	const TSharedRef<FJsonObject> State = BuildStateObject();	// Full snapshot, without the revision
	const FString SemanticJson = SamplePanel::ToJson(State);
	const bool bChanged = !SemanticJson.Equals(PublishedSemanticStateJson, ESearchCase::CaseSensitive);
	if (!bChanged && !bForceRepublish)
	{
		return;
	}
	if (bChanged || StateRevision <= 0)
	{
		StateRevision = UOrionInstantScreenEndpoint::AllocateRevision();
		PublishedSemanticStateJson = SemanticJson;
	}

	State->SetNumberField(SamplePanel::StateRevisionField.ToString(), static_cast<double>(StateRevision));
	Host->PostFlowControlledLatestEventToWeb(
		SamplePanel::StateChangedEvent,
		SamplePanel::ToJson(State),
		SamplePanel::StateAppliedEvent,
		SamplePanel::StateRevisionField,
		StateRevision);
}
```

When switching to an InstantScreen parent class:

| Skeleton code | Change to |
| --- | --- |
| `GetWebUIWidget()` | `GetInstantScreenEndpoint()`; check it for null before use and check `IsValidEndpoint()` |
| Sends only business events | First `PushState(PayloadJson, StateRevision)`; if it returns true, send the same `PostFlowControlledLatestEventToWeb` |
| First-frame state | Override `BuildInitialInstantScreenState(OutInitialStateJson, OutStateRevision)` and provide the same snapshot and revision |
| Business buttons go through `HandleWebUIEvent` | The Web uses `requestIntent()`; override `HandleWebUIRequest_Implementation`, and after revalidation you must call `Response->ResolveIntent(Request.Id, EOrionWebUIIntentStatus::Completed / Accepted / Rejected, Code, Authority, OperationId, Message)`; `Accepted` must carry `Authority` |
| Release on deactivation | When residency is needed, override `ShouldKeepInstantScreenOnDeactivation()` and the two `Should…StandardWebUIPresentation…`; when the Endpoint is retained, `HandleWebUIReady` is not sent again, so push again in `NativeOnActivated` |

For asynchronous business (for example sending a Server RPC) whose result is not available inside the call, reply `Accepted` immediately and let the authoritative snapshot give the final result; not returning a result is rejected with `E_INSTANT_INTENT_RESULT_MISSING`, and this shows up only on remote clients.

## Native interfaces of fixed buttons

- Each fixed button known at compile time has its own `BlueprintNativeEvent`, one enable property or enable check, and one disabled guard written at the C++ dispatch site; the default business logic goes in `_Implementation`. Do not use one generic entry point with a string parameter to carry all buttons. The enabled state is published to the Web for rendering with the full snapshot; disabling in the Web is only presentation.
- Dynamic items (list rows, data-driven buttons) share one event with typed parameters; C++ resolves and validates the business ID in the payload against the current authoritative data, and rejects it if resolution fails.
- When modifying an existing Screen, keep the Blueprint overrides the user already has: do not rename, do not change signatures, and do not delete events that the WBP already overrides; an override that must keep the default business logic has to call the Parent Function.
- For the button contract file, `data-orion-control-id` and the sound policy see [Controls and resources](controls-resources.en.md).

## CommonUI integration

- A page is pushed only through the host's CommonUI layer stack, never with `AddToViewport` directly. The two base classes set `bIsBackHandler` to true in their constructors.
- Input mode: `UOrionWebUIActivatableWidget.InputConfig` (`Default` / `GameAndMenu` / `Game` / `Menu`) and `GameMouseCaptureMode`; InstantScreen takes `ScreenDefinition.InputPolicy` (`Passthrough` / `Game` / `GameAndMenu` / `Menu` / `Modal`), which a page can override with `InputPolicyOverride` + `bOverrideDefinitionInputPolicy`.
- Actions: `InputManifest.Actions` are registered in the activation tree of this page; when triggered, they push `ue:commonAction` (or the entry's `WebEventName`) to the Web, broadcast `OnCommonAction`, and call `HandleCommonAction`, in that order. **Choose only one business entry point for the same action**: if a DOM click in the Web also sends a business Intent, C++ must not execute it again in `HandleCommonAction`, otherwise one key press triggers the business twice. Actions that are not `bPersistent` no longer trigger after the page is deactivated.
- Back: `bForwardBackActionToWeb` pushes `ue:backAction` first; `HandleWebUIBackAction()` returning true means it has been consumed; otherwise, according to `bDeactivateOnBackAction`, the default close is run or the input is only swallowed. An entry in `InputManifest` that equals the default Back is not registered again. Confirm is configured as a normal action.
- Input devices: on activation and after Ready, `ue:inputModeChanged` and the full `ue:inputPromptsChanged` are pushed again; the device-switch and ActionBar delegates are bound only while active. Icons are resolved from the CommonInput brush in the order `AssetManifest` → the entry's `Glyphs` → `keyDisplayName` text.
- Focus: a plain page focuses the `WebUI` control by default; InstantScreen follows `FocusPolicy` (with `Automatic`, `Menu` / `Modal` / `GameAndMenu` focus the WebUI and the others return to the game viewport), which can be overridden with `FocusPolicyOverride` + `bOverrideDefinitionFocusPolicy`. A host base class that creates its slots dynamically must put the child control named `WebUI` into the WidgetTree before calling the base class `NativeConstruct()`, otherwise no focus target is available.
- Pointer: the InstantScreen proxy page itself is forced to `SelfHitTestInvisible` and the slot to `HitTestInvisible`, and the pointer is received by the Runtime Host; do not change their Visibility in order to receive the mouse.
- Covering and restoring: on deactivation the base class revokes the sound policy, unbinds the input delegates, and sends `ue:webUI.presentationSuspended`. When a resident page is temporarily covered, the document, business state and route are kept; on restore, focus and input are regained only after the presentation transaction with a new `presentationRevision` has completed, and a late acknowledgement of an old revision must not restore a wrong page. When a Native request such as exit must be started immediately after a restore, first wait until `IsReliablePresentationFrameCertified` holds.

## Localization

- The text source is the `FText` in `UOrionWebUITextCatalog.Texts`; Keys use stable dot-separated English (such as `samplePanel.confirm`); the Web references only the Key. Dynamic business text is generated in C++ as `FText` and put into the state snapshot.
- When the text revision changes (language switch, localization resource update), the host control regenerates the text table and font styles and pushes `ue:localeChanged`; it is merged by latest value together with `ue:inputModeChanged` and `ue:inputPromptsChanged`.
- The page replaces text on the **same semantic node**; it does not list hard-coded multiple languages side by side and does not switch language by reloading the page.

## Hard limits on threads and lifecycle

- CEF callback threads copy only plain values; UObject, Slate and Gameplay operations return to the game thread. The delegates and `Handle*` entry points in this document are all triggered on the game thread, and a Presenter must not move them to another thread. The plugin already queues Web calls that arrive during PostLoad to a safe Tick; pages and Presenters must not add a similar patch themselves.
- Do not use fixed delays, forced Flush / Fence, repeated `ReloadApp()` or Browser rebuilds to hide races in Ready, first frame, Native Surface or exit; wait with readiness delegates and certification queries.
- The Generation and Revision of Browser / Document / Surface / State / Presentation must match exactly; an old document, a late frame or a late ACK must not advance the current transaction. Code that stores an Endpoint checks `IsValidEndpoint()` before every use.
- Delegates, Timers, Ticker handles, async load handles and response handles that were `Defer()`red must all be cleaned up symmetrically; cover activation / deactivation, Travel, World destruction, Widget pool reuse and repeated entry.
- Do not create a Browser per Actor: world-space UI registers with `UOrionWebUIWorldElementComponent` into the overlay shared by each LocalPlayer. Also do not add page-specific global managers, hidden WBPs, page pools or background prewarm Browsers; a Browser is created only by a real presentation request (`AcquireRuntimeLease` is deprecated).

## Performance and frame rate

- Keep `BrowserFrameRate` at 0: the frame rate is driven by `bUseAdaptiveFrameRate` under `[OrionBrowser]` in `DefaultEngine.ini`; do not set a fixed cap on a single page.
- `BrowserRenderScale` only increases pixel cost and does not change the CSS layout size: a static menu can raise it (limited by `[OrionBrowser] MaxWebUIRenderScale`), while pages with high-frequency animation or video keep it at 1.0; do not use a scale below 1 to gain frame rate.
- High-frequency data goes through `PostFlowControlledLatestEventToWeb`, not `PostEventToWeb` every frame; continuously changing images (SceneCapture, Media) go through Native Surface, and icons and avatars go through Runtime Image; do not pass pixels through the Bridge.
- A covered page should enter `CoveredSuspended` and stop producing frames; rAF and polling on the Web side must also stop.

## Provided by the plugin / supplied by the host

The plugin provides: the classes of the modules above, the Scheme and resource endpoints, Bridge injection, the presentation transaction and certification, input action routing, the shared runtime and scripts under `<OrionBrowser>/Content/UI/WebUI/Shared`, and `<OrionBrowser>/Content/UI/WebUI/Sample`.

The host project must supply:

- **A common page base class** (recommended): on top of the two CommonUI base classes, a unified publishing wrapper for "semantic de-duplication + revision allocation + `PushState` + flow-controlled event", an Intent result wrapper (`ResolveIntent`), lifecycle acknowledgement filtering, telemetry and close policy. `PublishState` in the skeleton is its minimal form. Put it in a category A client UI module; keep the business authority in the gameplay or backend adapter module, and have the Screen call only its public interface.
- **Root layout and layer stack**: the CommonUI layer container, the layer GameplayTags, and the entry points that push and pop pages. The host defines and registers its layer Tags and maps them to Runtimes in the Catalog RuntimeProfile; the plugin installs no default layer mappings.
- **Placement of the Runtime Host and Catalog registration**: put `UOrionInstantScreenRuntimeHost` in the root layout, and call `UOrionInstantScreenSubsystem::RegisterCatalog` / `UnregisterCatalog` within a suitable owner lifecycle; when registering per gameplay module, write your own GameFeature Action (the plugin has none).
- **Cover / restore orchestration**: record the covered page, decide whether a temporary page has really left the stack, and send `ue:webUI.presentationCovered` / `ue:webUI.presentationRestored`. The Web lifecycle of the template already listens to these two events; the Native sender is not in the plugin.
- The integration of **LoadingScreen and HUD suppression**, the popup queue, the shared frontend component library, and the button contract check script.

## Common problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| The page is blank | The three AppId names differ, `dist` was not built, or `EntryHtml` is wrong; files are missing after packaging | Check that the three names are identical and rebuild the frontend; `dist` is registered as a runtime dependency during the Target build, so produce `dist` first and then build and package; see [Build and validation](build-validation.en.md) |
| The page is transparent but holds input | The revisions of presentation events come from several counters, and a restore sequence number that goes backwards is discarded by the Web | Use `AllocateRevision()` uniformly |
| `StateRevision=<n> was reused with different snapshot content` | The content changed but the revision was reused | Compare semantically before allocating a revision |
| `acknowledgement … is already owned by event …` | Two streams share one acknowledgement name | Use a separate acknowledgement event name for each stream |
| `E_INSTANT_REQUEST_UNHANDLED` / `E_INSTANT_INTENT_RESULT_MISSING` | `HandleWebUIRequest` was not overridden, or after handling there was no result and no `Defer()` | Call `ResolveIntent` / `Reject` in every branch |
| `E_INSTANT_INTENT_SCOPE` / `E_INSTANT_INTENT_AUTHORITY` | The request comes from an old document / old instance, or the page has not yet obtained input ownership of the current presentation | This is a normal rejection; do not loosen the validation; check whether clicks were allowed before the presentation completed |
| External iframes, images, audio or video are blocked by CSP | `AllowedFrameOrigins` / `AllowedImageOrigins` / `AllowedMediaOrigins` are not configured | Fill in the exact origin for each and reload; the three do not allow each other; the target site's own `X-Frame-Options` / `frame-ancestors` may still forbid embedding |
| Layouts overlap or scrollbars appear after scaling | The page reflows responsively by physical pixels | Keep `SlateLogicalSize`, and have the page scale a fixed-design-resolution stage as a whole; see [Web App scaffold](web-app-scaffold.en.md) |
