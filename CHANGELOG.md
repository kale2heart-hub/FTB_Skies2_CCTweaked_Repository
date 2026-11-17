# Changelog

This log records major build changes. Script metadata versions remain separate
and identify individual files. Unreleased entries describe local work that has
not yet been committed or published as a release.

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
| control_center.lua | 1.1.0 |
| gear_ui.lua | 1.3.1 |
| station_setup.lua | 1.2.1 |
| scan.lua | 1.0.1 |
| update.lua | 1.0.8 |
| cast_check.lua | 1.2.1 |
| cast_tracking.lua | 1.1.1 |
| casting_recovery.lua | 1.0.0 |
| casting_test.lua | 1.0.1 |
| startup.lua | 1.0.0 |
| gear_config.lua | 1.0.0 |
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
