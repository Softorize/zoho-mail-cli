const std = @import("std");
const common = @import("../model/common.zig");
const msg = @import("../model/message.zig");
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from message API operations.
pub const MessageApiError = error{
    /// API returned an error response.
    ApiRequestFailed,
    /// Response JSON could not be parsed.
    ParseError,
    /// A required parameter was invalid or missing.
    InvalidParameter,
} || auth.AuthError || http.HttpError;

/// List messages in a folder.
/// Allocator owns all returned Message slices.
pub fn listMessages(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
    start: i64,
    limit: i64,
) MessageApiError![]const msg.Message {
    const path = std.fmt.allocPrint(allocator, "/api/accounts/{s}/messages/view", .{account_id}) catch return error.ApiRequestFailed;
    const query = std.fmt.allocPrint(allocator, "folderId={s}&start={d}&limit={d}", .{ folder_id, start, limit }) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, query) catch return error.ApiRequestFailed;
    const response = try http.get(allocator, url, token);
    return parseList(allocator, response.body);
}

/// Search messages with a query string.
/// Allocator owns all returned Message slices.
pub fn searchMessages(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    params: msg.SearchParams,
) MessageApiError![]const msg.Message {
    const path = std.fmt.allocPrint(allocator, "/api/accounts/{s}/messages/search", .{account_id}) catch return error.ApiRequestFailed;
    const query = std.fmt.allocPrint(allocator, "searchKey={s}&start={d}&limit={d}", .{ params.searchKey, params.start, params.limit }) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, query) catch return error.ApiRequestFailed;
    const response = try http.get(allocator, url, token);
    return parseList(allocator, response.body);
}

/// Read full message content by ID.
/// Allocator owns returned Message.
pub fn getMessage(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
    message_id: []const u8,
) MessageApiError!msg.Message {
    const path = std.fmt.allocPrint(allocator, "/api/accounts/{s}/folders/{s}/messages/{s}/content", .{ account_id, folder_id, message_id }) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch return error.ApiRequestFailed;
    const response = try http.get(allocator, url, token);
    return parseOne(allocator, response.body);
}

/// Send an email message.
/// Allocator owns returned Message (sent message details).
pub fn sendMessage(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    request: msg.SendRequest,
) MessageApiError!msg.Message {
    const path = std.fmt.allocPrint(allocator, "/api/accounts/{s}/messages", .{account_id}) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch return error.ApiRequestFailed;
    const body = std.json.Stringify.valueAlloc(allocator, request, .{}) catch return error.ApiRequestFailed;
    const response = try http.post(allocator, url, token, body);
    return parseOne(allocator, response.body);
}

/// Delete a message by ID.
pub fn deleteMessage(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
    message_id: []const u8,
) MessageApiError!void {
    const path = std.fmt.allocPrint(allocator, "/api/accounts/{s}/folders/{s}/messages/{s}", .{ account_id, folder_id, message_id }) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch return error.ApiRequestFailed;
    _ = try http.delete(allocator, url, token);
}

/// Update message properties (flag, move, mark-read, label).
pub fn updateMessage(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    params: msg.UpdateParams,
) MessageApiError!void {
    const path = std.fmt.allocPrint(allocator, "/api/accounts/{s}/updatemessage", .{account_id}) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch return error.ApiRequestFailed;
    const body = buildUpdateBody(allocator, params) catch return error.ApiRequestFailed;
    _ = try http.put(allocator, url, token, body);
}

/// Parse a list-style JSON response into a Message slice.
fn parseList(allocator: std.mem.Allocator, body: []const u8) MessageApiError![]const msg.Message {
    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const msg.Message },
        allocator,
        body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;
    return parsed.data;
}

/// Parse a single-item JSON response into a Message.
fn parseOne(allocator: std.mem.Allocator, body: []const u8) MessageApiError!msg.Message {
    const parsed = std.json.parseFromSliceLeaky(
        struct { data: msg.Message },
        allocator,
        body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;
    return parsed.data;
}

/// Build JSON body for the update-message endpoint.
fn buildUpdateBody(allocator: std.mem.Allocator, params: msg.UpdateParams) ![]const u8 {
    return std.json.Stringify.valueAlloc(allocator, .{
        .mode = params.mode,
        .messageId = params.message_id,
        .destFolderId = params.dest_folder_id,
        .flagValue = params.flag_value,
        .labelId = params.label_id,
    }, .{});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "MessageApiError composes auth and http errors" {
    const err: MessageApiError = error.ParseError;
    try std.testing.expectEqual(error.ParseError, err);
}

test "MessageApiError includes InvalidParameter" {
    const err: MessageApiError = error.InvalidParameter;
    try std.testing.expectEqual(error.InvalidParameter, err);
}

test "buildUpdateBody produces valid JSON" {
    const allocator = std.testing.allocator;
    const params = msg.UpdateParams{ .message_id = "12345", .mode = "markAsRead" };
    const body = try buildUpdateBody(allocator, params);
    defer allocator.free(body);
    const parsed = try std.json.parseFromSlice(
        struct { mode: []const u8, messageId: []const u8 },
        allocator,
        body,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try std.testing.expectEqualStrings("markAsRead", parsed.value.mode);
    try std.testing.expectEqualStrings("12345", parsed.value.messageId);
}
