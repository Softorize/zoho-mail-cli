const std = @import("std");
const config = @import("../config.zig");
const Config = config.Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api = @import("../api/labels.zig");

/// Execute the "label" subcommand. Subcommands: list, create, rename, delete.
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
        const lid = args.next() orelse {
            output.printError("label ID required") catch {};
            return error.MissingArgument;
        };
        deleteFn(allocator, cfg, flags, lid) catch return error.CommandFailed;
    } else {
        output.printError("unknown label subcommand") catch {};
        return error.UnknownCommand;
    }
}

/// List all labels for the active account.
pub fn list(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags) root.CliError!void {
    const aid = acctId(cfg, flags);
    const labels = api.listLabels(allocator, cfg, aid) catch return error.CommandFailed;
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, labels) catch return error.CommandFailed;
        return;
    }
    const columns = [_]output.Column{
        .{ .header = "ID", .width = 18 },    .{ .header = "Name", .width = 20 },
        .{ .header = "Color", .width = 10 }, .{ .header = "Messages", .width = 10 },
    };
    var rows: std.ArrayList([]const []const u8) = .{};
    for (labels) |l| {
        const row = allocator.alloc([]const u8, 4) catch return error.CommandFailed;
        row[0] = l.labelId;
        row[1] = l.labelName;
        row[2] = l.color;
        row[3] = std.fmt.allocPrint(allocator, "{d}", .{l.messageCount}) catch "";
        rows.append(allocator, row) catch return error.CommandFailed;
    }
    output.printTable(&columns, rows.items) catch return error.CommandFailed;
}

/// Handle create subcommand with --name and --color args.
fn handleCreate(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var name: ?[]const u8 = null;
    var color: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--name")) {
            name = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--color")) {
            color = args.next() orelse return error.MissingArgument;
        }
    }
    const n = name orelse {
        output.printError("--name is required") catch {};
        return error.MissingArgument;
    };
    const c = color orelse {
        output.printError("--color is required") catch {};
        return error.MissingArgument;
    };
    create(allocator, cfg, flags, n, c) catch return error.CommandFailed;
}

/// Create a new label.
pub fn create(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, name: []const u8, color: []const u8) root.CliError!void {
    _ = api.createLabel(allocator, cfg, acctId(cfg, flags), name, color) catch return error.CommandFailed;
    output.printSuccess("Label created.") catch {};
}

/// Handle rename subcommand.
fn handleRename(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var lid: ?[]const u8 = null;
    var new_name: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--name")) {
            new_name = args.next() orelse return error.MissingArgument;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            lid = arg;
        }
    }
    const l = lid orelse {
        output.printError("label ID required") catch {};
        return error.MissingArgument;
    };
    const n = new_name orelse {
        output.printError("--name is required") catch {};
        return error.MissingArgument;
    };
    renameFn(allocator, cfg, flags, l, n) catch return error.CommandFailed;
}

/// Rename an existing label.
pub fn renameFn(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, label_id: []const u8, new_name: []const u8) root.CliError!void {
    _ = api.renameLabel(allocator, cfg, acctId(cfg, flags), label_id, new_name) catch return error.CommandFailed;
    output.printSuccess("Label renamed.") catch {};
}

/// Delete a label by ID.
pub fn deleteFn(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, label_id: []const u8) root.CliError!void {
    api.deleteLabel(allocator, cfg, acctId(cfg, flags), label_id) catch return error.CommandFailed;
    output.printSuccess("Label deleted.") catch {};
}

/// Resolve account ID from flags or config.
fn acctId(cfg: Config, flags: root.GlobalFlags) []const u8 {
    return flags.account_id orelse cfg.active_account_id;
}

/// Print usage help for the label command.
fn printUsage() void {
    const help =
        \\Usage: zoho-mail label <subcommand> [options]
        \\
        \\Subcommands:
        \\  list                            List all labels
        \\  create --name <n> --color <hex> Create a label
        \\  rename <id> --name <new-name>   Rename a label
        \\  delete <id>                     Delete a label
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
