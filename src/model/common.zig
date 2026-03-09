const std = @import("std");

/// Generic API response envelope matching Zoho Mail JSON structure.
/// `T` is the data payload type; `void` for status-only responses.
pub fn ApiResponse(comptime T: type) type {
    return struct {
        /// Parsed status object.
        status: Status,
        /// Array of parsed items.
        data: []const T = &.{},
        /// Pagination info; null if not present.
        paging: ?Pagination = null,

        pub const Status = struct {
            /// Numeric status code from Zoho.
            code: i64 = 0,
            /// Status description string.
            description: []const u8 = "",
        };
    };
}

/// Pagination metadata returned by list endpoints.
/// Field names match Zoho API JSON keys (camelCase).
pub const Pagination = struct {
    /// Total number of results available.
    total: ?i64 = null,
    /// Whether more results are available.
    hasMore: bool = false,
    /// Index of first result in this page.
    start: i64 = 0,
    /// Number of results per page.
    limit: i64 = 50,
};

/// Zoho datacenter region, determines base URL TLD.
pub const Region = enum {
    com,
    eu,
    in_,
    com_au,
    com_cn,
    jp,

    /// Return the TLD string for URL construction.
    pub fn tld(self: Region) []const u8 {
        return switch (self) {
            .com => "com",
            .eu => "eu",
            .in_ => "in",
            .com_au => "com.au",
            .com_cn => "com.cn",
            .jp => "jp",
        };
    }
};

test "Region.tld returns correct strings" {
    try std.testing.expectEqualStrings("com", Region.com.tld());
    try std.testing.expectEqualStrings("in", Region.in_.tld());
    try std.testing.expectEqualStrings("com.au", Region.com_au.tld());
}

test "ApiResponse default values" {
    const Resp = ApiResponse([]const u8);
    const r = Resp{
        .status = .{ .code = 200, .description = "success" },
    };
    try std.testing.expectEqual(@as(usize, 0), r.data.len);
    try std.testing.expect(r.paging == null);
}

test "Pagination default values" {
    const p = Pagination{};
    try std.testing.expectEqual(@as(i64, 50), p.limit);
    try std.testing.expectEqual(false, p.hasMore);
}
