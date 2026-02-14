# Fix Clock So It Doesn't Hang

## Problem

The clock environment uses `os.clock()` with a blocking polling loop (`while true ... step() ...`). In the browser, this freezes the page.

## Options

**A) Run the entire Atmos program synchronously**
- Simple approach — keep the blocking loop as-is
- Fine for short programs, freezes UI for long ones
- Good for a first version with small examples

**B) Use Web Workers or async stepping**
- More complex but non-blocking
- Better UX for longer-running programs
- Future improvement

## Plan

Start with option (A) — keep it simple. Adapt `os.clock()` for the browser (e.g. `performance.now()` or `Date.now()`) but keep synchronous execution. Improve to (B) later if needed.
