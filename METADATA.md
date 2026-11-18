# Script discovery and versions

Control Center scans its own folder and subfolders (up to six levels), skipping
ROM, .git and request-output folders. It reads files; it does not execute them
to discover their metadata. Lua files without headers are listed by filename
as unversioned. Extensionless scripts need a metadata header to be discovered.

Discovery runs on startup, with R, and after a managed updater finishes. Deleted
scripts disappear on rescan. The generated control_registry.txt contains the
current file versions, fingerprints, runnable actions and scan warnings. It is
a cache, not a second source of truth: edit the header in the script itself.
No individual program needs to register itself or rewrite this file at startup.

## Metadata header

Place this in the first 32 lines, ideally the first line:

```lua
-- @crafting-center {"id":"example","title":"Example Tool","category":"Console Scripts","args":[],"description":"What this tool does.","version":"1.0.0"}
```

Use a stable unique id. The scanner determines the actual file path. Helpers
and configuration files should include `"launchable":false`. They remain in
the version report but never appear as launch buttons.

Scripts offering multiple commands can define actions:

```lua
-- @crafting-center {"id":"example","title":"Example Tool","version":"1.0.0","actions":[{"id":"example.inspect","title":"Inspect","args":["inspect"]},{"id":"example.run","title":"Run","args":["run"]}]}
```

Each action has its own unique id, title, args and optional description. Shared
values may be defined on the base script metadata. Malformed metadata and
duplicate runnable IDs are reported instead of silently choosing a program.
A script cannot add launchable paths outside the scanned files through metadata.

Optional fields:

- `locks`: shared-resource names; two managed programs needing the same lock
  cannot be launched simultaneously. Production and mutating manual casting
  tests use `casting-state`. Read-only diagnostics do not hold it.
- `dependencies`: files, relative to that script's folder, to include in its
  loaded-version comparison. Current declared dependencies cover config/demo
  source files, not continuously changing job/queue state.
- `refreshAfterExit`: rescan after this managed action finishes; Update uses it.

## Version and parity view

Press V in Control Center. It shows each file's version and normalized content
checksum, the installation fingerprint, and managed tabs' loaded versions.
If a script or its declared dependencies changed on disk, its tab is marked
RESTART NEEDED. A running tab keeps the version it originally loaded rather
than falsely claiming the new on-disk version. Older wrappers without version
reporting show their loaded version as unknown.

The first versioned baseline is 1.0.0 for all eight existing Lua files. Future
code changes should increment the changed file's version (for example 1.0.1).
Versions do not have to be identical across independently evolving scripts.
Fingerprints also reveal changes made without a version bump. Line-ending
conventions are normalized before calculating checksums.

Compare installation fingerprints across computers for a quick parity check;
use individual file/version/checksum rows to locate differences. The aggregate
includes configuration source, so deliberate per-computer configuration changes
will also produce a different installation fingerprint.

## GitHub deployment

The repository is https://github.com/kale2heart-hub/FTB_Skies2_CCTweaked_Repository
and its default branch is main. All eight Lua files are at its root.

The GitHub updater resolves main to one commit and checks update.lua first.
If its contents changed (ignoring line endings), it validates and backs up the
new updater, installs it and reboots. Startup then runs the new updater to
validate and install the remaining scripts. Installation failure triggers a
restore attempt; failed updates do not reboot. The installed_revision.txt receipt records the commit and file versions.
Queue state, station assignments and registry files remain local.

Update Scripts is now version 1.0.1; unchanged scripts remain version 1.0.0.
Different script versions are valid; compare corresponding files across computers.

For the one-time migration, first publish the new update.lua in the repository.
Then run this from the in-game scripts folder:

```text
wget https://raw.githubusercontent.com/kale2heart-hub/FTB_Skies2_CCTweaked_Repository/main/update.lua update_github.lua
update_github
```

This installs the normal update.lua too. After success, run `delete update_github.lua` to remove the bootstrap copy;
otherwise Control Center will detect two scripts with the same updater ID. Subsequent updates use the existing Control Center
Update entry. HTTP access to api.github.com and raw.githubusercontent.com is
required. No GitHub token is needed on Minecraft when the repository is public.

Future edits: change local source files, bump their metadata versions, commit
and push to main. Local job/queue data is ignored by Git. Control Center's version
view continues to compare installed versus loaded code after updating.

The foundation updater was tested under Lua 5.2 with mocked normal/fresh
installs, API/download errors, invalid syntax/metadata and rollback. For the
current 1.1.0 build, metadata/category, resource-lock and Lua structural checks
passed. Current shell/navigation behavior and Minecraft HTTP/install operation
still require in-game verification.

## Categories and managed shells (build 1.1.0)

Control Center starts with Applications, Console Scripts and Tools. Set the
category field in a script header or an individual action to one of those
exact names. Actions inherit their parent script's category. Missing categories
default to Console Scripts; invalid categories are reported as metadata errors.

Current organization:

- Applications: Gear UI.
- Console Scripts: Station Setup and Diagnostics.
- Tools: Update Scripts, casting tests and the built-in Open Shell action.

Enter opens a category, B returns to the category menu, and the existing
arrow/page navigation remains. S opens a new empty foreground shell tab from
any view. Open Shell is also available under Tools. Shells open in the scripts
folder. Type exit to close a shell tab; exiting Control Center closes all its
managed shell/program tabs. Ordinary programs still reuse their existing
managed instance; Open Shell deliberately allows multiple tabs.

The shell is a built-in virtual entry, not a discovered local script, so no
extra Lua download or script metadata file is needed. Its system implementation
is not included in the project's version checksum. CHANGELOG.md records major
builds; individual script metadata versions identify smaller file changes.

Station Setup uses backups/ for state backups, and discovery skips that folder.
Updater 1.4.0 removes only managed script backups and uses in-memory recovery
copies during installation; state backups remain intact. Current source files are maintained in the local GitHub checkout.

Casting recovery adds the non-launchable casting_recovery.lua helper (v1.0.0),
listed in Gear UI dependencies and the updater. cast_installations.txt now also
persists tableError and actualCast per physical table. The casting job journal
records recovery attempts, matching fluid, each top-up intent/result, and delivery
of unexpected output; these are local state and are not replaced by updates.

Control Center 1.2.0's Text Files section is separate from runnable-script metadata.
It discovers local .txt paths without executing them, including reports/backups.
Text contents are cached on open and refreshed only with R; selection never
launches a script or alters the selected file.

Gear UI 1.5.0 adds the non-launchable gear_casting_data.lua helper (v1.0.0), which
is included in its dependencies and updater 1.0.9. Tool Rod and Tip share the
existing persisted queue/job journal; their batches specify the shape, exact fluid
volume and Silent Gear output ID. Existing Other batches need no migration.

Gear UI 1.6.0 adds helper dependencies gear_chest_data.lua, chest_catalog.lua and
chest_delivery.lua (v1.0.0). Chest queue batches use kind="chest" with source/output
chests and exact item/NBT components. Casting batches retain their existing schema.
The job journal records delivered quantities per component and transfer intent;
recovery never re-sends a component whose successful delivery was recorded.

Gear UI 2.0.0 adds gear_kit_data.lua and gear_request.lua to its helper dependencies.
Kit requests append ordinary casting/chest batches with requestId, requestItem,
kitNumber, kitTotal and partName metadata. Each has its own persistent job token;
existing queue formats remain valid. Preview planning uses cached stock only.

- `gear_stats_data.lua` (1.0.0): non-launchable FTB Skies 2 1.25.3 material/trait snapshot.
- `gear_preview.lua` (1.0.0): non-launchable pure review formatter; no storage access.
- Gear UI 2.1.0 adds both modules as dependencies; updater 1.3.0 installs them.

## Shared liquid network

- Gear UI 1.1.0 depends on `fluid_network.lua` and `fluid_client.lua`; configured
  Gear computers route tanks/pushFluid through the pinned fluid server.
- `fluid_monitor.lua` 1.0.0 is an Applications entry and holds `fluid-service`.
  It depends on `fluid_network.lua` and `fluid_service.lua`.
- `network_setup.lua` 1.0.0 is a Console Scripts entry. It saves per-computer
  assignments to `fluid_network.txt`; settings are not distributed by the updater.
- `fluid_network.lua`, `fluid_client.lua`, `fluid_service.lua` are non-launchable
  helpers, each 1.0.0. Protocol: `crafting_center.fluids.v1`, over a local wired modem.
- `casting_test.lua` 1.1.0 uses the service on a configured Gear computer.
- Updater 1.5.0 distributes all five new files and preserves local network state.
- Local state: `fluid_network.txt`, `fluid_jobs.txt`, `fluid_auto.txt`, and
  `fluid_transfers.txt`, each potentially with a recoverable `.pending` save.
