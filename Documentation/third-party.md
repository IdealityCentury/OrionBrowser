# Third-party software and distribution

Read the plugin's [third-party notices](../THIRD_PARTY_NOTICES.md). The CEF SDK, compiled browser libraries and their resources are part of the plugin distribution. Helper is a separate executable paired with that SDK. WebUIStudio is distributed separately and contains its own dependency notices.

The example uses bundled, unmodified Geist, Geist Mono and Noto Sans SC fonts, Vue and three.js. Their original licenses are provided with the plugin and copied into the sample's production web output. Retain those files when reusing the sample web app.

The Type room of the Showcase also names nine fonts that Windows usually has, such as Segoe UI and Microsoft YaHei. They are referred to by name only: no file of theirs is in the plugin, and each is drawn only on a machine where it is already installed. Ship the fonts your own interface depends on, under a licence that allows it.

Everything else in the sample is original and generated: the pavilion, the solar system, the galaxy, the black hole and the asteroid field are built in code and shaded by procedures, the pavilion's textures are painted on canvases at run time, and the soundtrack and film are produced by the scripts in `Content/Python/Showcase` and `Content/UI/WebUI/Showcase/tools`. No stock footage, sampled audio or private game asset is included. Generated primitive meshes and sample game logic do not depend on private game assets.

A Fab plugin package, a local installation bundle, a public example and a packaged game contain different files:

| Deliverable | Contains |
| --- | --- |
| Fab plugin | Unreal source, plugin content, browser SDK/runtime materials, production web resources, documentation and preparation scripts; companion EXEs are obtained separately |
| Local installation bundle | Complete plugin installation and prepared companion executables |
| Public example | Blueprint sample project and instructions; commercial plugin installed separately |
| Packaged game | Cooked game assets, required web output, Helper, CEF runtime and notices; no Studio |

Fab approval is a separate platform review. A local compile, a GitHub Release or a successful game run does not establish that approval. Product support is limited to the platform and engine versions stated in the release.
