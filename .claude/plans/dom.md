# Plan: DOM — Email Reader with Thread Tree

## Description

3-pane email reader (Freechains) using Lua via Wasmoon for
logic and native `<details>`/`<summary>` for the thread tree.
JS is presentation only; Lua is the "backend in the browser".

## Scenario

```
┌─────────┬──────────────────┬─────────────────────┐
│ Pastas  │  Threads (tree)  │  Mensagem           │
│         │                  │                     │
│ INBOX   │ ▼ Re: Freechains │  De: alice@...      │
│ Sent    │   ├ alice        │  Para: chico@...    │
│ Drafts  │   └ você         │                     │
│         │ ▶ Bug no pico    │  Corpo do email...  │
└─────────┴──────────────────┴─────────────────────┘
```

Logic runs in Lua via Wasmoon. JS is the presentation layer;
Lua is the "backend in the browser". Data model has Freechains
semantics: signed messages, reputation, DAG of posts.

---

## GUI Widget Patterns for Web

No native `<tree>` in HTML. Available patterns:

**Web Components (W3C native standard)**
Custom Elements, Shadow DOM, HTML Templates.
Zero dependencies, works in all modern browsers.

**Component Model (React/Vue/Svelte)**
Industry de facto standard. Same idea: widget = component
with state + template + encapsulated style.

### Framework-independent API patterns

- **Props in, Events out** — data enters as attributes,
  changes exit as custom events
- **Controlled vs Uncontrolled** — widget manages its own
  state, or state lives outside
- **Slots/Children** — composition via projected content
  (`<slot>` in Shadow DOM, `children` in React)

---

## Why not use a ready-made library (Shoelace, etc.)

Ready-made libraries expose the DOM as the data model — you
build the tree creating child elements one by one. With
Wasmoon this is costly and verbose from the Lua side.
`<details>`/`<summary>` already covers the hardest part,
and the remaining feature list is short enough that building
is simpler than adapting to someone else's API.

**Shoelace pays off if:** you want to prototype fast and the
tree will be small (< 50 nodes).
**Building pays off if:** you want to control the data model
and will integrate Freechains semantics.

---

## `<details>` and `<summary>` — Native Tree View

HTML has no `<tree>`, but `<details>`/`<summary>` works as
a native collapsible tree:

```html
<details>
  <summary>Thread: Re: Freechains sync</summary>
  <details>
    <summary>alice — 10:32</summary>
    <details>
      <summary>você — 11:05</summary>
      <p>mensagem...</p>
    </details>
  </details>
</details>
```

Advantages:
- Native, zero JS for expand/collapse
- Accessible by default
- `open` attribute controls state
- `toggle` event notifies changes

### The `open` attribute

Boolean — present = expanded, absent = collapsed:

```html
<details open>   <!-- starts expanded -->
<details>        <!-- starts collapsed -->
```

From Lua via Wasmoon:

```lua
d:setAttribute("open", "")    -- expand
d:removeAttribute("open")     -- collapse
local expanded = d:hasAttribute("open")
```

### The `toggle` event

Fired when the user clicks `<summary>`. Fires **after** the
change — `details.open` already reflects the new state.
No `preventDefault`.

In JS:
```js
details.addEventListener("toggle", (e) => {
    if (details.open) {
        // just opened
    } else {
        // just closed
    }
})
```

From Lua:
```lua
d:addEventListener("toggle", function(e)
    if d.open then
        app.onExpand(id)
    end
end)
```

---

## Why not use custom element `<x-thread-tree>`

A `<x-thread-tree>` would only be worth it to offer a
data-oriented API:

```lua
-- With custom element
tree.threads = js.tojs(minhas_threads)
```

Instead of building node by node:

```lua
-- Without custom element
local d = doc:createElement("details")
local s = doc:createElement("summary")
s.innerText = "alice — 10:32"
d:appendChild(s)
```

Since Lua will build the DOM directly via Wasmoon, the
custom element adds nothing. What's still missing beyond
native (selection, style) doesn't justify encapsulation
— it's ~20 lines of standalone JS/CSS.

---

## jQuery vs Vanilla JS vs Lua

jQuery was the answer to browser incompatibility chaos in
2000-2010. Browsers converged and copied what jQuery offered:

| jQuery                        | Native                                       |
|-------------------------------|----------------------------------------------|
| `$(".cls")`                   | `querySelector` / `querySelectorAll`         |
| `.addClass` / `.removeClass`  | `classList.add` / `classList.remove`          |
| `$.ajax`                      | `fetch`                                      |
| `.attr("data-x")`            | `dataset.x`                                  |
| `.closest(".cls")`            | `element.closest(".cls")`                    |
| `.is(".cls")`                 | `element.matches(".cls")`                    |
| `.on("click")`               | `addEventListener`                           |

What jQuery still does better: **chaining** —
`$(...).find(...).addClass(...).attr(...)`.
The native DOM doesn't have this.

In the browser devtools, `$` and `$$` exist as shortcuts
(`document.querySelector` and `document.querySelectorAll`),
but only in the console — not in the page.

### Comparison: build a thread node

**jQuery**
```js
const node = $("<details>").append(
    $("<summary>").text("alice — 10:32")
                  .attr("data-id", "42")
)
$("#tree").append(node)
```

**Vanilla JS**
```js
const d = document.createElement("details")
const s = document.createElement("summary")
s.textContent = "alice — 10:32"
s.dataset.id = "42"
d.appendChild(s)
document.getElementById("tree").appendChild(d)
```

**Lua (Wasmoon)**
```lua
local d = doc:createElement("details")
local s = doc:createElement("summary")
s.textContent = "alice — 10:32"
s.dataset.id = "42"
d:appendChild(s)
doc:getElementById("tree"):appendChild(d)
```

### Comparison: select all expanded nodes

**jQuery**
```js
$("details[open] summary").addClass("selected")
```

**Vanilla JS**
```js
document.querySelectorAll("details[open] summary")
    .forEach(s => s.classList.add("selected"))
```

**Lua (Wasmoon)**
```lua
local nodes = doc:querySelectorAll("details[open] summary")
for i = 0, nodes.length - 1 do
    nodes:item(i).classList:add("selected")
end
```

Lua ends up almost identical to vanilla JS — same DOM API,
just different syntax. The only real friction is looping
over `NodeList`, which doesn't have `forEach` accessible
from Lua. jQuery would hide this with `.each()`, but it's
not worth the dependency.

**Conclusion:** with Wasmoon you lose nothing relevant by
not using jQuery.

---

## JS/Lua Architecture

**JS handles:** layout, rendering, style, DOM events
**Lua handles:** logic — which threads to load, selected
state, filters, sorting, Freechains metadata

Bridge via plain DOM:

```lua
-- Lua builds the tree
local d = doc:createElement("details")
local s = doc:createElement("summary")
s.innerText = "alice — 10:32"
d:appendChild(s)

-- Lua listens for selection
summary:addEventListener("click", function(e)
    local id = e.target:getAttribute("data-id")
    app.selectMessage(id)
end)

-- Lua listens for expand/collapse
d:addEventListener("toggle", function(e)
    if d.open then
        app.onExpand(id)
    end
end)
```

---

## Demo: Lua adding threads and replies dynamically

Two independent timers running from Lua:
- `addThread` every 1000ms — new topic with subject and
  sender
- `addReply` every 200ms — nested reply in the current
  thread

JS only initializes the Wasmoon engine and hands control
to Lua.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Thread Demo — Lua + Wasmoon</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@400;500&display=swap');

  :root {
    --bg:      #0e0e0f;
    --surface: #161618;
    --border:  #2a2a2e;
    --accent:  #5af;
    --muted:   #555;
    --text:    #d4d4d4;
  }

  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'IBM Plex Sans', monospace;
    font-size: 14px;
    display: grid;
    grid-template-rows: auto 1fr;
    height: 100vh;
    overflow: hidden;
  }

  header {
    padding: 12px 20px;
    border-bottom: 1px solid var(--border);
    display: flex;
    align-items: center;
    gap: 16px;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 12px;
    color: var(--muted);
  }

  header strong { color: var(--accent); font-size: 13px; }
  #status { margin-left: auto; display: flex; gap: 20px; }
  #status span { color: var(--text); }

  #tree {
    padding: 16px 20px;
    overflow-y: auto;
    height: 100%;
  }

  details {
    border-left: 1px solid var(--border);
    margin: 2px 0;
    padding-left: 14px;
    animation: fadein 120ms ease;
  }

  details[data-root] {
    border-left: 2px solid var(--accent);
    padding-left: 12px;
    margin-top: 10px;
  }

  @keyframes fadein {
    from { opacity: 0; transform: translateX(-4px); }
    to   { opacity: 1; transform: translateX(0); }
  }

  summary {
    list-style: none;
    cursor: default;
    padding: 4px 6px;
    border-radius: 3px;
    display: flex;
    align-items: baseline;
    gap: 8px;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 12px;
    user-select: none;
  }

  summary::-webkit-details-marker { display: none; }

  summary::before {
    content: '▸';
    color: var(--muted);
    font-size: 10px;
    transition: transform 100ms;
  }

  details[open] > summary::before {
    transform: rotate(90deg);
  }

  details[data-root] > summary {
    font-size: 13px;
    font-weight: 600;
    color: #eee;
  }

  details[data-root] > summary::before {
    color: var(--accent);
  }

  .from { color: var(--accent); }
  .time {
    color: var(--muted);
    font-size: 11px;
    margin-left: auto;
  }

  #log {
    position: fixed;
    bottom: 0; right: 0;
    width: 280px;
    max-height: 160px;
    overflow-y: auto;
    background: #111;
    border-top: 1px solid var(--border);
    border-left: 1px solid var(--border);
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    color: var(--muted);
    padding: 8px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  #log .entry { animation: fadein 80ms ease; }
  #log .entry.thread { color: var(--accent); }
  #log .entry.reply  { color: #888; padding-left: 10px; }
</style>
</head>
<body>

<header>
  <strong>thread-demo</strong>
  <span>lua via wasmoon</span>
  <div id="status">
    threads: <span id="c-threads">0</span>
    &nbsp;replies: <span id="c-replies">0</span>
  </div>
</header>

<div id="tree"></div>
<div id="log"></div>

<script type="module">
import { LuaFactory } from
    'https://cdn.jsdelivr.net/npm/wasmoon@latest/+esm'

const factory = new LuaFactory()
const lua = await factory.createEngine()

const luaCode = `
local js  = require("js")
local win = js.global
local doc = win.document

local tree      = doc:getElementById("tree")
local cThreads  = doc:getElementById("c-threads")
local cReplies  = doc:getElementById("c-replies")
local log       = doc:getElementById("log")

local threadCount   = 0
local replyCount    = 0
local currentThread = nil

local senders = {
    "alice", "bob", "chico", "diana", "eve"
}
local subjects = {
  "Re: Freechains sync protocol",
  "Bug: realm-allocator segfault",
  "Atmos xspawn API",
  "pico-lua drawing system",
  "FrescoGO! scoring rules",
}

local function logEntry(cls, msg)
  local e = doc:createElement("div")
  e.className = "entry " .. cls
  e.textContent = msg
  log:appendChild(e)
  log.scrollTop = log.scrollHeight
  if log.childElementCount > 40 then
    log:removeChild(log.firstChild)
  end
end

local function now()
  local d = js.new(win.Date)
  local h = d:getHours()
  local m = d:getMinutes()
  local s = d:getSeconds()
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function addThread()
  threadCount = threadCount + 1
  replyCount  = 0

  local subj = subjects[
      ((threadCount - 1) % #subjects) + 1
  ]

  local details = doc:createElement("details")
  details:setAttribute("open", "")
  details:setAttribute("data-root", "")
  details:setAttribute("data-id",
      tostring(threadCount))

  local summary = doc:createElement("summary")

  local span_from = doc:createElement("span")
  span_from.className = "from"
  span_from.textContent = senders[
      ((threadCount-1) % #senders)+1
  ]

  local span_subj = doc:createElement("span")
  span_subj.textContent = subj

  local span_time = doc:createElement("span")
  span_time.className = "time"
  span_time.textContent = now()

  summary:appendChild(span_from)
  summary:appendChild(span_subj)
  summary:appendChild(span_time)
  details:appendChild(summary)
  tree:appendChild(details)

  currentThread = details
  cThreads.textContent = tostring(threadCount)

  logEntry("thread",
      "+ thread " .. threadCount .. ": " .. subj)
end

local function addReply()
  if currentThread == nil then return end
  replyCount = replyCount + 1

  local sender = senders[
      ((replyCount) % #senders) + 1
  ]

  local details = doc:createElement("details")
  details:setAttribute("open", "")

  local summary = doc:createElement("summary")

  local span_from = doc:createElement("span")
  span_from.className = "from"
  span_from.textContent = sender

  local span_msg = doc:createElement("span")
  span_msg.textContent = "reply #" .. replyCount

  local span_time = doc:createElement("span")
  span_time.className = "time"
  span_time.textContent = now()

  summary:appendChild(span_from)
  summary:appendChild(span_msg)
  summary:appendChild(span_time)
  details:appendChild(summary)
  currentThread:appendChild(details)

  local total = tonumber(cReplies.textContent) + 1
  cReplies.textContent = tostring(total)

  logEntry("reply",
      "  ↳ " .. sender .. " #" .. replyCount)
end

win:setInterval(addThread, 1000)
win:setInterval(addReply,  200)
`

await lua.doString(luaCode)
</script>
</body>
</html>
```

---

## What to implement

| Component          | How                             |
|--------------------|---------------------------------|
| Layout 3-pane      | CSS Grid                        |
| Thread tree        | `<details>`/`<summary>` + Lua   |
| Node selection     | ~20 lines JS/CSS                |
| Folders panel      | simple `<ul>`                   |
| Message panel      | `<div>` with sanitized text     |

## Tasks

- [ ] Layout 3-pane — CSS Grid
- [ ] Thread tree — `<details>`/`<summary>` + Lua
- [ ] Node selection — ~20 lines JS/CSS
- [ ] Folders panel — simple `<ul>`
- [ ] Message panel — `<div>` with sanitized text

## Progress

- (pending)
