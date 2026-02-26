# Plan: env-js

## Context

Adopt a build-based approach for the three browser IDE pages
under `web/try/`. A `build.sh` generates versioned HTML files,
CI verifies rebuilds match committed files, and a proper README
documents everything.

## Steps

- [x] Step 1 — Create `build.sh` + `exs/` samples
- [x] Step 2 — Generate versioned files (`index-v0.5.html`)
- [x] Step 3 — Remove unversioned `index.html` files
- [x] Step 4 — Update CI/CD workflow (`deploy.yml`)
- [x] Step 5 — Write `README.md`

## Files

| Action | File |
|--------|------|
| CREATE | `build.sh` |
| CREATE | `web/try/lua/index-v0.5.html` |
| CREATE | `web/try/lua-atmos/index-v0.5.html` |
| CREATE | `web/try/atmos/index-v0.5.html` |
| DELETE | `web/try/lua/index.html` |
| DELETE | `web/try/lua-atmos/index.html` |
| DELETE | `web/try/atmos/index.html` |
| MODIFY | `.github/workflows/deploy.yml` |
| REWRITE | `README.md` |
