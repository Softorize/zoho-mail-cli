const std = @import("std");

/// Zoho Mail label representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Label = struct {
    /// Unique label identifier.
    labelId: []const u8,
    /// Label display name.
    labelName: []const u8,
    /// Label color hex code.
    color: []const u8 = "",
    /// Number of messages with this label.
    messageCount: i64 = 0,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Label default field values" {
    const l = Label{
        .labelId = "l1",
        .labelName = "Important",
    };
    try std.testing.expectEqualStrings("l1", l.labelId);
    try std.testing.expectEqualStrings("Important", l.labelName);
    try std.testing.expectEqualStrings("", l.color);
    try std.testing.expectEqual(@as(i64, 0), l.messageCount);
}

test "Label JSON parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{"labelId":"l2","labelName":"Work","color":"#FF0000","messageCount":42}
    ;
    const l = try std.json.parseFromSliceLeaky(
        Label,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("l2", l.labelId);
    try std.testing.expectEqualStrings("Work", l.labelName);
    try std.testing.expectEqualStrings("#FF0000", l.color);
    try std.testing.expectEqual(@as(i64, 42), l.messageCount);
}

test "Label JSON parsing ignores unknown fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{"labelId":"l3","labelName":"Personal","unknownKey":"val"}
    ;
    const l = try std.json.parseFromSliceLeaky(
        Label,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("l3", l.labelId);
    try std.testing.expectEqualStrings("Personal", l.labelName);
}
