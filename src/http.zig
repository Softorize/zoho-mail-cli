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
    const hdr = buildAuthHeader(tok) catch return error.ConnectionFailed;
    return runCurl(a, &.{ "curl", "-s", "-X", "GET", "-H", hdr, url });
}

/// Perform a POST request with a JSON body. Allocator owns Response.body.
pub fn post(a: std.mem.Allocator, url: []const u8, tok: []const u8, body: []const u8) HttpError!Response {
    const hdr = buildAuthHeader(tok) catch return error.ConnectionFailed;
    return runCurl(a, &.{ "curl", "-s", "-X", "POST", "-H", hdr, "-H", "Content-Type: application/json", "-d", body, url });
}

/// Perform a PUT request with a JSON body. Allocator owns Response.body.
pub fn put(a: std.mem.Allocator, url: []const u8, tok: []const u8, body: []const u8) HttpError!Response {
    const hdr = buildAuthHeader(tok) catch return error.ConnectionFailed;
    return runCurl(a, &.{ "curl", "-s", "-X", "PUT", "-H", hdr, "-H", "Content-Type: application/json", "-d", body, url });
}

/// Perform a DELETE request. Allocator owns Response.body.
pub fn delete(a: std.mem.Allocator, url: []const u8, tok: []const u8) HttpError!Response {
    const hdr = buildAuthHeader(tok) catch return error.ConnectionFailed;
    return runCurl(a, &.{ "curl", "-s", "-X", "DELETE", "-H", hdr, url });
}

/// Build auth header using page_allocator to avoid arena memcpy aliasing.
fn buildAuthHeader(tok: []const u8) ![]const u8 {
    return std.fmt.allocPrint(std.heap.page_allocator, "Authorization: Zoho-oauthtoken {s}", .{tok});
}

/// Unauthenticated POST with form-urlencoded content type (OAuth token exchange).
pub fn postForm(a: std.mem.Allocator, url: []const u8, form_body: []const u8) HttpError!Response {
    return runCurl(a, &.{ "curl", "-s", "-X", "POST", "-H", "Content-Type: application/x-www-form-urlencoded", "-d", form_body, url });
}

/// Build a Zoho Mail API URL: `https://mail.zoho.{tld}/api/{path}[?{query}]`.
pub fn buildUrl(a: std.mem.Allocator, region: Region, path: []const u8, query: ?[]const u8) HttpError![]const u8 {
    const r = if (query) |q|
        std.fmt.allocPrint(a, "https://mail.zoho.{s}/api/{s}?{s}", .{ region.tld(), path, q })
    else
        std.fmt.allocPrint(a, "https://mail.zoho.{s}/api/{s}", .{ region.tld(), path });
    return r catch error.InvalidUrl;
}

/// Build an accounts URL: `https://accounts.zoho.{tld}/oauth/v2/{path}`.
pub fn buildAccountsUrl(a: std.mem.Allocator, region: Region, path: []const u8) HttpError![]const u8 {
    return std.fmt.allocPrint(a, "https://accounts.zoho.{s}/oauth/v2/{s}", .{ region.tld(), path }) catch
        error.InvalidUrl;
}

/// Run curl as a subprocess and return the response.
fn runCurl(allocator: std.mem.Allocator, argv: []const []const u8) HttpError!Response {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.spawn() catch return error.ConnectionFailed;
    const stdout = child.stdout.?.readToEndAlloc(allocator, 10 * 1024 * 1024) catch
        return error.ReadFailed;
    _ = child.wait() catch return error.ConnectionFailed;
    return Response{ .status_code = 200, .body = stdout };
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

test "Response struct fields" {
    const r = Response{ .status_code = 200, .body = "ok" };
    try std.testing.expectEqual(@as(u16, 200), r.status_code);
    try std.testing.expectEqualStrings("ok", r.body);
}

test "Method enum has five variants" {
    try std.testing.expectEqual(@as(usize, 5), std.meta.fields(Method).len);
}
