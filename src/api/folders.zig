const std = @import("std");
const Folder = @import("../model/folder.zig").Folder;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from folder API operations.
pub const FolderApiError = error{
    /// API returned an error response.
    ApiRequestFailed,
    /// Response JSON could not be parsed.
    ParseError,
} || auth.AuthError || http.HttpError;

/// List all folders for an account.
/// Allocator owns returned Folder slices.
pub fn listFolders(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
) FolderApiError![]const Folder {
    const path = std.fmt.allocPrint(
        allocator,
        "/api/accounts/{s}/folders",
        .{account_id},
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const Folder },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// Get a single folder by ID.
/// Allocator owns returned Folder.
pub fn getFolder(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
) FolderApiError!Folder {
    const path = std.fmt.allocPrint(
        allocator,
        "/api/accounts/{s}/folders/{s}",
        .{ account_id, folder_id },
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: Folder },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// Create a new folder.
/// Returns the created Folder.
pub fn createFolder(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_name: []const u8,
    parent_folder_id: []const u8,
) FolderApiError!Folder {
    const path = std.fmt.allocPrint(
        allocator,
        "/api/accounts/{s}/folders",
        .{account_id},
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const body = std.json.Stringify.valueAlloc(allocator, .{
        .folderName = folder_name,
        .parentFolderId = parent_folder_id,
    }, .{}) catch return error.ApiRequestFailed;

    const response = try http.post(allocator, url, token, body);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: Folder },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// Rename a folder.
/// Returns the updated Folder.
pub fn renameFolder(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
    new_name: []const u8,
) FolderApiError!Folder {
    const path = std.fmt.allocPrint(
        allocator,
        "/api/accounts/{s}/folders/{s}",
        .{ account_id, folder_id },
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const body = std.json.Stringify.valueAlloc(allocator, .{
        .folderName = new_name,
    }, .{}) catch return error.ApiRequestFailed;

    const response = try http.put(allocator, url, token, body);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: Folder },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}

/// Delete a folder by ID.
pub fn deleteFolder(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
) FolderApiError!void {
    const path = std.fmt.allocPrint(
        allocator,
        "/api/accounts/{s}/folders/{s}",
        .{ account_id, folder_id },
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    _ = try http.delete(allocator, url, token);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "FolderApiError composes auth and http errors" {
    const err: FolderApiError = error.ParseError;
    try std.testing.expectEqual(error.ParseError, err);
}

test "FolderApiError includes ApiRequestFailed" {
    const err: FolderApiError = error.ApiRequestFailed;
    try std.testing.expectEqual(error.ApiRequestFailed, err);
}

test "FolderApiError includes HttpError variants" {
    const err: FolderApiError = error.Timeout;
    try std.testing.expectEqual(error.Timeout, err);
}
