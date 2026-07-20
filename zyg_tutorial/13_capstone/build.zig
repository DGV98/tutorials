const std = @import("std");

// Same shape as module 10's wordcount build script, with three additions
// worth knowing about, each commented at the line where it happens:
//
//   1. ONE module for the whole project. wordcount split lib and exe into
//      two modules; here every file is reached from src/main.zig through
//      file-relative imports ("lib/parse.zig"). That's what lets you also
//      run `zig test src/lib/parse.zig` directly, without the build system.
//   2. setCwd on every run step, so "input/final.txt" resolves against the
//      project root no matter where the build is invoked from.
//   3. Focused test steps (test-parse, test-grid, ...) — the milestone
//      workflow. Plain `zig build test` still runs everything.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "aoc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    // ---- zig build run -- <puzzle> [input-path] ---------------------------
    const run_step = b.step("run", "Run the puzzle runner");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    // The runner reads input files by relative path at RUNTIME. Pinning the
    // working directory to the project root makes "input/final.txt" work
    // regardless of where `zig build` was invoked.
    run_cmd.setCwd(b.path("."));
    if (b.args) |args| run_cmd.addArgs(args);
    run_step.dependOn(&run_cmd.step);

    // ---- zig build test: everything ---------------------------------------
    // One test binary rooted at src/main.zig; its `test { _ = @import ... }`
    // block pulls in the tests of every other file.
    const all_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_all_tests = b.addRunArtifact(all_tests);
    // The final.zig answer tests read input/final.txt at runtime, so test
    // runs get their cwd pinned too.
    run_all_tests.setCwd(b.path("."));
    const test_step = b.step("test", "Run every test in the project");
    test_step.dependOn(&run_all_tests.step);

    // ---- zig build test-parse / test-grid / test-algo ---------------------
    // One small module per library file. Identical to what plain
    // `zig test src/lib/parse.zig` does, but cached and named.
    const focused = [_]struct { step: []const u8, file: []const u8, desc: []const u8 }{
        .{ .step = "test-parse", .file = "src/lib/parse.zig", .desc = "Milestone 1: parse.zig tests" },
        .{ .step = "test-grid", .file = "src/lib/grid.zig", .desc = "Milestone 2: grid.zig tests" },
        .{ .step = "test-algo", .file = "src/lib/algo.zig", .desc = "Milestone 3: algo.zig tests" },
    };
    for (focused) |f| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(f.file),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_t = b.addRunArtifact(t);
        run_t.setCwd(b.path("."));
        b.step(f.step, f.desc).dependOn(&run_t.step);
    }

    // ---- zig build test-final ----------------------------------------------
    // final.zig imports "../lib/..." — paths that climb ABOVE the file. Zig
    // only allows that while the file is part of a module rooted higher up
    // (here: src/main.zig), so final.zig can't be its own test root like the
    // lib files can. Instead: build the full test binary and let a name
    // filter select just the puzzle's tests.
    const final_tests = b.addTest(.{
        .root_module = exe.root_module,
        .filters = &.{"puzzles.final"},
    });
    const run_final_tests = b.addRunArtifact(final_tests);
    run_final_tests.setCwd(b.path("."));
    b.step("test-final", "Milestone 5: the mega-puzzle answer checker").dependOn(&run_final_tests.step);
}
