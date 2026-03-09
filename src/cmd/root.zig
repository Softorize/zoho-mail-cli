const std = @import("std");
const config = @import("../config.zig");
const Config = config.Config;
const common = @import("../model/common.zig");
const output = @import("../output.zig");
const auth_cmd = @import("auth.zig");
const account_cmd = @import("account.zig");
const mail_cmd = @import("mail.zig");
const folder_cmd = @import("folder.zig");
const label_cmd = @import("label.zig");
const task_cmd = @import("task.zig");
const org_cmd = @import("org.zig");

/// CLI version string.
const version = "0.1.0";

/// Errors from command dispatch.
pub const CliError = error{ UnknownCommand, MissingArgument, InvalidArgument, CommandFailed };

/// Global flags parsed from the command line.
pub const GlobalFlags = struct {
    /// Override output format (--format json|table|csv).
    format: ?Config.OutputFormat = null,
    /// Override region (--region com|eu|in|...).
    region: ?common.Region = null,
    /// Override account ID (--account ID).
    account_id: ?[]const u8 = null,
    /// Show help (--help or -h).
    help: bool = false,
    /// Show version (--version or -v).
    version: bool = false,
};

/// Parse global flags and dispatch to the appropriate subcommand.
pub fn run(gpa: std.mem.Allocator) CliError!void {
    var arena_impl = std.heap.ArenaAllocator.init(gpa);
    defer arena_impl.deinit();
    const arena = arena_impl.allocator();
    var args = std.process.args();
    _ = args.next();
    const parsed = parseGlobalFlags(&args) catch return error.InvalidArgument;
    if (parsed.flags.version) {
        printVersion();
        return;
    }
    const command = parsed.command orelse {
        printHelp();
        return;
    };
    if (parsed.flags.help) {
        printHelp();
        return;
    }
    const cfg = config.load(arena) catch Config{};
    dispatch(arena, cfg, parsed.flags, command, &args) catch return error.CommandFailed;
}

/// Dispatch to the correct subcommand module.
fn dispatch(arena: std.mem.Allocator, cfg: Config, flags: GlobalFlags, command: []const u8, args: *std.process.ArgIterator) CliError!void {
    if (std.mem.eql(u8, command, "auth")) {
        auth_cmd.execute(arena, cfg, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, command, "account")) {
        account_cmd.execute(arena, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, command, "mail")) {
        mail_cmd.execute(arena, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, command, "folder")) {
        folder_cmd.execute(arena, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, command, "label")) {
        label_cmd.execute(arena, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, command, "task")) {
        task_cmd.execute(arena, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, command, "org")) {
        org_cmd.execute(arena, cfg, flags, args) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, command, "help")) {
        printHelp();
    } else {
        output.printError("unknown command") catch {};
        return error.UnknownCommand;
    }
}

/// Parse global flags from the argument iterator.
pub fn parseGlobalFlags(args: *std.process.ArgIterator) CliError!struct { flags: GlobalFlags, command: ?[]const u8 } {
    var flags = GlobalFlags{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            flags.help = true;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            flags.version = true;
        } else if (std.mem.eql(u8, arg, "--format")) {
            const val = args.next() orelse return error.MissingArgument;
            flags.format = parseFormat(val) orelse return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--region")) {
            const val = args.next() orelse return error.MissingArgument;
            flags.region = parseRegion(val) orelse return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--account")) {
            flags.account_id = args.next() orelse return error.MissingArgument;
        } else {
            return .{ .flags = flags, .command = arg };
        }
    }
    return .{ .flags = flags, .command = null };
}

/// Parse an output format string.
fn parseFormat(val: []const u8) ?Config.OutputFormat {
    if (std.mem.eql(u8, val, "json")) return .json;
    if (std.mem.eql(u8, val, "table")) return .table;
    if (std.mem.eql(u8, val, "csv")) return .csv;
    return null;
}

/// Parse a region string.
fn parseRegion(val: []const u8) ?common.Region {
    if (std.mem.eql(u8, val, "com")) return .com;
    if (std.mem.eql(u8, val, "eu")) return .eu;
    if (std.mem.eql(u8, val, "in")) return .in_;
    if (std.mem.eql(u8, val, "com.au")) return .com_au;
    if (std.mem.eql(u8, val, "com.cn")) return .com_cn;
    if (std.mem.eql(u8, val, "jp")) return .jp;
    return null;
}

/// Print top-level help text to stdout.
pub fn printHelp() void {
    const help =
        \\Usage: zoho-mail [options] <command> [subcommand] [args]
        \\
        \\Commands:
        \\  auth       Login, logout, token management
        \\  account    Manage accounts
        \\  mail       Send, list, search, read, delete emails
        \\  folder     Manage folders
        \\  label      Manage labels
        \\  task       Manage tasks
        \\  org        Organization admin
        \\  help       Show this help
        \\
        \\Global options:
        \\  --format <json|table|csv>  Output format
        \\  --account <id>             Override active account
        \\  --region <region>          Override region (com,eu,in,...)
        \\  -h, --help                 Show help
        \\  -v, --version              Show version
        \\
    ;
    std.fs.File.stdout().deprecatedWriter().writeAll(help) catch {};
}

/// Print version information to stdout.
pub fn printVersion() void {
    std.fs.File.stdout().deprecatedWriter().print("zoho-mail {s}\n", .{version}) catch {};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "GlobalFlags default values" {
    const f = GlobalFlags{};
    try std.testing.expect(f.format == null);
    try std.testing.expect(f.region == null);
    try std.testing.expect(!f.help);
}

test "parseFormat returns correct values" {
    try std.testing.expectEqual(Config.OutputFormat.json, parseFormat("json").?);
    try std.testing.expectEqual(Config.OutputFormat.table, parseFormat("table").?);
    try std.testing.expect(parseFormat("invalid") == null);
}

test "parseRegion returns correct values" {
    try std.testing.expectEqual(common.Region.com, parseRegion("com").?);
    try std.testing.expectEqual(common.Region.eu, parseRegion("eu").?);
    try std.testing.expectEqual(common.Region.in_, parseRegion("in").?);
    try std.testing.expect(parseRegion("invalid") == null);
}

test "CliError variants exist" {
    const err: CliError = error.UnknownCommand;
    try std.testing.expectEqual(error.UnknownCommand, err);
}
