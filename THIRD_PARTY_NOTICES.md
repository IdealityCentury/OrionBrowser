# Third-party notices

The OrionBrowser commercial license does not replace licenses for included third-party components. Preserve their original notices when redistributing the relevant runtime files.

| Component | Version supplied | License material |
| --- | --- | --- |
| Chromium Embedded Framework | 149, paired with this release's Helper | [CEF license](Resources/Licenses/CEF-LICENSE.txt) |
| Chromium and bundled dependencies, including FFmpeg | Chromium 149.0.7827.201 | [Generated Chromium credits](Resources/Licenses/Chromium-CREDITS.html) |
| FlatBuffers | 25.9.23 | [Apache-2.0 license](Resources/Licenses/FlatBuffers-LICENSE.txt) |
| Vue | 3.5.43 | [MIT license](Resources/Licenses/Vue-LICENSE.txt) |
| three.js | 0.180.0 | [MIT license](Resources/Licenses/three-LICENSE.txt) |
| Noto Sans SC | 2.004 variable font, unmodified | [SIL Open Font License 1.1](Resources/Licenses/NotoSansSC-LICENSE.txt) |
| Geist and Geist Mono | 1.7.2 variable fonts, unmodified | [SIL Open Font License 1.1](Resources/Licenses/Geist-LICENSE.txt) |

The CEF runtime staging rules also copy `LICENSE.txt` and `CREDITS.html` beside the browser DLLs in the packaged game. The Showcase production app carries Vue, three.js and font licenses under its `licenses` directory. Its soundtrack and film were synthesized and rendered for this sample by the scripts in the app's `tools` directory; they contain no third-party recordings.

WebUIStudio is a separate companion application. Its distribution includes Electron/Chromium, Node/npm, Python/PyInstaller and application dependency notices. Those notices belong to the exact Studio build and remain in its extracted distribution. Consult them before redistributing or modifying that application.

Unreal Engine code and derived engine components remain governed by the applicable Epic licenses. Original Epic and third-party source headers are retained. This file does not grant rights to unrelated game content, trademarks or third-party patents.
