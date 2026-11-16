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

## Deployment

Publish the updated copies of all eight Lua files once so every current file
has its own header. Files are in this bundle. The updater now includes:

| File | Pastebin ID |
|---|---|
| gear_ui.lua | Kpv3DFpw |
| gear_config.lua | AaycZMFq |
| scan.lua | XBN2xPDu |
| gear_demo.lua | nvS0XYuk |
| station_setup.lua | RsndMVeb |
| casting_test.lua | A0GFb1LH |
| control_center.lua | tcBkF1vf |
| update.lua | 9p0dsT5Z |

The Control Center edit link is downloaded through its raw URL. update.lua is
still installed last, and prints the downloaded version of each file. Existing
queue files, station assignments and saved state are not replaced by metadata
registration. Foreground tabs, focus/reuse, and Q/Ctrl+T managed shutdown remain.

Local metadata, action/lock, checksum and Lua block/delimiter checks passed.
In-game multishell discovery/version behavior still needs testing.
