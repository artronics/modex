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

    const backend = b.option([]const u8, "backend", "Which backend to use: sdl3|sdl2") orelse "sdl3";
    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
    });

    if (std.mem.eql(u8, backend, "sdl3")) {
        exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
        exe.root_module.addImport("backend", dvui_dep.module("sdl3"));
        exe.linkSystemLibrary("SDL3");
    } else {
        @panic("Unsupported backend; choose -Dbackend=sdl3 or -Dbackend=sdl2");
    }

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

pub fn build2(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const backend = b.option([]const u8, "backend", "Which backend to use: sdl3|sdl2") orelse "sdl3";

    const exe = b.addExecutable(.{
        .name = "hello-dvui",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Pull in DVUI
    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
    });

    // Select and wire the backend and dvui module
    if (std.mem.eql(u8, backend, "sdl3")) {
        exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
        exe.root_module.addImport("backend", dvui_dep.module("sdl3"));

        // On your system, install SDL3 dev files, then link it:
        // Linux: libSDL3-dev or equivalent
        // macOS: brew install sdl3
        // Windows: vcpkg install sdl3 or ship the DLL
        exe.linkSystemLibrary("SDL3");
    } else if (std.mem.eql(u8, backend, "sdl2")) {
        exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl2"));
        exe.root_module.addImport("backend", dvui_dep.module("sdl2"));
        exe.linkSystemLibrary("SDL2");
    } else {
        @panic("Unsupported backend; choose -Dbackend=sdl3 or -Dbackend=sdl2");
    }

    // Optional: enable LLD if you run into linking issues (platform-dependent)
    // exe.use_lld = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.stdio = .inherit;
    const run_step = b.step("run", "Run hello-dvui");
    run_step.dependOn(&run_cmd.step);
}