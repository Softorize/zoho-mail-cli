const std = @import("std");

/// Organization user account.
/// Field names match Zoho API JSON keys (camelCase).
pub const User = struct {
    /// Zoho user ID.
    zuid: []const u8,
    /// User email address.
    emailAddress: []const u8,
    /// Display name.
    displayName: []const u8 = "",
    /// Account status ("active", "suspended").
    accountStatus: []const u8 = "",
    /// User role in the organization.
    role: []const u8 = "",
};

/// Organization domain.
/// Field names match Zoho API JSON keys (camelCase).
pub const Domain = struct {
    /// Domain name string.
    domainName: []const u8,
    /// Verification status.
    isVerified: bool = false,
    /// MX record status.
    mxStatus: []const u8 = "",
};

/// Organization user group.
/// Field names match Zoho API JSON keys (camelCase).
pub const Group = struct {
    /// Unique group identifier.
    groupId: []const u8,
    /// Group email address.
    emailAddress: []const u8,
    /// Group display name.
    groupName: []const u8 = "",
    /// Number of members.
    memberCount: i64 = 0,
    /// Group description.
    description: []const u8 = "",
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "User default field values" {
    const u = User{
        .zuid = "z1",
        .emailAddress = "user@org.com",
    };
    try std.testing.expectEqualStrings("z1", u.zuid);
    try std.testing.expectEqualStrings("user@org.com", u.emailAddress);
    try std.testing.expectEqualStrings("", u.displayName);
    try std.testing.expectEqualStrings("", u.role);
}

test "Domain JSON parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{"domainName":"example.com","isVerified":true,"mxStatus":"active"}
    ;
    const d = try std.json.parseFromSliceLeaky(
        Domain,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("example.com", d.domainName);
    try std.testing.expect(d.isVerified);
    try std.testing.expectEqualStrings("active", d.mxStatus);
}

test "Group JSON parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{"groupId":"g1","emailAddress":"team@org.com","groupName":"Dev","memberCount":5}
    ;
    const g = try std.json.parseFromSliceLeaky(
        Group,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqualStrings("g1", g.groupId);
    try std.testing.expectEqualStrings("team@org.com", g.emailAddress);
    try std.testing.expectEqualStrings("Dev", g.groupName);
    try std.testing.expectEqual(@as(i64, 5), g.memberCount);
}

test "Group default field values" {
    const g = Group{
        .groupId = "g2",
        .emailAddress = "all@org.com",
    };
    try std.testing.expectEqualStrings("", g.groupName);
    try std.testing.expectEqual(@as(i64, 0), g.memberCount);
    try std.testing.expectEqualStrings("", g.description);
}
