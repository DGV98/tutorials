----------------------------------------------------------------------
-- 04_coroutines.lua — Coroutines: functions that can pause
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • coroutine.create / resume / yield / status / wrap
--   • How values flow BOTH ways through resume and yield
--   • A producer-consumer pipeline
--   • Coroutines as iterators (coroutine.wrap in a for loop)
--   • Why Neovim plugin authors reach for coroutines to make async
--     code LOOK synchronous
-- HOW TO RUN
--   luajit 04_coroutines.lua          (from this directory)
--   or inside nvim:  :luafile %       (with this file open)
-- PREREQUISITES: 03_iterators.lua (closures, the iterator protocol)
----------------------------------------------------------------------

------------------------------------------------------------ 1. Pause and resume
-- A coroutine is a function that can SUSPEND itself mid-run
-- (coroutine.yield) and be continued later exactly where it stopped
-- (coroutine.resume) — with all its locals intact. Not threads: nothing
-- runs in parallel, control is handed over explicitly. Think "two
-- scripts taking turns", like a shell job you Ctrl-Z and `fg` — except
-- suspension happens from the INSIDE, voluntarily and precisely.

local co = coroutine.create(function()
  print("  co: part 1")
  coroutine.yield()
  print("  co: part 2")
  coroutine.yield()
  print("  co: part 3 (last)")
end)

print("1a status:", coroutine.status(co))   -- "suspended": born paused
coroutine.resume(co)                        -- runs until first yield
print("1b status:", coroutine.status(co))   -- "suspended" again
coroutine.resume(co)
coroutine.resume(co)                        -- runs to the end
print("1c status:", coroutine.status(co))   -- "dead": finished, cannot restart

-- Resuming a dead coroutine doesn't crash — resume reports failure:
print("1d resume dead:", coroutine.resume(co))  -- false  "cannot resume dead coroutine"

-- The four statuses: "suspended" (paused or not yet started),
-- "running" (it's the one executing right now), "dead" (finished or
-- errored), "normal" (it resumed ANOTHER coroutine and is waiting).

------------------------------------------------------------ 2. Values flow both ways
-- This is the part people memorize wrong, so stare at it:
--   • resume(co, a, b)  → a, b arrive INSIDE: as the function's
--     arguments on the FIRST resume, as yield's return values afterwards
--   • yield(x, y)       → x, y come OUT: resume returns true, x, y
--   • return z          → the final resume returns true, z (then dead)

local calc = coroutine.create(function(a, b)
  print("  calc: got initial", a, b)
  local c = coroutine.yield(a + b)      -- sends 30 out; receives 5 later
  print("  calc: got follow-up", c)
  return c * 10                          -- final answer
end)

print("2a resume ->", coroutine.resume(calc, 10, 20))  -- true  30
print("2b resume ->", coroutine.resume(calc, 5))       -- true  50
-- First value from resume is always ok (like pcall). If the coroutine
-- errors, you get false + the error message instead of a crash:
local bomb = coroutine.create(function() error("boom inside") end)
print("2c errored:", coroutine.resume(bomb))
print("2d status:", coroutine.status(bomb))            -- dead

------------------------------------------------------------ 3. Producer–consumer
-- The classic use: one side produces values at its own pace, the other
-- consumes them, and NEITHER is written inside-out to serve the other.
-- The producer below "reads" config lines; the consumer filters and
-- prints. Each is a straight-line loop.

local function producer(lines)
  return coroutine.create(function()
    for _, line in ipairs(lines) do
      coroutine.yield(line)     -- hand one line to whoever resumed us
    end
    -- fall off the end → dead → consumer sees nil and stops
  end)
end

local function consumer(prod)
  while true do
    local ok, line = coroutine.resume(prod)
    if not ok or line == nil then break end   -- dead or finished
    if not line:match("^%s*#") then           -- skip comment lines
      print("3a consumed:", line)
    end
  end
end

consumer(producer({
  "# hyprland gaps",
  "gaps_in = 3",
  "gaps_out = 3",
  "# borders",
  "border_size = 1",
}))

------------------------------------------------------------ 4. coroutine.wrap
-- wrap(f) builds the coroutine AND returns a plain function that does
-- the resuming for you. Each call = one resume; yielded values are
-- returned directly (no `true` in front); errors propagate as real
-- errors (catch with pcall) instead of a false flag.
-- Bonus: since it's "a function you call repeatedly until nil", a
-- wrapped coroutine IS a closure iterator (lesson 03) — drop it
-- straight into a for loop.

local function keyvalues(text)
  return coroutine.wrap(function()
    for k, v in text:gmatch("([%w_]+)%s*=%s*([^\n]+)") do
      coroutine.yield(k, v)
    end
  end)
end

for k, v in keyvalues("rounding = 10\nactive_opacity = 0.75") do
  print("4a pair:", k, v)
end

-- Why bother, when gmatch alone did this in lesson 03? Because INSIDE a
-- wrapped function you can yield from nested loops, recursive calls,
-- helper functions... Try writing "yield every node of a tree" as a
-- plain closure and you'll appreciate this. Generators for free.

------------------------------------------------------------ 5. Why Neovim people love these
-- Neovim's event loop (vim.uv / libuv) is callback-based. Real async
-- code ends up nested like this (DON'T write this):
--
--   uv.fs_open(path, "r", 438, function(err, fd)
--     uv.fs_fstat(fd, function(err, stat)
--       uv.fs_read(fd, stat.size, 0, function(err, data)
--         uv.fs_close(fd, function(err) use(data) end)
--       end)
--     end)
--   end)
--
-- The coroutine trick: run your logic in a coroutine; when you'd need
-- to wait, yield — and let the CALLBACK resume you with the result:
--
--   local function await(async_fn, ...)
--     local co = coroutine.running()
--     async_fn(..., function(result) coroutine.resume(co, result) end)
--     return coroutine.yield()   -- pause until the callback fires
--   end
--
--   -- inside a coroutine, async code now reads top-to-bottom:
--   local fd   = await(uv.fs_open, path, "r", 438)
--   local stat = await(uv.fs_fstat, fd)
--   ...
--
-- That's the whole secret behind plenary.nvim's async module and
-- nio/nvim-nio: yield when waiting, resume from the callback. Same
-- idea as async/await in JS — Lua just exposes the raw mechanism.
--
-- Here it is working end-to-end. Plain luajit has no event loop, so
-- the main thread below PLAYS libuv: async functions push their
-- callbacks onto a queue, and after the coroutine suspends, the "loop"
-- fires whatever "completed". (Note the callback must NOT run while
-- the coroutine is still running — you can't resume a running
-- coroutine. Real event loops guarantee that; our queue recreates it.)

local pending = {}   -- our toy event loop's completion queue

local function fake_async_read(path, callback)
  -- pretend we kicked off disk I/O; the "result" will arrive "later"
  table.insert(pending, function() callback("contents-of-" .. path) end)
end

local function await(async_fn, arg)
  local co = assert(coroutine.running(), "await must run inside a coroutine")
  async_fn(arg, function(result)
    coroutine.resume(co, result)   -- the callback wakes us back up
  end)
  return coroutine.yield()         -- pause here until that happens
end

coroutine.wrap(function()
  print("5a start")
  local data = await(fake_async_read, "hyprland.conf")  -- looks synchronous!
  print("5b got:", data)
  print("5c still straight-line code, no nesting")
end)()

-- Main thread = event loop: deliver completed "I/O" until quiet.
while #pending > 0 do
  table.remove(pending, 1)()   -- each of these resumes the coroutine
end

-- Lua version note: coroutine.running() in 5.1/LuaJIT returns nil when
-- called from the main thread; in 5.2+ it returns the main coroutine
-- plus a boolean. The assert above covers us either way.

------------------------------------------------------------ TRY IT
-- 1. In section 1, add a 4th resume after 1c and print its results.
--    Predict first: crash, or (false, message)?
-- 2. Change section 2 to yield TWICE and pass a value in with each
--    resume. Write down the full value flow before running.
-- 3. Rewrite section 3's producer with coroutine.wrap and let the
--    consumer be a plain `for line in prod do` loop.
-- 4. Write walk(t) with coroutine.wrap that recursively yields every
--    scalar value in a nested table — then loop over
--    walk({1, {2, {3}}, 4}). This is the "generators for free" claim
--    from section 4; verify it.
