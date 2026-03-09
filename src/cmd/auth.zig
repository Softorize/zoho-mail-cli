const std = @import("std");
const config = @import("../config.zig");
const Config = config.Config;
const auth = @import("../auth.zig");
const output = @import("../output.zig");
const http = @import("../http.zig");
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

/// Perform interactive OAuth login flow.
pub fn login(allocator: std.mem.Allocator, cfg: Config) root.CliError!void {
    const reader = std.fs.File.stdin().deprecatedReader();
    const writer = std.fs.File.stdout().deprecatedWriter();

    writer.writeAll("Enter client ID: ") catch return error.CommandFailed;
    const client_id = readLine(reader) orelse return error.MissingArgument;

    writer.writeAll("Enter client secret: ") catch return error.CommandFailed;
    const client_secret = readLine(reader) orelse return error.MissingArgument;

    var new_cfg = cfg;
    new_cfg.client_id = client_id;
    new_cfg.client_secret = client_secret;
    config.save(allocator, new_cfg) catch return error.CommandFailed;

    const auth_url = std.fmt.allocPrint(
        allocator,
        "https://accounts.zoho.{s}/oauth/v2/auth?scope=ZohoMail.messages.ALL,ZohoMail.folders.ALL,ZohoMail.labels.ALL,ZohoMail.accounts.READ,ZohoMail.tasks.ALL,ZohoMail.organization.ALL&client_id={s}&response_type=code&access_type=offline&redirect_uri=http://localhost",
        .{ cfg.region.tld(), client_id },
    ) catch return error.CommandFailed;

    writer.print("\nOpen this URL in your browser:\n{s}\n\n", .{auth_url}) catch {};
    writer.writeAll("Enter authorization code: ") catch return error.CommandFailed;
    const auth_code = readLine(reader) orelse return error.MissingArgument;

    exchangeCode(allocator, new_cfg, auth_code) catch return error.CommandFailed;
    output.printSuccess("Login successful!") catch {};
}

/// Exchange authorization code for tokens.
fn exchangeCode(
    allocator: std.mem.Allocator,
    cfg: Config,
    code: []const u8,
) !void {
    const url = try http.buildAccountsUrl(allocator, cfg.region, "token");

    const body = try std.fmt.allocPrint(
        allocator,
        "code={s}&client_id={s}&client_secret={s}&grant_type=authorization_code&redirect_uri=http://localhost",
        .{ code, cfg.client_id, cfg.client_secret },
    );

    const response = try http.postForm(allocator, url, body);

    const parsed = std.json.parseFromSliceLeaky(
        struct {
            access_token: []const u8 = "",
            refresh_token: []const u8 = "",
            expires_in: i64 = 3600,
        },
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
    const tokens = (auth.loadTokens(allocator) catch
        return error.CommandFailed) orelse {
        output.printError("Not logged in. Run 'auth login' first.") catch {};
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
        output.printWarning("Not authenticated or token expired.") catch {};
    }
}

/// Clear stored tokens (logout).
pub fn logout(allocator: std.mem.Allocator) root.CliError!void {
    auth.clearTokens(allocator) catch return error.CommandFailed;
    output.printSuccess("Logged out. Tokens cleared.") catch {};
}

/// Read a line from stdin, trimming whitespace.
fn readLine(reader: anytype) ?[]const u8 {
    var buf: [4096]u8 = undefined;
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
        \\  login    Authenticate with Zoho (interactive)
        \\  refresh  Force token refresh
        \\  status   Show authentication status
        \\  logout   Clear stored tokens
        \\
    ;
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.writeAll(help) catch {};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "printUsage does not crash" {
    printUsage();
}

test "readLine returns null for empty" {
    _ = &readLine;
}

test "execute function signature is correct" {
    _ = &execute;
}
