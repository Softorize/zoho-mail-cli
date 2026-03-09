const std = @import("std");
const config = @import("../config.zig");
const Config = config.Config;
const auth = @import("../auth.zig");
const output = @import("../output.zig");
const http = @import("../http.zig");
const creds = @import("../credentials.zig");
const oauth = @import("../oauth_server.zig");
const root = @import("root.zig");

/// Execute the "auth" subcommand.
/// Subcommands: login, refresh, status, logout.
pub fn execute(
    allocator: std.mem.Allocator,
    cfg: Config,
    args: *std.process.ArgIterator,
) root.CliError!void {
    const subcmd = args.next() orelse {
        printUsage();
        return;
    };
    if (std.mem.eql(u8, subcmd, "--help") or std.mem.eql(u8, subcmd, "-h") or std.mem.eql(u8, subcmd, "help")) {
        printUsage();
        return;
    }
    if (std.mem.eql(u8, subcmd, "login")) {
        login(allocator, cfg) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "refresh")) {
        refresh(allocator, cfg) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "status")) {
        status(allocator) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "logout")) {
        logout(allocator) catch return error.CommandFailed;
    } else {
        output.printError("unknown auth subcommand") catch {};
        printUsage();
        return error.UnknownCommand;
    }
}

/// Perform OAuth login flow.
/// Opens browser for authorization, user pastes the redirect URL back.
pub fn login(allocator: std.mem.Allocator, cfg: Config) root.CliError!void {
    if (!creds.isConfigured()) {
        output.printError("OAuth credentials not configured. Rebuild with valid credentials.") catch {};
        return error.CommandFailed;
    }

    const writer = std.fs.File.stdout().deprecatedWriter();
    const region = cfg.region;

    const auth_url = std.fmt.allocPrint(
        allocator,
        "https://accounts.zoho.{s}/oauth/v2/auth?scope={s}&client_id={s}&response_type=code&access_type=offline&redirect_uri={s}&prompt=consent",
        .{ region.tld(), creds.scopes, creds.client_id, creds.redirect_uri },
    ) catch return error.CommandFailed;

    writer.print("\nOpening browser for Zoho authorization...\n\n", .{}) catch {};
    oauth.openBrowser(auth_url);

    writer.print("After authorizing, you will be redirected to a localhost URL.\n", .{}) catch {};
    writer.print("Copy the FULL URL from your browser's address bar and paste it here.\n\n", .{}) catch {};
    writer.print("Paste redirect URL: ", .{}) catch {};

    const redirect_url = readLine() orelse {
        output.printError("No URL provided.") catch {};
        return error.MissingArgument;
    };

    const code = extractCodeFromUrl(redirect_url) orelse {
        output.printError("Could not find authorization code in URL.") catch {};
        return error.InvalidArgument;
    };

    exchangeCode(allocator, region, code) catch return error.CommandFailed;
    output.printSuccess("Login successful! You are now authenticated.") catch {};
}

/// Extract the "code" query parameter from a redirect URL.
fn extractCodeFromUrl(url: []const u8) ?[]const u8 {
    const qmark = std.mem.indexOf(u8, url, "?") orelse return null;
    const query = url[qmark + 1 ..];
    var iter = std.mem.splitScalar(u8, query, '&');
    while (iter.next()) |param| {
        if (std.mem.startsWith(u8, param, "code=")) {
            return param["code=".len..];
        }
    }
    return null;
}

/// Exchange authorization code for tokens using embedded credentials.
fn exchangeCode(allocator: std.mem.Allocator, region: @import("../model/common.zig").Region, code: []const u8) !void {
    const url = try http.buildAccountsUrl(allocator, region, "token");
    const body = try std.fmt.allocPrint(
        allocator,
        "code={s}&client_id={s}&client_secret={s}&grant_type=authorization_code&redirect_uri={s}",
        .{ code, creds.client_id, creds.client_secret, creds.redirect_uri },
    );
    const response = try http.postForm(allocator, url, body);
    const parsed = std.json.parseFromSliceLeaky(
        struct { access_token: []const u8 = "", refresh_token: []const u8 = "", expires_in: i64 = 3600, @"error": []const u8 = "" },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch {
        output.printError("Failed to parse token response.") catch {};
        const writer = std.fs.File.stderr().deprecatedWriter();
        writer.print("Response: {s}\n", .{response.body}) catch {};
        return error.CommandFailed;
    };

    if (parsed.access_token.len == 0) {
        const writer = std.fs.File.stderr().deprecatedWriter();
        if (parsed.@"error".len > 0) {
            writer.print("Zoho error: {s}\n", .{parsed.@"error"}) catch {};
        } else {
            writer.print("Response: {s}\n", .{response.body}) catch {};
        }
        return error.CommandFailed;
    }

    try auth.saveTokens(allocator, .{
        .access_token = parsed.access_token,
        .refresh_token = parsed.refresh_token,
        .expires_at = std.time.timestamp() + parsed.expires_in,
    });
}

/// Force token refresh.
pub fn refresh(allocator: std.mem.Allocator, cfg: Config) root.CliError!void {
    const tokens = (auth.loadTokens(allocator) catch return error.CommandFailed) orelse {
        output.printError("Not logged in. Run 'zoho-mail auth login' first.") catch {};
        return error.CommandFailed;
    };
    const new_tokens = auth.refreshToken(allocator, cfg, tokens.refresh_token) catch {
        output.printError("Token refresh failed.") catch {};
        return error.CommandFailed;
    };
    auth.saveTokens(allocator, new_tokens) catch return error.CommandFailed;
    output.printSuccess("Token refreshed successfully.") catch {};
}

/// Print current authentication status.
pub fn status(allocator: std.mem.Allocator) root.CliError!void {
    const is_auth = auth.isAuthenticated(allocator) catch false;
    if (is_auth) {
        output.printSuccess("Authenticated (token valid).") catch {};
    } else {
        output.printWarning("Not authenticated or token expired. Run 'zoho-mail auth login'.") catch {};
    }
}

/// Clear stored tokens (logout).
pub fn logout(allocator: std.mem.Allocator) root.CliError!void {
    auth.clearTokens(allocator) catch return error.CommandFailed;
    output.printSuccess("Logged out. Tokens cleared.") catch {};
}

/// Read a line from stdin, trimming whitespace.
fn readLine() ?[]const u8 {
    var buf: [4096]u8 = undefined;
    const reader = std.fs.File.stdin().deprecatedReader();
    const line = reader.readUntilDelimiter(&buf, '\n') catch return null;
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return null;
    return trimmed;
}

/// Print usage help for the auth command.
fn printUsage() void {
    const help =
        \\Usage: zoho-mail auth <subcommand>
        \\
        \\Subcommands:
        \\  login    Authenticate with Zoho (opens browser)
        \\  refresh  Force token refresh
        \\  status   Show authentication status
        \\  logout   Clear stored tokens
        \\
    ;
    std.fs.File.stdout().deprecatedWriter().writeAll(help) catch {};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "printUsage does not crash" {
    printUsage();
}

test "extractCodeFromUrl finds code" {
    const url = "http://localhost:8749/callback?code=abc123&location=us";
    try std.testing.expectEqualStrings("abc123", extractCodeFromUrl(url).?);
}

test "extractCodeFromUrl returns null for no code" {
    const url = "http://localhost:8749/callback?error=denied";
    try std.testing.expectEqual(@as(?[]const u8, null), extractCodeFromUrl(url));
}
