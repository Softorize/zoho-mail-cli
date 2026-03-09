const std = @import("std");

/// Email message as returned by the Zoho Mail API.
/// All fields are strings because Zoho returns mixed types
/// (numbers as strings, bools as "0"/"1").
pub const Message = struct {
    /// Unique message identifier.
    messageId: []const u8,
    /// Folder containing this message.
    folderId: []const u8 = "",
    /// Subject line.
    subject: []const u8 = "",
    /// Sender address (display format).
    sender: []const u8 = "",
    /// From address.
    fromAddress: []const u8 = "",
    /// Comma-separated To recipients.
    toAddress: []const u8 = "",
    /// Comma-separated Cc recipients.
    ccAddress: []const u8 = "",
    /// Received timestamp (epoch ms as string).
    receivedTime: []const u8 = "",
    /// Message summary (snippet).
    summary: []const u8 = "",
    /// Full message content (only populated on read).
    content: []const u8 = "",
    /// Has attachment flag ("0" or "1").
    hasAttachment: []const u8 = "0",
    /// Message status code from Zoho.
    status: []const u8 = "",
    /// Flag status string.
    flagid: []const u8 = "",
    /// Thread ID.
    threadId: []const u8 = "",
    /// Message priority.
    priority: []const u8 = "",
    /// Message size in bytes.
    size: []const u8 = "",

    /// Check if message has been read (status "1" = read).
    pub fn isRead(self: Message) bool {
        return std.mem.eql(u8, self.status, "1");
    }
};

/// Request payload for sending an email.
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
pub const SearchParams = struct {
    /// Search query string.
    searchKey: []const u8,
    /// Maximum results to return.
    limit: i64 = 50,
    /// Start index for pagination.
    start: i64 = 0,
};

/// Parameters for updating a message.
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
    const m = Message{ .messageId = "m1" };
    try std.testing.expectEqualStrings("m1", m.messageId);
    try std.testing.expectEqualStrings("", m.subject);
    try std.testing.expect(!m.isRead());
}

test "Message isRead returns true for status 1" {
    const m = Message{ .messageId = "m1", .status = "1" };
    try std.testing.expect(m.isRead());
}

test "SendRequest default values" {
    const req = SendRequest{
        .fromAddress = "me@example.com",
        .toAddress = "you@example.com",
    };
    try std.testing.expectEqualStrings("html", req.mailFormat);
}

test "SearchParams default values" {
    const sp = SearchParams{ .searchKey = "test" };
    try std.testing.expectEqual(@as(i64, 50), sp.limit);
}
