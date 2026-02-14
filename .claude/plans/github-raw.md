# Plan: Fetch Lua files from GitHub raw content

**DONE** — `build.sh` fetches all Lua modules from GitHub raw content
(pinned to version tags) and inlines them into `web/try/atmos/index.html`.
The `index-self.html`, `index-fetch.html`, `build-self.py`, and
`build-github.py` variants have all been removed. Only `build.sh` and
`index.html` remain.
