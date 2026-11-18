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
files. It checks update.lua first; a changed updater is installed,
then the computer reboots so startup can continue with the new updater. If it is
unchanged, remaining downloads are validated in memory and only changed scripts
are written, with in-memory rollback on failure. It writes installed_revision.txt
with the commit and file versions. API/download failures leave installed code
unchanged. Downloads use public GitHub access, without a token in Minecraft.

Saved gear_stations.txt, gear_queue.txt, casting_test_state.txt and registry
files remain local. They are not downloaded or committed. Existing configuration
source is updated without saving a script backup. Updater 1.4.0 removes its old
script .bak files, including legacy copies, while preserving cast/queue/settings
recovery files. Downloads no longer occupy disk space. Recovery copies exist
only in RAM during the update; a power loss mid-install requires rerunning the
updater. Disk space is checked before installation.
Running programs keep their loaded code until restarted; Control Center's V
view identifies script/dependency differences.

## Current live features

Other supports Ingot/Nugget/Gem/Gear/Rod/Plate/Block jobs on assigned dedicated
stations. Station assignment and material costs must match the installed casts
and pack recipes. Table casts remain physically installed; cast swapping via
normal inventory APIs is not assumed. Tool Parts and supported Gear kits now
use the live routes described below; final equipment assembly is manual.

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
changed script. Current changes remain local/unreleased until published.

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

Gear UI 1.2.3 keeps menu rendering free of inventory/file reads. A separate worker
refreshes the shared cast snapshot on the configured polling interval and after
cast state changes. Menus briefly show Checking cast stock on first startup.
Actual casting and Resume still validate live state. Registry-recognized casts
avoid detail queries; NBT-specific names are cached for 30 seconds.

Gear UI 1.2.4 buffers monitor drawing locally and sends only changed rows after
composing each frame. This reduces wired-modem calls when opening menus and
avoids transmitting intermediate clears and per-button style/cursor operations.

## Bounded casting recovery (1.3.0)

After five seconds in item transfer, Gear UI queries the table and attempts
100 mB top-ups of the matching fluid, waiting three seconds after each. Insufficient
stock reports Not Enough Fluid and stops; Resume queries the table again. Limits
are 20 top-ups (2,000 mB) per unit and 90 seconds per run. Restocking after an
insufficient-fluid pause resets the run time, but never the top-up count.

A completed output ends top-ups. This matters because 100 mB increments cannot
always exactly empty a wrong cast's recipe (for example 90 + 100n cannot be an
exact multiple of 360). Remaining fluid requires inspection rather than further
blind pours. Partial/uncertain transfers also stop, and are journalled before
sending fluid so restarting cannot silently repeat them.

Wrong-cast output is delivered once to the output chest, the requested unit
remains queued, and the table is marked TableError with its installation missing.
New jobs using that table, including dependent equipment, are blocked. Stock is
rescanned and the error reports the actual/expected cast, physical table location,
and whether a correct spare is available. Other errors do not set TableError.
Replace/remove the wrong cast and inspect any remaining fluid, then use Clear
Errors in Error Report. This revalidates flagged tables and clears locks that pass; it does not physically
remove casts or drain fluid. Resume can then install a spare and retry the requested unit.

Gear UI 1.3.1: Clear Errors now revalidates each flagged table and reports which
locks cleared or remain blocked. Wrong outputs, fluid and unreadable tables keep
their locks. Matching outputs verify installation; empty, fluid-free tables clear
stale locks, with unverified installation still marked missing. Hidden installed
casts can be confirmed with I in Station Setup. No fluid is sent or item moved by
Clear Errors. An active wrong-output job is released only if its own table passes.

Cast Tracking recovers interrupted installation saves automatically from a
valid pending file or backup. A pending save retains its recorded state. In
1.1.3, older backup-only recovery marks installations unverified; ordinary
requested outputs verify them, while TableError and pending transfers stay protected. The next successful save repairs the
primary record. Corrupt originals are retained. If no valid copy exists, records
are not silently discarded.

Control Center 1.2.0 adds Text Files beside Applications, Console Scripts and Tools.
It lists local .txt files alphabetically, including reports, requests and backups.
Enter reads a selected file inside Control Center. Up/Down, PageUp/PageDown and
mouse wheel scroll; B returns; R reloads the file or refreshes the file list.
The reader never executes or edits file contents. Q retains its existing meaning:
it closes Control Center and all its managed programs.

Control Center 1.2.1 adds text-reader highlighting: red errors, green success,
yellow warnings, cyan headings/table IDs/field keys, and coloured structured
values. tableError=true is red; false is green. Files are unchanged, and cached
colours are recalculated on R reload or terminal-width changes.

Recovery correction in Gear UI 1.3.2 / Cast Tracking 1.1.3: the earlier synthetic
suspect markers from backup recovery automatically become unverified, rather
than blocking every table. The next ordinary requested cast verifies that table's
output using the existing guards and recovery limits. No extra test pour is added
and unverified installations do not cause duplicate cast insertion. Actual wrong
casts, pending transfers and genuine suspect records remain protected.

Gear UI 1.4.0 adds Utilities at the bottom of the main menu. Choose Reset Installed
Cast List, review the four filenames and Confirm Reset to erase installation
tracking and its recovery copies. It never moves physical casts or deletes queue
data. Waiting jobs pause. Finish/cancel active casts or resolve unfinished casting
jobs first. Availability refreshes automatically after reset; casts remaining in
tables are now unrecorded and can be confirmed in Station Setup.

## Live Tool Parts (1.5.0)

Tool Parts > Tool Rod and Tip now cast parts into the output chest using stations
casting_40 and casting_41 (or saved Station Setup assignments). Select a compatible
stocked molten material, Review, choose quantity, and add to the existing queue.
These routes use real stock even when demoMode remains enabled for unfinished gear.
Set liveToolPartCasting=false to disable them. castMaterialOverrides still takes
precedence for server-specific changes.

gear_casting_data.lua was extracted from the locally installed FTB Skies 2 1.25.3
resources: bridge material_count=2, casting-enabled material properties for the
requested part type, and exact ingredient-tag melting amounts. Infusing materials
and unsupported materials are excluded. Tool Rod and Tip have separate allowlists
(53 and 19 fluids); menus show only those actually in storage. Iron takes 180 mB,
Diamond 200 mB, and an Obsidian Tool Rod takes 2,000 mB. Supported stock can differ
if the server has changed datapacks; use overrides for those changes.

These produce standalone parts for manual assembly. Chest Tool Parts are supported
by the delivery routes below; Gear kit requests can queue these components together. The known
case where a player manually removes output before delivery remains deferred.

## Chest-supplied Tool Parts (1.6.0)

Binding, Grip, Lining, Cord, Fletching and Coating now use the real parts chest.
Choose a Part: option to deliver a ready-made part, or Material: for compatible raw
items the player will hand-craft. Tag/item compatibility and recipe counts come
from the installed 1.25.3 data. Cord bundles contain three material items; raw
Coating bundles also include one glass bottle. Finished parts need no raw extras.
Tool Rod and Tip continue using their working fluid-casting routes.

Review quantities, then queue delivery to the output chest. Stock is reserved
across queued requests. Item metadata is preserved, and different finished-part
variants are kept separate. Resume retries only known undelivered components;
uncertain transfer results stop for inspection. Cancellation leaves already
sent items in the output chest. No casting fluid is used for chest deliveries.
The shared casting_test_state.txt journal also records these delivery jobs.

liveChestParts=false disables these routes. Inventory scanning stays in the
background; menu drawing never scans the chest. Gear kit delivery is described below. The known manual table-output removal
issue remains deferred.

## Live Gear part kits (2.0.0)

Choose Gear, an equipment item, and the material for each required/optional part.
Main and Tool Rod use compatible molten stock; selected chest parts can be ready
parts or material bundles for manual crafting. Review quantity and queue the kit.
Every kit's casts are followed by its chest bundle before the next kit begins.
The queue lists component jobs, not finished equipment; final assembly stays manual.

Whole-request checks combine shared resources, such as iron for both Main and
Tool Rod, or string for Cord and Binding. Existing queued jobs reserve their stock.
Nothing is enqueued when a required part, enabled station or shared resource is
missing. Required table errors block dependent Gear requests. Component jobs retain
normal cancellation/recovery, including exact item/NBT chest delivery.

There are 32 supported Gear casting profiles from the installed pack. Ranged
items require Cord, Arrows require Fletching, and armor requires Lining under the
Crafting Center's existing policy. Mace has no configured live recipe/station
profile; Elytra has no verified casting recipe. Their buttons explain this.
Jewelry Setting remains an optional None-only placeholder until its material rule
is verified. Other mapped extras remain selectable. Set liveGearKits=false to
return to the earlier demo/request-only Gear behavior.

gear_kit_data.lua records exact primary casting amounts/output IDs; gear_request.lua
plans the grouped jobs without inventory/file reads during drawing. All three
monitors keep the same selection and request queue. Existing queue batches remain
compatible. The new helpers are included in updater 1.2.0.

### Material stats and traits (Gear UI 2.1.0)

On a Gear or Tool Parts review, select **Stats & Traits**. The paged panel shows
material base values and part modifiers from the installed FTB Skies 2 1.25.3
material definitions, plus trait levels and descriptions. Conditional traits are
marked. **Selections** returns to the selected-parts summary.

These are material contributions, not final equipment totals: grades, synergy,
trait effects, and equipment-specific multipliers are not calculated. Finished
parts with unreadable material components and unmapped custom materials show
unavailable details. The material snapshot must be regenerated when pack data
changes; live inventory availability remains separate.

Gear UI 1.0.4 cycles through Stats & Traits pages every five seconds. Touching
any configured screen pauses this for ten seconds; Previous/Next still work
manually. Paging wraps to the first page. Existing inactivity-to-Welcome/Queue
rules remain in effect. Every non-Welcome footer shows the current Gear UI version.

## Shared fluid network (Gear UI 1.1.0 / Liquid Resource Monitor 1.1.0)

The two computers share a wired modem network. Liquid Resource Monitor owns the
Functional Storage fluid supply and serializes transfers. Gear UI requests exact
fluid IDs/mB for its own casting stations. The Fluid Monitor's own casting is
**whole blocks only**, poured directly into one or more exclusively assigned
Productive Metalworks basins. It waits for cooling, checks the finished block,
and collects it into a dedicated output chest.

### One-time setup

1. Stop the original monitor script and Gear UI before joining the cables.
   Install the updated suite on both computers, then join their wired networks.
2. Open **Fluid Network Setup** from Control Center's Console Scripts on both
   computers. The header shows the current computer ID. Select the local wired modem.
3. On the fluid computer choose role **fluid**, assign only its monitors and
   Functional Storage fluid controllers/drawers, and enter **Gear: Computer ID**.
   Select the allowed Gear destinations: Gear's basin and assigned casting tables
   (current reserved range: casting_0 through casting_42, including the manual
   test station). Use **Apply ranges: Gear 0-42 / Basins 43-105** to fill both lists.
4. Select **Managed block basins** for the Fluid Monitor. Use additional physical
   basins (casting_43 through casting_105), separate from Gear's casting_0 through
   casting_42. The selector excludes
   assigned Gear destinations. Productive Metalworks exposes tables and basins
   with the same casting peripheral type: select the devices that are physically
   basins. Assign **Block output chest** to collect the completed blocks.
5. On the Gear computer choose role **gear**, assign its in/out/dev monitors
   (up to three), and enter **Fluid: Computer ID**. Save on both computers.
6. Start **Liquid Resource Monitor** first, then Gear UI. Gear checks for overlapping
   monitor/basin assignments before drawing.

Select each storage controller once; do not also select its linked drawers or
another alias for the same storage, which would double-count available fluid.
Settings remain in `fluid_network.txt` and survive updates. Changes require an
application restart. Without shared-network setup, Gear retains standalone behavior.
After setup, Gear monitor discovery is disabled and casting/recovery fluid reads
and pours go through the fluid server. The fluid role prevents launching Gear UI
on that computer. Keep the original uncoordinated monitor script stopped.

### Upgrade from the buffer-based Fluid Monitor

Run Network Setup on the fluid computer, assign **Managed block basins** and
**Block output chest**, save, and restart Liquid Resource Monitor. Old ingot/block
buffer assignments are ignored, not converted into basins. Legacy buffer jobs
pause with an explanation; cancel them and inspect their old destinations before
queuing new block jobs. Existing Gear stations, queues and cast records are not reset.

### Whole-block workflow

- Resources -> fluid -> block quantity (1-64) -> Review -> Add to Queue.
  Ingot casting has been removed from the Fluid Monitor. Gear still handles its
  own equipment, parts and Other casting routes.
- Each idle basin receives exactly one block's recipe volume. Multiple basins
  cool concurrently. Only verified output IDs from the installed pack's 68
  cast-free whole-block recipes are accepted; unknown fluids cannot be queued.
- After at least three seconds, basins are checked for completion. Completion
  that takes longer is polled, with a fifteen-second cooling timeout. The
  monitor never adds speculative top-up fluid to a stalled basin.
- Completed blocks are moved into the output chest. A full/filtered chest pauses
  the job; after making room, Resume retries extraction without pouring again.
- Cancelling removes waiting blocks. Basins already poured keep their work and
  are collected before that job ends; allocations not yet poured are cancelled.
- Known partial pours pause and retain their measured amount. Resume checks the
  actual basin contents, then requests only the exact remaining mB. Pours are
  limited to eight attempts per block; unexpected fluid/output pauses for inspection.
- Utilities offers revalidation, explicit retry of inspected empty basins, or
  confirmation that an empty basin's block was already delivered. These choices
  resolve uncertain extraction/transfer states without silently guessing an outcome.

### Automatic casting and Gear fluid requests

Automatic Casting toggles each exact supported fluid. It queues 64 whole blocks
when enough unreserved fluid exists. Gear queue demand and an optional per-fluid
extra reserve are protected. Local block pouring waits for a fresh Gear heartbeat;
after fifteen seconds without one, it cannot consume Gear's reserved supply.
Gear UI continues its heartbeat on Welcome. Restart Gear if necessary, then Resume
paused local jobs. Blocks already cooling can still be collected.

The service validates pinned computer IDs and assigned destinations, serializes
pours, and persists bounded receipts and sequence watermarks. Duplicate requests
return their measured result. Expired receipts are rejected, and client timeouts
never automatically resend fluid. Uncertain physical transfers require inspection.
The adapter also serves Gear's bounded recovery and manual Casting Test.

The Fluid Monitor uses welcome/home navigation, cached mirrored displays,
alphabetic stock with quantities, review/queue controls, progress and a muted version
footer. Its block completion indicator now means a verified block was collected.
