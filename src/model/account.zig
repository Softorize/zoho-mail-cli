const std = @import("std");

/// Zoho Mail account representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Account = struct {
    /// Unique account identifier.
    accountId: []const u8,
    /// Display name for the account.
    displayName: []const u8 = "",
    /// Primary email address (parsed from mailboxAddress).
    mailboxAddress: []const u8 = "",
    /// Account name.
    accountName: []const u8 = "",
    /// Whether this is the default account.
    isDefaultAccount: bool = false,
    /// User's first name.
    firstName: []const u8 = "",
    /// User's last name.
    lastName: []const u8 = "",
    /// Account role (member, admin, etc).
    role: []const u8 = "",
    /// Mailbox status.
    mailboxStatus: []const u8 = "",
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Account default field values" {
    const acct = Account{
        .accountId = "123",
    };
    try std.testing.expectEqualStrings("123", acct.accountId);
    try std.testing.expectEqualStrings("", acct.displayName);
    try std.testing.expect(!acct.isDefaultAccount);
}

test "Account JSON parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{"accountId":"456","mailboxAddress":"a@b.com","displayName":"Test","isDefaultAccount":true}
    ;
    const acct = try std.json.parseFromSliceLeaky(
        Account,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("456", acct.accountId);
    try std.testing.expectEqualStrings("Test", acct.displayName);
    try std.testing.expect(acct.isDefaultAccount);
}

test "Account JSON parsing ignores unknown fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{"accountId":"789","mailboxAddress":"x@y.com","unknownField":"ignore"}
    ;
    const acct = try std.json.parseFromSliceLeaky(
        Account,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("789", acct.accountId);
    try std.testing.expectEqualStrings("x@y.com", acct.mailboxAddress);
}
