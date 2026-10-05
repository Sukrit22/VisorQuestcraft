# Fabric Loader selection — alpha.13

## Reason for the change

The user's Pico log captured on 2026-10-04 reports Fabric Loader 0.16.14 and rejects three installed mods that require at least 0.17.2: TaCZ Refabricated 0.7.1-forge1.1.8-hotfix2, Visor TaCZ Compatibility 0.12.0-alpha.12, and SimpleBedrockModel 2.3.0.1+mc1.20.1. It also reports missing `forgeconfigapiport`, required by both TaCZ and the compatibility addon.

The 0.16.14 pin was a reproducible launcher baseline introduced with Fabric support; it is not a Visor requirement. Lowering the compatibility addon's declared minimum alone would not fix this modpack because the other two mods independently require 0.17.2.

## Player workflow

Choose **Fabric** when creating an instance and set **Fabric Loader** to the desired release number. The new-instance default is **0.17.2**. For an existing instance, open its information page and the runtime/loader settings, choose the version and save. The requested loader is prepared on the next launch. Existing instances retain their installed version until the user changes it.

An upgrade downloads the official Fabric profile and its libraries and updates the loader classpath together. Do not put the Fabric Loader JAR into `mods` or merely change its filename. Forge instances use their separate Forge installation.

For the reported TaCZ test, also add the **Fabric / Minecraft 1.20.1** build of [Forge Config API Port](https://modrinth.com/mod/forge-config-api-port/version/v8.0.3-1.20.1-Fabric) to the instance's `mods` folder. This dependency is a mod even though its name includes Forge. Updating Fabric Loader does not install missing mod dependencies automatically.

The APK is delivered for manual installation. No headset files are changed by the build process. The user has reported successful Forge and Fabric Visor startup on alpha.12; alpha.13's selectable-loader path still requires a headset test.

## Implementation and checks

The instance stores requested and installed loader versions separately. Old instances infer their existing loader from the classpath and remain unchanged until a version is selected. A migration resolves the official Fabric profile, verifies downloads against SHA-1 metadata, and replaces the old/new loader library identities together (including ASM, Mixin, Intermediary and Loader). Minecraft, Android LWJGL and launcher helper entries retain their relative order. Old library files remain on disk for other instances and rollback.

The old registry is backed up as `instances-before-fabric-<id>.json`. The new classpath/version is committed using a temporary registry file; a failed commit restores the previous in-memory launch profile. An invalid or unavailable release reports a preparation error rather than claiming the upgrade succeeded. Version selection does not promise compatibility with every future loader release.

Validation completed: Pojlib compilation, 33 host checks against the production migration/version/commit code, and a live download of the official 0.17.2 profile and all eight verified Maven libraries. Unity checks passed for the new field's visibility, version input, and layout alongside the custom Visor controls. Run `tools/Test-FabricLoaderProfile.ps1 -Live` to repeat the migration and live-download checks after compiling Pojlib.

Both alpha.13 APKs built successfully and passed target manifest, loader, ARM64, signature, 77 shared-file hashes, ten launcher dependency class definitions, and fourteen bridge JNI export checks. Both APKs also contain the FabricLoaderProfile class in their DEX code. SHA-256 hashes and sizes are recorded in `outputs/alpha13-artifacts.json`. These build/host checks do not replace the pending headset upgrade and TaCZ gameplay test.
