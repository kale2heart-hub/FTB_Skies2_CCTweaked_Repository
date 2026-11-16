# Silent Gear parts console — first version

Files:
- gear_ui.lua: synchronized touch UI for inDisplay, outDisplay, devDisplay.
- gear_config.lua: peripheral assignments, verified recipes and material rules.
- scan.lua: discovers peripheral names, fluid IDs, item IDs and item NBT hashes.

## Demo mode (enabled by default)

Copy gear_ui.lua, gear_config.lua, gear_demo.lua and scan.lua into the same
folder on your CC computer. Run `gear_ui`. Only an Advanced Monitor is needed;
no connected storage is required. One monitor is enough to test, including
only devDisplay. With blank monitor assignments, demo mode discovers up to
three monitors automatically. Set explicit assignments to control their roles.

The header says DEMO. Sample fluids include Iron, Diamond, Uru and a small
Gold supply; supplemental parts have sample chest materials and finished parts.
These are synthetic compatibility and recipe fixtures, not pack-verified data.
Select Weapon > Sword, fill Main and Tool Rod, then Review > Save request.
Leave a required part empty to see saving disabled. Gold has only 90 mB:
selecting a Gold Main (180 mB) demonstrates the insufficient-stock check.

Test requests are saved separately in demo_requests/ with status demo_only.
Sample stock is fixed and is not consumed. No storage peripherals are read
and no items or fluids are moved. Real monitors are still used for the UI.

To switch to live stock, set demoMode=false in gear_config.lua and restart.
Demo rules replace only the in-memory configuration; your live rules and
recipes in gear_config.lua are preserved. Live mode requires explicit monitor
assignments, actual stock rules and pack-verified recipes. Casting/delivery
remain unimplemented in both modes.

## Install / configure live mode

Put all four Lua files together in a folder on the CC computer.
Run `scan` in that folder. Open `discovery.txt` with `edit discovery.txt`.
Edit gear_config.lua and assign the three monitor peripheral names. Logical
names such as inDisplay are aliases, not names assigned by wired modems.
Assign partsChest and outputChest. Add the Functional Storage peripherals
which expose tanks() to fluidStores. Do not include casting tables or basins
in fluidStores, and do not list two views of the same shared storage.
Run `gear_ui` from the same folder.

Advanced monitors are required for touches. Text scale is set before measuring
monitor dimensions. All screens use the smallest monitor's dimensions, centered
on larger monitors. devDisplay has exactly the same controls as the others.
The UI requires at least 30 columns and 14 rows at the configured scale.
Monitor order is explicit and never inferred from discovery order.

## Live mode (demoMode = false)

All 41 entries appear in the six requested categories. You can navigate the
screens immediately. Material lists initially contain only Clear selection:
there are no invented registry IDs or compatibility rules in this version.
A missing fluid-store configuration means no fluid choices. A missing parts
chest means no chest choices. Peripheral read errors block request saving.

Send discovery.txt back to continue configuring the material rules. The scan
contains registry IDs and NBT hashes, but does not reveal full Silent Gear
material components or recipes. For those, provide the part recipes from JEI
(including amounts), and the required/optional part list for each equipment
item. Parts using NBT/components need explicit, verified mappings; display
names and item registry IDs alone do not establish their material.

## Recipe and stock rules

The default part layouts are drafts solely for trying the UI. Sword, armor and
crossbow start from the requirements discussed in chat. Other layouts must be
corrected against the pack. No default layout enables saving a request.

Set recipes["Item Name"] to {verified=true, parts={...}} only after checking it.
Each part needs name, required (boolean), and source ("fluid" or "chest").
Main and Tool Rod normally use fluid; the supplemental parts use chest.
Custom layouts define exceptions such as Cord, Fletching and Jewelry Setting.
Every listed part is one selectable material requirement; use amount in its
material rule to represent the total quantity required for that part.

Every compatibility rule needs a unique id, item, part, label, source, exact
registry name, and positive amount. See commented shapes in gear_config.lua.
For chest items with an NBT hash from list(), include that exact hash. Rules
without nbt match only stacks without NBT. Add distinct rules for raw-material
and already-crafted-part choices, and make their labels explain which is which.
Only configured compatible rules with stock > 0 appear. An insufficient
quantity can be selected but cannot pass the review stock check. A recipe's
parts must have unique names; rules should have unique ids.

Review marks required parts with *. Missing required choices, unverified
recipes, storage read errors and insufficient combined stock disable Save
request. Stock is read again when saving. Shared stock demand is added together
across selected parts. Optional parts can be cleared. Choices are held in
memory and are lost on restart.

## Current production boundary

Save request writes a numbered file in requests/ beside the program, with
status awaiting_production_adapter. This does not reserve inventory or run a
queue. The selection clears after a successful save. Production must revalidate
stock before consuming anything; saved requests do not guarantee availability.

This version moves no items or fluids, installs no casts and operates no
machines. outputChest is reserved for the production stage. Before implementing
that stage, we need table/basin inventory and fluid capabilities, cast handling,
recipe fluid amounts, expected output IDs/components, and how raw chest
materials become parts. No placeholder transfer commands are used.

## Verification

Code has been reviewed against CC:Tweaked's monitor, inventory and fluid
peripheral interfaces. It has not been executed in Minecraft or a Lua runtime
here. In-game checks: navigate from each monitor; confirm all three synchronize;
page through Tools; select and clear optional parts; remove stock before saving;
try two selections consuming the same stock; disconnect a configured storage;
and resize a monitor. Confirm no items or fluids move during this stage.


## Layout update: ground-level displays

bottomMargin defaults to 18 text rows, independently reserved on each monitor.
The common workspace ends exactly 18 rows above each monitor's bottom edge;
larger monitors position that workspace lower while preserving the same content.
No touch targets are placed in the reserved area. Requires at least 30 columns
and 11 usable rows (29 total rows with the default margin). Reduce textScale
if available, enlarge the monitor, or deliberately reduce bottomMargin if the
monitor reports too little usable space. Both settings require restart.

Categories, equipment and review now use the same two-column visual style as
the parts/materials workspace. Lists paginate independently to fit the reduced
height. Up/Down are page controls. The left category list stays visible while
browsing items. Review lists each part beside its chosen material; tapping a
part returns to the material workspace. Saving remains blocked by validation.

Pastebin deployment: replace the Gear UI paste contents with gear_ui.lua, then
run the existing update script and restart gear_ui. The UI defaults to an
18-row margin even with an older config; replacing the config paste is optional
unless you want the editable bottomMargin setting. No server file access is
needed. Local edits have not been uploaded to Pastebin automatically.

## Latest layout revision

Supersedes the 18-row margin above: bottomMargin now defaults to 9. Set this
value in gear_config.lua as well: an older explicit bottomMargin=18 overrides
the UI default. Update BOTH the Gear UI and Gear Config Pastebin contents,
or change only bottomMargin to 9 in your existing config to preserve local
assignments. All buttons and touch targets now occupy two rows. Up/Down are
hidden when no page exists in that direction, with one blank row above and
below their reserved positions. Lists leave room for the larger controls.
Requires 30 columns and 20 usable rows (29 total with margin 9). Geometry checks
passed; Minecraft rendering and touch behavior still require in-game testing.

## Other casting category

The former Other category is now Other Tool Parts. Other contains Ingot,
Nugget, Gem, Gear, Rod, Plate and Block, each with a required Material choice.
Other derives options from molten fluid IDs in configured fluid stores and
never offers chest items. Exact cast compatibility still needs production
recipe data; the current category records requests rather than casting.
Amounts per output: Ingot/Plate 90 mB; Nugget 10; Gem 100; Gear 360 (Diamond
400); Rod 45 (Blaze 400). Block uses 810 normally and Amethyst/Glowstone 400.
Diamond, Slime, Emerald, Lapis/Lapiz, Fluxite, Redstone, Quartz, Obsidian and
Glass block choices are temporarily excluded pending confirmation of 100
versus 900 mB per block. No quantity is guessed for those choices.
Update both Gear UI and Gear Demo Pastebin contents for this revision. Config
and scan are unchanged. The demo includes Blaze, Amethyst, Glowstone and Lapis
fluids in addition to the previous samples.

Block correction (supersedes pending amounts above): Fluxite, Glass and
Obsidian use 1000 mB. Diamond, Slime, Emerald, Lapis/Lapiz, Redstone and Quartz
use 900 mB. Amethyst/Glowstone remain 400 mB; default remains 810 mB.
All previously pending choices are enabled. Demo stock now includes every
listed exception so their displayed quantities can be checked in-game.

## Screen-based diagnostics

scan.lua now opens an interactive diagnostic viewer on the computer terminal;
no direct server-file access is needed. Refresh R after connecting blocks.
Use Up/Down and Enter to inspect a block. Inspection lists exact peripheral
name, types, monitor size, item/fluid read and transfer method availability,
fluid contents, inventory slots/IDs/NBT hashes and every exposed method.
Up/Down or mouse wheel scroll; PageUp/PageDown page; B returns to devices.
D prompts for a slot number and displays getItemDetail results. S optionally
saves discovery.txt; Q quits. No data is sent outside the computer.

Prepare one fluid store containing molten iron, a casting table with its ingot
cast, an empty output chest, and the parts chest if available. Enable the wired
modems attached to each block. Use the scanner to report the peripheral names,
fluid IDs, cast item/slot, and available item/fluid transfer methods. Optional
components may remain disconnected; they will simply be absent from the list.
Method availability alone is not proof of a working casting route. The next
stage will test a measured single ingot transfer once these details are known.
The scanner invokes read methods only; it does not start that transfer test.
Code and viewport/read-method checks passed; in-game execution remains untested.

## Casting commissioning test

casting_0 is the basin; casting_1 is the table. Both expose one inventory slot.
The table's cast is not exposed in list(); finished output appears in slot 1.
Observed manual output: ftbmaterials:steel_ingot. Controller fluids observed:
productivemetalworks:molten_iron and productivemetalworks:molten_constantan.

casting_test.lua is separate from the demo UI and makes real transfers only
with explicit collect/iron arguments. Add it as a new Pastebin and download it
as casting_test.lua beside the other files. No updater URL exists for it yet.
- casting_test: read-only inspection.
- casting_test collect: transfers one existing iron/steel ingot from table slot
  1 to chest_2. Run this first to verify output delivery.
- casting_test iron: requires empty table output/fluid, an installed ingot cast,
  90 mB iron at the source and an empty output-chest slot. Sends at most 90 mB
  once, waits at most 60 seconds, validates iron output, then delivers one.

Leave the ingot cast installed. Isolate the table from other fluid feeds and
item extractors during the test. The script records transfer state BEFORE
sending fluid, and blocks another iron request after an incomplete attempt.
It never automatically retries partial transfers or failed deliveries. If it
stops, report its message and inspect before manually changing its state file.
The iron output IDs accepted for this test are minecraft:iron_ingot and
ftbmaterials:iron_ingot; another output is left untouched for inspection.
No cast swapping has been implemented. The UI remains in demo mode.
This test has not been run in Minecraft or a local Lua runtime here.

Cooling correction: the table exposes its result before it can be extracted.
casting_test iron now waits at least 3 seconds after injecting the 90 mB.
Delivery, including collect mode, retries only zero-result item extraction at
0.5-second intervals for up to 10 seconds. It stops immediately after moving
one item. Missing/changed/unexpected output or method errors stop the test.
No fluid transfer is retried. State remains pending on a failed delivery.
Only casting_test.lua changes in this revision; UI/config are unchanged.

## First live UI route and casting progress

Update Gear UI and Gear Config Pastebin contents. No new file is required.
Config liveIronCasting=true enables only Other > Ingot > Iron as a REAL route,
even when demoMode=true. That route reads real fluidStores and offers only
productivemetalworks:molten_iron. Its header says LIVE and review says Cast Iron.
Other categories/recipes remain demo. Setting liveIronCasting=false disables
the live route. Leave the ingot cast installed in casting_1 and keep other
fluid feeds/item extractors isolated during commissioning.

After a live request, the existing bottom three usable rows show status and
a two-row progress bar. The bar fills for 3 seconds AFTER the single 90 mB
insertion succeeds, then waits for confirmed extraction into chest_2. Success
flashes green for 1.5 seconds and fades for 2.5 seconds before controls return.
The reserved bottom 9 text rows remain blank. All monitors share job progress.
Animation updates use the existing 0.2-second UI animation timer; the worker
runs cooperatively alongside navigation/storage polling. Only one cast runs
at a time. Navigation elsewhere remains available while the footer is covered.

The worker uses casting_test_state.txt, so incomplete commissioning tests
block new UI casts and vice versa. Transfer intent is recorded before fluid
insertion. There is no automatic fluid retry or automatic job resume after
restart. Output-only extraction retries run every 0.5 seconds for up to 10
seconds. Unknown output/errors stop the job, leaving a visible error status.
Tap the bottom error status to dismiss it; this does not clear a pending job
or authorize another fluid insertion. Use casting_test inspect/collect to
investigate and complete a pending iron delivery, then restart the UI.
Code flow and geometry checks passed; this integration still needs in-game
verification. Other recipes, automatic cast swapping, bulk jobs and production
assembly remain outside this first live route.

## Quantity, FIFO queue, and separate status panel

Only gear_ui.lua changes. Live Other > Ingot > Iron now has -16/-1/+1/+16
quantity buttons, limited to 1-64 per batch. Review displays the total fluid
required; Queue Iron adds that quantity to a first-in-first-out queue. New
batches may be added while casting runs. Queued fluid demand is accounted for
when accepting another batch, and actual stock is rechecked before every cast.
This applies only to the commissioned live iron-ingot route; other demo routes
still save requests and do not enter the production queue.

The queue panel sits BELOW Reset/Review/Queue in six rows of the previously
blank bottom area. All interactive controls retain the 9-row ground clearance;
the bottom three rows stay blank. Panel content: separator, Items in Queue,
Next Item and batch remaining quantity, casting status, two-row progress bar.
On narrow screens the queue count/next-item text splits across two lines.
Items in Queue counts waiting units, excluding the ingot currently in flight.
Next Item shows remaining units of the earliest waiting batch. Each cast has
its own 3-second progress bar, then confirmed delivery. Between consecutive
items completion flashes briefly; the final completion fades out over 4 seconds.
Queue information remains visible when idle. Reset clears selections/quantity,
not accepted queue entries.

Batches persist in gear_queue.txt. Failures and restarts pause the queue; the
Reset position becomes Resume Queue. If an in-flight ingot was delivered using
casting_test collect, Resume verifies the matching queueToken in the shared
casting_test_state.txt before decrementing that unit exactly once. Unresolved
in-flight transfers cannot be automatically resumed, preventing duplicate fluid
insertion. Fix external preflight problems and press Resume to continue when
there is no unresolved cast. Do not delete state files to bypass recovery.
Keep the test table isolated from other fluid feeds/extractors.

FIFO/count/stock modeling, operation-order checks, Lua block balance and panel
bounds were checked locally. No full Lua runtime or Minecraft test was run for
this revision; first try a batch of 2 and add a batch of 1 while it is casting.

## Welcome, sections, and queue editing

Only gear_ui.lua changes. Startup shows Welcome to the Crafting Center and
Right click to begin. The next screen offers Gear / Tool Parts / Other.
Gear lists Weapon, Armor, Tool, Accessory and Extra. Tool Parts opens a dedicated
part grid; Other opens a casting-shape grid. Back returns through the relevant
section. The shared editor/stock rules remain underneath these separate entry
points; only the commissioned Iron Ingot route performs real casting.

Back/Queue controls in the top-left navigation area open the queue manager from
section/editor screens. Main Menu also has a Queue button. The queue manager
shows batches with -1 and Remove controls, plus Clear waiting items. These
remove only waiting units. A unit currently being prepared/cast/delivered, or
an unresolved in-flight unit after failure, is protected and finishes normally.
Cancellation updates persistent queue entries and frees their fluid reservation.
When paused, Resume and Clear waiting remain independently accessible.

Min sets quantity to 1; Max sets it to 64. Existing +/- controls remain.
After successfully adding a batch the quantity resets to 1. Reset also resets
quantity, and does not erase accepted queued work. Cancellation accounting,
control/grid bounds and Lua block balance were checked locally. Actual Lua
execution and Minecraft verification of this revision remain outstanding.

## Welcome styling and idle navigation

Only gear_ui.lua changes. Welcome is a separate full-display renderer using
monitor text scale 3, with no header or queue panel. Text is #1F2E3D; background
breathes from #1F2E3D to #090E12 over 6 seconds. Text wraps at actual monitor
width and centers vertically/horizontally. If welcome plus prompt cannot fit at
scale 3, it alternates the welcome and Right click to begin every 4 seconds.
A touch anywhere begins. Leaving Welcome restores the configured text scale
and normal palette before drawing regular screens.

Main Menu has no Welcome button and no queue status panel. Select Option has
no colon; the Gear/Tool Parts/Other group is two-thirds of its former width and
centered. The Queue button is consistently upper-right across Main Menu and
crafting sections, muted with no hitbox when queue/in-flight work is empty.
Crafting breadcrumbs use the row below the header. Queue contents remain on
the dedicated queue screen and the status panel on crafting screens.

Every material list starts with None, which clears that part's material. The
separate Clear Material footer button is removed. Required-part validation
continues to block requests if None is chosen for a required part.

Touches on any configured display reset one shared idle clock. After 30
seconds without interaction and no work, navigate to Welcome. With waiting,
in-flight or unresolved queued work, navigate to Queue after 60 seconds.
Background polls, animation and job progress do not reset the idle clock.
Idle thresholds/in-flight cases, control bounds, state-path checks and Lua
block balance passed locally; Minecraft verification remains outstanding.

Welcome typography correction: heading is now approximately scale 1.5,
rendered as compact mosaic lettering on the 0.5 cell grid. It remains white.
Right click to begin stays simultaneously below it at the normal 0.5 text
size in #1F2E3D; welcome/prompt no longer alternate. Background breathes from
#101820 to #009E12. Mixed-size layout and all 64 mosaic patterns were checked;
actual Minecraft appearance remains to be verified. Only gear_ui.lua changes.

## Queue placement, available stock and footer

Only gear_ui.lua changes. Welcome background now breathes #101820 -> #090E12.
The Queue button is full width with a small inset directly below the action
row on Main/crafting screens; it remains disabled when no work is present.
The queue status panel follows it on crafting/queue screens, hidden on Welcome
and Main Menu. The action label now reads Add N Iron to Queue.

Material choices and review summaries include available stock, e.g. Iron
(500 B), with fluids shown in B above 1000 mB and mB below that. Item quantities
are shown as items. Needed quantities remain below, separate from availability.
Long labels are shortened to preserve the stock suffix where possible.

A muted Crafting Center footer occupies the last display row, including
Welcome. With bottomMargin=9, the lower arrangement is: Queue button (2 rows),
separator, waiting count, optional next-item row, status, progress (2 rows),
footer. All elements fit without covering the action controls. Welcome retains
its white mixed-size heading and dark prompt. Geometry/stock-formatting checks
and Lua block balance passed; in-game visual verification remains outstanding.

Latest spacing/footer update: one blank row now separates action controls from
the crafting Queue button. Main Menu Queue instead sits beneath Other, at the
same centered width, and is always enabled even when empty. Footer is now a
blank blue/header-style strip with no text, absent from Welcome. Status layout
uses the last available rows without covering the footer; narrow displays put
the status caption on the progress bar to retain both queue summary lines.
Geometry and Lua block checks passed. Only gear_ui.lua changes.

## Matching editor actions, Gear grids and mapped live ingots

Files changed: gear_ui.lua and gear_config.lua. Editor Reset/Review and
Reset/Add-to-Queue now use equal-width teal buttons with outer insets and a
central gap, matching the reference. Gear categories and equipment use the
same tile-grid renderer as Tool Parts and Other. Weapon order is Knife,
Machete, Sword, Katana (blades), Mace (blunt), Spear, Trident (polearms),
Slingshot, Bow, Crossbow (ranged). Quantity controls are on review only, leaving
material-list pagination available when multiple live materials are enabled.

liveIngotMaterials explicitly maps a fluid ID to label, fluid amount and
accepted output IDs. Iron remains enabled; Constantan is a commented example
until its actual output ID is observed. The legacy liveIronCasting switch is
retained as the live-ingot feature switch for compatibility. All other shapes
and equipment remain demo/request-only; no automatic cast swapping is assumed.

Each queued batch stores its fluid, amount and accepted outputs. Existing
iron-only queues are migrated in memory without dropping entries. Reservations
are per fluid, so one material does not consume another material's availability.
The worker can collect one recipe's fluid across multiple configured stores,
limiting each transfer to the remaining required volume, and checks the
finished item against that batch's accepted outputs. Do not list aliases to
the same shared store twice. A failure pauses without repeating fluid insertion.

Resume can now attempt delivery-only recovery within the UI for an in-flight
job with a matching token and a confirmed full fluid transfer. It will not
inject fluid. A missing, still-cooling, blocked or unexpected output leaves the
queue paused for inspection/retry. A successful delivery is recorded and counted
once before proceeding. Partial/uncertain fluid transfers still require manual
inspection. Local accounting, operation/path checks, action/grid bounds and
Lua delimiter/block checks passed; in-game execution of this revision remains
to be verified. Next commissioning material: manually cast Constantan and read
the exact ingot item ID in scan before adding its mapping.

Output-ID clarification: live ingot mappings no longer require outputs.
When omitted/empty, the worker accepts the new output from the initially empty,
isolated casting table after cooling, records its actual registry ID, and
moves one item to output. If outputs is supplied, exact ID validation remains.
Changing output identity during delivery/recovery pauses processing. Fluid ID,
amount and cast compatibility remain recipe requirements; station inventory
presence alone cannot establish those. Constantan is now enabled with the
user-confirmed ftbmaterials:constantan_ingot output and 90 mB requirement.
Files changed: gear_ui.lua and gear_config.lua. This generic-output option
currently applies to the live ingot/table route, not automatic basin recipes
or arbitrary equipment parts. Local path/acceptance checks passed; in-game
verification remains outstanding.

## Automatic molten-material discovery

gear_ui.lua and gear_config.lua now support autoDiscoverMolten=true (also the
UI default when omitted). Other casting menus use actual fluid storage even
while equipment/chest demo recipes remain enabled. The existing 3-second poll
adds/removes options and updates amounts from tanks(), sums the same fluid
across uniquely named configured sources, and ignores empty/non-molten fluid
entries. An unavailable selected material cannot pass review validation.

Live Ingot no longer uses a fixed material whitelist: newly discovered molten
metals receive a 90 mB ingot recipe and optional/unrestricted output detection.
Explicit liveIngotMaterials entries override label, amount and expected output;
enabled=false blocks an individual fluid from ingot casting. Known non-ingot
fluids (gems, basic glowstone, glass, obsidian, etc.) still appear but cannot
queue an Ingot. They must use matching cast shapes; those additional shapes
remain live-stock previews/request-only until their production paths are
commissioned. Unknown custom fluids may need explicit recipe overrides.
Gear/Tool Part compatibility still requires pack recipe data; their demo rules
have not been promoted to live recipes by this change.

Discovery/aggregation/depletion modeling, non-ingot exclusion, output policy,
transfer/cooling path checks and Lua block/delimiter checks passed locally.
New material discovery/casting still requires in-game verification. No monitor
layout or queue-file migration is required for this revision.

## Dedicated tables and live Other cast shapes

Files: gear_ui.lua, gear_config.lua, and new station_setup.lua. Material choices
sort case-insensitively by name with fluid ID tie-breaking; None stays first.
The Other queue now supports Ingot, Nugget, Gem, Gear, Rod, Plate and Block.
Each accepted batch snapshots its shape, dedicated station, fluid, volume,
outputs and timing. Old ingot-only queue records retain their table assignment.

Known assignments: Ingot -> productivemetalworks:casting_1, Block ->
productivemetalworks:casting_0. Other shapes are unassigned until station setup;
review blocks requests without a dedicated station, and shared assignments
between cast types are rejected. No cast swapping or cast-chest extraction is
attempted: upstream source shows castInv has no normal item capability and
itemHandler exposes only results. Use permanently installed casts per table.

New deployment action: publish station_setup.lua in its own Pastebin, download
it beside the other scripts, and run station_setup. It lists wired casting
peripherals, assigns selected stations, rejects duplicates, and saves
gear_stations.txt. This local data file overrides config station defaults and
survives normal updates. Restarting the UI loads the assignments. Use 0 to
unassign a role; A adds custom roles for future tool-part casts. Extra roles
are saved, but do not invent or enable missing Silent Gear part recipes.
The setup tool does not touch machine contents or move items/fluids.

Volumes follow the user's confirmed material rules. Ingot/Plate 90, Nugget 10,
Gem 100, Gear 360 or Diamond 400, Rod 45 or Blaze 400; Block 810 normally,
900 for listed gem materials, 1000 Fluxite/Glass/Obsidian, 400 Amethyst/Glowstone.
Per-shape/fluid overrides can be supplied using castMaterialOverrides. Material
compatibility prevents obvious metal/gem cast mismatches. Unknown custom
recipes may need explicit overrides, and live tests must confirm pack values.

Cooling estimates scale from measured ingot cooling: 3 seconds per 90 mB,
minimum 0.5 seconds (Iron Block estimate 27 seconds). Each station can override
coolSeconds and deliverySeconds. Extraction readiness is still determined by
actual successful item transfer, with a 120-second delivery retry window.
The progress bar uses each job's cooling estimate. Completion requires delivery.

Next commissioning test: one Iron Block via Other > Block, which sends at most
810 mB to casting_0 and delivers the block to chest_2. Keep the basin empty of
casts/ingredients for ordinary storage blocks. Then assign and test the other
cast tables one item at a time. Equipment/Silent Gear part production is still
pending recipe mapping, even if additional custom station roles are registered.
Local amount/routing/timing models, queue migration, assignment uniqueness,
alphabetical sorting and Lua delimiter/block checks passed. No in-game run of
this revision was performed here.

## All 40 cast roles and template insertion test

Station setup now includes the six basic table casts plus all 34 requested
roles. The fixed plan assigns Ingot/Nugget/Gem/Gear/Rod/Plate to casting_2..7,
then the user's requested list in order to casting_8..41. casting_0 remains
Block basin; casting_1 is reserved for manual tests and cannot be assigned as
a permanent production station. Equipment casts record part=Main; Tool Rod
and Tip record their own part names. Leggins is normalized to Leggings.
See station_map.md for the complete table-by-table plan.

Files changed: station_setup.lua, gear_config.lua, gear_ui.lua (Dagger added
to the equipment catalog), casting_test.lua (uses manualCastingTable before
production castingTable). Normal production Ingot now defaults to casting_2.

Run station_setup and select P to apply the fixed 2-41 plan to persistent
gear_stations.txt, including replacing older assignments that still point at
the manual table. The previous bindings are saved to gear_stations.txt.bak.
Existing custom roles conflicting with the fixed plan are unassigned, not
silently given duplicate station ownership. Installed casts cannot be inferred
from the name/plan; these are intended role assignments. Ordinary edits remain
available. Current live Other recipes can use their dedicated assignments;
registering equipment cast roles alone does not invent missing part recipes.

T performs one template insertion experiment. Choose 0 for the manual table
or select an assigned role, then choose an actual occupied SLOT in the cast
chest. The tool prints item ID, counts and destination; verifies empty output
inventory and no fluid, rechecks the chosen source identity, and calls
castChest.pushItems(destination,slot,1) exactly once. It shows actual items moved
and resulting inventory. No fluid, production, mass transfer or automatic retry
is performed. Use a physically cast-free destination for the experiment.
The normal inventory API cannot verify hidden-cast occupancy.

Zero moved means the normal insertion was rejected. One moved proves item
transport only: visually confirm whether it installed a cast. Upstream source
shows a separate castInv without a capability and an output-only handler that
rejects inserted items, so successful automatic cast loading is not assumed.
A screenshot of this test's result determines whether another mechanism is
needed; the dedicated-station production route works with manually installed
casts regardless of the template-transfer experiment.

Checked exactly 40 unique stations in range 2-41, part-role metadata, protected
manual table, single-item transfer limits/preflight, and Lua block/delimiter
balance. The new setup/test has not been executed in Minecraft here.

## Station Setup navigation refresh

Only station_setup.lua changes. The tool now uses a paged terminal viewer like
scan: arrows select/scroll, PageUp/PageDown page, mouse wheel scrolls, Enter
opens/chooses, B/Backspace returns with previous selection preserved, Q quits.
The role list shows connected/missing markers and compact station names.

Enter opens role details; E opens the station picker; U unassigns; D inspects
station items, fluids and methods. P opens the fixed-plan preview; Enter applies
it and retains the saved-assignment backup behavior. A creates a custom role.
R refreshes discovery or cast-chest contents in their respective pickers.

T opens cast-chest item selection for the selected role; M uses casting_1 for
manual testing. Select a chest item with arrows/Enter, review its ID, source
slot and target, then Enter attempts exactly one transfer. B cancels the review
without movement. Results/errors remain in a scrollable report. Successful or
uncertain transfer attempts leave the armed test page, preventing Enter from
immediately repeating a transfer. D in the chest list shows full item details.
Only the explicit test-confirmation page invokes pushItems; no fluid is sent.

Checked viewport/footer bounds, navigation history, test review path,
one-item/no-fluid limits, and Lua block/delimiter balance. In-game operation
of the new navigation still needs user testing. Existing gear_stations.txt and
its 40-cast plan remain compatible; no reassignment is required for this UI edit.

## Console Control Center

New file: control_center.lua. No existing scripts change. Put it beside the
other scripts and launch control_center on an Advanced Computer. The menu
contains Gear UI, Station Setup, Diagnostics, Update and read-only/collect/iron
casting-test actions. All launches use fg and a managed wrapper in a separate
foreground tab. Control Center remains in its own tab. Additional handlers can
be added to the programs table with unique IDs, filenames and argument lists.

Navigation matches the established style: arrows/PageUp/PageDown, Enter run
or focus an already-running managed instance, D details, F focus existing tab,
R refresh and B back. Finished programs retain their output until Q closes
that child tab. Use the tab bar to return to Control Center while Gear UI runs.
Selecting Enter on a finished program launches a fresh instance; F opens its
existing result tab. Session discovery/heartbeats avoid duplicates started
through Control Center. Independently launched scripts are not managed.

Q or Ctrl+T IN CONTROL CENTER broadcasts shutdown to all its managed wrappers,
including background Gear UI and finished-result tabs. The wrapper abandons
its runner at the next yield and returns; production sends no further queued
casts. Existing in-flight cast/queue journals remain intact, so relaunch uses
the existing paused/recovery behavior. The scripts do not force-stop physical
machine cooling. Closing an individual child tab does not close Control Center
or other child tabs. No computer reboot or unrelated-program termination occurs.

The manual mutating casting tests share a recovery-state file with production,
so the launcher blocks running them concurrently with managed Gear UI. Read-only
inspection, scans and station setup can run alongside it. Updating files does
not automatically restart running programs. A Pastebin URL for Control Center
is needed before adding this new file to update.lua's download list.

Checked foreground-launch/focus policy, managed shutdown paths, test conflict
guards, viewport bounds and Lua block/delimiter balance locally. Full multishell
execution and in-game operation remain to be verified.
