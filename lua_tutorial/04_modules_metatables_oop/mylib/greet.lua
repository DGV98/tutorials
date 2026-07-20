----------------------------------------------------------------------
-- mylib/greet.lua — a leaf module: require("mylib.greet") loads THIS file
----------------------------------------------------------------------
-- The dot in the module name maps to a directory separator:
--   require("mylib.greet")  →  looks for  mylib/greet.lua  on package.path
-- Exactly like require("me.opts") → lua/me/opts.lua in your nvim config.

-- This print runs when the FILE is executed — which happens only the
-- first time it is require()d (see 01_modules.lua, section 4).
print("        [mylib.greet] file is being executed (loaded fresh)")

local M = {}

function M.hello(name)
  return "Hello, " .. (name or "stranger") .. "!"
end

function M.shout(name)
  return string.upper(M.hello(name))
end

-- Whatever the chunk RETURNS is what require() hands back and caches.
return M
