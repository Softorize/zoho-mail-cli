const std = @import("std");

/// Zoho Mail account representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Account = struct {
    /// Unique account identifier.
    accountId: []const u8,
    /// Display name for the account.
    displayName: []const u8 = "",
    /// Primary email address.
    emailAddress: []const u8,
    /// Account type (e.g., "premium", "free").
    type: []const u8 = "",
    /// Whether this is the primary account.
    primary: bool = false,
    /// Incoming mail server name.
    incomingServer: []const u8 = "",
    /// Outgoing mail server name.
    outgoingServer: []const u8 = "",
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Account default field values" {
    const acct = Account{
        .accountId = "123",
        .emailAddress = "user@example.com",
    };
    try std.testing.expectEqualStrings("123", acct.accountId);
    try std.testing.expectEqualStrings("user@example.com", acct.emailAddress);
    try std.testing.expectEqualStrings("", acct.displayName);
    try std.testing.expect(!acct.primary);
}

test "Account JSON parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{"accountId":"456","emailAddress":"a@b.com","displayName":"Test","primary":true}
    ;
    const acct = try std.json.parseFromSliceLeaky(
        Account,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("456", acct.accountId);
    try std.testing.expectEqualStrings("Test", acct.displayName);
    try std.testing.expect(acct.primary);
}

test "Account JSON parsing ignores unknown fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{"accountId":"789","emailAddress":"x@y.com","unknownField":"ignore"}
    ;
    const acct = try std.json.parseFromSliceLeaky(
        Account,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("789", acct.accountId);
    try std.testing.expectEqualStrings("x@y.com", acct.emailAddress);
}
