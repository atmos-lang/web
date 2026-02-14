# Plan: Fetch Lua files from GitHub raw content

## Analysis

**Yes, and `index-fetch.html` already does 90% of this.** It fetches modules at
runtime via `fetch()` from relative URLs. The only change needed is switching the
base URL from relative paths to GitHub raw content URLs:

```
https://raw.githubusercontent.com/atmos-lang/web/master/web/try/atmos/lua/
```

This would allow:
- Removing all files under `web/try/atmos/lua/` from this repo
- Removing `build-self.py` entirely (no need to inline if we always fetch)
- `index-self.html` (the generated file) could also be removed
- Only `index-fetch.html` remains, pointing at GitHub raw URLs

**Caveat:** GitHub raw content has no CORS headers for cross-origin requests from
arbitrary domains. This works if the HTML is served from `*.github.io` or opened
locally as `file://`, but **will fail on a custom domain** (like DreamHost
deployment) due to CORS. Workarounds:
- Use jsDelivr CDN which proxies GitHub with CORS:
  `https://cdn.jsdelivr.net/gh/atmos-lang/web@master/web/try/atmos/lua/`
- Or keep `index-self.html` (inlined, no fetching, no CORS issues) for production
  and use `index-fetch.html` only for development

---

## Implementation Steps

### Step 1: Switch `index-fetch.html` to use GitHub URLs via jsDelivr

Update the `LUA_MODULES` paths in `index-fetch.html` to use a `BASE_URL`:

```javascript
const BASE_URL =
    'https://cdn.jsdelivr.net/gh/atmos-lang/web@master/'
    + 'web/try/atmos/lua/';

const LUA_MODULES = {
    'streams':         'streams/init.lua',
    'atmos':           'atmos/init.lua',
    // ...same relative paths, but without 'lua/' prefix
};

// In fetchModules(), prepend BASE_URL:
const resp = await fetch(BASE_URL + path);
```

### Step 2: Remove local Lua files

Delete the entire `web/try/atmos/lua/` directory — modules are now served from
GitHub/jsDelivr.

### Step 3: Remove build-self.py and index-self.html

- Delete `build-self.py` (no longer needed)
- Delete `web/try/atmos/index-self.html` (no longer generated)

### Step 4: Rename index-fetch.html → index.html

Since it's now the only variant, give it the canonical name.

---

## Risk: CORS & CDN caching

- **jsDelivr** caches aggressively. After pushing new Lua code, there may be a
  delay before the CDN picks it up. Use versioned refs (`@v1.0`) or commit SHAs
  instead of `@master` for production.
- If jsDelivr is unacceptable, keep `build-self.py` for production builds and
  use `index-fetch.html` (with relative paths) only during development when
  served locally.

## Alternative: Keep both modes

Keep `index-self.html` for production (zero-fetch, works everywhere) and
`index-fetch.html` with GitHub URLs for a live-updating demo. This avoids the
CORS/caching issues entirely but means keeping the Lua files and build script.
