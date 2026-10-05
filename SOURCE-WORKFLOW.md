# Source and remote workflow

`origin` for this project is `git@github.com:Sukrit22/VisorQuestcraft.git`. `upstream` at the project root refers to Coah's release index. VisorModStudio's Visor repository is the upstream for the Visor component, not for this multi-repository build workspace.

The working repositories under `sources/` contain local source changes and their own Git histories. This top-level repository publishes those changes as complete patches against exact commits in `source-lock.json`, plus the standalone companion code in `bridge-source/`. Generated JARs, APKs, Unity caches, personal IDE state and headset diagnostic reports are excluded. Each restored component retains its original license and history; the companion retains its MPL license. The Pico loader binary included in the Unity patch comes from the Pico SDK provenance documented in TARGET.md.

## Clone and restore

```powershell
git clone git@github.com:Sukrit22/VisorQuestcraft.git
Set-Location VisorQuestcraft
.\tools\Restore-Sources.ps1
```

The script restores the pinned component revisions and applies the source patches. Existing source directories are checked and preserved rather than reset. `bridge-source` is copied into `sources/Visor-Android-Bridge` for the existing build scripts. A pinned Coah checkout supplies the inherited custom Android LWJGL OpenXR binding. The Unity source inventory is generated locally for the build/recovery tools.

Build AtumVR API/core first and copy their outputs into both Visor `libs/` directories as `atumvr-api-pico.jar` and `atumvr-core-pico.jar`. Build the 0.5 Forge/Fabric cores, the 0.6 Forge experiment and companion, then prepare Forge and stage assets before compiling Pojlib/Unity. Follow BUILD-AND-DEBUG.md, FABRIC-AND-ANDROID-BACKEND.md and VISOR-0.6-ANDROID.md for toolchains and commands. This push does not publish compiled artifacts or make a clean build automatically install all prerequisite toolchains.

## Publish later source changes

```powershell
python .\tools\Export-SourcePatches.py
git add source-patches bridge-source source-lock.json
git commit -m "Update Android port sources"
git push origin main
```

The exporter uses a temporary index and leaves each component's real staged/unstaged changes intact. It excludes generated dependency JARs, the generated Pojlib AAR and staged runtime assets. Do not add nested repositories as ordinary Git directories or commit a gitlink whose commit has never been published.

## Bring in a new Visor release

In the Visor component, fetch its canonical upstream (`https://github.com/VisorModStudio/Visor.git`). Inspect the desired tag and create a new checkout/worktree from it; carry forward and resolve the Android changes there. Review upstream changes to AtumVR and loader APIs too. Build and test both headset targets and supported mod loaders before changing the source lock and exporting new patches. Fetching alone preserves local work; pulling directly into the dirty checkout can create conflicts or mix versions unintentionally.

Keep the canonical remote named `upstream`. A separately hosted fork of that component can have its own `origin`; this top-level repository's origin should not be assigned to every component, because each has a different directory layout.

If SSH keys are not configured but Git Credential Manager is authenticated, the same repository can be pushed over HTTPS. This workspace retains the requested SSH origin URL and can use a per-command HTTPS override without changing the canonical remote.
