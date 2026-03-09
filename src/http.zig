const std = @import("std");
const Region = @import("model/common.zig").Region;

/// Errors from the HTTP transport layer.
pub const HttpError = error{
    /// Failed to connect to the server.
    ConnectionFailed,
    /// HTTP request timed out.
    Timeout,
    /// Server returned non-2xx status.
    RequestFailed,
    /// Response body could not be read.
    ReadFailed,
    /// Request body could not be sent.
    WriteFailed,
    /// URL could not be parsed.
    InvalidUrl,
};

/// HTTP method for requests.
pub const Method = enum { GET, POST, PUT, DELETE, PATCH };

/// Result of an HTTP request.
pub const Response = struct {
    /// HTTP status code.
    status_code: u16,
    /// Response body bytes. Owned by the allocator passed to the request.
    body: []const u8,
};

/// Perform a GET request with auth header. Allocator owns Response.body.
pub fn get(a: std.mem.Allocator, url: []const u8, tok: []const u8) HttpError!Response {
    return doFetch(a, url, .GET, tok, null, null);
}

/// Perform a POST request with a JSON body. Allocator owns Response.body.
pub fn post(a: std.mem.Allocator, url: []const u8, tok: []const u8, body: []const u8) HttpError!Response {
    return doFetch(a, url, .POST, tok, body, "application/json");
}

/// Perform a PUT request with a JSON body. Allocator owns Response.body.
pub fn put(a: std.mem.Allocator, url: []const u8, tok: []const u8, body: []const u8) HttpError!Response {
    return doFetch(a, url, .PUT, tok, body, "application/json");
}

/// Perform a DELETE request. Allocator owns Response.body.
pub fn delete(a: std.mem.Allocator, url: []const u8, tok: []const u8) HttpError!Response {
    return doFetch(a, url, .DELETE, tok, null, null);
}

/// Unauthenticated POST with form-urlencoded content type (OAuth token exchange).
/// Allocator owns the returned Response.body.
pub fn postForm(a: std.mem.Allocator, url: []const u8, form_body: []const u8) HttpError!Response {
    return doFetch(a, url, .POST, null, form_body, "application/x-www-form-urlencoded");
}

/// Build a Zoho Mail API URL: `https://mail.zoho.{tld}/api/{path}[?{query}]`.
/// Caller owns returned slice.
pub fn buildUrl(a: std.mem.Allocator, region: Region, path: []const u8, query: ?[]const u8) HttpError![]const u8 {
    const r = if (query) |q|
        std.fmt.allocPrint(a, "https://mail.zoho.{s}/api/{s}?{s}", .{ region.tld(), path, q })
    else
        std.fmt.allocPrint(a, "https://mail.zoho.{s}/api/{s}", .{ region.tld(), path });
    return r catch error.InvalidUrl;
}

/// Build an accounts URL: `https://accounts.zoho.{tld}/oauth/v2/{path}`.
/// Caller owns returned slice.
pub fn buildAccountsUrl(a: std.mem.Allocator, region: Region, path: []const u8) HttpError![]const u8 {
    return std.fmt.allocPrint(a, "https://accounts.zoho.{s}/oauth/v2/{s}", .{ region.tld(), path }) catch
        error.InvalidUrl;
}

const HMethod = std.http.Method;
const Headers = std.http.Client.Request.Headers;

/// Core fetch implementation shared by all public request functions.
fn doFetch(
    allocator: std.mem.Allocator,
    url: []const u8,
    method: HMethod,
    access_token: ?[]const u8,
    body: ?[]const u8,
    content_type: ?[]const u8,
) HttpError!Response {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();

    var hdrs = Headers{};
    if (access_token) |tok| {
        const auth_val = std.fmt.allocPrint(allocator, "Zoho-oauthtoken {s}", .{tok}) catch
            return error.ConnectionFailed;
        defer allocator.free(auth_val);
        hdrs.authorization = .{ .override = auth_val };
    }
    if (content_type) |ct| hdrs.content_type = .{ .override = ct };

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = method,
        .payload = body,
        .headers = hdrs,
        .response_writer = &aw.writer,
        .redirect_behavior = if (access_token != null) .not_allowed else null,
    }) catch return error.ConnectionFailed;

    const resp_body = aw.toOwnedSlice() catch return error.ReadFailed;
    return Response{ .status_code = @intFromEnum(result.status), .body = resp_body };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "buildUrl without query" {
    const a = std.testing.allocator;
    const url = try buildUrl(a, .com, "accounts", null);
    defer a.free(url);
    try std.testing.expectEqualStrings("https://mail.zoho.com/api/accounts", url);
}

test "buildUrl with query params" {
    const a = std.testing.allocator;
    const url = try buildUrl(a, .eu, "messages", "limit=10&start=0");
    defer a.free(url);
    try std.testing.expectEqualStrings("https://mail.zoho.eu/api/messages?limit=10&start=0", url);
}

test "buildAccountsUrl constructs OAuth URL" {
    const a = std.testing.allocator;
    const url = try buildAccountsUrl(a, .in_, "token");
    defer a.free(url);
    try std.testing.expectEqualStrings("https://accounts.zoho.in/oauth/v2/token", url);
}

test "buildUrl covers all regions" {
    const a = std.testing.allocator;
    const regions = [_]Region{ .com, .eu, .in_, .com_au, .com_cn, .jp };
    const tlds = [_][]const u8{ "com", "eu", "in", "com.au", "com.cn", "jp" };
    for (regions, tlds) |region, tld| {
        const url = try buildUrl(a, region, "x", null);
        defer a.free(url);
        const exp = try std.fmt.allocPrint(a, "https://mail.zoho.{s}/api/x", .{tld});
        defer a.free(exp);
        try std.testing.expectEqualStrings(exp, url);
    }
}

test "Response struct fields" {
    const r = Response{ .status_code = 200, .body = "ok" };
    try std.testing.expectEqual(@as(u16, 200), r.status_code);
    try std.testing.expectEqualStrings("ok", r.body);
}

test "Method enum has five variants" {
    try std.testing.expectEqual(@as(usize, 5), std.meta.fields(Method).len);
}
