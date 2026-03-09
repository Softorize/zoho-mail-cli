const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api = @import("../api/tasks.zig");

/// Execute the "task" subcommand. Subcommands: list, show, create, update, delete.
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
        handleList(allocator, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "show")) {
        const tid = args.next() orelse {
            output.printError("task ID required") catch {};
            return error.MissingArgument;
        };
        show(allocator, cfg, flags, tid) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "create")) {
        create(allocator, cfg, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "update")) {
        update(allocator, cfg, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "delete")) {
        const tid = args.next() orelse {
            output.printError("task ID required") catch {};
            return error.MissingArgument;
        };
        deleteFn(allocator, cfg, tid) catch return error.CommandFailed;
    } else {
        output.printError("unknown task subcommand") catch {};
        return error.UnknownCommand;
    }
}

/// Handle list with optional --group flag.
fn handleList(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    var gid: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--group")) gid = args.next() orelse return error.MissingArgument;
    }
    list(allocator, cfg, flags, gid) catch return error.CommandFailed;
}

/// List tasks (personal or group).
pub fn list(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, group_id: ?[]const u8) root.CliError!void {
    const tasks = if (group_id) |g|
        api.listGroupTasks(allocator, cfg, g) catch return error.CommandFailed
    else
        api.listMyTasks(allocator, cfg) catch return error.CommandFailed;
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, tasks) catch return error.CommandFailed;
        return;
    }
    const columns = [_]output.Column{
        .{ .header = "ID", .width = 18 },     .{ .header = "Title", .width = 30 },
        .{ .header = "Status", .width = 12 }, .{ .header = "Priority", .width = 10 },
    };
    var rows: std.ArrayList([]const []const u8) = .{};
    for (tasks) |t| {
        const row = allocator.alloc([]const u8, 4) catch return error.CommandFailed;
        row[0] = t.taskId;
        row[1] = t.title;
        row[2] = t.status;
        row[3] = priorityLabel(t.priority);
        rows.append(allocator, row) catch return error.CommandFailed;
    }
    output.printTable(&columns, rows.items) catch return error.CommandFailed;
}

/// Show a single task's details.
pub fn show(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, task_id: []const u8) root.CliError!void {
    const t = api.getTask(allocator, cfg, task_id) catch return error.CommandFailed;
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, t) catch return error.CommandFailed;
        return;
    }
    output.printHeader("Task Details") catch {};
    output.printDetail("ID", t.taskId) catch {};
    output.printDetail("Title", t.title) catch {};
    output.printDetail("Status", t.status) catch {};
    output.printDetail("Priority", priorityLabel(t.priority)) catch {};
    output.printDetail("Notes", t.notes) catch {};
    output.printDetail("Assignee", t.assignee) catch {};
    output.printDetail("Progress", std.fmt.allocPrint(allocator, "{d}%", .{t.percentage}) catch "") catch {};
}

/// Create a new task from command-line arguments.
pub fn create(allocator: std.mem.Allocator, cfg: Config, args: *std.process.ArgIterator) root.CliError!void {
    var title: ?[]const u8 = null;
    var notes: []const u8 = "";
    var priority: i32 = 2;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--title")) {
            title = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--notes")) {
            notes = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--priority")) {
            const v = args.next() orelse return error.MissingArgument;
            priority = std.fmt.parseInt(i32, v, 10) catch return error.InvalidArgument;
        }
    }
    const t = title orelse {
        output.printError("--title is required") catch {};
        return error.MissingArgument;
    };
    _ = api.createTask(allocator, cfg, t, notes, 0, priority) catch return error.CommandFailed;
    output.printSuccess("Task created.") catch {};
}

/// Update a task's fields from command-line arguments.
pub fn update(allocator: std.mem.Allocator, cfg: Config, args: *std.process.ArgIterator) root.CliError!void {
    var tid: ?[]const u8 = null;
    var title: ?[]const u8 = null;
    var task_status: ?[]const u8 = null;
    var priority: ?i32 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--title")) {
            title = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--status")) {
            task_status = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--priority")) {
            const v = args.next() orelse return error.MissingArgument;
            priority = std.fmt.parseInt(i32, v, 10) catch return error.InvalidArgument;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            tid = arg;
        }
    }
    const id = tid orelse {
        output.printError("task ID required") catch {};
        return error.MissingArgument;
    };
    _ = api.updateTask(allocator, cfg, id, title, null, task_status, priority) catch return error.CommandFailed;
    output.printSuccess("Task updated.") catch {};
}

/// Delete a task by ID.
pub fn deleteFn(allocator: std.mem.Allocator, cfg: Config, task_id: []const u8) root.CliError!void {
    api.deleteTask(allocator, cfg, task_id) catch return error.CommandFailed;
    output.printSuccess("Task deleted.") catch {};
}

/// Convert priority integer to a human-readable label.
fn priorityLabel(p: i32) []const u8 {
    return switch (p) {
        1 => "Low",
        2 => "Medium",
        3 => "High",
        else => "Unknown",
    };
}

/// Print usage help for the task command.
fn printUsage() void {
    const help =
        \\Usage: zoho-mail task <subcommand> [options]
        \\
        \\Subcommands:
        \\  list [--group <id>]      List tasks
        \\  show <task-id>           Show task details
        \\  create --title <title>   [--notes <n>] [--priority <1-3>]
        \\  update <id>              [--title t] [--status s] [--priority p]
        \\  delete <task-id>         Delete a task
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

test "priorityLabel returns correct strings" {
    try std.testing.expectEqualStrings("Low", priorityLabel(1));
    try std.testing.expectEqualStrings("Medium", priorityLabel(2));
    try std.testing.expectEqualStrings("High", priorityLabel(3));
    try std.testing.expectEqualStrings("Unknown", priorityLabel(99));
}

test "execute function signature is correct" {
    _ = &execute;
}
