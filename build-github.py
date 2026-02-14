#!/usr/bin/env python3
"""
Generates web/try/atmos/index-self.html with all Lua
modules fetched from GitHub tags and inlined as
<script type="text/lua"> tags.

Fetches from three upstream repos:
  lua-atmos/f-streams  - streams library
  lua-atmos/atmos      - atmos runtime
  atmos-lang/atmos     - atmos compiler

Usage: python3 build-github.py
"""
import os
import urllib.request

TAGS = {
    'lua-atmos/f-streams': 'v0.2',
    'lua-atmos/atmos':     'v0.5',
    'atmos-lang/atmos':    'v0.5',
}

RAW = 'https://raw.githubusercontent.com'

# (module-name, repo, path)
MODULES = [
    ('streams',
        'lua-atmos/f-streams',
        'streams/init.lua'),
    ('atmos',
        'lua-atmos/atmos',
        'atmos/init.lua'),
    ('atmos.util',
        'lua-atmos/atmos',
        'atmos/util.lua'),
    ('atmos.run',
        'lua-atmos/atmos',
        'atmos/run.lua'),
    ('atmos.streams',
        'lua-atmos/atmos',
        'atmos/streams.lua'),
    ('atmos.x',
        'lua-atmos/atmos',
        'atmos/x.lua'),
    ('atmos.env.clock',
        'lua-atmos/atmos',
        'atmos/env/clock/init.lua'),
    ('atmos.lang.global',
        'atmos-lang/atmos',
        'src/global.lua'),
    ('atmos.lang.aux',
        'atmos-lang/atmos',
        'src/aux.lua'),
    ('atmos.lang.lexer',
        'atmos-lang/atmos',
        'src/lexer.lua'),
    ('atmos.lang.parser',
        'atmos-lang/atmos',
        'src/parser.lua'),
    ('atmos.lang.prim',
        'atmos-lang/atmos',
        'src/prim.lua'),
    ('atmos.lang.coder',
        'atmos-lang/atmos',
        'src/coder.lua'),
    ('atmos.lang.tosource',
        'atmos-lang/atmos',
        'src/tosource.lua'),
    ('atmos.lang.exec',
        'atmos-lang/atmos',
        'src/exec.lua'),
    ('atmos.lang.run',
        'atmos-lang/atmos',
        'src/run.lua'),
]

OUT = 'web/try/atmos/index-github.html'

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# fetch all modules from GitHub
tags = ''
for name, repo, path in MODULES:
    tag = TAGS[repo]
    url = f'{RAW}/{repo}/{tag}/{path}'
    print(f'  {name}: {url}')
    content = urllib.request.urlopen(url).read()
    content = content.decode('utf-8')
    tags += (
        f'<script type="text/lua"'
        f' data-module="{name}">\n'
        + content
        + '</script>\n\n'
    )

HEADER = '''\
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

'''

FOOTER = r'''
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
'''

with open(OUT, 'w') as f:
    f.write(HEADER)
    f.write(tags)
    f.write(FOOTER)

sz = os.path.getsize(OUT)
print(f'Generated {OUT} ({sz} bytes)')
