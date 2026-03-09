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

/// Perform browser-based OAuth login flow.
/// Opens browser -> user authorizes -> CLI captures callback -> exchanges code.
pub fn login(allocator: std.mem.Allocator, cfg: Config) root.CliError!void {
    if (!creds.isConfigured()) {
        output.printError("OAuth credentials not configured in binary. Rebuild with valid credentials.") catch {};
        return error.CommandFailed;
    }

    const writer = std.fs.File.stdout().deprecatedWriter();
    const region = cfg.region;

    const auth_url = std.fmt.allocPrint(
        allocator,
        "https://accounts.zoho.{s}/oauth/v2/auth?scope={s}&client_id={s}&response_type=code&access_type=offline&redirect_uri={s}&prompt=consent",
        .{ region.tld(), creds.scopes, creds.client_id, creds.redirect_uri },
    ) catch return error.CommandFailed;

    writer.print("\nOpening browser for Zoho authorization...\n", .{}) catch {};
    writer.print("If it doesn't open, visit:\n{s}\n\n", .{auth_url}) catch {};
    writer.print("Waiting for authorization...\n", .{}) catch {};

    oauth.openBrowser(auth_url);

    const code = oauth.waitForCallback(allocator) catch {
        output.printError("Failed to receive authorization callback.") catch {};
        return error.CommandFailed;
    };

    exchangeCode(allocator, region, code) catch return error.CommandFailed;
    output.printSuccess("Login successful! You are now authenticated.") catch {};
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
        struct { access_token: []const u8 = "", refresh_token: []const u8 = "", expires_in: i64 = 3600 },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.CommandFailed;

    if (parsed.access_token.len == 0) return error.CommandFailed;

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

test "execute function signature is correct" {
    _ = &execute;
}

test "login function signature is correct" {
    _ = &login;
}
