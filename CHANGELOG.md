# Changelog

This log records major build changes. Script metadata versions remain separate
and identify individual files. Unreleased entries describe local work that has
not yet been committed or published as a release.

## Gear UI 2.1.1 - Review tab spacing (Unreleased)

- Review tabs now use a distinct active marker, muted inactive background, and
  separate underline, with a blank row before content.
- Selections and Stats & Traits share the same content start; selection paging
  stays below the list and above quantity controls without covering tab buttons.

## Updater 1.4.0 - Disk space fix (Unreleased)

Date: 2026-11-17

- Removes previous updater-managed script backups, including legacy script copies;
  cast-tracking, queue, settings and Station Setup state backups remain intact.
- Validates downloads in memory instead of staging every script on disk.
- Skips unchanged scripts and checks free disk space before installation.
- Retains originals in memory for rollback during this run; no persistent script
  backups are created. A power loss during installation requires rerunning updates.

## 2.1.0 - Gear material review (Unreleased)

Date: 2026-11-17

- Review now includes Selections and Stats & Traits tabs for Gear and Tool Parts.
- Added a local FTB Skies 2 1.25.3 snapshot: 77 compatible materials, 72 trait
  definitions, and all 57 supported main-casting fluid mappings.
- Shows relevant material base stats, part modifiers, per-part trait levels and
  descriptions. Conditional traits are marked; levels are not summed together.
- Raw chest selections retain unambiguous material IDs. Finished/mixed parts and
  unmapped custom materials explicitly report unavailable stats instead of guessing.
- This first preview shows material contributions, not calculated finished equipment
  totals. Grades, synergy, trait effects and equipment multipliers remain excluded.
- Preview paging preserves quantity and queue controls and performs no inventory
  or file reads during drawing. Updater includes both new preview modules.

## 1.1.0 - Control Center organization (Unreleased)

Date: 2026-11-16

### Added

- Main categories: Applications, Console Scripts, and Tools.
- Script metadata category field, inherited by individual command actions.
- Open Shell in Tools and an S shortcut available throughout Control Center.
- A new empty managed foreground shell tab for each Open Shell action.
- This changelog for future major builds.
- Read-only cast-chest checker with Missing/Found/All/Unknown views.

### Changed

- Gear UI is under Applications; Station Setup and Diagnostics are under
  Console Scripts; Update and casting tests are under Tools.
- Scripts without category metadata default to Console Scripts.
- Typing exit closes a shell tab; exiting Control Center still closes all
  managed tabs, including shells.
- Back returns from a category to the main category menu.
- Canonical source/working files now live in the local GitHub checkout.
- The updater checks its own source first, installs and reboots if changed,
  then updates the remaining scripts on the next startup.
- Previous backup-folder changes are included: backups/ is excluded from
  discovery, and updater/station backups are stored there.

### Script versions

| Script | Version |
|---|---|
| control_center.lua | 1.2.2 |
| gear_ui.lua | 2.0.0 |
| station_setup.lua | 1.2.2 |
| scan.lua | 1.0.1 |
| update.lua | 1.2.0 |
| cast_check.lua | 1.2.1 |
| cast_tracking.lua | 1.1.6 |
| casting_recovery.lua | 1.0.0 |
| casting_test.lua | 1.0.1 |
| startup.lua | 1.0.0 |
| gear_config.lua | 1.3.0 |
| gear_casting_data.lua | 1.0.0 |
| gear_kit_data.lua | 1.0.0 |
| gear_request.lua | 1.0.0 |
| gear_chest_data.lua | 1.1.0 |
| chest_catalog.lua | 1.0.0 |
| chest_delivery.lua | 1.0.0 |
| gear_demo.lua | 1.0.0 |

### Deployment and validation

- Commit and publish the changed scripts together so their metadata categories
  arrive with the updated launcher.
- No station reassignment or queue-state reset is required.
- Local metadata/category, resource-lock, navigation-path, layout-bound and Lua
  structural checks passed.
- In-game navigation, shell-tab behavior and managed shutdown still need testing.

## 1.0.x - Foundation builds

Historical summary, before the 1.1.0 organization changes:

- Synchronized monitor interface, material selection and review.
- Live casting queue, quantities, cancellation, recovery and progress display.
- Forty dedicated cast assignments plus a basin and manual test station.
- Paged console diagnostics, station setup and casting tests.
- Managed foreground tabs and shutdown from Control Center.
- Dynamic script discovery, metadata versions and parity checks.
- GitHub updater, commit-pinned downloads, rollback and automatic startup.

## Maintaining this log

For each major build, add a new section above the previous build. Record the
user-facing changes, changed script versions, any migration actions and test
status. Mark it Unreleased until the build is published. Routine small fixes
can remain under the current build while their individual script versions are
incremented. Do not claim a release or test result before it actually occurs.

### Cast availability integration
- Check Cast Chest now saves cast_availability.txt on every scan, including scan errors.
- Gear UI flags missing required casts in red and report problems in amber; tapping explains the issue.
- Queue submission and each new cast recheck cast availability.

### Bulk station cast delivery
- Station Setup S previews and sends one available matching cast to each assigned table.
- Skips missing, ambiguous, disabled, conflicting, disconnected or occupied destinations.
- Saves per-role results in station_delivery_report.txt; uncertain transfers stop the batch.

### Installed casts and output verification
- Shared cast_tracking.lua tracks chest stock and recorded/verified installations.
- Station Setup records deliveries; I/X confirms installed/removed in role details.
- Cast checker preserves installed records when rescanning the chest.
- Gear UI installs missing available casts, verifies output names before collection,
  and pauses with physical table locations on wrong/missing output.
- update.lua v1.0.7 includes the new shared helper.

### Queue error recovery fixes (Gear UI 1.2.1)
- Zero-fluid rejection reports a missing/incompatible cast and physical table location; real partial pours report measured amounts.
- Paused failed jobs can be removed, with active journals archived and table contents preserved.
- Home sits beside Back; opening the queue from an error no longer traps navigation.
- Queue rows show pouring/cooling/transfer progress or a clickable paused-job error.

### Automatic cast stock refresh (Gear UI 1.2.2, Cast Tracking 1.0.1)
- Gear UI scans and saves cast availability at startup, on its normal stock poll,
  after casting failures, and before Resume. Cast Checker is no longer required.
- Successful cast installation and missing/suspect state updates refresh chest
  quantities and installed records together, including Station Setup transfers.
- Unreadable inventories are reported as unavailable data rather than stale stock.

### Cast-menu performance fix (Gear UI 1.2.3, Cast Tracking 1.0.2)
- Drawing buttons reads an in-memory cast snapshot, with no inventory scans or installation-file reads per button/monitor.
- Periodic cast scans run in a separate parallel worker; production actions still revalidate live state.
- Recognizable cast registry names avoid detail calls; NBT-specific display names are cached for 30 seconds.

### Wired monitor drawing (Gear UI 1.2.4)
- Monitor rendering composes in memory, then sends only changed rows with blit.
- Unchanged rows/palette values are not sent again. Intermediate clears, cursor moves and style changes stay local.
- The UI flushes each finished frame after event handling, including welcome/pulse updates; all monitor flushes run concurrently.

### Error screen presentation (Gear UI 1.2.5)
- Resume Queue is restricted to Queue and Error Report screens.
- Cast Availability is now titled Error Report.
- Headers and footers turn red while the queue is paused or an error report is open; Welcome remains unchanged.

## 1.3.0 - Bounded casting recovery (Unreleased)

- After five seconds in item transfer, query table contents and recover with 100 mB
  of the fluid actually present, waiting three seconds between attempts.
- Not Enough Fluid stops immediately; Resume re-queries the table before another
  attempt. Attempts persist across resumes, with a 20-top-up / 90-second bound.
- Wrong-type outputs are delivered once and reported with actual/expected cast
  and physical table location. The requested unit stays queued for a later retry.
- Wrong casts alone set persistent TableError, mark installation missing, and
  disable new queues for that table and dependent equipment. Chest stock still
  records spare casts. Missing spares are reported separately.
- Clear Errors on Error Report clears all TableError flags after manual correction.
- Partial/uncertain recovery pours, rejected transfers, mixed/changed fluids,
  blocked output, and remaining fluid stop recovery for inspection.
- Added casting_recovery.lua v1.0.0; updater v1.0.8 includes it automatically.

### Revalidate persistent table errors (Gear UI 1.3.1)
- Clear Errors queries every affected table before clearing saved locks, including stale wrong-output journals.
- Wrong output, remaining fluid, conflicting assignments and unreadable tables stay blocked with current location/details.
- Matching outputs verify installation. Empty, fluid-free tables clear stale locks without claiming the hidden cast is verified.
- A wrong-output journal is released for retry only when that specific table passes revalidation.

### Recover interrupted installation records (Cast Tracking 1.1.2)
- Loads a validated primary, pending save, or backup instead of failing solely because the primary is missing.
- Backup recovery preserves locks/uncertain transfers and requires installation verification.
- Saves back up a complete surviving source before reusing pending files and validate the new record before replacement.
- In-process readers use a stable commit snapshot; readers never restore files into an active commit gap.
- Unrecoverable/corrupt originals are retained for inspection rather than silently reset.

## Control Center 1.2.0 - Text files (Unreleased)

- New Text Files section discovers .txt files below the computer's script folder, including reports, requests and backups (up to six subfolder levels).
- Enter opens a built-in read-only, wrapped text reader; arrows/pages/mouse wheel scroll, B returns, R reloads/rescans.
- Files are read only when opened/reloaded, not on every heartbeat redraw. The reader displays up to 512 KiB with a truncation notice for larger files.
- Small terminals page the section list so the fourth section does not overlap navigation controls.

### Text-reader colours (Control Center 1.2.1)
- Read-only highlighting colours error/success/warning log lines and headings/table names.
- Serialized keys, strings, numbers, booleans and status values have distinct colours; tableError=true is red and false is green.
- Highlighted rows are cached until reload or terminal-width changes. Monochrome terminals retain plain text.

### Avoid global recovery lockout (Gear UI 1.3.2, Cast Tracking 1.1.3)
- Artificial suspect reasons created by backup recovery migrate automatically to unverified, including already saved records.
- Unverified stations can perform the next requested cast, which verifies the output; no extra test job is added and no duplicate cast is inserted.
- Actual TableError locks, pending transfers and genuine suspect states remain protected.
- A missing cast still becomes missing on zero acceptance; a wrong cast still sets TableError through output verification.
- Station Setup bulk delivery skips unverified installations; Text Reader colours unverified as a warning.

## 1.4.0 - Gear UI Utilities (Unreleased)

- Utilities button is anchored at the bottom of the main menu.
- Reset Installed Cast List reviews and deletes the primary installation record,
  pending save, backup and staged backup, then refreshes cast availability.
- Physical casts and queue data are unchanged; waiting jobs pause until Resume.
- Reset is blocked during active or unresolved in-progress casting jobs.
- Cast Tracking v1.1.4 exposes the shared reset operation and retains the primary
  until last if file deletion fails partway through.

## 1.5.0 - Live Tool Rod and Tip casting (Unreleased)

- Tool Parts > Tool Rod and Tip now select real stored, compatible molten materials and queue live casts at their assigned stations.
- Material data extracted from installed FTB Skies 2 1.25.3 (SGear Metalworks 1.5.0, Silent Gear 4.2.1.1 and Productive Metalworks 1.15.1): 53 Tool Rod fluids and 19 Tip fluids.
- Recipe volume is the bridge recipe's two-material requirement multiplied by each material's real melting amount; for example Iron costs 180 mB and Diamond 200 mB.
- Existing review, quantities, fluid reservations, error locks, output delivery and bounded recovery also apply to these routes.
- Silent Gear's silentgear:rod output is classified as Tool Rod, distinct from generic metal Rod.
- liveToolPartCasting enables these routes even while remaining gear screens use demo fixtures. Other tool parts and equipment requests remain at their previous stage.
- The known manual-removal-before-delivery issue is deferred, as requested.
- Added gear_casting_data.lua; updater 1.0.9 includes the helper.

## 1.6.0 - Live chest-supplied Tool Parts (Unreleased)

- Binding, Grip, Lining, Cord, Fletching and Coating now select compatible stock from the parts chest and deliver through the existing queue.
- Finished parts retain exact item/NBT/display identity; raw materials are clearly labelled and delivered as manual-crafting bundles.
- Material rules and counts come from installed FTB Skies 2 1.25.3. Cord raw bundles need three material items; raw Coating bundles include a glass bottle.
- Shared item reservations include queued quantities and extra ingredients.
- Per-component delivery journals let Resume continue a known partial bundle without resending completed components. Uncertain transfers require inspection instead of automatic repetition.
- Parts scanning runs in the background; rendering uses cached material rules and stock. These routes use real storage even with demoMode=true.
- Added gear_chest_data.lua, chest_catalog.lua and chest_delivery.lua; updater 1.1.0 includes them.

## 2.0.0 - Live Gear part kits (Unreleased)

Date: 2026-11-17

- 32 Gear entries now queue their main cast, required rod/cord/fletching/lining,
  and selected compatible chest extras for manual assembly.
- Main casting costs, required part types and output IDs come from the locally
  installed FTB Skies 2 1.25.3 recipes. Armor Lining remains required by user policy.
- Per-part material menus use real compatible stock even while demoMode is enabled.
- Validate combined fluid/chest demand and queued reservations before adding any
  component jobs. Each kit's casting jobs and chest bundle remain together in FIFO order.
- All jobs share the existing progress, recovery, table locks, cancellation and
  persistence mechanisms; kit/request identifiers are recorded in queue batches.
- Output IDs explicitly classify Boots, Leggings, Fishing Rod and Shears components
  whose names differ from menu labels.
- Added optional chest-supplied Tip rules; standalone Tip casting remains unchanged.
- Mace and Elytra explain unavailable routes. Jewelry Setting remains a placeholder
  until its manual-assembly material rule is verified; None is still permitted.
- Added gear_kit_data.lua and gear_request.lua; updater 1.2.0 includes both.
