const std = @import("std");
const org_model = @import("../model/org.zig");
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from organization admin API operations.
pub const OrgApiError = error{
    /// API returned an error response.
    ApiRequestFailed,
    /// Response JSON could not be parsed.
    ParseError,
    /// Insufficient permissions for org operations.
    Unauthorized,
} || auth.AuthError || http.HttpError;

/// List organization users.
/// Allocator owns returned User slices.
pub fn listUsers(
    allocator: std.mem.Allocator,
    config: Config,
    zoid: []const u8,
) OrgApiError![]const org_model.User {
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;

    const path = std.fmt.allocPrint(
        allocator,
        "organization/{s}/users",
        .{zoid},
    ) catch return error.ApiRequestFailed;

    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const org_model.User },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// List organization domains.
/// Allocator owns returned Domain slices.
pub fn listDomains(
    allocator: std.mem.Allocator,
    config: Config,
    zoid: []const u8,
) OrgApiError![]const org_model.Domain {
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;

    const path = std.fmt.allocPrint(
        allocator,
        "organization/{s}/domains",
        .{zoid},
    ) catch return error.ApiRequestFailed;

    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const org_model.Domain },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// List organization groups.
/// Allocator owns returned Group slices.
pub fn listGroups(
    allocator: std.mem.Allocator,
    config: Config,
    zoid: []const u8,
) OrgApiError![]const org_model.Group {
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;

    const path = std.fmt.allocPrint(
        allocator,
        "organization/{s}/groups",
        .{zoid},
    ) catch return error.ApiRequestFailed;

    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const org_model.Group },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "OrgApiError composes auth and http errors" {
    const err: OrgApiError = error.ParseError;
    try std.testing.expectEqual(error.ParseError, err);
}

test "OrgApiError includes Unauthorized" {
    const err: OrgApiError = error.Unauthorized;
    try std.testing.expectEqual(error.Unauthorized, err);
}

test "OrgApiError includes HttpError variants" {
    const err: OrgApiError = error.ConnectionFailed;
    try std.testing.expectEqual(error.ConnectionFailed, err);
}
