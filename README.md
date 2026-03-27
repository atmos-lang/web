[![Web](https://github.com/atmos-lang/web/actions/workflows/deploy.yml/badge.svg)](https://github.com/atmos-lang/web/actions/workflows/deploy.yml)

# web

Browser IDEs for Lua, lua-atmos, and Atmos. Each page embeds
a textarea + Run button that loads a runner iframe from
GitHub raw (`lua-atmos/env-js`).

## Build

    bash build.sh <version>

Generates versioned HTML files from templates and sample code:

- `web/try/<version>/lua/index.html`
- `web/try/<version>/lua-atmos/index.html`
- `web/try/<version>/atmos/index.html`

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

The `deploy` job depends on `verify` and pushes `web/` to
DreamHost on every push to `main`.

- https://www.ceu-lang.org/atmos/try/

Deployment uses rsync over SSH. Required secrets and variables:

| Kind   | Name         | Description        |
| ------ | ------------ | ------------------ |
| secret | `DH_SSH_KEY` | SSH private key    |
| var    | `DH_HOST`    | DreamHost hostname |
| var    | `DH_USER`    | SSH username       |
| var    | `DH_DIR_PRO` | Remote directory   |

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
            main/
                lua/
                    index.html
                    run.html
                lua-atmos/
                    index.html
                    run.html
                atmos/
                    index.html
                    run.html
