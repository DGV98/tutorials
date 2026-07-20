----------------------------------------------------------------------
-- mini_plugin/lua/scratchpad/init.lua — a tiny but REAL plugin
----------------------------------------------------------------------
-- This directory (mini_plugin/) has the shape of every plugin you install:
-- a root that goes on runtimepath, with the module under lua/. Once the
-- root is on rtp, require("scratchpad") resolves to THIS file
-- (lua/scratchpad/init.lua — lesson 01 §3 rules).
-- 05_build_a_plugin.lua is the guided tour; this file is the subject.
--
-- Design rule it follows (steal it for your own modules):
--   requiring the module has NO side effects — it only defines functions.
--   All the world-touching (command, keymap, autocmd) happens in setup().
----------------------------------------------------------------------

local M = {}

-- All defaults in one visible table. Users override any subset via setup().
M.defaults = {
  name = "scratchpad://notes", -- buffer name; also drives the autocmd pattern
  filetype = "markdown", -- what the scratch buffer is highlighted as
  keymap = "<leader>ss", -- set to false to opt out of the mapping
  notify = true, -- announce opens via vim.notify
}

M.opts = nil -- the merged options; filled in by setup()
M.stats = { enters = 0 } -- bumped by the autocmd, so tests can observe it
local state = { buf = nil } -- private: not reachable from outside the module

-- Find-or-create the scratch buffer.
local function ensure_buf()
  -- vim.api.nvim_buf_is_valid(b)  →  false if b was :bwipeout'd or never existed
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  -- vim.api.nvim_create_buf(listed, scratch)  →  new empty buffer id;
  --   scratch=true ≈ :setlocal buftype=nofile bufhidden=hide noswapfile
  state.buf = vim.api.nvim_create_buf(true, true)
  -- vim.api.nvim_buf_set_name(buf, name)  ≈  :file {name} (names the buffer)
  vim.api.nvim_buf_set_name(state.buf, M.opts.name)
  -- vim.bo[buf].filetype = x  ≈  :setlocal filetype=x  (buffer-local option;
  --   the modern replacement for deprecated nvim_buf_set_option)
  vim.bo[state.buf].filetype = M.opts.filetype
  return state.buf
end

function M.open()
  local buf = ensure_buf()
  -- vim.api.nvim_set_current_buf(buf)  ≈  :buffer {N} (show buf in current window)
  vim.api.nvim_set_current_buf(buf)
end

function M.toggle()
  -- vim.api.nvim_get_current_buf()  →  id of the buffer in the current window
  if vim.api.nvim_get_current_buf() == state.buf then
    -- vim.fn.bufnr("#")  →  Vimscript bufnr(): alternate buffer id, -1 if none
    local alt = vim.fn.bufnr("#")
    if alt > 0 and vim.api.nvim_buf_is_valid(alt) then
      -- vim.api.nvim_set_current_buf(alt)  ≈  :buffer # (back where you were)
      vim.api.nvim_set_current_buf(alt)
    end
  else
    M.open()
  end
end

-- The one public entry point, following the setup(opts) convention that
-- lazy.nvim's `opts = {...}` key expects (lesson 04 §2).
function M.setup(opts)
  -- vim.tbl_deep_extend("force", a, b)  →  recursive merge; on conflicts the
  --   RIGHTMOST table wins, and nested tables merge key-by-key instead of
  --   being replaced wholesale. THE way to lay user opts over defaults.
  --   :help vim.tbl_deep_extend()
  M.opts = vim.tbl_deep_extend("force", M.defaults, opts or {})

  -- 1) A USER COMMAND
  -- vim.api.nvim_create_user_command(name, fn, o)  ≈  :command! Scratch ...
  vim.api.nvim_create_user_command("Scratch", M.toggle,
    { desc = "Toggle the scratchpad buffer" })

  -- 2) A KEYMAP (opt-out-able — polite plugins make mappings optional)
  if M.opts.keymap then
    -- vim.keymap.set("n", lhs, fn, o)  ≈  :nnoremap, with a Lua function rhs
    vim.keymap.set("n", M.opts.keymap, M.toggle, { desc = "Toggle scratchpad" })
  end

  -- 3) AN AUTOCMD — in a cleared group, so calling setup() twice does NOT
  --    stack duplicate handlers (exactly the bug in lesson 06, bug 4).
  -- vim.api.nvim_create_augroup(name, {clear=true})  ≈  :augroup X | au! | augroup END
  local group = vim.api.nvim_create_augroup("Scratchpad", { clear = true })
  -- vim.api.nvim_create_autocmd(event, o)  ≈  :autocmd Scratchpad BufEnter pat ...
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = M.opts.name .. "*", -- fires only for our own buffer
    callback = function()
      M.stats.enters = M.stats.enters + 1
      if M.opts.notify then
        -- vim.notify(msg, level)  ≈  :echomsg, routable by UI plugins
        vim.notify("scratchpad opened (visit #" .. M.stats.enters .. ")",
          vim.log.levels.INFO)
      end
    end,
  })

  return M -- returning M lets callers chain: require("scratchpad").setup{}.open()
end

-- Without this line, require("scratchpad") yields `true`, and
-- require("scratchpad").setup{} dies with "attempt to index a boolean value"
-- (lesson 03 §1, cause a). Never forget it.
return M
