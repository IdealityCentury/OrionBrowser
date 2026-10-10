# OrionBrowser 1.0.1 documentation

**Unreal Engine 5.8 · Windows 64-bit · Blueprint and C++**

OrionBrowser embeds local HTML, CSS and JavaScript interfaces in Unreal widgets. Build your presentation with web tools or an AI coding assistant; keep game rules, inventory and saved data in Unreal Blueprint or C++. The supported default rendering setting is `DefaultWebUIRenderMode=LegacyTexture`.

English | [简体中文](README.zh-CN.md)

## Start here

1. [Install and prepare the tools](installation.md)
2. Run the [Orion Station sample](sample.md) to confirm that the environment works

## Tutorials

| Tutorial | For | Content |
| --- | --- | --- |
| [1. Build an interface with AI (recommended)](tutorial-1-ai.md) | The fastest way to an interface, or little web experience | Four steps to get started: open WebUIStudio, optionally make a UI style library first, create the interface with a prompt, add sounds |
| [2. WebUIStudio](tutorial-2-webui-studio.md) | Previewing and inspecting interfaces, or annotating them for an AI agent | Starting, previews and views, Inspect and Log, annotating and sending, new apps, isolated drafts, command-line checks |
| [3. Blueprint and C++ integration](tutorial-3-blueprint-and-cpp.md) | Whoever owns the Unreal side and wires or codes it | Three routes (Blueprint only, C++, a C++ base class with a Blueprint subclass), a Blueprint node reference, CommonUI and InstantScreen |
| [4. Write the interface by hand (not recommended)](tutorial-4-write-by-hand.md) | Understanding how each step works, or looking up how one feature is done | Every operation without AI, from an app in an empty folder to messaging, input, sound, text, fonts, images, WorldUI, remote websites, security, performance and debugging |

The four tutorials use the same example, a settings panel named `SettingsPanel`, so they can be read side by side.

## Reference

- [Package and troubleshoot](packaging.md)
- [Orion Station sample](sample.md)
- [Third-party software and distribution](third-party.md)
- [Creation Skill](../Skills/orion-webui-creation/SKILL.en.md): the rules written for coding assistants such as Codex and Claude

Support: [Orion website](https://orionue.com) · [Issue tracker](https://github.com/IdealityCentury/OrionBrowser/issues) · [Versioned downloads](https://github.com/IdealityCentury/OrionBrowser/releases).

The public repository distributes documentation, examples and companion applications. The commercial Unreal plugin is distributed separately. Installing a sample alone does not grant or install the commercial plugin.
