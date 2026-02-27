[![Web](https://github.com/atmos-lang/web/actions/workflows/deploy.yml/badge.svg)](https://github.com/atmos-lang/web/actions/workflows/deploy.yml)

# web

Browser IDEs for Lua, lua-atmos, and Atmos. Each page embeds
a textarea + Run button that loads a runner iframe from
jsDelivr CDN.

## Build

    bash build.sh <version>

Generates versioned HTML files from templates and sample code:

- `web/try/lua/index-<version>.html`
- `web/try/lua-atmos/index-<version>.html`
- `web/try/atmos/index-<version>.html`

Sample code lives in `exs/` and is embedded in the textarea.

## Adding a new version

1. Run `bash build.sh <version>`
2. Commit the generated files
3. Add `bash build.sh <version>` to the verify job in
   `.github/workflows/deploy.yml`

## CI/CD

The `verify` job runs on every push and PR. It rebuilds all
versioned files and checks `git diff --exit-code` to ensure
committed files match the build output.

Deploy jobs depend on `verify`:

- **deploy-dev** — pushes `web/` to DreamHost dev on main
- **deploy-pro** — pushes `web/` to DreamHost pro on tags

## DreamHost

### Dev

- https://www.dev.ceu-lang.org/atmos/try/

### Pro

- https://www.ceu-lang.org/atmos/try/

### Deployment

Deployment is handled by GitHub Actions (rsync over SSH to
DreamHost):

- **Dev** — push to `main` deploys to dev
- **Pro** — push a `v*` tag deploys to pro

Deployment uses rsync over SSH. Required secrets and variables:

| Kind | Name | Description |
|------|------|-------------|
| secret | `DH_SSH_KEY` | SSH private key |
| var | `DH_HOST` | DreamHost hostname |
| var | `DH_USER` | SSH username |
| var | `DH_DIR_DEV` | Remote directory (dev) |
| var | `DH_DIR_PRO` | Remote directory (pro) |

## Directory structure

    .github/workflows/deploy.yml
    build.sh
    exs/
        hello.lua
        hello-atmos.lua
        hello.atm
    web/
        try/
            index.html
            lua/
                index-main.html
            lua-atmos/
                index-main.html
            atmos/
                index-main.html
