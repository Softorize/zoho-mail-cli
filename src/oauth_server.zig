//! Temporary localhost HTTP server for capturing OAuth callbacks.
//! Starts on a local port, waits for Zoho's redirect with ?code=XXX,
//! extracts the authorization code, and shuts down.

const std = @import("std");
const creds = @import("credentials.zig");

/// Errors from the OAuth callback server.
pub const OAuthServerError = error{
    /// Could not bind to the callback port.
    BindFailed,
    /// No authorization code in the callback.
    NoCodeReceived,
    /// Timeout waiting for callback.
    Timeout,
    /// Failed to parse the callback request.
    ParseFailed,
};

/// Start a localhost server, wait for the OAuth callback, return the auth code.
/// Blocks until a request arrives at /callback?code=XXX or timeout.
/// Caller owns the returned code slice (allocated with the provided allocator).
pub fn waitForCallback(allocator: std.mem.Allocator) OAuthServerError![]const u8 {
    const addr = std.net.Address.parseIp4("127.0.0.1", creds.callback_port) catch
        return error.BindFailed;

    var server = addr.listen(.{ .reuse_address = true }) catch
        return error.BindFailed;
    defer server.deinit();

    const conn = server.accept() catch return error.Timeout;
    defer conn.stream.close();

    return handleCallback(allocator, conn.stream) catch error.NoCodeReceived;
}

/// Parse the HTTP request from the callback and extract the code parameter.
fn handleCallback(allocator: std.mem.Allocator, stream: std.net.Stream) ![]const u8 {
    var buf: [4096]u8 = undefined;
    const n = stream.read(&buf) catch return error.ParseFailed;
    if (n == 0) return error.ParseFailed;

    const request = buf[0..n];
    const code = extractCode(request) orelse return error.NoCodeReceived;

    const owned = allocator.dupe(u8, code) catch return error.ParseFailed;
    errdefer allocator.free(owned);

    sendSuccessPage(stream);
    return owned;
}

/// Extract the "code" query parameter from an HTTP GET request line.
/// Expects: "GET /callback?code=XXXX&... HTTP/1.1\r\n..."
fn extractCode(request: []const u8) ?[]const u8 {
    const line_end = std.mem.indexOf(u8, request, "\r\n") orelse request.len;
    const line = request[0..line_end];

    const qmark = std.mem.indexOf(u8, line, "?") orelse return null;
    const space = std.mem.indexOfPos(u8, line, qmark, " ") orelse line.len;
    const query = line[qmark + 1 .. space];

    var iter = std.mem.splitScalar(u8, query, '&');
    while (iter.next()) |param| {
        if (std.mem.startsWith(u8, param, "code=")) {
            return param["code=".len..];
        }
    }
    return null;
}

/// Send a simple HTML success page back to the browser.
fn sendSuccessPage(stream: std.net.Stream) void {
    const body =
        \\<html><body style="font-family:system-ui;text-align:center;padding:60px">
        \\<h1>Authorization Successful</h1>
        \\<p>You can close this window and return to the terminal.</p>
        \\</body></html>
    ;
    const response = "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: text/html\r\n" ++
        "Content-Length: " ++ std.fmt.comptimePrint("{d}", .{body.len}) ++ "\r\n" ++
        "Connection: close\r\n\r\n" ++ body;
    stream.writeAll(response) catch {};
}

/// Open a URL in the default browser (macOS/Linux).
pub fn openBrowser(url: []const u8) void {
    const cmd = if (comptime @import("builtin").os.tag == .macos) "open" else "xdg-open";
    const argv = [_][]const u8{ cmd, url };
    var child = std.process.Child.init(&argv, std.heap.page_allocator);
    _ = child.spawnAndWait() catch {};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "extractCode finds code in query string" {
    const req = "GET /callback?code=abc123&location=us HTTP/1.1\r\nHost: localhost\r\n";
    const code = extractCode(req);
    try std.testing.expect(code != null);
    try std.testing.expectEqualStrings("abc123", code.?);
}

test "extractCode returns null when no code" {
    const req = "GET /callback?error=access_denied HTTP/1.1\r\n";
    try std.testing.expectEqual(@as(?[]const u8, null), extractCode(req));
}

test "extractCode handles code-only query" {
    const req = "GET /callback?code=xyz HTTP/1.1\r\n";
    try std.testing.expectEqualStrings("xyz", extractCode(req).?);
}
