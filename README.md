[![Web](https://github.com/atmos-lang/web/actions/workflows/deploy.yml/badge.svg)](https://github.com/atmos-lang/web/actions/workflows/deploy.yml)

# web

## Sites

### Dev

- https://www.dev.ceu-lang.org/atmos/try/atmos/
- https://www.dev.ceu-lang.org/atmos/try/lua/
- https://www.dev.ceu-lang.org/atmos/try/lua-atmos/

### Pro

- https://www.ceu-lang.org/atmos/try/atmos/
- https://www.ceu-lang.org/atmos/try/lua/
- https://www.ceu-lang.org/atmos/try/lua-atmos/

## Deployment

Deployment is handled by GitHub Actions (rsync over SSH to
DreamHost):

- **Dev** — push to `main` deploys to dev
- **Pro** — push a `v*` tag deploys to pro

## SSH Access

SSH credentials are stored in GitHub secrets and variables:

- `DH_SSH_KEY` (secret) — private key
- `DH_HOST` (variable) — remote host
- `DH_USER` (variable) — remote user
- `DH_DIR_DEV` (variable) — dev target directory
- `DH_DIR_PRO` (variable) — pro target directory
