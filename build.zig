const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // exe_mod.addImport("modex_lib", lib_mod);
    const exe = b.addExecutable(.{
        .name = "modex",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    install_lib(b, target, optimize, test_step, "src/rope/root.zig", "rope");

    test_step.dependOn(&run_exe_unit_tests.step);
}

// FIXME: extract params into a struct
fn install_lib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, test_step: *std.Build.Step, path: []const u8, name: []const u8) void {
    const mod = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = name,
        .root_module = mod,
    });
    b.installArtifact(lib);

    const tests = b.addTest(.{ .root_module = mod, .name = name });
    const test_artifact = b.addInstallArtifact(
        tests,
        .{ .dest_dir = .{ .override = .{ .custom = "tests" } } },
    );
    const run_tests = b.addRunArtifact(tests);
    run_tests.step.dependOn(&test_artifact.step);

    test_step.dependOn(&run_tests.step);
}
