const std = @import("std");

const LibData = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    test_step: *std.Build.Step,
    install_test_step: *std.Build.Step,
    path: []const u8,
    name: []const u8,
};

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
    const install_test_step = b.step("install_test", "Create test binaries for debugging");
    const rope_lib: LibData = .{
        .b = b,
        .target = target,
        .optimize = optimize,
        .name = "rope",
        .path = "src/rope/root.zig",
        .test_step = test_step,
        .install_test_step = install_test_step,
    };
    install_lib(rope_lib);

    test_step.dependOn(&run_exe_unit_tests.step);
}

fn install_lib(d: LibData) void {
    const mod = d.b.createModule(.{
        .root_source_file = d.b.path(d.path),
        .target = d.target,
        .optimize = d.optimize,
    });
    const lib = d.b.addLibrary(.{
        .linkage = .static,
        .name = d.name,
        .root_module = mod,
    });
    d.b.installArtifact(lib);

    const tests = d.b.addTest(.{ .root_module = mod, .name = d.name });
    const test_artifact = d.b.addInstallArtifact(
        tests,
        .{ .dest_dir = .{ .override = .{ .custom = "tests" } } },
    );
    const run_tests = d.b.addRunArtifact(tests);
    run_tests.step.dependOn(&test_artifact.step);
    d.install_test_step.dependOn(&test_artifact.step);

    d.test_step.dependOn(&run_tests.step);
}
