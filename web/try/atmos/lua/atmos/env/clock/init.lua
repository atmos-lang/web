local atmos = require "atmos"

local M = {
    now = 0,
}

-- now_ms: set from JS as a global (returns ms since epoch)
local old = now_ms()

function M.step ()
    local now = now_ms()
    if now > old then
        emit('clock', (now-old), now)
        M.now = now
        old = now
    end
end

M.env = {
    init = M.init,
    step = M.step,
}

atmos.env(M.env)

return M
