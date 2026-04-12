const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // We define the executable directly.
    // Since we aren't splitting into a library (root.zig) and a CLI (main.zig),
    // we put all logic into the executable's root module.
    const exe = b.addExecutable(.{
        .name = "merry_christmas_1234",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add the Vulkan dependency to the executable
    const vulkan = b.dependency("vulkan", .{
        .registry = b.path("vk.xml"),
    }).module("vulkan-zig");
    exe.root_module.addImport("vulkan", vulkan);

    // Install the executable
    b.installArtifact(exe);

    // Create the 'run' step
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create the 'test' step
    // This will now only run test blocks found inside main.zig
    // (and any files main.zig imports)
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
