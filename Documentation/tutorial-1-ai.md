# Tutorial 1: Build an interface with AI (recommended)

Describe the interface you want to an AI agent: it writes the web page and builds it, and the Blueprint or C++ on the Unreal side can be handed to it as well. The four steps below get you started, and step 2 can be skipped.

[简体中文](tutorial-1-ai.zh-CN.md) · [Manual index](README.md) · The tool is covered in full in [Tutorial 2: WebUIStudio](tutorial-2-webui-studio.md), Blueprint wiring and C++ code in [Tutorial 3](tutorial-3-blueprint-and-cpp.md), and writing the page yourself without AI in [Tutorial 4](tutorial-4-write-by-hand.md).

```text
① Open WebUIStudio → ② (optional) Make a UI style library first → ③ Create the interface with a prompt → ④ Add sounds
```

## Step 1: Open WebUIStudio

1. Complete [installation](installation.md) and wait for tool preparation to finish.
2. Click the **WebUIStudio** button on the Level Editor toolbar. It opens the current project.

Then provide whatever is missing from the table below. Studio checks the first two itself after opening the project and reports them on its banner.

| Needed | How to provide it |
| --- | --- |
| App packages | Click "Install environment" on the banner |
| The Codex or Claude desktop app | Install one of them yourself and sign in. Studio hands your request to the AI through it |
| Node.js 22 or a newer LTS release | Install it yourself. The Node.js inside Studio serves the preview only; the AI builds the page from a terminal with the one on your system |

Keeping the plugin in the project's `Plugins/OrionBrowser` is recommended: the web project the AI writes imports the plugin's shared runtime by relative path.

## Step 2 (optional): Make a UI style library first

Do this first in a large project with many interfaces: settle colours, type, spacing and the look of every control once, and each later interface follows it, which is what keeps the style consistent. Skip it for one or two interfaces.

Send the prompt below to the AI (step 3 shows how), with your own game and the feeling you want:

```text
Make a UI style library for this game. Every OrionBrowser interface will follow it from now on.
Game: third-person sci-fi survival, cold and dark imagery. Feeling: restrained, hard-edged, few words, interfaces sit along the edges.
Platform: PC, usable with keyboard and mouse and with a gamepad. Design resolution 1920×1080. Languages: English and Simplified Chinese.

Deliver three things:
1. Docs/UI/ui-style.md: the style rules and a checklist to run before delivery.
2. Content/UI/WebUI/Shared/src/game-ui/: design tokens (colours, sizes, spacing, durations) and control styles shared by all interfaces.
3. Tools/WebUI/UIStyleGuide: a development-only interface showing colours, type, every button state, a sample panel and a HUD strip.
Give me 3 clearly different directions to choose from first, and lock the chosen one afterwards.
```

When the AI is done, `UIStyleGuide` appears in Studio's left rail. Look through its pages, choose a direction and say what to change (for example "take direction B, make the primary colour a warmer orange, no rounded corners"). From then on, add "follow `Docs/UI/ui-style.md`" to your prompts.

## Step 3: Create the interface with a prompt

Write the interface down as a short description: **what it shows, what the player can do, and whether the Unreal side is Blueprint or C++**. Here is the settings panel as an example to adapt:

```text
Build a settings panel named SettingsPanel.
It shows: volume (0–100), quality (low / medium / high), language (English / 简体中文).
The player can: change the volume, choose the quality, restore defaults, close the panel.
The Unreal side is Blueprint (or write: C++), and you do that part too: host the interface, receive and validate these actions, send the state to the interface.
Build when you are done, and tell me which steps are left for me in the editor and what you did not verify.
```

For a complex interface you are unsure about, ask for a plan first: turn on "Plan mode" in Studio, or end the description with "give me a plan first, change no files".

There are two places to send this description from.

### In WebUIStudio (recommended)

1. Click "New app" in the first row of the left rail.
2. Enter `SettingsPanel` as "App name" and paste the description above into "Description".
3. Choose Codex or Claude and click "Send to …".

Studio puts "read the creation Skill shipped with the plugin completely first", with its location, in front of your description and the project's existing apps after it, so you write only the request. When the AI reports completion, the new app appears in the left rail.

### In Codex, Claude or another AI tool

Open the project root (the folder with the `.uproject`) in it, and put one line in front of the description so that it reads the Skill shipped with the plugin first:

```text
Read Plugins/OrionBrowser/Skills/orion-webui-creation/SKILL.en.md completely first, then do the following by its rules.
```

If the plugin is not in the project's `Plugins` folder, use its real location. You can also click "Copy prompt" in Studio's "New app" sheet and paste the complete prompt, Skill location included, into any AI tool.

### Who does the Unreal side

You wrote "you do that part too" in the description. How far the AI gets depends on the tools it has:

| You chose | The AI does | May be left to you |
| --- | --- | --- |
| C++ | Writes and builds the page; writes the class that hosts the interface in the project's C++ module: receiving actions, validating, publishing state | Compiling the project; creating assets in the editor by the steps it lists |
| Blueprint | Writes and builds the page; with an editor automation tool, creates assets and connects nodes through Unreal's official interfaces | Without such a tool, it lists the steps to do in the editor |

Do the steps left to you with [Tutorial 3](tutorial-3-blueprint-and-cpp.md), which has every node and every piece of code. **Never let an AI edit a `.uasset` or `.umap` file as text or bytes.**

### Look at the result and ask for changes

- **In Studio.** Click the new app in the left rail and look at each view. To change something, click it with the "Element" tool in the tool dock, write what should change and save; then choose the receiver under "Send to" in the right panel and click "Send annotations". The location, a screenshot and the source line travel with the annotation; see [Tutorial 2](tutorial-2-webui-studio.md#annotate-and-send-to-an-agent).
- **In Unreal.** Once the Unreal side is connected, press Play and carry out every action for real. When something is wrong, start with [Troubleshooting in Tutorial 3](tutorial-3-blueprint-and-cpp.md#troubleshooting).

## Step 4: Add sounds

Hover and click sounds are played by Unreal, and the page contains no playback code; you only say which control uses which sound. Choose one of two ways.

**Configure it in Blueprint yourself.** Add a sound policy variable to the Widget Blueprint that hosts the interface, fill in the default hover and click sounds, and name individual controls by control Id where needed; the steps are in [Tutorial 3: Control sounds](tutorial-3-blueprint-and-cpp.md#control-sounds). You do not have to guess a control Id: click the control with the "Element" tool in Studio and read it in the "Inspect" tab of the right panel.

**Have the AI add it.** Give it the sound assets and what you want, with the asset paths of your own project:

```text
Add control sounds to SettingsPanel, on the Unreal side in the same way as the previous step.
Hover uses /Game/Audio/UI/SC_Hover, click uses /Game/Audio/UI/SC_Click.
The click sound of the Restore defaults button (settings-reset) becomes /Game/Audio/UI/SC_Confirm; the volume slider has no hover sound.
The page must not play hover or click sounds itself.
```

With a C++ host the AI writes this straight into the code. With a Blueprint host it is as in step 3: without an editor automation tool it lists the steps, and you fill them in with Tutorial 3. Sounds with a meaning in the game, such as "saved", are in [Tutorial 3: Sounds with a business meaning](tutorial-3-blueprint-and-cpp.md#sounds-with-a-business-meaning).

## Next

- Previews, views, annotations, isolated drafts and the rest of the tool: [Tutorial 2: WebUIStudio](tutorial-2-webui-studio.md)
- Blueprint wiring, C++ code, runtime images, WorldUI: [Tutorial 3: Blueprint and C++ integration](tutorial-3-blueprint-and-cpp.md)
- How each step of the page side works: [Tutorial 4: Write the interface by hand](tutorial-4-write-by-hand.md)
- Shipping: [Package and troubleshoot](packaging.md). After page files change, rebuild `dist` first, then package.
