const std = @import("std");

/// Configure the zoho-mail CLI build.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "zoho-mail",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the CLI");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const test_step = b.step("test", "Run unit tests");

    // Integration test via main.zig (covers cmd/*, api/*, and all transitives)
    const main_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_main_test = b.addRunArtifact(main_test);
    test_step.dependOn(&run_main_test.step);

    // Standalone model tests (no parent imports needed)
    const model_files = [_][]const u8{
        "src/model/common.zig",
        "src/model/account.zig",
        "src/model/message.zig",
        "src/model/folder.zig",
        "src/model/label.zig",
        "src/model/task.zig",
        "src/model/org.zig",
    };

    for (model_files) |file| {
        const unit_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(file),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_unit_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_unit_test.step);
    }

    // Standalone lib tests (no parent imports needed)
    const lib_files = [_][]const u8{
        "src/http.zig",
        "src/config.zig",
    };

    for (lib_files) |file| {
        const unit_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(file),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_unit_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_unit_test.step);
    }
}
