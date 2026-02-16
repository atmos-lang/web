# Fix Clock So It Doesn't Hang

## Problem

The clock environment uses `os.clock()` with a blocking polling loop (`while true ... step() ...`). In the browser, this freezes the page.

## Approach

**JS drives the loop with a timer, emitting clock events directly.**

Instead of Lua owning the loop, JS uses `setInterval` to call `atmos.emit("clock", "tick")` each tick. This means:

1. **Split `atmos.call(f)`** into init + emit:
   - `atmos.init(f)` — spawn the coroutine, register the environment, but don't loop
   - `atmos.emit(tag, val)` — push an event and resume the coroutine
2. **JS side** sets up the timer:
   ```js
   await lua.doString('atmos.init(f)')
   const timer = setInterval(() => {
       lua.doString('atmos.emit("clock", "tick")')
   }, 16)  // ~60fps
   ```
3. **No clock env needed in Lua** — the `setInterval` *is* the clock
4. **Stop** by clearing the interval when the program finishes

## Why This Approach

- No Wasmoon async hacks — each emit is a short synchronous call
- Timer interval is the clock source — no polling needed
- Natural browser pattern (like game loops, requestAnimationFrame)
- Easy to add pause/stop — just `clearInterval`
- UI stays responsive by design
- Collapses the entire clock env into one `setInterval` on the JS side
