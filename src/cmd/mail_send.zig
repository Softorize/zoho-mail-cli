const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api = @import("../api/messages.zig");

/// Send an email. Reads recipients, subject, body from args.
pub fn send(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var to: ?[]const u8 = null;
    var subject: []const u8 = "";
    var body: []const u8 = "";
    var cc: []const u8 = "";
    var bcc: []const u8 = "";
    var from: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--to")) {
            to = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--subject")) {
            subject = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--body")) {
            body = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--cc")) {
            cc = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--bcc")) {
            bcc = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--from")) {
            from = args.next() orelse return error.MissingArgument;
        }
    }
    const to_addr = to orelse {
        output.printError("--to is required") catch {};
        return error.MissingArgument;
    };
    const aid = acctId(cfg, flags);
    // Look up account email if --from not provided
    const from_addr = from orelse blk: {
        const accts = @import("../api/accounts.zig").listAccounts(allocator, cfg) catch {
            output.printError("Could not look up account email. Use --from to specify sender.") catch {};
            return error.CommandFailed;
        };
        for (accts) |acct| {
            if (std.mem.eql(u8, acct.accountId, aid)) break :blk acct.mailboxAddress;
        }
        output.printError("Account not found. Use --from to specify sender.") catch {};
        return error.CommandFailed;
    };
    _ = api.sendMessage(allocator, cfg, aid, .{
        .fromAddress = from_addr,
        .toAddress = to_addr,
        .subject = subject,
        .content = body,
        .ccAddress = cc,
        .bccAddress = bcc,
    }) catch {
        output.printError("Failed to send message. Check auth token and recipient address.") catch {};
        return error.CommandFailed;
    };
    output.printSuccess("Message sent successfully.") catch {};
}

/// Delete a message by ID. Requires message-id and --folder.
pub fn deleteMail(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var mid: ?[]const u8 = null;
    var fid: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--folder")) {
            fid = args.next() orelse return error.MissingArgument;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            mid = arg;
        }
    }
    const m_id = mid orelse {
        output.printError("message ID required") catch {};
        return error.MissingArgument;
    };
    const f_id = fid orelse {
        output.printError("--folder is required") catch {};
        return error.MissingArgument;
    };
    api.deleteMessage(allocator, cfg, acctId(cfg, flags), f_id, m_id) catch return error.CommandFailed;
    output.printSuccess("Message deleted.") catch {};
}

/// Resolve account ID from flags or config.
fn acctId(cfg: Config, flags: root.GlobalFlags) []const u8 {
    return flags.account_id orelse cfg.active_account_id;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "acctId prefers flags over config" {
    const cfg = Config{ .active_account_id = "config-id" };
    try std.testing.expectEqualStrings("flag-id", acctId(cfg, .{ .account_id = "flag-id" }));
    try std.testing.expectEqualStrings("config-id", acctId(cfg, .{}));
}

test "send function signature is correct" {
    _ = &send;
}

test "deleteMail function signature is correct" {
    _ = &deleteMail;
}
