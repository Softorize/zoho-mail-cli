const std = @import("std");
const common = @import("../model/common.zig");
const Account = @import("../model/account.zig").Account;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from account API operations.
pub const AccountApiError = error{
    /// API returned an error response.
    ApiRequestFailed,
    /// Response JSON could not be parsed.
    ParseError,
} || auth.AuthError || http.HttpError;

/// Fetch all accounts for the authenticated user.
/// Allocator owns all returned Account slices (use arena).
pub fn listAccounts(
    allocator: std.mem.Allocator,
    config: Config,
) AccountApiError![]const Account {
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;

    const url = http.buildUrl(allocator, config.region, "accounts", null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const Account },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// Fetch a single account by ID.
/// Allocator owns returned Account strings.
pub fn getAccount(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
) AccountApiError!Account {
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;

    const path = std.fmt.allocPrint(allocator, "accounts/{s}", .{account_id}) catch
        return error.ApiRequestFailed;

    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: Account },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "AccountApiError composes auth and http errors" {
    // Verify the error set includes expected variants.
    const err: AccountApiError = error.ParseError;
    try std.testing.expectEqual(error.ParseError, err);
}

test "AccountApiError includes ApiRequestFailed" {
    const err: AccountApiError = error.ApiRequestFailed;
    try std.testing.expectEqual(error.ApiRequestFailed, err);
}

test "AccountApiError includes HttpError variants" {
    const err: AccountApiError = error.ConnectionFailed;
    try std.testing.expectEqual(error.ConnectionFailed, err);
}
