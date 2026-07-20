----------------------------------------------------------------------
-- mylib/init.lua — the "package front door": require("mylib") loads THIS file
----------------------------------------------------------------------
-- When you require("mylib") and there is no mylib.lua, Lua also tries
-- mylib/init.lua (if package.path contains a "?/init.lua" pattern).
-- Same rule in Neovim: require("me") → lua/me/init.lua in your config.

print("        [mylib] init.lua is being executed (loaded fresh)")

local M = {}

-- A package's init.lua typically pulls in its submodules and re-exports
-- the pieces it wants to be public. Your lua/me/init.lua does exactly
-- this: require("me.remap"); require("me.opts"); require("me.todos").
M.greet = require("mylib.greet")

M.version = "1.0.0"

function M.banner()
  return ("mylib v%s — %s"):format(M.version, M.greet.hello("David"))
end

return M
