const std = @import("std");

/// Zoho Mail task representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Task = struct {
    /// Unique task identifier.
    taskId: []const u8,
    /// Task title.
    title: []const u8,
    /// Task description/notes.
    notes: []const u8 = "",
    /// Due date (epoch ms, 0 = no due date).
    dueDate: i64 = 0,
    /// Task priority (1=Low, 2=Medium, 3=High).
    priority: i32 = 2,
    /// Completion percentage (0-100).
    percentage: i32 = 0,
    /// Task status: "notstarted", "inprogress", "completed".
    status: []const u8 = "notstarted",
    /// Assignee email address.
    assignee: []const u8 = "",
    /// Group ID (for group tasks).
    groupId: []const u8 = "",
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Task default field values" {
    const t = Task{
        .taskId = "t1",
        .title = "Fix bug",
    };
    try std.testing.expectEqualStrings("t1", t.taskId);
    try std.testing.expectEqualStrings("Fix bug", t.title);
    try std.testing.expectEqual(@as(i32, 2), t.priority);
    try std.testing.expectEqual(@as(i32, 0), t.percentage);
    try std.testing.expectEqualStrings("notstarted", t.status);
    try std.testing.expectEqual(@as(i64, 0), t.dueDate);
}

test "Task JSON parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{"taskId":"t2","title":"Deploy","priority":3,"percentage":50,"status":"inprogress"}
    ;
    const t = try std.json.parseFromSliceLeaky(
        Task,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("t2", t.taskId);
    try std.testing.expectEqualStrings("Deploy", t.title);
    try std.testing.expectEqual(@as(i32, 3), t.priority);
    try std.testing.expectEqual(@as(i32, 50), t.percentage);
    try std.testing.expectEqualStrings("inprogress", t.status);
}

test "Task JSON parsing ignores unknown fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{"taskId":"t3","title":"Review","extra":true}
    ;
    const t = try std.json.parseFromSliceLeaky(
        Task,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("t3", t.taskId);
    try std.testing.expectEqualStrings("Review", t.title);
}
