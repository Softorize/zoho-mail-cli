const std = @import("std");
const config = @import("../config.zig");
const Config = config.Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api_accounts = @import("../api/accounts.zig");

/// Execute the "account" subcommand.
/// Subcommands: list, info, set-default.
pub fn execute(
    allocator: std.mem.Allocator,
    cfg: Config,
    flags: root.GlobalFlags,
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
    if (std.mem.eql(u8, subcmd, "list")) {
        list(allocator, cfg, flags) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "info")) {
        const account_id = args.next() orelse {
            output.printError("account ID required") catch {};
            return error.MissingArgument;
        };
        info(allocator, cfg, flags, account_id) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "set-default")) {
        const account_id = args.next() orelse {
            output.printError("account ID required") catch {};
            return error.MissingArgument;
        };
        var mutable_cfg = cfg;
        setDefault(allocator, &mutable_cfg, account_id) catch
            return error.CommandFailed;
    } else {
        output.printError("unknown account subcommand") catch {};
        printUsage();
        return error.UnknownCommand;
    }
}

/// List all accounts and print as table or JSON.
pub fn list(
    allocator: std.mem.Allocator,
    cfg: Config,
    flags: root.GlobalFlags,
) root.CliError!void {
    const accounts = api_accounts.listAccounts(allocator, cfg) catch
        return error.CommandFailed;

    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, accounts) catch return error.CommandFailed;
        return;
    }

    const columns = [_]output.Column{
        .{ .header = "ID", .width = 20 },
        .{ .header = "Email", .width = 30 },
        .{ .header = "Name", .width = 20 },
        .{ .header = "Primary", .width = 8 },
    };

    var rows: std.ArrayList([]const []const u8) = .{};
    for (accounts) |acct| {
        const row = allocator.alloc([]const u8, 4) catch return error.CommandFailed;
        row[0] = acct.accountId;
        row[1] = acct.mailboxAddress;
        row[2] = acct.displayName;
        row[3] = if (acct.isDefaultAccount) "yes" else "no";
        rows.append(allocator, row) catch return error.CommandFailed;
    }

    output.printTable(&columns, rows.items) catch return error.CommandFailed;
}

/// Show details for a single account.
pub fn info(
    allocator: std.mem.Allocator,
    cfg: Config,
    flags: root.GlobalFlags,
    account_id: []const u8,
) root.CliError!void {
    const acct = api_accounts.getAccount(allocator, cfg, account_id) catch
        return error.CommandFailed;

    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, acct) catch return error.CommandFailed;
        return;
    }

    output.printHeader("Account Details") catch {};
    output.printDetail("ID", acct.accountId) catch {};
    output.printDetail("Email", acct.mailboxAddress) catch {};
    output.printDetail("Name", acct.displayName) catch {};
    output.printDetail("Type", acct.role) catch {};
    output.printDetail("Primary", if (acct.isDefaultAccount) "yes" else "no") catch {};
    output.printDetail("Incoming", acct.accountName) catch {};
    output.printDetail("Outgoing", acct.mailboxStatus) catch {};
}

/// Set the default active account.
pub fn setDefault(
    allocator: std.mem.Allocator,
    cfg: *Config,
    account_id: []const u8,
) root.CliError!void {
    cfg.active_account_id = account_id;
    config.save(allocator, cfg.*) catch return error.CommandFailed;
    output.printSuccess("Default account updated.") catch {};
}

/// Print usage help for the account command.
fn printUsage() void {
    const help =
        \\Usage: zoho-mail account <subcommand>
        \\
        \\Subcommands:
        \\  list                  List all accounts
        \\  info <account-id>     Show account details
        \\  set-default <id>      Set the default account
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

test "execute function signature is correct" {
    _ = &execute;
}

test "list function signature is correct" {
    _ = &list;
}
