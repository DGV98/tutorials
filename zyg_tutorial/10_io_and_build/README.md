# Module 10: I/O and the Build System

Everything you've written so far was a pure function checked by a test, with
`std.debug.print` as the only window out. This module is where your programs
meet the outside world: real stdout, real files, real command-line arguments —
and a real multi-file project built with `zig build`.

One warning up front: **I/O is the part of Zig that changed most in 0.15/0.16.**
Nearly every tutorial, blog post, and LLM answer online shows `std.fs.cwd()`
and `std.io.getStdOut()`. Those are gone. Trust this README and
[docs/zig-0.16-notes.md](../docs/zig-0.16-notes.md) over anything older.

## What you'll learn

- The `std.Io` interface: I/O as an explicit dependency, exactly like allocators
- `pub fn main(init: std.process.Init)` — where the `Io` and allocator come from
- Buffered writers, the `.interface` pointer, and why you must `flush()`
- Reading a file whole (`readFileAlloc`) vs streaming it line by line
- Constructing an `Io` inside tests with `std.Io.Threaded`
- Command-line arguments with `std.process.Args.Iterator`
- `build.zig` and `build.zig.zon`: modules, executables, test steps
- The `zig init` / `zig build` / `zig build test` / `zig build run` workflow

## Io is an explicit dependency

Module 7 taught you Zig's deal on memory: nothing allocates without being
handed an `std.mem.Allocator`. Since 0.15, I/O works the same way. Any function
that touches a file, a socket, or stdout takes an `std.Io` value, and you can
tell *from the signature* that it does I/O:

```zig
fn analyze(io: std.Io, path: []const u8) !Stats   // does I/O
fn countLines(text: []const u8) usize             // provably doesn't
```

The payoffs are the same as with allocators — honest signatures, testable code,
swappable implementations (thread-pool, event-loop, mock) — and so is the
cost: one more parameter to thread through your program.

Where does the first `Io` come from? The entry point. Plain `pub fn main() !void`
still works, but declare main the new way and the runtime hands you everything:

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;    // the Io instance
    const gpa = init.gpa;  // general-purpose allocator, leak-checked in Debug
    // init.arena.allocator() — an arena freed automatically at exit
    // init.minimal.args     — the command-line arguments
}
```

No more declaring a `DebugAllocator` by hand at the top of every main: you get
a checked allocator and an `Io` for free, and pass them down to whoever needs them.

## Buffered stdout — and flush

`std.debug.print` goes to *stderr*, unbuffered — right for debugging and error
messages, wrong for program output. Real output goes to stdout through a
buffered writer. It's a three-line incantation:

```zig
var buf: [1024]u8 = undefined;
var stdout_writer = std.Io.File.stdout().writer(io, &buf);
const stdout = &stdout_writer.interface; // *std.Io.Writer

try stdout.print("Hello, {s}! {d}\n", .{ "world", 42 });
try stdout.flush(); // nothing appears without this
```

Two things to internalize:

- **Why the buffer?** Every unbuffered write is a syscall. Print a table
  cell by cell and that's dozens of syscalls; with a buffer it's one. You
  supply the buffer yourself — Zig won't hide an allocation from you.
- **Why `.interface`?** `stdout_writer` is a concrete `std.Io.File.Writer`.
  Its `interface` field is the generic `*std.Io.Writer` that `print`,
  `writeAll`, and friends are defined on. You always format through that
  pointer. Readers mirror this exactly (`file_reader.interface`).

The price of buffering: bytes sit in your buffer until it fills or you flush.
Forget `flush()` and the program exits with output still in the buffer —
silently dropped. This is the classic bug of the module; there's a Gotchas
entry on it below.

## Reading a whole file

For small inputs, slurp the file into one allocated buffer:

```zig
const text = try std.Io.Dir.cwd().readFileAlloc(io, "input.txt", gpa, .limited(1 << 16));
defer gpa.free(text);
```

Read that call left to right: current working directory, the `io`, the path,
the allocator that owns the result, and a size limit. `.limited(1 << 16)`
means "refuse files over 64 KiB" — a guard against slurping a gigabyte by
accident. You own the returned `[]u8`; the `defer gpa.free(text)` is not
optional (in tests, `std.testing.allocator` will fail the test if you leak it).

Old-code translation: `std.fs.cwd()` is now `std.Io.Dir.cwd()`, and everything
downstream wants the `io` passed in.

For files known at *compile* time there's also `@embedFile("input.txt")` — no
`Io`, no allocator, the bytes are baked into the binary. Handy for fixed data,
useless for anything the user picks at runtime.

## Streaming a file line by line

Slurping is O(file size) in memory. The streaming version uses a fixed 4 KiB
buffer no matter how big the file is, and it's the canonical shape for parsing
puzzle input — you'll write this loop in module 12 more times than you'd like:

```zig
var file = try std.Io.Dir.cwd().openFile(io, path, .{});
defer file.close(io); // close wants the io back too

var rbuf: [4096]u8 = undefined;
var file_reader = file.reader(io, &rbuf);
const r = &file_reader.interface; // *std.Io.Reader — same dance as the writer

while (try r.takeDelimiter('\n')) |line| {
    const trimmed = std.mem.trim(u8, line, " \t\r");
    if (trimmed.len == 0) continue;
    const n = try std.fmt.parseInt(i64, trimmed, 10);
    // ... accumulate ...
}
```

`takeDelimiter('\n')` returns the next line without the `'\n'` (which it
consumes) and `null` at end of stream — it slots straight into the
while-with-unwrap pattern from module 4.

Two sharp edges:

- **`line` points into the reader's buffer.** It's valid only until the next
  `take*` call. Parse it or copy it before moving on.
- **`takeDelimiterExclusive` is a near-miss trap.** It does *not* consume the
  delimiter, so a naive loop reads the first line and then spins forever on
  empty slices. `takeDelimiter` is the loop-friendly one.

## Getting an Io inside a test

Tests don't receive `std.process.Init`, so there's no `init.io` to grab.
Construct an implementation yourself — `std.Io.Threaded` is the standard
general-purpose one:

```zig
test "reads a file" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    // pass io to the code under test
}
```

Note the shape: `threaded` is the concrete implementation, `threaded.io()` is
the interface value you pass around. The same split you've seen with
`DebugAllocator` / `.allocator()` in module 7 — Zig uses this pattern for
every pluggable dependency.

## Command-line arguments

The raw arguments live in `init.minimal.args`; an iterator walks them:

```zig
var args: std.process.Args.Iterator = .init(init.minimal.args);
_ = args.next(); // argv[0] is the program's own path — skip it

while (args.next()) |arg| {
    const n = std.fmt.parseInt(i64, arg, 10) catch {
        std.debug.print("error: '{s}' is not an integer\n", .{arg});
        std.process.exit(1);
    };
    // ...
}
```

CLI habits worth keeping: a user typo is not a programmer bug, so `catch` it
and print something helpful instead of `try`-ing an error trace at them; error
messages go to stderr (`std.debug.print` is exactly right for once); and
`std.process.exit(1)` tells the shell the run failed. When testing with
`zig run`, arguments go after a `--`:

```sh
zig run 04_args_cli.zig -- 3 4 5
```

## A real project: wordcount

Single files and `zig test` carried you through nine modules. Real programs
have multiple files, a library/executable split, and a build description. The
`wordcount/` directory is a complete, minimal package — the same layout
`zig init` generates:

```
wordcount/
├── build.zig       # how to build it (a Zig program!)
├── build.zig.zon   # package metadata (name, version, dependencies)
└── src/
    ├── main.zig    # the CLI — argument handling only
    └── root.zig    # the library — the actual logic, plus its tests
```

The split matters: `main.zig` does I/O and argument parsing, `root.zig` is
pure functions over `[]const u8`. That's why the logic is unit-testable at
all — tests hand it strings, no files required.

### build.zig, top to bottom

`build.zig` is a normal Zig program. Its `build` function doesn't compile
anything — it declares a *graph* of steps, which the build runner executes in
parallel where possible, caching what hasn't changed.

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
```

These two register the standard knobs: `-Dtarget=...` (cross-compilation is
built in — try `zig build -Dtarget=x86_64-windows`) and `-Doptimize=Debug|
ReleaseSafe|ReleaseFast|ReleaseSmall`, defaulting to your machine and Debug.

```zig
    const mod = b.addModule("wordcount", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
```

A *module* is a set of source files rooted at one file. This is the library:
everything reachable from `src/root.zig`. `addModule` (versus `createModule`
below) also exports it to other packages that might depend on this one.

```zig
    const exe = b.addExecutable(.{
        .name = "wordcount",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "wordcount", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);
```

The executable is a second module, rooted at `src/main.zig`. The `.imports`
list is the wiring: it makes `@import("wordcount")` inside main.zig resolve to
the library module. That name is *not* a file path — imports between modules
go through build.zig, only imports within a module use paths.
`installArtifact` means "when someone runs plain `zig build`, copy the
finished exe into `zig-out/bin/`" — without it the exe is built but stays in
the cache.

```zig
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
```

`b.step` creates a top-level step you can name on the command line:
`zig build run`. On its own a step does nothing — it only does what the steps
it *depends on* do, so we hang a run-the-exe command under it. The last line
forwards everything after `--` to your program: `zig build run -- src/main.zig`.

```zig
    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
```

A test binary covers exactly one module, hence two of them: one for the
library's `test` blocks, one for any in the exe. `zig build test` depends on
both; they run in parallel.

### build.zig.zon

The package manifest — `.zon` is "Zig Object Notation", an anonymous struct
literal. Four fields to know: `.name` (an enum literal — the key other
packages use to depend on you), `.fingerprint` (generated once by `zig init`,
then never changed; identifies the package across versions), `.dependencies`
(empty here; `zig fetch --save <url>` fills it), and `.paths` (which files
ship when someone fetches this package).

### The workflow

```sh
zig init            # scaffold build.zig, build.zig.zon, src/ in an empty dir
zig build           # build everything, install to zig-out/
zig build test      # build and run all test steps
zig build run -- X  # build, install, and run the exe with argument X
```

The first build populates `.zig-cache/`; later builds recompile only what
changed. `.zig-cache/` and `zig-out/` are disposable — delete freely, never commit.

## Gotchas

- **Forgetting `flush()`.** The program runs, exits 0, prints nothing (or —
  nastier — prints only the part that fit in one buffer fill). If output is
  mysteriously missing, check for a missing flush before anything else.
- **cwd-relative paths in `zig test`.** `std.Io.Dir.cwd()` resolves against
  the directory you *run from*, not the .zig file's location. Exercises 02
  and 03 open `data/...`, so run `zig test` from this module's directory or
  you'll get `error.FileNotFound`. `./check.sh 10` cd's in for you. (Only
  `@embedFile` resolves relative to the source file.)
- **`takeDelimiterExclusive` in a loop.** Doesn't consume the delimiter;
  loops over it spin forever. Use `takeDelimiter` — and remember the slice it
  returns is invalidated by the next read; `gpa.dupe` it if you keep it.
- **Forgetting to skip argv[0].** Your program tries to parse its own path
  as input. First `args.next()` is the program name; throw it away.
- **`.zig-cache/` and `zig-out/` noise.** Every `zig build` (and `zig test`
  inside a package) drops these in the package directory. They're caches:
  safe to delete, pure noise in `git status` — put both in `.gitignore` on
  your own projects.
- **Old-tutorial I/O won't compile.** `std.fs.cwd()`, `std.io.getStdOut()`,
  `readUntilDelimiterOrEof` — all pre-0.15. See the cheat table in
  [docs/zig-0.16-notes.md](../docs/zig-0.16-notes.md) for the translations.

## Exercises

Work through them in order. 01 and 04 are programs — `zig run` them and
compare against the expected output in the header; 02 and 03 are the usual
red-to-green `zig test` files (run from this directory!); 05 is a package.

1. `01_stdout.zig` — buffered stdout writer, `.interface`, `flush()`; print a
   5×5 multiplication table. Run: `zig run 01_stdout.zig`.
2. `02_read_file.zig` — `std.Io.Threaded` in a test, `readFileAlloc` with a
   size limit, freeing what you read.
3. `03_read_lines.zig` — `openFile` + `File.Reader` + `takeDelimiter`: stream
   numbers.txt and compute sum and max.
4. `04_args_cli.zig` — `Args.Iterator`, parse-or-exit-1, a usage message;
   sum and product of integer arguments. Run: `zig run 04_args_cli.zig -- 3 4 5`.
5. `wordcount/` — implement the counting functions in `src/root.zig`, then
   `zig build test` and `zig build run -- src/main.zig` from `wordcount/`.

Solutions live in `solutions/10_io_and_build/` — same filenames.
