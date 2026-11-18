# Fluid network checks

Requires Python and `lupa` with its Lua 5.2 runtime (`python -m pip install lupa`).
Run from the checkout: `python tests/test_fluid_network.py`.

These tests use in-memory files, computers, modem replies and peripherals.
They verify queue reservations, stale heartbeats, distinct display/destination
assignments, measured partial transfers, durable receipts, replay rejection,
interrupted journals, client timeouts, monitor drawing, persisted buffer queues,
automatic block batches, console setup, and Lua 5.2 compilation. They do not
connect to Minecraft or move actual items/fluids.
