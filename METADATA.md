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
-- @crafting-center {"id":"example","title":"Example Tool","args":[],"description":"What this tool does.","version":"1.0.0"}
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

The GitHub updater resolves main to one commit, downloads every script from
that commit, checks syntax and metadata before installing, backs up installed
files and replaces itself last. Installation failure triggers a restore
attempt. The installed_revision.txt receipt records the commit and file versions.
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

All eight files compile under Lua 5.2. Mocked updater execution passed normal
and fresh installs, API/download errors, invalid syntax/metadata and installation
rollback. Full Minecraft HTTP/install behavior still needs in-game verification.
