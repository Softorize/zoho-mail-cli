const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api = @import("../api/org.zig");

/// Execute the "org" subcommand. Subcommands: users, domains, groups.
pub fn execute(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, args: *std.process.ArgIterator) root.CliError!void {
    const subcmd = args.next() orelse {
        printUsage();
        return;
    };
    if (std.mem.eql(u8, subcmd, "--help") or std.mem.eql(u8, subcmd, "-h") or std.mem.eql(u8, subcmd, "help")) {
        printUsage();
        return;
    }
    if (std.mem.eql(u8, subcmd, "users")) {
        const z = parseZoid(args) orelse {
            output.printError("--zoid is required") catch {};
            return error.MissingArgument;
        };
        users(allocator, cfg, flags, z) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "domains")) {
        const z = parseZoid(args) orelse {
            output.printError("--zoid is required") catch {};
            return error.MissingArgument;
        };
        domains(allocator, cfg, flags, z) catch return error.CommandFailed;
    } else if (std.mem.eql(u8, subcmd, "groups")) {
        const z = parseZoid(args) orelse {
            output.printError("--zoid is required") catch {};
            return error.MissingArgument;
        };
        groups(allocator, cfg, flags, z) catch return error.CommandFailed;
    } else {
        output.printError("unknown org subcommand") catch {};
        return error.UnknownCommand;
    }
}

/// List organization users.
pub fn users(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, zoid: []const u8) root.CliError!void {
    const items = api.listUsers(allocator, cfg, zoid) catch return error.CommandFailed;
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, items) catch return error.CommandFailed;
        return;
    }
    const columns = [_]output.Column{
        .{ .header = "ZUID", .width = 18 }, .{ .header = "Email", .width = 30 },
        .{ .header = "Name", .width = 20 }, .{ .header = "Status", .width = 10 },
        .{ .header = "Role", .width = 12 },
    };
    var rows: std.ArrayList([]const []const u8) = .{};
    for (items) |u| {
        const row = allocator.alloc([]const u8, 5) catch return error.CommandFailed;
        row[0] = u.zuid;
        row[1] = u.emailAddress;
        row[2] = u.displayName;
        row[3] = u.accountStatus;
        row[4] = u.role;
        rows.append(allocator, row) catch return error.CommandFailed;
    }
    output.printTable(&columns, rows.items) catch return error.CommandFailed;
}

/// List organization domains.
pub fn domains(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, zoid: []const u8) root.CliError!void {
    const items = api.listDomains(allocator, cfg, zoid) catch return error.CommandFailed;
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, items) catch return error.CommandFailed;
        return;
    }
    const columns = [_]output.Column{
        .{ .header = "Domain", .width = 30 },    .{ .header = "Verified", .width = 10 },
        .{ .header = "MX Status", .width = 12 },
    };
    var rows: std.ArrayList([]const []const u8) = .{};
    for (items) |d| {
        const row = allocator.alloc([]const u8, 3) catch return error.CommandFailed;
        row[0] = d.domainName;
        row[1] = if (d.isVerified) "yes" else "no";
        row[2] = d.mxStatus;
        rows.append(allocator, row) catch return error.CommandFailed;
    }
    output.printTable(&columns, rows.items) catch return error.CommandFailed;
}

/// List organization groups.
pub fn groups(allocator: std.mem.Allocator, cfg: Config, flags: root.GlobalFlags, zoid: []const u8) root.CliError!void {
    const items = api.listGroups(allocator, cfg, zoid) catch return error.CommandFailed;
    const fmt = flags.format orelse cfg.output_format;
    if (fmt == .json) {
        output.printJson(allocator, items) catch return error.CommandFailed;
        return;
    }
    const columns = [_]output.Column{
        .{ .header = "ID", .width = 18 },   .{ .header = "Email", .width = 30 },
        .{ .header = "Name", .width = 20 }, .{ .header = "Members", .width = 10 },
    };
    var rows: std.ArrayList([]const []const u8) = .{};
    for (items) |g| {
        const row = allocator.alloc([]const u8, 4) catch return error.CommandFailed;
        row[0] = g.groupId;
        row[1] = g.emailAddress;
        row[2] = g.groupName;
        row[3] = std.fmt.allocPrint(allocator, "{d}", .{g.memberCount}) catch "";
        rows.append(allocator, row) catch return error.CommandFailed;
    }
    output.printTable(&columns, rows.items) catch return error.CommandFailed;
}

/// Parse --zoid flag from remaining args.
fn parseZoid(args: *std.process.ArgIterator) ?[]const u8 {
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--zoid")) return args.next();
    }
    return null;
}

/// Print usage help for the org command.
fn printUsage() void {
    const help =
        \\Usage: zoho-mail org <subcommand> --zoid <zoid>
        \\
        \\Subcommands:
        \\  users    List organization users
        \\  domains  List organization domains
        \\  groups   List organization groups
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
test "users function signature is correct" {
    _ = &users;
}
