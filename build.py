#!/usr/bin/env python3
import os

modules = [
    ('streams',          'lua/streams/init.lua'),
    ('atmos',            'lua/atmos/init.lua'),
    ('atmos.util',       'lua/atmos/util.lua'),
    ('atmos.run',        'lua/atmos/run.lua'),
    ('atmos.streams',    'lua/atmos/streams.lua'),
    ('atmos.x',          'lua/atmos/x.lua'),
    ('atmos.env.clock',  'lua/atmos/env/clock/init.lua'),
    ('atmos.lang.global',    'lua/atmos/lang/global.lua'),
    ('atmos.lang.aux',       'lua/atmos/lang/aux.lua'),
    ('atmos.lang.lexer',     'lua/atmos/lang/lexer.lua'),
    ('atmos.lang.parser',    'lua/atmos/lang/parser.lua'),
    ('atmos.lang.prim',      'lua/atmos/lang/prim.lua'),
    ('atmos.lang.coder',     'lua/atmos/lang/coder.lua'),
    ('atmos.lang.tosource',  'lua/atmos/lang/tosource.lua'),
    ('atmos.lang.exec',      'lua/atmos/lang/exec.lua'),
    ('atmos.lang.run',       'lua/atmos/lang/run.lua'),
]

os.chdir('/home/user/work')

# Build script tags
script_tags = ''
for name, path in modules:
    with open(path) as f:
        content = f.read()
    script_tags += (
        f'<script type="text/lua" data-module="{name}">\n'
        + content
        + '</script>\n\n'
    )

header = '''<!DOCTYPE html>
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

footer = r'''
    <script type="module">
    import { LuaFactory } from
        'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/+esm';

    // collect all inlined Lua modules
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
            const lua = await factory.createEngine();

            // redirect print to output
            lua.global.set('print', (...args) => {
                output.textContent +=
                    args.join('\t') + '\n';
            });

            // provide now_ms for clock env
            lua.global.set('now_ms', () => {
                return Date.now();
            });

            // preload all Lua modules
            for (const [name, src] of
                Object.entries(LUA_MODULES))
            {
                lua.global.set('_mod_name_', name);
                lua.global.set('_mod_src_', src);
                await lua.doString(
                    'package.preload[_mod_name_] = ' +
                    'assert(load(_mod_src_, ' +
                    '"@" .. _mod_name_))'
                );
            }

            // load runtime + compiler
            status.textContent = 'Compiling...';
            await lua.doString(
                'atmos = require "atmos"\n' +
                'X = require "atmos.x"\n' +
                'require "atmos.lang.exec"\n' +
                'require "atmos.lang.run"'
            );

            // compile .atm source to Lua function
            const atmSrc = codeEl.value;
            const wrapped =
                '(func (...) { ' + atmSrc + '\n})(...)';

            lua.global.set('_atm_src_', wrapped);
            lua.global.set('_atm_file_', 'input.atm');

            status.textContent = 'Running...';
            await lua.doString(
                'local f, err = ' +
                'atm_loadstring(_atm_src_, _atm_file_)\n' +
                'if not f then error(err) end\n' +
                'atmos.call(f)'
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

with open('index-standalone.html', 'w') as f:
    f.write(header)
    f.write(script_tags)
    f.write(footer)

sz = os.path.getsize('index-standalone.html')
print(f'Generated index-standalone.html ({sz} bytes)')
