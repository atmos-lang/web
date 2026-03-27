#!/usr/bin/env bash
set -euo pipefail

VER="${1:?Usage: bash build.sh <version>}"

gen() {
    local tier="$1" title="$2" sample_file="$3"
    local dir="web/try/${VER}/${tier}"
    local sample
    sample="$(cat "$sample_file")"

    mkdir -p "$dir"

    local url="https://raw.githubusercontent.com"
    url+="/lua-atmos/env-js/main/out/${VER}/${tier}.html"
    curl -sfL "$url" > "${dir}/run.html"
    echo "  ${dir}/run.html"

    cat > "${dir}/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>${title} - Browser</title>
    <style>
        body { font-family: monospace; margin: 20px; }
        #code {
            width: 80ch; height: 16em;
            font-family: monospace; font-size: 14px;
            tab-size: 4;
        }
        button {
            font-size: 14px; padding: 4px 16px;
            margin: 4px 4px 4px 0;
        }
        #runner {
            display: block; width: 80ch; height: 20em;
            border: 1px solid #ccc; background: #f8f8f8;
        }
    </style>
</head>
<body>
    <h3>${title} in the Browser</h3>
    <textarea id="code">${sample}</textarea>
    <br>
    <button onclick="runner.src='run.html#'+btoa(code.value)">Run</button>
    <iframe id="runner"></iframe>
</body>
</html>
EOF
    echo "  ${dir}/index.html"
}

echo "Generating index-${VER}.html files..."

gen "lua"       "Lua"       "exs/hello.lua"
gen "lua-atmos" "lua-atmos" "exs/hello-atmos.lua"
gen "atmos"     "Atmos"     "exs/hello.atm"

echo "Done."
