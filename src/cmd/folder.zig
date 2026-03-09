const std = @import("std");
const config = @import("../config.zig");
const Config = config.Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api = @import("../api/folders.zig");

/// Execute the "folder" subcommand. Subcommands: list, create, rename, delete.
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
        list(allocator, cfg, flags) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "create")) {
        handleCreate(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "rename")) {
        handleRename(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "delete")) {
        const fid = args.next() orelse {
            output.printError("folder ID required") catch {};
            return error.MissingArgument;
        };
        deleteFn(allocator, cfg, flags, fid) catch return error.CommandFailed;
    } else {
        output.printError("unknown folder subcommand") catch {};
        return error.UnknownCommand;
    }
}

/// List all folders for the active account.
pub fn list(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags) root.CliError!void {
    const aid = acctId(cfg, flags);
    const folders = api.listFolders(allocator, cfg, aid) catch |e| {
        std.log.err("listFolders failed: {}", .{e});
        return error.CommandFailed;
    };
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, folders) catch return error.CommandFailed;
        return;
    }
    const columns = [_]output.Column{
        .{ .header = "ID", .width = 18 },   .{ .header = "Name", .width = 20 },
        .{ .header = "Path", .width = 25 }, .{ .header = "Unread", .width = 8 },
        .{ .header = "Total", .width = 8 },
    };
    var rows: std.ArrayList([]const []const u8) = .{};
    for (folders) |f| {
        const row = allocator.alloc([]const u8, 5) catch return error.CommandFailed;
        row[0] = f.folderId;
        row[1] = f.folderName;
        row[2] = f.folderPath;
        row[3] = std.fmt.allocPrint(allocator, "{d}", .{f.unreadCount}) catch "";
        row[4] = std.fmt.allocPrint(allocator, "{d}", .{f.messageCount}) catch "";
        rows.append(allocator, row) catch return error.CommandFailed;
    }
    output.printTable(&columns, rows.items) catch return error.CommandFailed;
}

/// Handle create subcommand with --name and --parent args.
fn handleCreate(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var name: ?[]const u8 = null;
    var parent_id: []const u8 = "";
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--name")) {
            name = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--parent")) {
            parent_id = args.next() orelse return error.MissingArgument;
        }
    }
    const n = name orelse {
        output.printError("--name is required") catch {};
        return error.MissingArgument;
    };
    create(allocator, cfg, flags, n, parent_id) catch return error.CommandFailed;
}

/// Create a new folder with the given name.
pub fn create(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, name: []const u8, parent_id: []const u8) root.CliError!void {
    _ = api.createFolder(allocator, cfg, acctId(cfg, flags), name, parent_id) catch return error.CommandFailed;
    output.printSuccess("Folder created.") catch {};
}

/// Handle rename subcommand.
fn handleRename(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var fid: ?[]const u8 = null;
    var new_name: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--name")) {
            new_name = args.next() orelse return error.MissingArgument;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            fid = arg;
        }
    }
    const f = fid orelse {
        output.printError("folder ID required") catch {};
        return error.MissingArgument;
    };
    const n = new_name orelse {
        output.printError("--name is required") catch {};
        return error.MissingArgument;
    };
    rename(allocator, cfg, flags, f, n) catch return error.CommandFailed;
}

/// Rename an existing folder.
pub fn rename(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, folder_id: []const u8, new_name: []const u8) root.CliError!void {
    _ = api.renameFolder(allocator, cfg, acctId(cfg, flags), folder_id, new_name) catch return error.CommandFailed;
    output.printSuccess("Folder renamed.") catch {};
}

/// Delete a folder by ID.
pub fn deleteFn(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, folder_id: []const u8) root.CliError!void {
    api.deleteFolder(allocator, cfg, acctId(cfg, flags), folder_id) catch return error.CommandFailed;
    output.printSuccess("Folder deleted.") catch {};
}

/// Resolve account ID from flags or config.
fn acctId(cfg: Config, flags: root.GlobalFlags) []const u8 {
    return flags.account_id orelse cfg.active_account_id;
}

/// Print usage help for the folder command.
fn printUsage() void {
    const help =
        \\Usage: zoho-mail folder <subcommand> [options]
        \\
        \\Subcommands:
        \\  list                    List all folders
        \\  create --name <name>    Create a folder [--parent <id>]
        \\  rename <id> --name <n>  Rename a folder
        \\  delete <id>             Delete a folder
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

test "acctId prefers flags" {
    const cfg = Config{ .active_account_id = "cfg-id" };
    try std.testing.expectEqualStrings("flag-id", acctId(cfg, .{ .account_id = "flag-id" }));
}

test "execute function signature is correct" {
    _ = &execute;
}
