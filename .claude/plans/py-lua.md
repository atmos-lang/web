# Plan: Convert build-self.py to Lua

## Analysis

**Yes, but not practical here.** The script does simple file I/O (read 16 files,
concatenate into an HTML template) — trivially expressible in Lua. However, no
Lua interpreter is installed on this system (no `lua`, `luajit`, `lua5.x`), and
installing one adds a dependency. Python is already available everywhere (CI,
local dev, this environment). Converting to Lua gains nothing and adds friction.

**Better alternative:** Convert to a **Node.js script** — Node is commonly
available in web projects and already implied by the JS/Wasmoon toolchain. But
even that is a lateral move; Python works fine.

## Implementation Steps (if pursued)

### Step 1: Install Lua interpreter

Add `lua5.4` (or `luajit`) as a system/CI dependency.

### Step 2: Rewrite build-self.py in Lua

Port the file I/O logic:
- `io.open()` to read each of the 16 Lua module files
- String concatenation to build the HTML template
- `io.open()` to write `index-self.html`

### Step 3: Update CI/CD

Change `.github/workflows/deploy.yml` to call `lua build-self.lua` instead of
`python build-self.py`.

## Recommendation

**Don't do this.** Python is the right tool. The conversion adds a dependency
for zero benefit.
