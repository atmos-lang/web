#!/bin/bash
#
# Generates:
#   web/try/atmos/index.html     - Atmos language IDE
#   web/try/lua-atmos/index.html - Lua with atmos API
#
# Modules fetched from GitHub tags and inlined as
# <script type="text/lua"> tags.
#
# Upstream repos:
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
    [lua-atmos/atmos]=v0.5
    [atmos-lang/atmos]=v0.5
)

# lua-atmos modules (runtime)
LUA_ATMOS_MODULES=(
    'streams         lua-atmos/f-streams  streams/init.lua'
    'atmos           lua-atmos/atmos      atmos/init.lua'
    'atmos.util      lua-atmos/atmos      atmos/util.lua'
    'atmos.run       lua-atmos/atmos      atmos/run.lua'
    'atmos.streams   lua-atmos/atmos      atmos/streams.lua'
    'atmos.x         lua-atmos/atmos      atmos/x.lua'
    'atmos.env.clock lua-atmos/atmos      atmos/env/clock/init.lua'
)

# atmos-lang modules (compiler)
ATMOS_LANG_MODULES=(
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

# --- fetch modules from GitHub into _tags ---
_tags=''
fetch_modules() {
    _tags=''
    for entry in "$@"; do
        read -r name repo path <<< "$entry"
        tag="${TAGS[$repo]}"
        url="$RAW/$repo/$tag/$path"
        echo "  $name: $url"
        content=$(curl -sfL "$url")
        _tags+="<script type=\"text/lua\" data-module=\"$name\">
$content
</script>

"
    done
}

echo "Fetching lua-atmos modules..."
fetch_modules "${LUA_ATMOS_MODULES[@]}"
lua_atmos_tags="$_tags"

echo "Fetching atmos-lang modules..."
fetch_modules "${ATMOS_LANG_MODULES[@]}"
atmos_lang_tags="$_tags"

# ============================================
# web/try/lua-atmos/index.html
# ============================================

OUT='web/try/lua-atmos/index.html'
mkdir -p "$(dirname "$OUT")"

cat > "$OUT" <<'HEADER'
<!DOCTYPE html>
<html>
<head>
    <title>lua-atmos - Browser</title>
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
    <h3>lua-atmos in the Browser</h3>
    <textarea id="code">local atmos = require "atmos"
local X = require "atmos.x"
local streams = require "streams"

print("lua-atmos loaded!")
</textarea>
    <br>
    <button id="run">Run</button>
    <span id="status"></span>
    <pre id="output"></pre>

HEADER

echo "$lua_atmos_tags" >> "$OUT"

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

    btn.addEventListener('click', async () => {
        output.textContent = '';
        status.textContent = 'Loading...';
        btn.disabled = true;

        try {
            const factory = new LuaFactory();
            const lua =
                await factory.createEngine();

            lua.global.set('print', (...args) => {
                output.textContent +=
                    args.join('\t') + '\n';
            });

            lua.global.set('now_ms', () => {
                return Date.now();
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

            status.textContent = 'Running...';
            await lua.doString(codeEl.value);

            lua.global.close();
            status.textContent = 'Done.';

        } catch (e) {
            output.textContent +=
                'ERROR: ' + e.message + '\n';
            status.textContent = 'Error.';
        }

        btn.disabled = false;
    });
    </script>
</body>
</html>
FOOTER

sz=$(wc -c < "$OUT")
echo "Generated $OUT ($sz bytes)"

# ============================================
# web/try/atmos/index.html
# ============================================

OUT='web/try/atmos/index.html'

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
    <textarea id="code">val env = require "atmos.env.clock"

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

# append ALL module tags (lua-atmos + atmos-lang)
echo "$lua_atmos_tags" >> "$OUT"
echo "$atmos_lang_tags" >> "$OUT"

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

    btn.addEventListener('click', async () => {
        output.textContent = '';
        status.textContent = 'Loading...';
        btn.disabled = true;

        try {
            const factory = new LuaFactory();
            const lua =
                await factory.createEngine();

            lua.global.set('print', (...args) => {
                output.textContent +=
                    args.join('\t') + '\n';
            });

            lua.global.set('now_ms', () => {
                return Date.now();
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
            await lua.doString(
                'local f, err = '
                + 'atm_loadstring('
                + '_atm_src_, _atm_file_)\n'
                + 'if not f then'
                + ' error(err) end\n'
                + 'atmos.call(f)'
            );

            lua.global.close();
            status.textContent = 'Done.';

        } catch (e) {
            output.textContent +=
                'ERROR: ' + e.message + '\n';
            status.textContent = 'Error.';
        }

        btn.disabled = false;
    });
    </script>
</body>
</html>
FOOTER

sz=$(wc -c < "$OUT")
echo "Generated $OUT ($sz bytes)"
