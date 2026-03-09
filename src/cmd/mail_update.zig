const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api = @import("../api/messages.zig");
const msg = @import("../model/message.zig");

/// Execute message update subcommands dispatched from mail.zig.
pub fn execute(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, subcmd: []const u8, args: *std.process.ArgIterator) root.CliError!void {
    if (std.mem.eql(u8, subcmd, "flag")) {
        const mid = args.next() orelse {
            output.printError("message ID required") catch {};
            return error.MissingArgument;
        };
        flag(allocator, cfg, flags, mid) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "move")) {
        handleMove(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "mark-read")) {
        const mid = args.next() orelse {
            output.printError("message ID required") catch {};
            return error.MissingArgument;
        };
        markRead(allocator, cfg, flags, mid, true) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "mark-unread")) {
        const mid = args.next() orelse {
            output.printError("message ID required") catch {};
            return error.MissingArgument;
        };
        markRead(allocator, cfg, flags, mid, false) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "label")) {
        handleLabel(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else return error.UnknownCommand;
}

/// Toggle flag on a message.
pub fn flag(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, message_id: []const u8) root.CliError!void {
    api.updateMessage(allocator, cfg, acctId(cfg, flags), .{ .message_id = message_id, .mode = "flagMail", .flag_value = "true" }) catch return error.CommandFailed;
    output.printSuccess("Message flagged.") catch {};
}

/// Handle move subcommand with --folder arg.
fn handleMove(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var mid: ?[]const u8 = null;
    var dest: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--folder")) {
            dest = args.next() orelse return error.MissingArgument;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            mid = arg;
        }
    }
    const m = mid orelse {
        output.printError("message ID required") catch {};
        return error.MissingArgument;
    };
    const d = dest orelse {
        output.printError("--folder is required") catch {};
        return error.MissingArgument;
    };
    move(allocator, cfg, flags, m, d) catch return error.CommandFailed;
}

/// Move a message to a different folder.
pub fn move(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, message_id: []const u8, dest_folder_id: []const u8) root.CliError!void {
    api.updateMessage(allocator, cfg, acctId(cfg, flags), .{ .message_id = message_id, .mode = "moveToFolder", .dest_folder_id = dest_folder_id }) catch return error.CommandFailed;
    output.printSuccess("Message moved.") catch {};
}

/// Mark a message as read or unread.
pub fn markRead(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, message_id: []const u8, is_read: bool) root.CliError!void {
    const mode: []const u8 = if (is_read) "markAsRead" else "markAsUnread";
    api.updateMessage(allocator, cfg, acctId(cfg, flags), .{ .message_id = message_id, .mode = mode }) catch return error.CommandFailed;
    output.printSuccess(if (is_read) "Message marked as read." else "Message marked as unread.") catch {};
}

/// Handle label subcommand with --label arg.
fn handleLabel(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var mid: ?[]const u8 = null;
    var lid: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--label")) {
            lid = args.next() orelse return error.MissingArgument;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            mid = arg;
        }
    }
    const m = mid orelse {
        output.printError("message ID required") catch {};
        return error.MissingArgument;
    };
    const l = lid orelse {
        output.printError("--label is required") catch {};
        return error.MissingArgument;
    };
    applyLabel(allocator, cfg, flags, m, l) catch return error.CommandFailed;
}

/// Apply a label to a message.
pub fn applyLabel(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, message_id: []const u8, label_id: []const u8) root.CliError!void {
    api.updateMessage(allocator, cfg, acctId(cfg, flags), .{ .message_id = message_id, .mode = "addLabel", .label_id = label_id }) catch return error.CommandFailed;
    output.printSuccess("Label applied.") catch {};
}

/// Resolve account ID from flags or config.
fn acctId(cfg: Config, flags: root.GlobalFlags) []const u8 {
    return flags.account_id orelse cfg.active_account_id;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "acctId prefers flags" {
    const cfg = Config{ .active_account_id = "cfg-id" };
    try std.testing.expectEqualStrings("flag-id", acctId(cfg, .{ .account_id = "flag-id" }));
    try std.testing.expectEqualStrings("cfg-id", acctId(cfg, .{}));
}

test "execute function signature is correct" {
    _ = &execute;
}

test "flag function signature is correct" {
    _ = &flag;
}
