const std = @import("std");
const Label = @import("../model/label.zig").Label;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from label API operations.
pub const LabelApiError = error{
    /// API returned an error response.
    ApiRequestFailed,
    /// Response JSON could not be parsed.
    ParseError,
} || auth.AuthError || http.HttpError;

/// List all labels for an account.
/// Allocator owns returned Label slices.
pub fn listLabels(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
) LabelApiError![]const Label {
    const path = std.fmt.allocPrint(
        allocator,
        "accounts/{s}/labels",
        .{account_id},
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const Label },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// Create a new label.
/// Returns the created Label.
pub fn createLabel(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    label_name: []const u8,
    color: []const u8,
) LabelApiError!Label {
    const path = std.fmt.allocPrint(
        allocator,
        "accounts/{s}/labels",
        .{account_id},
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const body = std.json.Stringify.valueAlloc(allocator, .{
        .labelName = label_name,
        .color = color,
    }, .{}) catch return error.ApiRequestFailed;

    const response = try http.post(allocator, url, token, body);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: Label },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// Rename a label.
/// Returns the updated Label.
pub fn renameLabel(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    label_id: []const u8,
    new_name: []const u8,
) LabelApiError!Label {
    const path = std.fmt.allocPrint(
        allocator,
        "accounts/{s}/labels/{s}",
        .{ account_id, label_id },
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const body = std.json.Stringify.valueAlloc(allocator, .{
        .labelName = new_name,
    }, .{}) catch return error.ApiRequestFailed;

    const response = try http.put(allocator, url, token, body);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: Label },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// Delete a label by ID.
pub fn deleteLabel(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    label_id: []const u8,
) LabelApiError!void {
    const path = std.fmt.allocPrint(
        allocator,
        "accounts/{s}/labels/{s}",
        .{ account_id, label_id },
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    _ = try http.delete(allocator, url, token);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "LabelApiError composes auth and http errors" {
    const err: LabelApiError = error.ParseError;
    try std.testing.expectEqual(error.ParseError, err);
}

test "LabelApiError includes ApiRequestFailed" {
    const err: LabelApiError = error.ApiRequestFailed;
    try std.testing.expectEqual(error.ApiRequestFailed, err);
}

test "LabelApiError includes AuthError variants" {
    const err: LabelApiError = error.NotAuthenticated;
    try std.testing.expectEqual(error.NotAuthenticated, err);
}
