# UE 侧宿主：资产、Widget、Presenter 与事件入口

给一个新界面接上 Unreal 宿主：依赖哪些模块、建哪些资产、选哪个父类、C++ 怎样收 Intent 和发状态。Web 侧 API 见 [Bridge 与生命周期](bridge-lifecycle.zh-CN.md)；首帧包、Catalog、Runtime Host 见 [InstantScreen](instant-screen.zh-CN.md)；按钮合同文件、声音、字体、图片、Native Surface 见 [控件与资源](controls-resources.zh-CN.md)。类名与签名以 `<OrionBrowser>/Source/*/Public` 头文件为准，写代码前先读对应头文件。

## 模块与依赖

事实源：`<OrionBrowser>/OrionBrowser.uplugin` 与各模块 `*.Build.cs`。所有模块只允许 Win64。

| 模块 | Server | 职责 | 宿主何时依赖 |
| --- | --- | --- | --- |
| `OrionWebUI` | 禁用 | DataAsset 类型（AppDefinition、各 Manifest、InstantScreen Definition / Catalog）、`UOrionWebUIResponseHandle`、本地 Scheme 与资源注册 `IOrionWebUIModule` | 引用这些类型的模块 |
| `OrionWebUIWidget` | 禁用 | `UOrionWebUIWidget`、`UOrionInstantScreenWidget`、`UOrionInstantScreenRuntimeHost`、`UOrionInstantScreenEndpoint`、`UOrionInstantScreenSubsystem` | 持有 Widget / Endpoint 的 UI 与 Presenter 模块 |
| `OrionWebUICommonUI` | 禁用 | `UOrionWebUIActivatableWidget`、`UOrionInstantScreenActivatableWidget`、`UOrionWebUIInputManifest` | CommonUI 页面模块 |
| `OrionWebUIRuntimeImage` | 禁用 | `UTexture2D` / 像素 → 进程内图片 URL | 直接使用其类型时 |
| `OrionWebUIWorld` | **允许** | 纯数据的 `UOrionWebUIWorldElementComponent`、`UOrionWebUIWorldElementDefinition` 与 World 注册表 | 在 Actor 上挂世界 UI 锚点的玩法模块 |
| `OrionWebUIWorldWidget` | 禁用 | `UOrionWebUIWorldOverlayHost`、每个 LocalPlayer 一份的 `UOrionWebUIWorldSubsystem` | 承载世界 UI 覆盖层的 UI 模块 |
| `OrionBrowser`、`OrionBrowserWidget` | 禁用 | CEF 运行时、`SOrionBrowser`、通用网页控件 `UOrionBrowserWidget` | WebUI 界面不必直接依赖（`OrionWebUI` 已公开传递 `OrionBrowser`） |
| `OrionWebUIRender`、`OrionCEF3Utils`、`OrionBrowserHelper` | 禁用 | 渲染后端、CEF 加载、CEF 子进程 | 不依赖 |
| `OrionWebUIEditor` | 仅 Editor | `UOrionWebUIEditorLibrary`（校验、导出） | 仅宿主 Editor 模块 |

```csharp
// A. 只在客户端构建的 UI 模块：直接依赖
PublicDependencyModuleNames.AddRange(new string[] { "CommonUI", "OrionWebUI", "OrionWebUICommonUI", "OrionWebUIWidget", "UMG" });
PrivateDependencyModuleNames.AddRange(new string[] { "Json" });

// B. Server 也会编译的模块：条件依赖 + 宿主自己的宏
bool bWithOrionWebUI = Target.Platform == UnrealTargetPlatform.Win64 && Target.Type != TargetType.Server;
if (bWithOrionWebUI)
{
	PrivateDependencyModuleNames.AddRange(new string[] { "OrionWebUI", "OrionWebUIWidget" });
}
PublicDefinitions.Add("SAMPLEGAME_WITH_ORION_WEBUI=" + (bWithOrionWebUI ? "1" : "0"));
```

- 宿主 `.uproject`（或承载界面的宿主插件 `.uplugin`）启用 `OrionBrowser`；它自己声明依赖 `CommonUI` 与 `GeometryProcessing`。
- 派生自插件类的 `UCLASS`（Screen、页面基类）放进 A 类模块。工程有 Server Target 或 Win64 之外的平台时，让这个模块和插件模块在同样的条件下才参与构建：模块描述符用 `"Type": "ClientOnly"` 或 `"TargetDenyList": ["Server"]`，并加 `"PlatformAllowList": ["Win64"]`；宿主已有 UI 模块按别的方式隔离时沿用它的做法，并以 Server Target 实际编译通过为准。反射类型不能包进自定义宏，不要用 `#if` 在 Server 可达模块里藏 Screen 类。
- B 类模块里，插件头文件的 include 与调用全部写在宿主宏内；**对外的公共函数在宏外保留合法空路径**（函数存在、可调用、没有 Browser 时什么都不做），调用方不写宏；不声明插件类型的 `UPROPERTY`。模块边界或宏变化后 Server Target 也要编译。
- 插件按同一条件发布 `ORIONWEBUI_WITH_BROWSER`、`ORIONWEBUIWIDGET_WITH_BROWSER`、`ORIONWEBUICOMMONUI_WITH_BROWSER`。不能渲染（`FApp::CanEverRender()` 为假）或带 `-nocef` 时，`UOrionInstantScreenSubsystem` 不创建 Runtime、`ShowScreen` 返回空，`UOrionInstantScreenActivatableWidget` 激活后自行失活。宿主必须容忍空 Endpoint / 空 Widget，不能断言。

## 资产与类

| 资产 / 类 | 模块 · 父类 | 配置要点 |
| --- | --- | --- |
| `UOrionWebUIAppDefinition` | `OrionWebUI` · `UPrimaryDataAsset` | `AppId`、`EntryHtml`、`InitialRoute`，以及下列 Manifest 的引用和浏览器参数 |
| `UOrionWebUITextCatalog` | `OrionWebUI` · `UDataAsset` | `Texts`：`TMap<FName, FText>` |
| `UOrionWebUIAssetManifest` | `OrionWebUI` · `UDataAsset` | `Entries`：`StableId` + `SourceTexture` / `SourceMaterial` |
| `UOrionWebUISoundManifest` | `OrionWebUI` · `UDataAsset` | `Entries`：`StableId` + `Sound`、`ConcurrencySettings`、音量音高 |
| `UOrionWebUIFontManifest` | `OrionWebUI` · `UPrimaryDataAsset` | `Entries`、`CultureFonts`、`FontPolicy`、`DefaultFontFamilyOrder`；项目级入口是 `UOrionWebUIFontSettings.SystemFontManifest`，AppDefinition 的 `FontManifest` 留空即继承 |
| `UOrionWebUIInputManifest` | `OrionWebUICommonUI` · `UDataAsset` | `Actions`：`ActionId` + `InputAction` / `LegacyInputAction` |
| `UOrionInstantScreenDefinition`、`UOrionInstantScreenCatalog`、`UOrionInstantScreenRuntimeProfile` | `OrionWebUI` · `UPrimaryDataAsset` | 仅 InstantScreen 形态需要 |
| Widget Blueprint | 父类见下节 | 设计器里放一个名为 `WebUI` 的宿主控件；`ControlSoundPolicy` 在 Class Defaults 配置 |

- **三处同名**：`AppDefinition.AppId` = 目录名 `<WebUIRoot>/<AppId>` = 前端 `package.json` 的 `orionWebUI.appId`。运行时按 AppId 读取 `<ProjectRoot>/Content/UI/WebUI/<AppId>/dist`，找不到才回退到 `<OrionBrowser>/Content/UI/WebUI/<AppId>/dist`。这个根目录写死在插件里（`OrionWebUI.Build.cs` 也按它把各 App 的 `dist` 登记为运行时依赖），不能挪到别处。
- 生产入口固定为 `https://orion-webui.local/<AppId>/index.html`（`GetProductionURL()`），初始路由拼成 `#/<Route>`；运行时不使用 `file://`。多个 Widget 可以共用同一个 AppDefinition。
- 同源资源：`/<AppId>/assets/...` 来自 dist；`/<AppId>/ue/localization.json`、`/ue/assets/manifest.json`、`/ue/assets/<StableId>`、`/ue/sounds/manifest.json`、`/ue/fonts/orion-fonts.css`、`/ue/fonts/<StableId>` 由 AppDefinition 快照生成；`/<AppId>/instant/routes/<Route>/<Payload>` 只提供 Catalog 已注册的包。
- 顶层导航只允许当前 App 前缀，其他跳转被拦截并通过 `OnWebError` 报 `Blocked Orion WebUI top-level navigation: <url>`。

## 父类选择

| 形态 | 做法 | 何时选 |
| --- | --- | --- |
| 普通 Widget | 任意 Widget Blueprint 里放 `Orion WebUI` 控件（`UOrionWebUIWidget`），绑定 `OnWebReady` / `OnWebEvent` / `OnWebRequest`，或派生后覆写 `HandleWebEvent` / `HandleWebRequest` | 只是把一块 UMG 区域换成 Web 渲染，不进页面栈 |
| CommonUI 页面 | WBP 父类选宿主 C++ Screen（派生自 `UOrionWebUIActivatableWidget`），子控件 `WebUI` 是 `UOrionWebUIWidget` 并勾选变量；配置 `AppDefinition`、`InputManifest` | 页面进 CommonUI 层栈，要输入模式、返回、动作路由；独占一个 Browser |
| InstantScreen 层内页面 | Screen 派生自 `UOrionInstantScreenActivatableWidget`，子控件 `WebUI` 是 `UOrionInstantScreenWidget`；配置 `ScreenDefinition` | 同层多个页面共用一个常驻 Runtime Browser、需要首帧包或驻留文档；细节见 [InstantScreen](instant-screen.zh-CN.md) |

## 关键属性与 DOM 交互策略

`UOrionWebUIAppDefinition`（只列会改变接入决策的）：

- `BridgeReadyTimeoutSeconds`（握手）与 `BridgeCallTimeoutSeconds`（业务调用、延迟响应）相互独立：冷启动慢只调前者，不要放大后者。`MaxQueuedBridgeMessages` 是 Ready 前的有界队列。
- `CursorPolicy` 保持 `GameControlled`；`ViewportSizingMode` 保持 `SlateLogicalSize`（UMG 缩放不触发网页重排）；`BrowserFrameRate=0`、`BrowserRenderScale=0` 表示沿用全局策略。
- `AllowedFrameOrigins` / `AllowedImageOrigins` / `AllowedMediaOrigins`：分别放行 iframe、图片、音视频的精确 origin，默认全空；只填 origin，不填路径，不用通配。
- `bSupportsTransparency`、`bRetainBrowserSessionAcrossSlateRebuilds`（池化 Widget 重建 Slate 时保留已加载文档）、`bAllowWebSoundPlayback`、`bPreloadSoundsOnLoad`、`RequiredApiVersion`；Editor 专用的 `bUseDevServerInEditor` / `DevServerUrl`（仅设计器预览）与 `bAutoReloadLocalDistInEditor`。

`UOrionWebUIWidget`：`AppDefinition`、`InitialRouteOverride`、`bLoadOnConstruct`（关闭后只有显式 `LoadApp()` 才加载，Slate 重建后会恢复这次加载）、`bAutoResolveUnhandledRequests`、`NativeSurfaceBindings`、`bShowDesignTimePreview`、`DesignTimeControlIdPreviewMode`。

DOM 交互策略由宿主控件在文档加载和会话恢复时统一注入，页面不要自己加 `user-select: none`：默认禁止文本选择；`input`、`textarea`、有效的 `contenteditable`、`data-orion-user-select="text"` 与 `data-orion-user-select="all"` 仍可选择。跨域 iframe 内部由它自己的样式负责。

## Presenter 合同

1. Web 只发类型化 Intent 和回执，不持有业务成功。C++ 入口用**当前** Native 状态复验可用性、权限、平台与网络，再调用业务权威（Subsystem、服务器 RPC）。
2. 业务结果由业务回调驱动发布**完整** retained state，不发增量补丁；Web 以整份快照覆盖。
3. 每个业务状态流有独立、单调递增的 `stateRevision`，只在语义内容真实变化时分配新值，与 `presentationRevision` 不共用变量。展示版本必须来自 `UOrionInstantScreenEndpoint::AllocateRevision()`（`UOrionWebUIWidget::AllocatePresentationRevision()` 走同一序列）：标准展示、覆盖、恢复各建计数器会让恢复序号小于首次展示序号，被 Web 当过期事件丢弃。状态版本建议也用它，跨 Screen 实例和 Widget 池复用仍保持单调。
4. Web ACK 只释放传输槽位或停止重试，不改变 Native 的成功、失败与回滚；Native 不等 ACK 才执行或提交业务。
5. 每次激活使用新的 `presentationRevision`（两个 CommonUI 基类激活时在 `RequestStandardWebUIPresentation()` 里分配）。覆盖恢复只推进展示版本并保留业务状态与路由，内容没变就不分配新 `stateRevision`。
6. 真实激活、文档重载、Endpoint 更换后都按当前权威数据重建并发布快照；内容没变就复用原 revision。
7. 业务数据（Descriptor、Provider 快照）无效时直接返回，不发空占位：空快照会满足状态门禁并把空页面展示出来。

## 事件入口与发布 API

| 用途 | `UOrionWebUIWidget` | `UOrionInstantScreenEndpoint` |
| --- | --- | --- |
| 就绪 / 已呈现 | `OnWebReady`、`OnWebLocalResourcesReady` | `OnReady`、`OnLocalResourcesReady`、`OnDistinctVisualPresented` |
| Web → UE 通知 | `OnWebEvent` / `HandleWebEvent` | `OnEvent` |
| Web → UE 请求 | `OnWebRequest` / `HandleWebRequest` | `OnRequest`（`requestIntent()` 也到这里） |
| 错误 | `OnWebError` | `OnError`（Endpoint 失效即终止态；直接持有 Endpoint 的 Presenter 必须绑定） |
| 一次性事件 | `PostEventToWeb` | `SendEvent` / `PostEventToWeb` |
| 只留最新 / 保留并向晚注册的监听重放 | `PostLatestEventToWeb` / `PostRetainedLatestEventToWeb` | 同名 |
| 权威快照（单在途 + 单待发） | `PostFlowControlledLatestEventToWeb` | 先 `PushState`，再 `PostFlowControlledLatestEventToWeb` |
| 可靠重试到精确 ACK | `PostReliableRetainedLatestEventToWeb` | 同名 |
| 展示事务（ACK 后还要新帧认证） | `PostReliablePresentationEventToWeb` | 同名；`RequestStandardPresentation()` 是其标准封装；用页面自定义事件名作展示请求时改用 `PostReliablePresentationRequestToWeb` |
| 查询认证 | `IsReliablePresentationFrameCertified(Ack, Revision)` | 同名，另有 `OnReliablePresentationFrameCertified` |
| 取消 | `CancelFlowControlledLatestEvent`、`CancelReliableRetainedLatestEvent` 及对应 `CancelAll…` | 同名 |
| UE 调 Web | `CallWeb` → `OnWebCallCompleted`；`CancelWebCall` | `CallWeb`、`CancelWebCall` |

两个 CommonUI 基类把上述委托汇成可覆写的 `HandleWebUIReady`、`HandleWebUIEvent`、`HandleWebUIRequest`、`HandleWebUIRouteChanged`、`HandleCommonAction`、`HandleWebUIBackAction`（均为 `BlueprintNativeEvent`）以及虚函数 `HandleWebUILocalResourcesReady`。

- `PostFlowControlledLatestEventToWeb(EventName, PayloadJson, AcknowledgementEventName, RevisionFieldName, Revision, PresentationRevision = 0)`：同一回执名是一条流，同时最多一个在途、一个可被替换的最新值；同一 Widget / Endpoint 上 `Revision` 不大于已发布值的调用被忽略；一个回执名不能再绑定别的事件或可靠投递。Endpoint 版本多两个参数：`bRequirePresentationFrame=false` 用于只需收到回执的可替换坐标（此时 `PresentationRevision` 必须为 0），`bDeferDispatch` 配合 `FlushFlowControlledLatestEvent`。
- `PushState(StateJson, StateRevision)`：Runtime 状态通道，决定页面可见前的状态门禁。revision 小于当前值返回 false；同一 revision 内容不同则经 `OnError` 报 `StateRevision=<n> was reused with different snapshot content`；同一 revision 同一内容会重放。
- `UOrionWebUIWidget` 自己保留流控快照，在新文档 Ready 与每次进入 `Preparing` 时重放；Endpoint 的投递表随 Screen 实例新建而清空，所以 InstantScreen 每次真实激活都必须由 Presenter 重推。
- **生命周期与传输回执在事件入口最前面处理并返回**，不进入业务 Intent 分发。`webUI.presentationReady` 一定会转发到 `HandleWebUIEvent`；`webUI.presentationApplied` 在普通 Widget 路径会转发；流控回执（如 `samplePanel.stateApplied`）在 Endpoint 路径会转发。
- 请求入口返回前必须 `ResolveJson()` / `Reject()`，或先 `Defer()` 再异步响应。两者都没做时：普通 Widget 路径按 `bAutoResolveUnhandledRequests` 回 `{}` 或 `E_UNHANDLED`，InstantScreen 的业务请求回 `E_INSTANT_INTENT_RESULT_MISSING`；`Defer()` 后超过 `BridgeCallTimeoutSeconds` 未响应以 `E_TIMEOUT` 结束。

## 最小骨架（CommonUI 页面）

```cpp
// SamplePanelScreen.h
#pragma once

#include "OrionWebUIActivatableWidget.h"

#include "SamplePanelScreen.generated.h"

class FJsonObject;

/** 示例面板的 CommonUI 宿主与 Presenter：复验 Intent、调用业务权威、发布完整快照。 */
UCLASS(Abstract, Blueprintable)
class SAMPLEUI_API USamplePanelScreen : public UOrionWebUIActivatableWidget
{
	GENERATED_BODY()

	// CommonUI 激活与 WebUI 事件入口
protected:
	virtual void NativeOnActivated() override;
	virtual void HandleWebUIReady_Implementation() override;
	virtual void HandleWebUIEvent_Implementation(FName EventName, const FString& PayloadJson) override;

	// 固定按钮 Native 接口
protected:
	UFUNCTION(BlueprintNativeEvent, Category="Sample Panel|Button")
	void OnSamplePanelConfirmButtonClicked();

	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="Sample Panel|Button")
	bool bConfirmButtonEnabled = true;

	// 权威状态发布
private:
	bool HasValidModel() const;
	TSharedRef<FJsonObject> BuildStateObject() const;
	void PublishState(bool bForceRepublish);

private:
	FString PublishedSemanticStateJson;
	int64 StateRevision = 0;
};

// SamplePanelScreen.cpp（另需 include：Dom/JsonObject.h、Serialization/JsonSerializer.h、Policies/CondensedJsonPrintPolicy.h、OrionWebUIWidget.h、OrionInstantScreenEndpoint.h）
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
	Super::NativeOnActivated();	// 加载 App、注册动作、分配本次激活的 presentationRevision
	// 在这里绑定业务权威的变化委托（回调里调用 PublishState(false)），并在 NativeOnDeactivated 对称解绑
	PublishState(true);	// 失活期间业务可能已变：按当前数据重建
}

void USamplePanelScreen::HandleWebUIReady_Implementation()
{
	Super::HandleWebUIReady_Implementation();
	PublishState(true);
}

void USamplePanelScreen::HandleWebUIEvent_Implementation(FName EventName, const FString& PayloadJson)
{
	// 1. 生命周期与传输回执：最前面返回，不进入业务分发
	if (EventName == StandardPresentationReadyEventName
		|| EventName == StandardPresentationAppliedEventName
		|| EventName == SamplePanel::StateAppliedEvent)
	{
		return;
	}

	// 2. 类型化 Intent：guard 写在分发处，蓝图覆写绕不过去
	if (EventName == SamplePanel::ConfirmRequestedEvent)
	{
		if (!bConfirmButtonEnabled || !HasValidModel())
		{
			PublishState(true);	// 拒绝时回推权威状态，纠正 Web 的过期可用性
			return;
		}
		OnSamplePanelConfirmButtonClicked();
	}
}

void USamplePanelScreen::OnSamplePanelConfirmButtonClicked_Implementation()
{
	// 调用业务权威；成功与否由业务回调驱动 PublishState(false)，不等待 Web ACK
}

void USamplePanelScreen::PublishState(bool bForceRepublish)
{
	UOrionWebUIWidget* Host = GetWebUIWidget();
	if (!Host || !HasValidModel())
	{
		return;	// 数据无效不发空占位；数据到达后由业务回调再次进入
	}

	const TSharedRef<FJsonObject> State = BuildStateObject();	// 完整快照，不含 revision
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

换成 InstantScreen 父类时：

| 骨架写法 | 改成 |
| --- | --- |
| `GetWebUIWidget()` | `GetInstantScreenEndpoint()`，使用前判空并检查 `IsValidEndpoint()` |
| 只发业务事件 | 先 `PushState(PayloadJson, StateRevision)`，返回 true 再发同一份 `PostFlowControlledLatestEventToWeb` |
| 首帧状态 | 覆写 `BuildInitialInstantScreenState(OutInitialStateJson, OutStateRevision)`，给出同一份快照与 revision |
| 业务按钮走 `HandleWebUIEvent` | Web 用 `requestIntent()`；覆写 `HandleWebUIRequest_Implementation`，复验后必须 `Response->ResolveIntent(Request.Id, EOrionWebUIIntentStatus::Completed / Accepted / Rejected, Code, Authority, OperationId, Message)`；`Accepted` 必须带 `Authority` |
| 失活即释放 | 需要驻留时覆写 `ShouldKeepInstantScreenOnDeactivation()` 及两个 `Should…StandardWebUIPresentation…`；保留 Endpoint 时 `HandleWebUIReady` 不会重发，在 `NativeOnActivated` 重推 |

异步业务（例如发出 Server RPC）若调用内拿不到结果，立即回 `Accepted` 并由权威快照给出最终结果；不回结果会被 `E_INSTANT_INTENT_RESULT_MISSING` 拒绝，而且只有远端客户端会暴露。

## 固定按钮的 Native 接口

- 每个编译期已知的固定按钮对应一个独立的 `BlueprintNativeEvent`、一个启用属性或启用判断、一处写在 C++ 分发处的禁用 guard；默认业务写在 `_Implementation`。不要用一个带字符串参数的通用入口承载全部按钮。启用状态随完整快照发布给 Web 渲染，Web 的禁用只是表现。
- 动态项（列表行、数据驱动按钮）共用一个带类型化参数的事件，C++ 用当前权威数据解析并校验 payload 里的业务 ID，解析失败即拒绝。
- 修改已有 Screen 时保留用户已有的蓝图覆写：不改名、不改签名、不删除已被 WBP 覆写的事件；要保留默认业务的覆写必须调用 Parent Function。
- 按钮合同文件、`data-orion-control-id` 与声音策略见 [控件与资源](controls-resources.zh-CN.md)。

## CommonUI 接入

- 页面只通过宿主的 CommonUI 层栈推入，不直接 `AddToViewport`。两个基类在构造时把 `bIsBackHandler` 设为 true。
- 输入模式：`UOrionWebUIActivatableWidget.InputConfig`（`Default` / `GameAndMenu` / `Game` / `Menu`）与 `GameMouseCaptureMode`；InstantScreen 取 `ScreenDefinition.InputPolicy`（`Passthrough` / `Game` / `GameAndMenu` / `Menu` / `Modal`），页面可用 `InputPolicyOverride` + `bOverrideDefinitionInputPolicy` 覆盖。
- 动作：`InputManifest.Actions` 注册到本页面的激活树，触发时依次向 Web 推 `ue:commonAction`（或条目的 `WebEventName`）、广播 `OnCommonAction`、调用 `HandleCommonAction`。**同一动作只选一个业务入口**：Web 的 DOM 点击若还会发业务 Intent，C++ 就不要在 `HandleCommonAction` 里再执行一次，否则一次按键触发两次业务。非 `bPersistent` 动作在页面失活后不再触发。
- Back：`bForwardBackActionToWeb` 先推 `ue:backAction`；`HandleWebUIBackAction()` 返回 true 表示已消费；否则按 `bDeactivateOnBackAction` 走默认关闭或仅吞掉输入。`InputManifest` 里等于默认 Back 的条目不会重复注册。Confirm 作为普通动作配置。
- 输入设备：激活时与 Ready 后都会补推 `ue:inputModeChanged` 与完整的 `ue:inputPromptsChanged`；设备切换与 ActionBar 委托只在激活期间绑定。图标按 CommonInput brush 命中 `AssetManifest` → 条目 `Glyphs` → `keyDisplayName` 文本的顺序解析。
- 焦点：普通页面默认聚焦 `WebUI` 控件；InstantScreen 按 `FocusPolicy`（`Automatic` 时 `Menu` / `Modal` / `GameAndMenu` 聚焦 WebUI，其余回到游戏视口），可用 `FocusPolicyOverride` + `bOverrideDefinitionFocusPolicy` 覆盖。动态创建槽位的宿主基类必须在调用基类 `NativeConstruct()` 之前把名为 `WebUI` 的子控件放进 WidgetTree，否则拿不到焦点目标。
- 指针：InstantScreen 代理页自身被强制为 `SelfHitTestInvisible`、槽位为 `HitTestInvisible`，指针由 Runtime Host 接收；不要为了收鼠标而改它们的 Visibility。
- 覆盖与恢复：失活时基类撤销声音策略、解绑输入委托并发 `ue:webUI.presentationSuspended`。驻留页面被临时覆盖时保留文档、业务状态与路由；恢复时用新的 `presentationRevision` 走完展示事务后才重新取得焦点和输入，迟到的旧版本回执不得恢复错误页面。恢复后要立刻发起退出之类的 Native 请求时，先等 `IsReliablePresentationFrameCertified` 成立。

## 本地化

- 文本源头是 `UOrionWebUITextCatalog.Texts` 里的 `FText`，Key 用稳定的点分英文（如 `samplePanel.confirm`）；Web 只引用 Key。动态业务文本由 C++ 以 `FText` 生成后放进状态快照。
- 文本修订变化（切换语言、本地化资源更新）时宿主控件重新生成文本表与字体样式，并推送 `ue:localeChanged`；它与 `ue:inputModeChanged`、`ue:inputPromptsChanged` 都按最新值合并。
- 页面在**同一语义节点**上替换文本，不并列硬编码多语言，不靠重载页面切语言。

## 线程与生命周期红线

- CEF 回调线程只复制纯值；UObject、Slate、Gameplay 操作回到游戏线程。本文的委托与 `Handle*` 入口都在游戏线程触发，Presenter 不要把它们转到别的线程。插件已把 PostLoad 期间到达的 Web 调用排队到安全 Tick 执行，页面和 Presenter 不要自己加同类补丁。
- 不用固定延时、强制 Flush / Fence、反复 `ReloadApp()` 或重建 Browser 掩盖 Ready、首帧、Native Surface 或退出竞态；等待用就绪委托与认证查询。
- Browser / Document / Surface / State / Presentation 的 Generation 与 Revision 精确匹配；旧文档、迟到帧、迟到 ACK 不得推进当前事务。保存 Endpoint 的代码每次使用前检查 `IsValidEndpoint()`。
- Delegate、Timer、Ticker、异步加载句柄、`Defer()` 过的响应句柄都要对称清理；覆盖激活 / 失活、Travel、World 销毁、Widget 池复用与重复进入。
- 不为每个 Actor 建 Browser：世界空间 UI 用 `UOrionWebUIWorldElementComponent` 登记到每个 LocalPlayer 共享的覆盖层。也不新增页面专用的全局管理器、隐藏 WBP、页面池或后台预热 Browser；Browser 只由真实展示请求创建（`AcquireRuntimeLease` 已弃用）。

## 性能与帧率

- `BrowserFrameRate` 保持 0：帧率由 `DefaultEngine.ini` 的 `[OrionBrowser] bUseAdaptiveFrameRate` 驱动，不要给单页写固定上限。
- `BrowserRenderScale` 只增加像素成本、不改变 CSS 布局尺寸：静态菜单可以提高（受 `[OrionBrowser] MaxWebUIRenderScale` 限制），高频动画或视频页保持 1.0；不用小于 1 的倍率换帧率。
- 高频数据走 `PostFlowControlledLatestEventToWeb`，不要逐帧 `PostEventToWeb`；持续变化的画面（SceneCapture、Media）走 Native Surface，图标头像走 Runtime Image，不经 Bridge 传像素。
- 被覆盖的页面应进入 `CoveredSuspended` 并停止产生帧；Web 侧的 rAF 与轮询也要停。

## 插件提供 / 宿主自备

插件提供：上文各模块的类、Scheme 与资源端点、Bridge 注入、展示事务与认证、输入动作路由、`<OrionBrowser>/Content/UI/WebUI/Shared` 共享运行库与脚本、`<OrionBrowser>/Content/UI/WebUI/Sample`。

宿主工程需要自备：

- **页面公共基类**（建议）：在两个 CommonUI 基类之上统一“语义去重 + 分配 revision + `PushState` + 流控事件”的发布封装、Intent 结果封装（`ResolveIntent`）、生命周期回执过滤、埋点与关闭策略。骨架里的 `PublishState` 就是它的最小形态。放在 A 类客户端 UI 模块；业务权威留在玩法或后端适配模块，Screen 只调用其公开接口。
- **根布局与层栈**：CommonUI 层容器、层级 GameplayTag，以及推入、弹出页面的入口。宿主定义并注册层级 Tag，在 Catalog 的 RuntimeProfile 中声明对应 Runtime；插件不安装默认层映射。
- **Runtime Host 的摆放与 Catalog 注册**：根布局里放 `UOrionInstantScreenRuntimeHost`，并在合适的所有者生命周期内调用 `UOrionInstantScreenSubsystem::RegisterCatalog` / `UnregisterCatalog`；按玩法模块注册时自己写 GameFeature Action（插件没有）。
- **覆盖 / 恢复编排**：记录被覆盖页、判断临时页是否真正离栈、发送 `ue:webUI.presentationCovered` / `ue:webUI.presentationRestored`。模板的 Web 生命周期已监听这两个事件，Native 发送方不在插件里。
- **LoadingScreen 与 HUD 抑制**的衔接、弹窗队列、共享前端组件库、按钮合同检查脚本。

## 常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 页面空白 | AppId 三处不同名、`dist` 未构建或 `EntryHtml` 不对；打包后缺文件 | 核对三处同名并重建前端；`dist` 在 Target 构建时登记为运行时依赖，先产出 `dist` 再构建、打包，见 [构建与验证](build-validation.zh-CN.md) |
| 页面透明但占着输入 | 展示事件的 revision 来自多个计数器，恢复序号倒退被 Web 丢弃 | 统一用 `AllocateRevision()` |
| `StateRevision=<n> was reused with different snapshot content` | 内容变了却复用了 revision | 语义比较后再分配 revision |
| `acknowledgement … is already owned by event …` | 两条流共用了一个回执名 | 每条流使用独立回执事件名 |
| `E_INSTANT_REQUEST_UNHANDLED` / `E_INSTANT_INTENT_RESULT_MISSING` | 没覆写 `HandleWebUIRequest`，或处理后没回结果也没 `Defer()` | 每个分支都 `ResolveIntent` / `Reject` |
| `E_INSTANT_INTENT_SCOPE` / `E_INSTANT_INTENT_AUTHORITY` | 请求来自旧文档 / 旧实例，或页面还没取得当前展示的输入所有权 | 属于正常拒绝，不要放宽校验；检查是否在展示完成前就允许了点击 |
| 外部 iframe、图片、音视频被 CSP 拦截 | `AllowedFrameOrigins` / `AllowedImageOrigins` / `AllowedMediaOrigins` 未配置 | 分别填精确 origin 后重新加载，三者互不放行；目标站点自己的 `X-Frame-Options` / `frame-ancestors` 仍可能禁止嵌入 |
| 缩放后布局重叠、出现滚动条 | 页面按物理像素做响应式重排 | 保持 `SlateLogicalSize`，页面用固定设计分辨率舞台整体缩放，见 [Web App 脚手架](web-app-scaffold.zh-CN.md) |
