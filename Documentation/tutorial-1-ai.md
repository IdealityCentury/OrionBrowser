# Tutorial 1: Build an interface with AI (recommended)

Describe the interface you want to Codex or Claude. The agent writes the web page, builds it and lists the Blueprint wiring. You choose the style, confirm the data and actions, assign sounds in Blueprint and accept the result in Unreal. This tutorial teaches one thing: **what to say to the agent at each step**.

[简体中文](tutorial-1-ai.zh-CN.md) · [Manual index](README.md) · To write the page yourself, see [Tutorial 2](tutorial-2-build-it-yourself.md). For Blueprint and C++ wiring, see [Tutorial 3](tutorial-3-blueprint-and-cpp.md). For the preview tool, see [Tutorial 4](tutorial-4-webui-studio.md).

```text
Prepare → ① UI style guide → ② Data and actions → ③ Write the interface → ④ Review and revise → ⑤ Blueprint wiring → ⑥ Sounds in Blueprint → ⑦ Test
```

## Who does what

| Role | Responsible for |
| --- | --- |
| You | Saying what you want; choosing the style; confirming data and actions; wiring Blueprint and assigning sounds; checking the result in Unreal |
| Agent | Reading the Skill; writing the style guide and the page; building and self-checking; delivering the wiring list and control Ids; saying what it did not verify |
| The Skill shipped with the plugin | **How** to do it: Unreal owns state, the page only submits actions, folders and names, preview, build and validation |

Because the Skill covers the "how", your prompt does not teach the agent to code. It only has to state the **what** completely: who the interface is for, which data it shows, which actions it offers, what it looks like, and what counts as done.

## Prepare

1. Complete [installation](installation.md) and wait for tool preparation to finish. For your own web apps, keep the plugin in the project's `Plugins/OrionBrowser`: web projects import the plugin's shared runtime by relative path, and this is the verified layout.
2. Install Node.js 22 or a newer LTS release (npm is included). The agent needs it to build the page from a terminal.
3. Open the **project root** (the folder with the `.uproject`) in Codex or Claude Code, so that it can read both `Plugins/OrionBrowser` and `Content/UI/WebUI`.
4. Put standing requirements in the instruction file. Codex reads `AGENTS.md` in the project root; Claude Code reads `CLAUDE.md`:

```markdown
- Before creating or changing an OrionBrowser interface, read Plugins/OrionBrowser/Skills/orion-webui-creation/SKILL.en.md, and the references it points to when details are needed.
- The interface style is defined by Docs/UI/ui-style.md.
- You may run npm ci, npm run typecheck, npm test and npm run build in a web app folder.
- Do not start Unreal Editor, PIE or packaging without my approval, and never edit .uasset or .umap files directly.
```

The `ui-style.md` in the second line is produced in step 1; you can write the line now. Then confirm that the agent understood, with your first prompt:

```text
Read Plugins/OrionBrowser/Skills/orion-webui-creation/SKILL.en.md. Do not write code yet. Tell me in a few sentences:
who owns game state; how the page submits actions; where production files go; which commands you will use to verify; what you will not do.
```

The answer should mention: Unreal (Blueprint or C++) owns state; the page only renders state and submits actions; `Content/UI/WebUI/<AppId>/dist`; the type-check and build commands; no `.uasset` edits; no Unreal runs without approval. If one is missing, ask it to read again.

**There are two places to talk to the agent, and the prompts in this tutorial work in both:**

- **Directly in a Codex or Claude conversation.** Always available.
- **From WebUIStudio.** Its "New app" sheet and its annotations add the Skill location, the project's existing apps, the source location of a control and screenshots for you; you write only the request. This needs the Codex or Claude desktop app installed and signed in. See [Tutorial 4](tutorial-4-webui-studio.md#annotate-and-send-to-an-agent).

## Step 1: Settle the UI style guide

The style guide holds the decisions every screen shares: mood, what each colour means, typefaces and sizes, spacing, shapes, motion durations, layout skeletons, and every state of every control. Settle it before building screens. Otherwise each screen the agent delivers looks different, and the agent does not remember your previous conversation.

The style guide becomes three things, all written by the agent:

| Deliverable | Suggested location | Purpose |
| --- | --- | --- |
| Rules document | `Docs/UI/ui-style.md` | The rules and a pre-delivery checklist. The agent reads it before every interface |
| Style library | `Content/UI/WebUI/Shared/src/game-ui/` | Design tokens (CSS variables) and control styles shared by every interface |
| Reference app | `Tools/WebUI/UIStyleGuide` | Specification pages and a few sample screens, viewed in WebUIStudio or a browser. It lives outside `Content`, so it is not packaged with the game |

**Ask for directions first, not for real screens:**

```text
I want a UI style guide for the game. Every OrionBrowser interface will follow it. This round is for directions only.

Game: third-person sci-fi survival; the picture is cool and dark.
Feeling: restrained, hard-edged, few words; the scene is the lead and the interface stays at the edges.
References: the 6 screenshots in Docs/UI/refs/. Take their information hierarchy and spacing. Do not copy their colours or icons.
Platform and input: PC; everything must work with keyboard and mouse and with a gamepad.
Design resolution 1920×1080, scaled as a whole to other resolutions. Languages: English and Simplified Chinese.
Hard rules: transparent page background; no backdrop-filter and no mix-blend-mode; fonts and images are bundled, nothing is loaded from a remote address.

Build a development-only WebUI app in Tools/WebUI/UIStyleGuide with 3 clearly different directions.
One page per direction: the palette and what each colour is for, the type scale, buttons in default/hover/focus/pressed/disabled/selected states, one sample panel, one HUD sample.
Register a view for each page in webui-preview.json so that I can step through them in WebUIStudio. Tell me how to open it when you are done.
```

**Then lock the one you choose:**

```text
Take direction B with three changes: a warmer orange as the primary colour; no rounded corners; body text no smaller than 14px.
Turn it into three things:
1. Docs/UI/ui-style.md: the rules, ending with a pre-delivery checklist (clear hierarchy, contrast, no text overflow, all states present, consistent positions across similar screens).
2. Content/UI/WebUI/Shared/src/game-ui/: design tokens (colours, sizes, spacing and durations as CSS variables) and control styles. From now on interfaces use only token values; a new value is added to the tokens first.
3. Update UIStyleGuide: specification pages (colour, type, controls, states, motion) and two sample screens (a menu and a HUD), each with English, Chinese and 40%-longer-text views.
```

How to write style prompts:

- **Describe feeling and purpose, not CSS.** "The primary action is the brightest thing and there is one per screen" is more useful than a colour value. Give numbers when you really have them.
- **Say what to take from a reference and what to leave.** Given only a picture, the agent copies it.
- **Write down what is forbidden.** Rounded corners, gradient text, glow everywhere: unsaid, they may appear.
- **Ask for every state and the longest copy.** Hover, focus, pressed, disabled, selected, loading; one view each for the longest text and the other language.
- **Put the decision in a file.** A style you agreed to in chat does not exist in the next conversation.

When you look at the style guide in WebUIStudio, set the preview backdrop to a screenshot of your game to judge whether text and panels stay readable over the real picture.

## Step 2: Settle data and actions

Which data the interface shows and which actions the player has must become a table before any code is written. That table is what you wire in Blueprint later, and the names must match on both sides character for character. A settings panel serves as the example:

```text
Build a settings panel that follows ui-style.md. AppId: SettingsPanel. Event prefix: settingsPanel. The host is Blueprint only.
State owned by Blueprint: volume 0–100, quality low / medium / high, language zh-Hans / en.
What the player can do: change the volume, choose the quality, restore defaults, close the panel.

Do not write code yet. Give me a contract table:
- the state event Blueprint sends to the page and its full JSON: top-level strings, numbers and booleans only, with an increasing stateRevision;
- for each action: event name, parameters and their ranges, emit or call, and what the page shows when Blueprint rejects it;
- a stable Id for every clickable control (data-orion-control-id).
```

"Top-level strings, numbers and booleans only" is there because the plugin's Blueprint JSON nodes read and write top-level scalar fields. For arrays and nested objects, see [Tutorial 3](tutorial-3-blueprint-and-cpp.md#json-in-blueprint).

The agent should return a table like this:

| Direction | Name | Parameters | Meaning |
| --- | --- | --- | --- |
| Unreal → page | `ue:settingsPanel.state` | `{ stateRevision, volume, quality, culture }` | Full state, sent again on every change |
| Page → Unreal (emit) | `settingsPanel.ready` | `{}` | The page is listening and asks for the first state |
| Page → Unreal (emit) | `settingsPanel.setVolume` | `{ volume: 0–100 }` | Blueprint checks the range, then saves |
| Page → Unreal (emit) | `settingsPanel.setQuality` | `{ quality }` | Only the three values are accepted |
| Page → Unreal (call) | `settingsPanel.resetDefaults` | `{}` | Needs a result: `{}` on success, an error code on failure |
| Page → Unreal (emit) | `settingsPanel.close` | `{}` | Blueprint closes the panel |

Check three things before you approve it: the names are ones you want to see in Blueprint; every parameter has a range; no result is decided by the page alone (none should be).

## Step 3: Have the agent write the interface

```text
The contract is approved. Now implement SettingsPanel:
- Location: Content/UI/WebUI/SettingsPanel. Use only game-ui tokens and control classes for styling.
- English and Chinese; the language follows culture in the state.
- Fully usable with keyboard and mouse and with a gamepad: arrow keys move focus, the confirm key activates, and focus is clearly visible.
- Without a host (browser, UMG Designer) show preview data. Register views in webui-preview.json: default, Chinese, volume 0, longest copy.
- When done, run npm ci, npm run typecheck, npm test and npm run build. Deliver only after all pass.

Deliver:
1. the list of files added and changed;
2. a Blueprint wiring list I can follow step by step (node names, event names, field names), also written to Content/UI/WebUI/SettingsPanel/README.md;
3. every control Id;
4. which layers you did not verify.
```

From WebUIStudio: click "New app" at the top of the left rail, paste the text above into "Description", enter `SettingsPanel` as "App name", choose Codex or Claude, and send. Studio puts "read the creation Skill completely first" with its location in front of your description, and the list of existing apps and the delivery requirements after it. "Copy prompt" gives you the whole text.

A complete prompt has eight parts. Whatever is missing, the agent guesses:

| Part | Example |
| --- | --- |
| Goal | Build a settings panel |
| Identity and location | AppId, event prefix, folder |
| Style | Follow `ui-style.md`; use only the style library |
| Data and actions | The contract approved in step 2 |
| Cases to cover | Both languages, empty data, longest copy, disabled states |
| Input | Keyboard and mouse, gamepad, text entry |
| Preview | Preview data without a host; views in `webui-preview.json` |
| Definition of done | Commands that must pass, lists to deliver, what was not verified |

## Step 4: Review and revise

Three places to look:

- **WebUIStudio**: click the **WebUIStudio** button on the Level Editor toolbar, choose the app and step through its views. See [Tutorial 4](tutorial-4-webui-studio.md).
- **UMG Designer**: once the assets of step 5 exist, the Orion WebUI widget shows the page in Designer.
- **Browser**: run `npm run dev` in the app folder and open the address printed in the terminal.

**The easiest way to ask for changes is to annotate in Studio.** Pick the control with the Element tool and write what should change. If you want, open "Adjust properties" and tune colour, size and spacing until it looks right. Save, write the overall request in the right panel, choose a receiver and send. The location, screenshots, source line and the target values you tuned travel with the annotation. Without annotations you can send a request for the whole page.

**When you write the feedback yourself,** make it possible to find the place and understand the target:

```text
View "Chinese": the text of the reset button (settings-reset) is cut off. Show it completely; size the button to its content.
View "default": focus and hover on the volume slider look the same. Focus must be brighter.
Do not change the contract or the control Ids. Rebuild when done and tell me which views you checked.
```

- State in each item: **which view, which control (by control Id), what it looks like now, what it should look like**. Give the path of a screenshot if you have one.
- "Make it nicer" does not help. Name what you see: "the primary button does not stand out", "three things compete for attention on this screen".
- When requirements change, have the contract table changed first and the code second. Do not slip a new action into a feedback note.
- When a style problem keeps returning, have the conclusion added to `ui-style.md` instead of repeating it.
- For a large change you are unsure about, ask for a plan only (Studio's "Plan mode", or "give me a plan first, change no files" in the prompt).

## Step 5: Wire Blueprint

Follow the wiring list the agent delivered. The minimum is six steps; the nodes are described in [Tutorial 3](tutorial-3-blueprint-and-cpp.md#blueprint-only-from-scratch):

1. Create an `OrionWebUIAppDefinition` data asset: set `AppId` to `SettingsPanel` and clear **Use Dev Server in Editor**.
2. Create a Widget Blueprint, add an **Orion WebUI** widget named `WebUI`, enable **Is Variable**, and assign the asset.
3. **On Web Event** of `WebUI`: branch on `Event Name`. Read parameters with **Get Json Number / String / Boolean**, check `Valid` first, then the range, and only then change Blueprint variables.
4. Write a "publish state" function: add one to the revision, build the full state from `{}` with **Set Json Number / String / Boolean**, and call **Post Retained Latest Event to Web** with event `ue:settingsPanel.state`. Call it on `settingsPanel.ready` and after every state change.
5. **On Web Request** of `WebUI`: handle `settingsPanel.resetDefaults`, then call **Resolve Json** on `Response`, or **Reject** when it is not allowed.
6. Create the widget in the Player Controller, **Add to Viewport**, show the mouse cursor and call **Set Input Mode Game And UI**.

If your agent can operate Unreal through an editor automation tool, it may create the assets and nodes, but only through Unreal's official interfaces. Never let it edit a `.uasset` as text or bytes.

## Step 6: Assign sounds in Blueprint

Hover and click sounds are played by Unreal, and the page contains no playback code: the plugin reports which control was hovered or clicked, with its control Id, and a sound policy in Blueprint decides what to play. First have the agent tidy the control Ids:

```text
List every control Id of SettingsPanel and give each a sound role: default, confirm, back, danger, slider.
Check that every clickable element has a literal data-orion-control-id, and that disabled and waiting states use disabled, aria-disabled or aria-busy.
The page must not play hover or click sounds itself.
```

Then, in the Widget Blueprint that hosts the page:

1. Add a variable `ControlSounds` of type `OrionWebUIControlSoundPolicy` (search for `Control Sound Policy`) and compile.
2. Fill in its default value. **Hover Sound** and **Click Sound** under **Default Sounds** apply to every control. Each item in **Control Overrides** takes a **Control Id**; enable **Override Hover Sound** or **Override Click Sound** and choose the sound. To silence a control, add an override, enable the matching Override switch, and clear **Enabled** of that sound.
3. **Event Construct**: call **Activate Control Sound Policy** on `WebUI` with `Self` as `Policy Owner`, an empty `Context Id`, and `ControlSounds` as `Policy`.
4. **Event Destruct**: call **Deactivate Control Sound Policy** on `WebUI` with `Self` as `Policy Owner`.
5. Check the Ids. In WebUIStudio, click a control with the Element tool: the "Inspect" tab shows the control Id to enter in Blueprint, or "Not declared" when the control has none, which is a job for the agent. In the Widget Designer, **Design Time Control Id Preview Mode** of `WebUI` set to **All Controls** labels every control in the same way; a red frame labelled `ControlId: <missing>` marks a control without an Id.

Sounds with a business meaning, such as "saved" or "failed", are not control sounds. Register their Ids in an `OrionWebUISoundManifest` data asset, assign it to **Sound Manifest** of the App Definition, and have the agent call `playSound` at the right moments. You still choose the sound assets in Unreal.

## Step 7: Test

Each layer proves only itself. None replaces another:

| Layer | How | Proves | Does not prove |
| --- | --- | --- | --- |
| Build | The agent runs the type check, the contract check and the build | The code compiles; names and forbidden constructs are in order | What the page looks like |
| Preview | WebUIStudio, browser | Layout, states, both languages, longest copy | Blueprint logic, real input, sound |
| Designer | The Widget Blueprint's Designer | The assets are configured and the page loads in the engine | Runtime behaviour |
| PIE | Press Play | The Blueprint state round trip, keyboard, mouse, gamepad, IME, sound | The packaged result |
| Package | Run the packaged game | The web files are in the package and run offline | Pages nobody actually operated |

In PIE, at least: click every control with the mouse, then operate everything with the keyboard only and with the gamepad only; switch the language; type into a text field with an IME; open and close the interface repeatedly; listen for the hover and click sound of every control.

When something is wrong, give the agent the **symptom, the layer and the log** together:

```text
In PIE, dragging the volume slider does not change the number on screen.
The settingsPanel.setVolume branch in Blueprint runs (the breakpoint is hit). On Web Error prints nothing.
The relevant lines from the Output Log: (paste the lines starting with LogOrionWebUIWidget)
First decide whether the problem is in the page, the contract or Blueprint, then propose the change. Do not solve it with a delay.
```

For packaging, see [Package and troubleshoot](packaging.md). After the web files change, rebuild `dist` before packaging.

## Prompt checklist

- Have the agent read the Skill and `ui-style.md` before you state the request.
- One interface at a time. Ask for the contract table first; code comes after you approve it.
- Give names: AppId, event prefix, state fields, how control Ids are named.
- Give limits: which folders it may change, which commands it may run, what it must not do.
- Give the definition of done: commands that must pass, lists to deliver, what to report as unverified.
- Say "Blueprint owns state": the page saves no progress and decides no success.
- Feedback names the view, the control Id, the current state and the expected state. Annotate when you can.
- Put conclusions in files (`ui-style.md`, a `README.md` in the app folder). Do not rely on chat memory.
- Do not let it guess: when information is missing, it should ask first.
- Do not accept "it should work": ask for the commands it actually ran and their results.

## Common problems

| Symptom | Cause | Tell the agent |
| --- | --- | --- |
| Every interface looks different | No style guide, or the agent did not read it | "Read `ui-style.md` first and use only the tokens and control classes of the style library" |
| Blank in Studio, fine in a browser | Preview data exists only in the no-host branch | "Export a preview state as the Skill's Studio preview contract describes, and register the views" |
| Blank in Designer | The page draws only after it receives Unreal state | "Show preview data when there is no host" |
| A button does nothing in Blueprint | Event or field names differ between the two sides | "Compare event and field names with the contract table character by character and list the differences" |
| A disabled button still makes sound | Disabled is expressed only by a style class | "Express disabled and waiting with `disabled`, `aria-disabled` or `aria-busy`" |
| One click plays two sounds | The page also plays hover or click sounds itself | "Remove hover and click playback from the page and leave it to the control sound policy" |
| Text overflows in the other language | The longest copy was never checked | "Add a view with the longest copy and size controls to their content" |
| It says it is done but did not build | No definition of done | "Run the type check, the contract check and the build, and paste the result of each command" |
