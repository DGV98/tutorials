const std = @import("std");

// build.zig is a normal Zig program. This function does not compile anything
// itself — it declares a *graph* of steps (compile this, run that) which the
// build runner then executes, in parallel where possible, caching whatever
// hasn't changed. The README of module 10 walks through this file top to
// bottom.
pub fn build(b: *std.Build) void {
    // Lets the person running `zig build` pick a target CPU/OS with
    // -Dtarget=... (default: the machine you're on). Cross-compiling is
    // built in — try `zig build -Dtarget=x86_64-windows`.
    const target = b.standardTargetOptions(.{});

    // Lets them pick an optimization mode: -Doptimize=Debug (default),
    // ReleaseSafe, ReleaseFast, or ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    // A module is a collection of source files rooted at one file. This one
    // is our *library*: the counting logic in src/root.zig. addModule (as
    // opposed to createModule below) makes it importable by OTHER packages
    // that depend on this one, under the name "wordcount".
    const mod = b.addModule("wordcount", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // The executable: a second module rooted at src/main.zig (the CLI),
    // which imports the library module. Keeping logic in the library and
    // only argument handling in main is what makes the logic unit-testable.
    const exe = b.addExecutable(.{
        .name = "wordcount",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            // `.name` is what @import("wordcount") resolves to in main.zig.
            .imports = &.{
                .{ .name = "wordcount", .module = mod },
            },
        }),
    });

    // "When someone runs plain `zig build`, copy the finished exe into
    // zig-out/bin/." Without this line the exe is built but stays in the
    // cache.
    b.installArtifact(exe);

    // A top-level step: `zig build run`. On its own a step does nothing —
    // it only does what the steps it *depends on* do.
    const run_step = b.step("run", "Run the app");

    // A step that executes the compiled exe. Wiring it under run_step is
    // what makes `zig build run` actually run the program.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // Run from the installed location (zig-out), not the cache.
    run_cmd.step.dependOn(b.getInstallStep());

    // Everything after `--` on the command line is forwarded to the program:
    //   zig build run -- src/main.zig
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Compile the library module's `test` blocks into a test runner...
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // ...and the same for any tests in the exe module. A test binary covers
    // exactly one module, hence two of them.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // The `zig build test` step depends on both test runners; they run in
    // parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
