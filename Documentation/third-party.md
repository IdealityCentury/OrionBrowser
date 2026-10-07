# Third-party software and distribution

Read the plugin's [third-party notices](../THIRD_PARTY_NOTICES.md). The CEF SDK, compiled browser libraries and their resources are part of the plugin distribution. Helper is a separate executable paired with that SDK. WebUIStudio is distributed separately and contains its own dependency notices.

The example uses a bundled, unmodified Noto Sans SC font, Vue and three.js. Their original licenses are provided with the plugin and copied into the sample's production web output. Retain those files when reusing the sample web app. Generated primitive meshes and sample game logic do not depend on private game assets.

A Fab plugin package, a local installation bundle, a public example and a packaged game contain different files:

| Deliverable | Contains |
| --- | --- |
| Fab plugin | Unreal source, plugin content, browser SDK/runtime materials, production web resources, documentation and preparation scripts; companion EXEs are obtained separately |
| Local installation bundle | Complete plugin installation and prepared companion executables |
| Public example | Blueprint sample project and instructions; commercial plugin installed separately |
| Packaged game | Cooked game assets, required web output, Helper, CEF runtime and notices; no Studio |

Fab approval is a separate platform review. A local compile, a GitHub Release or a successful game run does not establish that approval. Product support is limited to the platform and engine versions stated in the release.
