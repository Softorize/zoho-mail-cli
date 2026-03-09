const std = @import("std");

/// Zoho Mail folder representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Folder = struct {
    /// Unique folder identifier.
    folderId: []const u8,
    /// Folder display name.
    folderName: []const u8,
    /// Parent folder ID (empty for root folders).
    parentFolderId: []const u8 = "",
    /// Folder path string.
    folderPath: []const u8 = "",
    /// Unread message count.
    unreadCount: i64 = 0,
    /// Total message count.
    messageCount: i64 = 0,
    /// Folder type (system or custom).
    folderType: []const u8 = "",
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Folder default field values" {
    const f = Folder{
        .folderId = "f1",
        .folderName = "Inbox",
    };
    try std.testing.expectEqualStrings("f1", f.folderId);
    try std.testing.expectEqualStrings("Inbox", f.folderName);
    try std.testing.expectEqualStrings("", f.parentFolderId);
    try std.testing.expectEqual(@as(i64, 0), f.unreadCount);
    try std.testing.expectEqual(@as(i64, 0), f.messageCount);
}

test "Folder JSON parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{"folderId":"f2","folderName":"Sent","unreadCount":5,"messageCount":100}
    ;
    const f = try std.json.parseFromSliceLeaky(
        Folder,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("f2", f.folderId);
    try std.testing.expectEqualStrings("Sent", f.folderName);
    try std.testing.expectEqual(@as(i64, 5), f.unreadCount);
    try std.testing.expectEqual(@as(i64, 100), f.messageCount);
}

test "Folder JSON parsing ignores unknown fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{"folderId":"f3","folderName":"Draft","extraField":42}
    ;
    const f = try std.json.parseFromSliceLeaky(
        Folder,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("f3", f.folderId);
    try std.testing.expectEqualStrings("Draft", f.folderName);
}
