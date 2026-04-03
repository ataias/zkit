const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zkit", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    const euler_problems = .{ "p0001", "p0005_1", "p0005_2", "p0006_1", "p0007_1", "p0008_1" };
    inline for (euler_problems) |name| {
        const euler_mod = b.addModule(name, .{
            .root_source_file = b.path("src/euler/" ++ name ++ ".zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zkit", .module = mod }},
        });

        const exe = b.addExecutable(.{
            .name = name,
            .root_module = euler_mod,
        });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run-" ++ name, "Run Euler problem " ++ name);
        run_step.dependOn(&run_cmd.step);

        const euler_test = b.addTest(.{ .root_module = euler_mod });
        test_step.dependOn(&b.addRunArtifact(euler_test).step);
    }
}
