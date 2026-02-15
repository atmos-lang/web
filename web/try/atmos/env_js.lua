local atmos = require "atmos"

local M = {
    now = 0,
}

function M.close ()
    if _js_close_ then
        _js_close_()
    end
end

M.env = {
    close = M.close,
    -- mode = nil: single-env only, start() pattern
}

atmos.env(M.env)

-- expose for JS clock driver to update M.now
_atm_js_env_ = M

return M
