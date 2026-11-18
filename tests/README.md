# Fluid network checks

Requires Python and `lupa` with its Lua 5.2 runtime (`python -m pip install lupa`).
Run from the checkout: `python tests/test_fluid_network.py`.

These tests use in-memory files, computers, modem replies and peripherals.
They verify queue reservations, stale heartbeats, distinct display/destination
assignments, measured partial transfers, durable receipts, replay rejection,
interrupted journals, client timeouts, monitor drawing, persistent per-basin queues,
automatic block batches, concurrent cooling, verified block extraction, partial
pours, blocked output, restart recovery, explicit uncertain-outcome resolution,
waiting-job cancellation, bounded time/attempt limits, console setup, and Lua 5.2
compilation. They do not
connect to Minecraft or move actual items/fluids.

Dedicated-store tests also verify exclusive main/Gear routing, 10,000 mB defaults,
refill priority, per-fluid/default/zero targets, blocked capacity, queued demand,
measured partial refills, restart-safe receipt IDs, selector overlap validation,
and saved on-monitor minimum edits without losing device assignments.

Ownership-exchange checks cover role-specific menus, independent station-range
presets, server-side monitor/storage/basin/chest/peer conflicts, registration-only
pour authority, heartbeat re-registration after restart, and client quarantine.

Missing-device tests exercise red category counts and retained offline entries
for every single/list device field, deselection, and disconnect/reconnect updates.

Computer-picker checks run the real Setup key/event loop through discovery,
refresh, role responses, wrong-role rejection and save without numeric input.
They also cover stale/mismatched replies, self exclusion and offline partner removal.

Queue-wide scheduling tests verify mixed-material jobs fill the basin pool,
finished jobs release capacity, cooling work survives restoration, duplicate
ownership is rejected, and automatic batches are admitted ahead without growing
an unbounded backlog.

`python tests/test_pipe_casting.py` exercises the Pipez feed model and actual
monitor worker, including material barriers, limited drawer capacity, ten-second
return-first recovery, exact top-up, checkpoint replay, bounded retries, missing
fluid, a stalled tank and blocked output. It requires the same Lua 5.2 Lupa runtime.

Large-batch checks cover the 55,300,000 mB default, material-specific Max,
over-capacity rejection, automatic batches above 64, narrow-screen quantity
labels and a 55,299,510 mB feed. Empty basin mocks return nil throughout Pipez
recovery tests; malformed non-table inventories produce named errors.

Automatic minimum tests check rejection below 64 blocks and admission exactly
at 64 and above; manual small-quantity coverage remains in the casting tests.

`python tests/test_updater.py` checks selective downloads (zero for unchanged
installations; only the changed file otherwise), updater-first reboot, download
and hash validation, rollback and space failures with mocked GitHub/file storage.
