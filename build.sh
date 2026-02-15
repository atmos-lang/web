#!/bin/bash
#
# Generates web/try/atmos/index.html with all Lua
# modules fetched from GitHub tags and inlined as
# <script type="text/lua"> tags.
#
# Fetches from three upstream repos:
#   lua-atmos/f-streams  - streams library
#   lua-atmos/atmos      - atmos runtime
#   atmos-lang/atmos     - atmos compiler
#
# Usage: bash build.sh
#
set -euo pipefail
cd "$(dirname "$0")"

RAW='https://raw.githubusercontent.com'

# repo -> tag
declare -A TAGS=(
    [lua-atmos/f-streams]=v0.2
    [lua-atmos/atmos]=main
    [atmos-lang/atmos]=v0.5
)

# module-name  repo  path
MODULES=(
    'streams         lua-atmos/f-streams  streams/init.lua'
    'atmos           lua-atmos/atmos      atmos/init.lua'
    'atmos.util      lua-atmos/atmos      atmos/util.lua'
    'atmos.run       lua-atmos/atmos      atmos/run.lua'
    'atmos.streams   lua-atmos/atmos      atmos/streams.lua'
    'atmos.x         lua-atmos/atmos      atmos/x.lua'
    'atmos.env.clock lua-atmos/atmos      atmos/env/clock/init.lua'
    'atmos.lang.global  atmos-lang/atmos  src/global.lua'
    'atmos.lang.aux     atmos-lang/atmos  src/aux.lua'
    'atmos.lang.lexer   atmos-lang/atmos  src/lexer.lua'
    'atmos.lang.parser  atmos-lang/atmos  src/parser.lua'
    'atmos.lang.prim    atmos-lang/atmos  src/prim.lua'
    'atmos.lang.coder   atmos-lang/atmos  src/coder.lua'
    'atmos.lang.tosource atmos-lang/atmos src/tosource.lua'
    'atmos.lang.exec    atmos-lang/atmos  src/exec.lua'
    'atmos.lang.run     atmos-lang/atmos  src/run.lua'
)

OUT='web/try/atmos/index.html'

# --- fetch all modules from GitHub ---
lua_tags=''
for entry in "${MODULES[@]}"; do
    read -r name repo path <<< "$entry"
    tag="${TAGS[$repo]}"
    url="$RAW/$repo/$tag/$path"
    echo "  $name: $url"
    content=$(curl -sfL "$url")
    lua_tags+="<script type=\"text/lua\" data-module=\"$name\">
$content
</script>

"
done

# --- inline local atmos.env.js module ---
js_env=$(cat web/try/atmos/env_js.lua)
lua_tags+="<script type=\"text/lua\" data-module=\"atmos.env.js\">
$js_env
</script>

"

# --- write output ---
cat > "$OUT" <<'HEADER'
<!DOCTYPE html>
<html>
<head>
    <title>Atmos - Browser</title>
    <style>
        body {
            font-family: monospace;
            margin: 20px;
        }
        #code {
            width: 80ch;
            height: 16em;
            font-family: monospace;
            font-size: 14px;
            tab-size: 4;
        }
        #output {
            width: 80ch;
            border: 1px solid #ccc;
            padding: 8px;
            min-height: 4em;
            background: #f8f8f8;
        }
        button {
            font-size: 14px;
            padding: 4px 16px;
            margin: 4px 4px 4px 0;
        }
        #status {
            color: #888;
            margin-left: 8px;
        }
    </style>
</head>
<body>
    <h3>Atmos in the Browser</h3>
    <textarea id="code">val env = require "atmos.env.js"

print(env.now)
watching @5 {
    every @.500 {
        print("Hello World!")
    }
}
print(env.now)
</textarea>
    <br>
    <button id="run">Run</button>
    <span id="status"></span>
    <pre id="output"></pre>

HEADER

# append lua module tags
echo "$lua_tags" >> "$OUT"

cat >> "$OUT" <<'FOOTER'
    <script type="module">
    import { LuaFactory } from
        'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/+esm';

    const LUA_MODULES = {};
    document.querySelectorAll(
        'script[type="text/lua"]'
    ).forEach(el => {
        LUA_MODULES[el.dataset.module] =
            el.textContent;
    });

    const btn = document.getElementById('run');
    const codeEl = document.getElementById('code');
    const output = document.getElementById('output');
    const status = document.getElementById('status');

    let clockInterval = null;
    let lua = null;
    let emitting = false;

    function cleanup () {
        if (clockInterval) {
            clearInterval(clockInterval);
            clockInterval = null;
        }
        if (lua) {
            lua.global.close();
            lua = null;
        }
        btn.textContent = 'Run';
        btn.disabled = false;
    }

    btn.addEventListener('click', async () => {
        if (clockInterval) {
            // stop running program
            try {
                await lua.doString('stop()');
            } catch (_) {}
            cleanup();
            status.textContent = 'Stopped.';
            return;
        }

        output.textContent = '';
        status.textContent = 'Loading...';
        btn.disabled = true;

        try {
            const factory = new LuaFactory();
            lua = await factory.createEngine();

            lua.global.set('print', (...args) => {
                output.textContent +=
                    args.join('\t') + '\n';
            });

            lua.global.set('now_ms', () => {
                return Date.now();
            });

            // env.close() callback
            lua.global.set('_js_close_', () => {
                if (clockInterval) {
                    clearInterval(clockInterval);
                    clockInterval = null;
                }
            });

            for (const [name, src] of
                Object.entries(LUA_MODULES))
            {
                lua.global.set('_mod_name_', name);
                lua.global.set('_mod_src_', src);
                await lua.doString(
                    'package.preload[_mod_name_]'
                    + ' = assert(load(_mod_src_,'
                    + ' "@" .. _mod_name_))'
                );
            }

            status.textContent = 'Compiling...';
            await lua.doString(
                'atmos = require "atmos"\n'
                + 'X = require "atmos.x"\n'
                + 'require "atmos.lang.exec"\n'
                + 'require "atmos.lang.run"'
            );

            const atmSrc = codeEl.value;
            const wrapped =
                '(func (...) { '
                + atmSrc + '\n})(...)';

            lua.global.set(
                '_atm_src_', wrapped
            );
            lua.global.set(
                '_atm_file_', 'input.atm'
            );

            status.textContent = 'Running...';
            btn.textContent = 'Stop';
            btn.disabled = false;

            // require env.js before start()
            // (env must be registered first)
            await lua.doString(
                'require "atmos.env.js"\n'
                + 'local f, err = '
                + 'atm_loadstring('
                + '_atm_src_, _atm_file_)\n'
                + 'if not f then'
                + ' error(err) end\n'
                + 'start(function (...)\n'
                + '  f(...)\n'
                + '  _atm_done_ = true\n'
                + 'end)'
            );

            // check if body finished immediately
            // (no awaits in user code)
            if (lua.global.get('_atm_done_')) {
                await lua.doString('stop()');
                cleanup();
                status.textContent = 'Done.';
                return;
            }

            // drive clock events from JS
            let last = Date.now();
            clockInterval = setInterval(
                async () => {
                if (emitting) return;
                emitting = true;
                try {
                    if (lua.global.get(
                        '_atm_done_'))
                    {
                        clearInterval(
                            clockInterval);
                        clockInterval = null;
                        await lua.doString(
                            'stop()');
                        cleanup();
                        status.textContent =
                            'Done.';
                        return;
                    }
                    const now = Date.now();
                    const dt = now - last;
                    if (dt > 0) {
                        await lua.doString(
                            '_atm_js_env_.now='
                            + now + ';'
                            + 'emit("clock",'
                            + dt + ',' + now
                            + ')');
                        last = now;
                    }
                } catch (e) {
                    clearInterval(clockInterval);
                    clockInterval = null;
                    output.textContent +=
                        'ERROR: ' + e.message
                        + '\n';
                    status.textContent = 'Error.';
                    cleanup();
                } finally {
                    emitting = false;
                }
            }, 16);

        } catch (e) {
            output.textContent +=
                'ERROR: ' + e.message + '\n';
            status.textContent = 'Error.';
            cleanup();
        }
    });
    </script>
</body>
</html>
FOOTER

sz=$(wc -c < "$OUT")
echo "Generated $OUT ($sz bytes)"
