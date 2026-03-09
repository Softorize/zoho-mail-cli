const std = @import("std");
const root = @import("cmd/root.zig");

/// Log level for the application.
pub const std_options: std.Options = .{ .log_level = .info };

/// Entry point. Creates GPA, delegates to cmd/root.zig.
pub fn main() void {
    run() catch |err| {
        std.log.err("fatal: {}", .{err});
        std.process.exit(1);
    };
}

/// Initialize allocator and dispatch to root command handler.
fn run() !void {
    var gpa_impl: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();
    try root.run(gpa);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test {
    std.testing.refAllDecls(@This());
    // Force-reference all modules so their tests get discovered.
    _ = root;
}

test "run function is callable" {
    _ = &run;
}

test "main function is callable" {
    _ = &main;
}
