# Visor QuestCraft — Quest and Pico Android port

Minecraft 1.20.1 with Forge 47.4.20 or selectable Fabric Loader, using Android-adapted Visor. Separate Pico and Quest APKs share the launcher/runtime sources and use their respective XR profiles. Current build configuration is alpha.13.

The launcher offers managed Visor 0.5, experimental Forge Visor 0.6 Alpha 2, unmanaged manual installation, and validated custom Android JAR URLs. New Fabric instances default to Loader 0.17.2; existing instances can select a version through Runtime / loader settings. Diagnostics are saved/shared locally by the player.

The user has reported successful Pico Forge and Fabric Visor startup with alpha.12. Build/package verification does not establish every headset, Visor version or modpack as working. TaCZ compatibility development is a separate project.

## Source and build

This repository includes pinned upstream revisions, complete port patches, standalone Android bridge source, build scripts and development notes. Working component checkouts and generated artifacts are excluded from Git.

- [Restore sources and manage upstream updates](SOURCE-WORKFLOW.md)
- [Headset targets and packaging](HEADSET-BUILDS.md)
- [Build and debugging procedure](BUILD-AND-DEBUG.md)
- [Visor runtime selection](VISOR-RUNTIME-ALPHA12.md)
- [Fabric Loader selection](FABRIC-LOADER-ALPHA13.md)
- [Download manifest](build-targets/VISOR-DOWNLOADS.md)

Use Unity 6000.4.10f1 with Android Build Support and the documented Java/Gradle/Android SDK toolchains. Compiled APKs and JARs are not published by this source push; distribute them separately through GitHub Releases when ready.

## Credits and upstreams

Based on [Coah's QuestCraft Visor port](https://github.com/coah80/questcraft-visor-releases), its [launcher](https://github.com/coah80/QCXR-XR-Wrapper) and [Pojlib](https://github.com/coah80/Pojlib), and the original QuestCraft work. Core upstreams include [VisorModStudio/Visor](https://github.com/VisorModStudio/Visor) and [AtumVR](https://github.com/Phoenix-Ra/AtumVR). Component licenses remain with their sources; the standalone Android companion includes its MPL license.
