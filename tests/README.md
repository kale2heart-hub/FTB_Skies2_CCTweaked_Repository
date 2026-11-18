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
