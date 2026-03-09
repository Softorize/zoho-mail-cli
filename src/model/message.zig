const std = @import("std");

/// Email message as returned by the Zoho Mail API.
/// Field names match Zoho API JSON keys (camelCase).
pub const Message = struct {
    /// Unique message identifier.
    messageId: []const u8,
    /// Folder containing this message.
    folderId: []const u8 = "",
    /// Subject line.
    subject: []const u8 = "",
    /// Sender address (display format).
    sender: []const u8 = "",
    /// Comma-separated To recipients.
    toAddress: []const u8 = "",
    /// Comma-separated Cc recipients.
    ccAddress: []const u8 = "",
    /// Received timestamp (epoch ms).
    receivedTime: i64 = 0,
    /// Read/unread status.
    isRead: bool = false,
    /// Flagged status.
    isFlagged: bool = false,
    /// Message summary (snippet).
    summary: []const u8 = "",
    /// Full message content (only populated on read).
    content: []const u8 = "",
    /// Whether the message has attachments.
    hasAttachment: bool = false,
    /// Message status code from Zoho.
    status: []const u8 = "",
};

/// Request payload for sending an email.
/// Field names match Zoho API JSON keys for serialization.
pub const SendRequest = struct {
    /// Sender email address.
    fromAddress: []const u8,
    /// Comma-separated To recipients.
    toAddress: []const u8,
    /// Email subject.
    subject: []const u8 = "",
    /// Email body content.
    content: []const u8 = "",
    /// Comma-separated Cc recipients.
    ccAddress: []const u8 = "",
    /// Comma-separated Bcc recipients.
    bccAddress: []const u8 = "",
    /// MIME content type ("text/html" or "text/plain").
    mailFormat: []const u8 = "html",
};

/// Parameters for searching messages.
/// Field names match Zoho API query parameter keys.
pub const SearchParams = struct {
    /// Search query string.
    searchKey: []const u8,
    /// Maximum results to return.
    limit: i64 = 50,
    /// Start index for pagination.
    start: i64 = 0,
};

/// Parameters for updating a message (flag/move/mark-read/label).
/// These are CLI-internal; serialized to Zoho JSON manually.
pub const UpdateParams = struct {
    /// Message IDs to update.
    message_id: []const u8,
    /// Update mode: "markAsRead", "markAsUnread", "moveToFolder", etc.
    mode: []const u8,
    /// Target folder ID (for move operations).
    dest_folder_id: []const u8 = "",
    /// Flag value (for flag operations).
    flag_value: []const u8 = "",
    /// Label ID (for label operations).
    label_id: []const u8 = "",
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Message default field values" {
    const msg = Message{ .messageId = "m1" };
    try std.testing.expectEqualStrings("m1", msg.messageId);
    try std.testing.expectEqualStrings("", msg.subject);
    try std.testing.expectEqual(@as(i64, 0), msg.receivedTime);
    try std.testing.expect(!msg.isRead);
    try std.testing.expect(!msg.hasAttachment);
}

test "Message JSON parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{"messageId":"m2","subject":"Hello","isRead":true,"receivedTime":1700000000}
    ;
    const msg = try std.json.parseFromSliceLeaky(
        Message,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("m2", msg.messageId);
    try std.testing.expectEqualStrings("Hello", msg.subject);
    try std.testing.expect(msg.isRead);
    try std.testing.expectEqual(@as(i64, 1700000000), msg.receivedTime);
}

test "SendRequest default values" {
    const req = SendRequest{
        .fromAddress = "me@example.com",
        .toAddress = "you@example.com",
    };
    try std.testing.expectEqualStrings("html", req.mailFormat);
    try std.testing.expectEqualStrings("", req.ccAddress);
}

test "SearchParams default values" {
    const sp = SearchParams{ .searchKey = "test" };
    try std.testing.expectEqual(@as(i64, 50), sp.limit);
    try std.testing.expectEqual(@as(i64, 0), sp.start);
}

test "UpdateParams default values" {
    const up = UpdateParams{
        .message_id = "m1",
        .mode = "markAsRead",
    };
    try std.testing.expectEqualStrings("", up.dest_folder_id);
    try std.testing.expectEqualStrings("", up.flag_value);
    try std.testing.expectEqualStrings("", up.label_id);
}
