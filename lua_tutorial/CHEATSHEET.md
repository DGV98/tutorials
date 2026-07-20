# CHEATSHEET — Lua (LuaJIT/5.1) + Neovim 0.12 quick reference

Dense, grep-friendly. Keep it open in a split (`:vsplit CHEATSHEET.md`).
Everything here is verified on this machine: `luajit` (LuaJIT 2.1, Lua 5.1
semantics) and `nvim` v0.12.4 (`nvim --clean -l`).

Sections: 1 syntax · 2 table ops · 3 strings & patterns · 4 LuaJIT gotchas ·
5 vim.* namespace map · 6 Vimscript→Lua · 7 debugging · 8 where is it taught?

----------------------------------------------------------------------

## 1. Lua in 60 seconds

```lua
-- locals (ALWAYS use local; bare names are globals shared by every plugin)
local n = 42                      -- number (all numbers are doubles in 5.1)
local s = "text"                  -- strings: immutable; "..." == '...'
local m = [[multi
line, no escapes]]                -- long string; [==[ ... ]==] nests
local b = true                    -- boolean
local nothing = nil               -- nil = absence; assigning nil deletes

-- strings
local full = "foo" .. "bar"       -- concatenation is .. (NOT +)
local len  = #full                -- # = length operator (bytes)
local txt  = "n = " .. n          -- numbers coerce into .. automatically

-- tables: THE only data structure (array + dict + object, all one thing)
local list = { "a", "b", "c" }            -- array part, indices 1..3
local dict = { name = "david", tabs = 2 } -- hash part
local mix  = { "x", key = "v", [10] = 1 } -- both at once
print(list[1], dict.name, dict["name"])   -- dict.k is sugar for dict["k"]

-- functions: first-class values; missing args -> nil, extra args dropped
local function add(a, b) return a + b end
local mul = function(a, b) return a * b end   -- same thing, as an expression
local function divmod(a, b) return math.floor(a / b), a % b end -- multi-return
local q, r = divmod(17, 5)
-- () optional when the sole arg is a table/string literal:  setup{ x = 1 }  require"me"

-- control flow (blocks end with `end`; no braces)
if n > 40 then print("big") elseif n > 0 then print("small") else print("neg") end
while n > 40 do n = n - 1 end
repeat n = n + 1 until n == 42
for i = 1, 5 do print(i) end            -- numeric for: start, stop INCLUSIVE
for i = 10, 2, -2 do print(i) end       -- optional step
for i, v in ipairs(list) do print(i, v) end  -- array walk, in order, stops at nil
for k, v in pairs(dict) do print(k, v) end   -- any table, NO order guarantee
-- no `continue` in 5.1: use  goto continue  ... ::continue::  (works in LuaJIT)

-- operators:  ~= is "not equal" (not !=);  and/or/not (not &&/||/!)
-- ternary idiom:  local x = cond and a or b      (TRAP: breaks if a is false/nil)

-- !! TRUTHINESS: only `false` and `nil` are falsy. 0, "" and {} are ALL truthy.
if 0 then print("0 is truthy in Lua!") end        -- prints. Unlike C/bash/JS.

-- !! 1-BASED: arrays start at index 1. list[0] is nil, #list counts from 1.
-- string.sub("hello", 1, 2) == "he".  Every off-by-one you'll ever write: here.
```

----------------------------------------------------------------------

## 2. Table operations quick table

`local t = { "a", "b", "c" }` for the examples. All in 5.1/LuaJIT.

| Operation             | Call                                    | Result / notes                                         |
|-----------------------|-----------------------------------------|--------------------------------------------------------|
| append                | `table.insert(t, "d")`                  | pushes at end: `t[#t+1] = "d"` is the same, faster      |
| insert at position    | `table.insert(t, 1, "z")`               | shifts the rest right (O(n))                            |
| remove last           | `table.remove(t)`                       | removes AND returns `t[#t]`                             |
| remove at position    | `table.remove(t, 1)`                    | shifts the rest left, returns removed value             |
| join to string        | `table.concat(t, ", ")`                 | `"a, b, c"` — array parts only, strings/numbers only    |
| join a slice          | `table.concat(t, "-", 2, 3)`            | `"b-c"`                                                 |
| sort in place         | `table.sort(t)`                         | default `<`; mixed types error                          |
| sort with comparator  | `table.sort(t, function(a,b) return a>b end)` | comparator = "a comes first?"; must be strict `<`-like |
| length                | `#t`                                    | array length. UNDEFINED on sparse arrays (nil holes)    |
| array iterate         | `for i, v in ipairs(t)`                 | 1,2,3… in order; STOPS at the first nil                 |
| full iterate          | `for k, v in pairs(t)`                  | every key incl. hash part; order is arbitrary           |
| count ALL keys        | (no builtin)                            | `#` misses hash keys: loop `pairs` and count; in nvim: `vim.tbl_count(t)` counts every key |
| shallow copy          | (no builtin)                            | loop `pairs`; in nvim: `vim.deepcopy(t)` for deep       |
| unpack to values      | `unpack(t)`                             | 5.1 name! `table.unpack` is nil here — see section 4    |
| membership            | (no builtin)                            | loop it; in nvim: `vim.tbl_contains(t, v)`              |

Assignment copies the REFERENCE, not the table: `local u = t` aliases; edits
through `u` show in `t`. (Strings/numbers/booleans copy by value.)

----------------------------------------------------------------------

## 3. String library + Lua patterns vs regex

All callable as methods: `s:upper()` == `string.upper(s)`. Indices 1-based;
negative counts from the end.

| Function                          | Example                                  | Result           |
|-----------------------------------|------------------------------------------|------------------|
| `s:len()` / `#s`                  | `#"hello"`                               | `5` (bytes)      |
| `s:sub(i, j)`                     | `("hello"):sub(2, 4)`                    | `"ell"`          |
| `s:sub(-n)`                       | `("hello"):sub(-3)`                      | `"llo"`          |
| `s:upper()` / `s:lower()`         | `("hi"):upper()`                         | `"HI"`           |
| `s:rep(n)`                        | `("ab"):rep(3)`                          | `"ababab"`       |
| `s:rep(n, sep)`                   | `("ab"):rep(3, "-")`                     | `"ab-ab-ab"` (LuaJIT extension) |
| `s:reverse()`                     | `("abc"):reverse()`                      | `"cba"`          |
| `s:byte()` / `string.char(n)`     | `("A"):byte()`, `string.char(66)`        | `65`, `"B"`      |
| `string.format(fmt, ...)`         | `("%s=%d"):format("n", 42)`              | `"n=42"` (printf-style; `%q` quotes) |
| `s:find(pat)`                     | `("key=v"):find("=")`                    | `4, 4` (start, stop) |
| `s:find(pat, init, true)`         | `("a.b"):find(".", 1, true)`             | plain-text find, no pattern magic |
| `s:match(pat)`                    | `("key = v"):match("^(%w+)%s*=")`        | `"key"` (returns captures, or whole match) |
| `s:gmatch(pat)`                   | `for w in s:gmatch("%a+") do ... end`    | iterator over matches |
| `s:gsub(pat, repl)`               | `("aaa"):gsub("a", "b")`                 | `"bbb", 3` (result, count) |
| `s:gsub(pat, fn)`                 | `s:gsub("%d+", function(d) ... end)`     | repl can be a function or table |

**Lua patterns are NOT regex.** Smaller, `%`-based, no alternation. Mapping:

| Regex               | Lua pattern       | Notes                                              |
|---------------------|-------------------|----------------------------------------------------|
| `\d` `\w` `\s`      | `%d` `%w` `%s`    | also `%a` letters, `%l` lower, `%u` upper, `%p` punct, `%x` hex |
| `\D` `\W` `\S`      | `%D` `%W` `%S`    | uppercase class = complement                       |
| `.`                 | `.`               | any char (same)                                    |
| `*` `+` `?`         | `*` `+` `?`       | same, but apply to ONE char/class only             |
| `.*?` (lazy)        | `.-`              | `-` is the lazy/shortest-match star                |
| `^` `$`             | `^` `$`           | anchors (same); `^` only special at pattern start  |
| `[a-z]` `[^x]`      | `[a-z]` `[^x]`    | char sets (same); classes work inside: `[%d%s]`    |
| `(group)`           | `(capture)`       | captures returned by match / usable as `%1` in gsub |
| `\1` backreference  | `%1`              | in patterns and in gsub replacement strings        |
| `\.` escape         | `%.`              | escape char is `%`, never `\`. Magic: `( ) . % + - * ? [ ] ^ $` |
| `a\|b` alternation  | — none            | no alternation. Match twice, or gsub tricks        |
| `x{2,4}` counts     | — none            | repeat by hand: `xx?x?` or loop                    |
| `\b` word boundary  | `%f[%w]` frontier | `%f[set]` matches the empty transition into `set`  |
| — (no regex equiv)  | `%b()`            | balanced pair match: `("f(a(b)c)"):match("%b()")` → `"(a(b)c)"` |

Escape a literal string for use inside a pattern: nvim has `vim.pesc(s)`;
plain Lua: `(s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))`.
Vim's own `:s/\v...` regexes are a THIRD dialect — don't mix them up.

----------------------------------------------------------------------

## 4. LuaJIT / Lua 5.1 vs newer Lua — gotcha list

Neovim embeds LuaJIT = **Lua 5.1** semantics. Your `/usr/bin/lua` is 5.5 —
a different dialect. Blog posts and Stack Overflow love 5.3+ syntax; these
are the traps (each verified with `luajit -e` and `nvim --clean -l` here):

- **`unpack`, not `table.unpack`.** `table.unpack` is `nil` on this machine's
  luajit AND inside nvim 0.12.4. Portable shim: `local unpack = table.unpack or unpack`.
- **No `//` integer division** — syntax error in 5.1. Use `math.floor(a / b)`.
- **No bitwise operators** (`&`, `~`, `<<` … are 5.3+ syntax errors). LuaJIT
  ships the `bit` library instead: `bit.band(5, 3)`, `bit.bor`, `bit.bxor`,
  `bit.bnot`, `bit.lshift`, `bit.rshift`. (Available in nvim too.)
- **`goto` WORKS** — it's a LuaJIT extension (5.2 feature). The `continue`
  idiom is fine: `for ... do if skip then goto continue end ... ::continue:: end`.
- **No integer subtype.** All numbers are doubles; `math.type` is `nil`.
  Integers are exact up to 2^53, so don't worry for config work.
- **`#` on sparse arrays is undefined** — `{[1]=1,[2]=2,[4]=4}` may report 4.
  Never put nil holes in arrays you'll `#`/`ipairs`.
- 5.2+ moved things: 5.1 has `loadstring` (5.2+: `load`), `setfenv`/`getfenv`
  (5.2+: `_ENV`), and `math.pow` (removed in 5.3+). LuaJIT keeps those 5.1
  names. (`math.mod` is 5.0-era and `nil` here — use `%` or `math.fmod`.)
- LuaJIT extras you MAY rely on (verified here + in nvim): `goto`, `bit.*`,
  `string.rep(s, n, sep)`, `xpcall(f, handler, args...)`, and the `ffi`
  library (luajit-only; nvim has it but plugins rarely should).
- Rule of thumb: if example code uses `//`, `<<`, `::label::`-free `continue`,
  `table.unpack`, or `math.type`, it's written for 5.3+ — translate before use.

----------------------------------------------------------------------

## 5. The vim.* namespace map (Neovim 0.12)

One line per namespace. `:help <name>` works for every one of them.

| Namespace         | What it's for                                                        | Canonical example                                          |
|-------------------|----------------------------------------------------------------------|------------------------------------------------------------|
| `vim.opt`         | Options as objects; `:append/:prepend/:remove/:get` for list options | `vim.opt.path:append("**")` · `vim.opt.number = true`      |
| `vim.o`           | Options as plain values (get/set, like `:set`)                       | `vim.o.ignorecase = true` · `print(vim.o.shiftwidth)`      |
| `vim.g`           | Global variables (`g:`), incl. plugin settings and leader            | `vim.g.mapleader = " "`                                    |
| `vim.b`           | Buffer-scoped variables (`b:`)                                       | `vim.b.did_ftplugin = 1` · `vim.b[bufnr].x = 1`            |
| `vim.w`           | Window-scoped variables (`w:`)                                       | `vim.w.my_marker = true`                                   |
| `vim.bo`          | Buffer-local options (`:setlocal` for buffers)                       | `vim.bo.shiftwidth = 2` · `vim.bo[bufnr].filetype`         |
| `vim.wo`          | Window-local options (`:setlocal` for windows)                       | `vim.wo.wrap = false`                                      |
| `vim.keymap`      | Keymaps: `set`/`del`, Lua functions as rhs                           | `vim.keymap.set("n", "<leader>ff", fn, { desc = "find" })` |
| `vim.api`         | The raw `nvim_*` C API: buffers, windows, autocmds, highlights       | `vim.api.nvim_create_autocmd("BufWritePre", { callback = f })` |
| `vim.fn`          | Call any Vimscript builtin function from Lua                         | `vim.fn.expand("%:p")` · `vim.fn.has("nvim-0.12") == 1`    |
| `vim.cmd`         | Run ex-commands; callable per command                                | `vim.cmd.colorscheme("tokyonight-night")` · `vim.cmd("set ic")` |
| `vim.uv`          | libuv: timers, filesystem, processes (0.9-era name: `vim.loop`)      | `vim.uv.fs_stat(path)` · `vim.uv.new_timer()`              |
| `vim.ui`          | Overridable UI prompts (plugins like telescope hook these)           | `vim.ui.select(items, { prompt = "?" }, on_choice)`        |
| `vim.lsp`         | LSP client: enable/configure servers, buffer requests                | `vim.lsp.enable("lua_ls")` · `vim.lsp.config("lua_ls", {})` |
| `vim.diagnostic`  | Diagnostics UI: signs, virtual text, lists, jumping                  | `vim.diagnostic.config({ virtual_text = true })`           |
| `vim.treesitter`  | Tree-sitter parsing/highlighting/queries                             | `vim.treesitter.start(bufnr, "lua")`                       |
| `vim.iter`        | Chainable iterator pipeline over tables/iterators                    | `vim.iter(t):map(f):filter(g):totable()`                   |
| `vim.json`        | JSON encode/decode (fast, C-backed)                                  | `vim.json.decode(str)` · `vim.json.encode(tbl)`            |
| `vim.system`      | Run external commands, async or `:wait()`                            | `vim.system({ "git", "status" }, { text = true }):wait().stdout` |
| `vim.notify`      | User-facing message (plugins can pretty it up)                       | `vim.notify("saved", vim.log.levels.INFO)`                 |
| `vim.schedule`    | Run a function on the main loop when it's safe (from callbacks)      | `vim.schedule(function() vim.notify("later") end)`         |
| `vim.defer_fn`    | `vim.schedule` with a delay in ms                                    | `vim.defer_fn(fn, 500)`                                    |
| `vim.tbl_*`       | Table helpers: `tbl_deep_extend/tbl_extend/tbl_contains/tbl_keys/tbl_count/tbl_isempty/tbl_get`, plus `vim.list_extend`, `vim.deepcopy`, `vim.islist` | `vim.tbl_deep_extend("force", defaults, user_opts)` |
| `vim.split` etc.  | String helpers: `split/gsplit/trim/startswith/endswith/pesc`         | `vim.split("a,b,c", ",")` → `{ "a", "b", "c" }` · `vim.trim(s)` |

Scope memory hook: one letter = variables (`g`/`b`/`w`), two letters = local
options (`bo`/`wo`), `opt`/`o` = options-in-general.

Renamed/deprecated names you'll meet in old plugins and blog posts (old → new):
`vim.loop` → `vim.uv` · `vim.highlight` → `vim.hl` · `vim.tbl_islist` →
`vim.islist` · `vim.tbl_flatten(t)` → `vim.iter(t):flatten():totable()` ·
`nvim_buf_set_option(b, k, v)` → `vim.bo[b].k = v` (or `nvim_set_option_value`).

----------------------------------------------------------------------

## 6. Vimscript → Lua translation table

| Vimscript                                   | Lua                                                                    |
|---------------------------------------------|------------------------------------------------------------------------|
| `set number`                                | `vim.opt.number = true` (or `vim.o.number = true`)                     |
| `set path+=**`                              | `vim.opt.path:append("**")`                                            |
| `setlocal shiftwidth=2`                     | `vim.bo.shiftwidth = 2` (buffer opt) / `vim.wo.foo` (window opt)       |
| `nnoremap <leader>w :w<CR>`                 | `vim.keymap.set("n", "<leader>w", "<cmd>w<cr>")`                       |
| `nnoremap` with a function                  | `vim.keymap.set("n", "<leader>f", function() ... end, { desc = "…" })` |
| `vnoremap` / `inoremap` / `tnoremap`        | `vim.keymap.set("v"/"i"/"t", lhs, rhs)` — mode is the first arg        |
| `nunmap <leader>w`                          | `vim.keymap.del("n", "<leader>w")`                                     |
| `autocmd BufWritePre * ...`                 | `vim.api.nvim_create_autocmd("BufWritePre", { pattern = "*", callback = fn })` |
| `augroup mygroup`                           | `local g = vim.api.nvim_create_augroup("mygroup", { clear = true })` then `group = g` in the autocmd |
| `command! Greet echo "hi"`                  | `vim.api.nvim_create_user_command("Greet", function(opts) ... end, { nargs = 0 })` |
| `colorscheme tokyonight-night`              | `vim.cmd.colorscheme("tokyonight-night")`                              |
| `let g:mapleader = " "`                     | `vim.g.mapleader = " "`                                                |
| `let b:x = 1` / `let w:x = 1`               | `vim.b.x = 1` / `vim.w.x = 1`                                          |
| `highlight Normal guibg=NONE`               | `vim.api.nvim_set_hl(0, "Normal", { bg = "none" })`                    |
| `highlight MyGrp guifg=#ff0000 gui=bold`    | `vim.api.nvim_set_hl(0, "MyGrp", { fg = "#ff0000", bold = true })`     |
| `call expand("%:p")`                        | `vim.fn.expand("%:p")` — any Vimscript builtin via `vim.fn`            |
| `echo "msg"`                                | `print("msg")` or `vim.notify("msg")`                                  |
| anything with no Lua API yet                | `vim.cmd("the ex command as a string")` — the escape hatch             |

----------------------------------------------------------------------

## 7. Debugging one-pager

| Tool                       | What it does                                                                  |
|----------------------------|-------------------------------------------------------------------------------|
| `:messages`                | Re-show message history — every `print()`/error that flashed past             |
| `vim.print(thing)`         | Pretty-print any value, tables included (uses `vim.inspect` under the hood)   |
| `:= expr`                  | Eval Lua + pretty-print result: `:=vim.opt.number:get()`, `:=vim.g.mapleader` |
| `:lua ...` / `:luafile %`  | Run one line of Lua / run the current file                                    |
| `:checkhealth`             | Diagnose nvim, providers, and plugins (`:checkhealth lazy`, `:checkhealth vim.lsp`) |
| `nvim --clean`             | Start WITHOUT your config: if the bug vanishes, it's your config/plugins      |
| `nvim --clean -l file.lua` | Headless: run a Lua script and exit — how this course's 06/07 files run       |
| `:Lazy log`                | lazy.nvim: recent plugin updates — "it broke after an update" starts here     |
| `:Lazy` / `:Lazy profile`  | Plugin states / startup time per plugin                                       |
| `:verbose set shiftwidth?` | Show an option's value AND which file last set it                             |
| `:verbose map <leader>f`   | Show a mapping and which file/plugin defined it                               |
| `:help <topic>`            | `:help vim.keymap.set()`, `:help lua-guide`, `:help api` — the real docs      |
| `pcall(require, "mod")`    | Trap a module error: `local ok, m = pcall(require, "telescope")`              |
| read the traceback         | Top line is `file:line:` — an address, not noise. Start there                 |

Bisect recipe: `nvim --clean` (config's fault?) → comment out half of
`lua/plugins/*.lua` → repeat. `:verbose` tells you WHO set the weird option.

----------------------------------------------------------------------

## 8. Where is it taught? — course index

| Topic                                        | File                                             |
|----------------------------------------------|--------------------------------------------------|
| Running Lua, print, comments                 | `01_basics/01_hello_world.lua`                   |
| local, nil, types, dynamic typing            | `01_basics/02_variables_and_types.lua`           |
| Strings, concat, string library basics       | `01_basics/03_strings.lua`                       |
| Numbers, math library, doubles               | `01_basics/04_numbers_and_math.lua`              |
| if/while/repeat/for, numeric for             | `01_basics/05_control_flow.lua`                  |
| Truthiness, and/or idioms, ternary trap      | `01_basics/06_logic_and_idioms.lua`              |
| Defining/calling functions                   | `02_functions/01_function_basics.lua`            |
| Multiple return values                       | `02_functions/02_multiple_returns.lua`           |
| Varargs `...`, select                        | `02_functions/03_varargs.lua`                    |
| Closures and upvalues (every nvim callback)  | `02_functions/04_closures_and_upvalues.lua`      |
| Higher-order functions, callbacks            | `02_functions/05_higher_order_functions.lua`     |
| Recursion                                    | `02_functions/06_recursion.lua`                  |
| Arrays, insert/remove/#, ipairs              | `03_tables/01_arrays.lua`                        |
| Dictionaries, pairs                          | `03_tables/02_dictionaries.lua`                  |
| Nested tables (the shape of every config)    | `03_tables/03_nested_tables.lua`                 |
| References vs copies, aliasing               | `03_tables/04_references_and_copies.lua`         |
| 1-based indexing, sparse `#`, table traps    | `03_tables/05_gotchas.lua`                       |
| Common table idioms/patterns                 | `03_tables/06_patterns.lua`                      |
| require and writing modules                  | `04_modules_metatables_oop/01_modules.lua`       |
| Metatables and `__index`                     | `04_modules_metatables_oop/02_metatables_index.lua` |
| Metamethods (`__add`, `__tostring`, …)       | `04_modules_metatables_oop/03_metamethods.lua`   |
| OOP: classes, methods, `:` sugar             | `04_modules_metatables_oop/04_oop.lua`           |
| Metatable applications (how vim.opt works)   | `04_modules_metatables_oop/05_metatable_applications.lua` |
| pcall/xpcall, error, tracebacks              | `05_advanced/01_error_handling.lua`              |
| String patterns in depth (section 3 here)    | `05_advanced/02_string_patterns.lua`             |
| Iterators, writing your own for-in           | `05_advanced/03_iterators.lua`                   |
| Coroutines                                   | `05_advanced/04_coroutines.lua`                  |
| Scope, environments, globals (`_G`)          | `05_advanced/05_scope_and_env.lua`               |
| File I/O and os.* (feeds the capstone)       | `05_advanced/06_file_io_and_os.lua`              |
| LuaJIT vs 5.x, bit library (section 4 here)  | `05_advanced/07_luajit_notes.lua`                |
| First vim.* contact, nvim --clean -l         | `06_neovim_api/01_hello_neovim.lua`              |
| Options: vim.opt / o / bo / wo               | `06_neovim_api/02_options.lua`                   |
| Keymaps: vim.keymap.set                      | `06_neovim_api/03_keymaps.lua`                   |
| Buffers/windows via vim.api                  | `06_neovim_api/04_buffers_windows_api.lua`       |
| vim.fn: calling Vimscript builtins           | `06_neovim_api/05_vim_fn_bridge.lua`             |
| Autocommands and augroups                    | `06_neovim_api/06_autocommands.lua`              |
| User commands                                | `06_neovim_api/07_user_commands.lua`             |
| vim.tbl_* / iter / json / system / uv        | `06_neovim_api/08_vim_utilities.lua`             |
| vim.cmd and vim.g                            | `06_neovim_api/09_vim_cmd_and_g.lua`             |
| Config anatomy: rtp, require resolution, load order | `07_neovim_config/01_config_anatomy.md`   |
| Debugging your config (section 7 here, deep)  | `07_neovim_config/02_debugging_toolkit.lua`     |
| Reading errors; the five classic config bugs  | `07_neovim_config/03_common_errors.lua`         |
| lazy.nvim specs: opts/config, lazy-loading    | `07_neovim_config/04_lazy_nvim_specs.lua`       |
| Build your own mini-plugin (setup convention) | `07_neovim_config/05_build_a_plugin.lua`        |
| Fix-the-config drills (six broken snippets)   | `07_neovim_config/06_fix_the_config.lua`        |
| Capstone: hyprland.conf as Lua data           | `08_capstone_hyprland/01_model_the_config.lua`  |
| Capstone: serializer, tables → hyprlang text  | `08_capstone_hyprland/02_serializer.lua`        |
| Capstone: DSL, metatables at work, ordering   | `08_capstone_hyprland/03_dsl.lua`               |
| Capstone: port + safely test your real config | `08_capstone_hyprland/04_port_your_config.lua`  |
| Capstone: stretch goals (hyprlock, watch, …)  | `08_capstone_hyprland/05_stretch_goals.md`      |
| Vimscript → Lua translation                  | this file, section 6                             |
| Debugging quick reference                    | this file, section 7                             |
