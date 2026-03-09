const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api = @import("../api/messages.zig");
const folders_api = @import("../api/folders.zig");
const mail_update = @import("mail_update.zig");
const mail_send = @import("mail_send.zig");
const msg = @import("../model/message.zig");

/// Execute the "mail" subcommand.
pub fn execute(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    const subcmd = args.next() orelse {
        printUsage();
        return;
    };
    if (std.mem.eql(u8, subcmd, "--help") or std.mem.eql(u8, subcmd, "-h") or std.mem.eql(u8, subcmd, "help")) {
        printUsage();
        return;
    }
    if (std.mem.eql(u8, subcmd, "list")) {
        listMail(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "search")) {
        search(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "read")) {
        readMsg(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "send")) {
        mail_send.send(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "delete")) {
        mail_send.deleteMail(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (isUpdateSubcmd(subcmd)) {
        mail_update.execute(allocator, cfg, flags, subcmd, args) catch return error.CommandFailed;
    } else {
        output.printError("unknown mail subcommand") catch {};
        return error.UnknownCommand;
    }
}

/// Check if subcmd is a mail-update operation.
fn isUpdateSubcmd(s: []const u8) bool {
    return std.mem.eql(u8, s, "flag") or std.mem.eql(u8, s, "move") or
        std.mem.eql(u8, s, "mark-read") or std.mem.eql(u8, s, "mark-unread") or
        std.mem.eql(u8, s, "label");
}

/// List messages in a folder.
pub fn listMail(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var folder_id: ?[]const u8 = null;
    var limit: i64 = 20;
    var start: i64 = 0;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--folder")) {
            folder_id = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--limit")) {
            const v = args.next() orelse return error.MissingArgument;
            limit = std.fmt.parseInt(i64, v, 10) catch return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--start")) {
            const v = args.next() orelse return error.MissingArgument;
            start = std.fmt.parseInt(i64, v, 10) catch return error.InvalidArgument;
        }
    }
    const aid = acctId(cfg, flags);
    const fid = folder_id orelse resolveInbox(allocator, cfg, aid) orelse {
        output.printError("Could not resolve inbox folder.") catch {};
        return error.CommandFailed;
    };
    const msgs = api.listMessages(allocator, cfg, aid, fid, start, limit) catch {
        output.printError("Failed to list messages.") catch {};
        return error.CommandFailed;
    };
    printMsgList(allocator, cfg, flags, msgs) catch return error.CommandFailed;
}

/// Search messages. Requires --query.
pub fn search(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var query: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--query")) query = args.next() orelse return error.MissingArgument;
    }
    const key = query orelse {
        output.printError("--query is required") catch {};
        return error.MissingArgument;
    };
    const aid = acctId(cfg, flags);
    const msgs = api.searchMessages(allocator, cfg, aid, .{ .searchKey = key }) catch return error.CommandFailed;
    printMsgList(allocator, cfg, flags, msgs) catch return error.CommandFailed;
}

/// Read a single message by ID.
pub fn readMsg(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
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
    const m = api.getMessage(allocator, cfg, acctId(cfg, flags), f_id, m_id) catch return error.CommandFailed;
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, m) catch return error.CommandFailed;
        return;
    }
    output.printHeader("Message") catch {};
    output.printDetail("From", m.sender) catch {};
    output.printDetail("To", m.toAddress) catch {};
    output.printDetail("Subject", m.subject) catch {};
    var tb: [32]u8 = undefined;
    const rts = std.fmt.parseInt(i64, m.receivedTime, 10) catch 0;
    output.printDetail("Date", output.formatTimestamp(rts, &tb)) catch {};
    output.printHeader("Content") catch {};
    std.fs.File.stdout().deprecatedWriter().print("{s}\n", .{m.content}) catch {};
}

/// Resolve the Inbox folder ID by listing folders and finding "Inbox".
fn resolveInbox(allocator: std.mem.Allocator, cfg: Config, aid: []const u8) ?[]const u8 {
    const folders = folders_api.listFolders(allocator, cfg, aid) catch return null;
    for (folders) |f| {
        if (std.ascii.eqlIgnoreCase(f.folderName, "inbox")) return f.folderId;
    }
    if (folders.len > 0) return folders[0].folderId;
    return null;
}

/// Resolve account ID from flags or config.
fn acctId(cfg: Config, flags: root.GlobalFlags) []const u8 {
    return flags.account_id orelse cfg.active_account_id;
}

/// Print a list of messages as table or JSON.
fn printMsgList(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, messages: []const msg.Message) !void {
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        try output.printJson(allocator, messages);
        return;
    }
    const columns = [_]output.Column{
        .{ .header = "ID", .width = 18 },   .{ .header = "Subject", .width = 40 },
        .{ .header = "From", .width = 25 }, .{ .header = "Date", .width = 20 },
        .{ .header = "Read", .width = 5 },
    };
    var rows: std.ArrayList([]const []const u8) = .{};
    for (messages) |m| {
        const row = try allocator.alloc([]const u8, 5);
        row[0] = m.messageId;
        row[1] = m.subject;
        row[2] = if (m.sender.len > 0) m.sender else m.fromAddress;
        var tb: [32]u8 = undefined;
        const ts = std.fmt.parseInt(i64, m.receivedTime, 10) catch 0;
        row[3] = output.formatTimestamp(ts, &tb);
        row[4] = if (m.isRead()) "yes" else "no";
        try rows.append(allocator, row);
    }
    try output.printTable(&columns, rows.items);
}

/// Print usage help for the mail command.
fn printUsage() void {
    const help =
        \\Usage: zoho-mail mail <subcommand> [options]
        \\
        \\Subcommands:
        \\  list        [--folder <id>] [--limit <n>] [--start <n>]
        \\  search      --query <search-key>
        \\  read        <message-id> --folder <folder-id>
        \\  send        --to <addr> --subject <subj> [--body <b>]
        \\  delete      <message-id> --folder <folder-id>
        \\  flag|move|mark-read|mark-unread|label  <message-id>
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

test "isUpdateSubcmd recognizes valid subcmds" {
    try std.testing.expect(isUpdateSubcmd("flag"));
    try std.testing.expect(isUpdateSubcmd("move"));
    try std.testing.expect(isUpdateSubcmd("mark-read"));
    try std.testing.expect(!isUpdateSubcmd("list"));
}

test "acctId prefers flags over config" {
    const cfg = Config{ .active_account_id = "config-id" };
    try std.testing.expectEqualStrings("flag-id", acctId(cfg, .{ .account_id = "flag-id" }));
    try std.testing.expectEqualStrings("config-id", acctId(cfg, .{}));
}
