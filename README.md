# Crafting Center - FTB Skies 2 / CC:Tweaked

A shared monitor interface, casting queue and console tools for Productive
Metalworks and Silent Gear parts. Scripts are downloaded from this repository.

## Files

- `control_center.lua`: paged console launcher; fg tabs, version view and managed shutdown.
- `gear_ui.lua`: synchronized touch UI and dedicated-station casting queue.
- `gear_config.lua`: station, storage and recipe defaults.
- `gear_demo.lua`: demo fixtures for equipment recipes not yet commissioned.
- `station_setup.lua`: assign 40 cast tables; one-template insertion test.
- `scan.lua`: read-only peripheral/item/fluid diagnostics.
- `casting_test.lua`: manual table commissioning tests.
- `update.lua`: validate and install all eight scripts from one GitHub commit.

## First migration from Pastebin

All eight Lua files live at the repository root on `main`. Keep the repository
public for unauthenticated in-game downloads. Publish this GitHub-backed updater
to the repository before using the bootstrap command below.

For an existing computer, from its scripts folder:

```text
wget https://raw.githubusercontent.com/kale2heart-hub/FTB_Skies2_CCTweaked_Repository/main/update.lua update_github.lua
update_github
```

The temporary updater installs the normal update.lua too. After success, run
`delete update_github.lua` to remove the bootstrap copy and avoid a duplicate
metadata ID in Control Center. Then use its normal Update entry. The computer must
allow HTTP access to api.github.com and raw.githubusercontent.com.

For a fresh computer the same bootstrap downloads all eight scripts into that
folder. Start `control_center` afterwards. It requires an Advanced Computer.

## Updating code

1. Edit the relevant Lua files in a local checkout, and increment each changed
   script's metadata version.
2. Commit and push the changes to main.
3. The game downloads the new revision through its existing updater.

Each update resolves main to a commit first and downloads all files at that
same commit. It validates Lua and version metadata before changing installed
files. It checks update.lua first; a changed updater is backed up and installed,
then the computer reboots so startup can continue with the new updater. If it is
unchanged, the remaining scripts are validated and installed with backups and
rollback on failure. It writes installed_revision.txt
with the commit and file versions. API/download failures leave installed code
unchanged. Downloads use public GitHub access, without a token in Minecraft.

Saved gear_stations.txt, gear_queue.txt, casting_test_state.txt and registry
files remain local. They are not downloaded or committed. Existing configuration
source is updated with a .bak copy, matching the previous updater's behavior.
Running programs keep their loaded code until restarted; Control Center's V
view identifies script/dependency differences.

## Current live features

Other supports Ingot/Nugget/Gem/Gear/Rod/Plate/Block jobs on assigned dedicated
stations. Station assignment and material costs must match the installed casts
and pack recipes. Table casts remain physically installed; cast swapping via
normal inventory APIs is not assumed. Equipment and Silent Gear tool-part
recipes are still being mapped and retain demo/request-only behavior.

See [METADATA.md](METADATA.md) for discovery, versions and parity, and
[station_map.md](station_map.md) for the 40-table plan.

## Control Center organization

Build 1.1.0 adds Applications / Console Scripts / Tools. Categories come from
each script's metadata. Enter opens a category and B returns. S opens a new
empty managed foreground shell without closing Control Center; Tools also has
an Open Shell entry. Type exit to close a shell. Q in Control Center closes all
managed programs and shell tabs.

Maintain code directly in the local GitHub checkout. Major build changes are
recorded in [CHANGELOG.md](CHANGELOG.md), while metadata versions track each
changed script. The current 1.1.0 build is local/unreleased until published.

## Cast chest audit

cast_check.lua is a read-only 40-cast inventory checker under Tools. It reads
the configured castChest (chest_1 by default), compares registry/display names
and shows Missing, Found, All and Unknown views. M/F/A/U switch views, R scans
again, Enter/D shows details, B returns and Q exits. It counts unique cast
types separately from duplicate stack quantities. It combines chest stock with
installation records for the current station assignments. Unknown names are not guessed; review
them before treating an undetected cast as truly absent. No items or fluids
are transferred. Cast names/aliases and exact-ID overrides can be extended
when real pack items are inspected.

Cast checker saves local cast_availability.txt on startup and R refresh. Gear UI
reloads it while running, flags missing required casts red, and shows details
when pressed. Missing/invalid reports are amber. Block uses a basin without a
cast. Gear, tool parts and live Other casting use the report.
The report covers chest contents and recorded installations, not station readiness
or recipe compatibility. Refresh after changing chest stock.

Station Setup: S opens Send All preview using current assignments. Enter sends
one recognized cast per role, skipping unsafe or unavailable destinations.
Results are saved in station_delivery_report.txt. Unknown/ambiguous items stay
in the chest. casting_1 is reserved; the Block basin needs no cast. Stop casting
and use physically cast-free tables. Transfer success requires visual verification
because installed casts are hidden from inventory access. Recorded installations
are skipped on repeated bulk delivery.

Cast tracking now combines chest stock with cast_installations.txt. Station Setup
records successful single/bulk deliveries and skips recorded installations on
repeat bulk runs. In a role's details, I confirms installed and X marks removed.
Use these for casts installed before tracking, or after manual changes. A transfer
records installation; the expected cast output verifies it. Checker rescans keep
these records and report chest quantity separately from installation status.
Gear UI installs an available missing cast before fluid is sent. Pending/uncertain
or suspect records require Station Setup inspection first. Casts are locked while
cooling. No output after the delivery timeout flags inspection; it does not prove
removal or trigger another pour. Wrong output is left on the table and pauses the
queue with its row/side/position. Correct output is checked before normal and
recovery collection. Installed records follow the physical table, not reassigned
roles. Queue jobs keep their original station assignments.

Queue recovery (Gear UI 1.2.1): an empty table accepting zero fluid reports a
missing/incompatible cast with its physical location, while real partial pours
show moved/required mB. Failed paused jobs can be removed, including their active
unit. Cancellation archives the active journal in backups/cancelled_cast_*.txt
and leaves table fluid/output untouched. Running casts remain protected. Home
beside Back returns to the main menu, and queued-job status shows pouring,
cooling or transferring with item progress. Tap a paused error for details.

Gear UI 1.2.2 refreshes cast chest stock automatically at startup, every pollSeconds,
after cast transfers/failures and before Resume. Adding a replacement cast updates
the buttons without running Cast Checker. A failed job remains paused until Resume;
uncertain/partial pours and wrong-output records still require inspection. Chest
quantities and installation state are saved together in cast_availability.txt.
