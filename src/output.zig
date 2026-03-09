const std = @import("std");

/// Errors from output formatting.
pub const OutputError = error{
    /// Output buffer overflow (stack buffer too small).
    BufferOverflow,
    /// Write to stdout/stderr failed.
    WriteFailed,
};

/// ANSI color codes for terminal output.
pub const Color = enum {
    reset,
    red,
    green,
    yellow,
    blue,
    cyan,
    bold,
    dim,

    /// Return the ANSI escape sequence for this color.
    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .cyan => "\x1b[36m",
            .bold => "\x1b[1m",
            .dim => "\x1b[2m",
        };
    }
};

/// Column definition for table output.
pub const Column = struct {
    /// Column header text.
    header: []const u8,
    /// Minimum width in characters.
    width: u16 = 0,
    /// Alignment within the column.
    alignment: Alignment = .left,

    pub const Alignment = enum { left, right, center };
};

/// Print a formatted table to stdout.
pub fn printTable(
    columns: []const Column,
    rows: []const []const []const u8,
) OutputError!void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    // Print headers
    for (columns, 0..) |col, i| {
        if (i > 0) stdout.writeAll("  ") catch return error.WriteFailed;
        printPadded(stdout, col.header, col.width) catch return error.WriteFailed;
    }
    stdout.writeAll("\n") catch return error.WriteFailed;

    // Print separator
    for (columns, 0..) |col, i| {
        if (i > 0) stdout.writeAll("  ") catch return error.WriteFailed;
        const w = @max(col.width, @as(u16, @intCast(col.header.len)));
        var j: u16 = 0;
        while (j < w) : (j += 1) {
            stdout.writeAll("-") catch return error.WriteFailed;
        }
    }
    stdout.writeAll("\n") catch return error.WriteFailed;

    // Print rows
    for (rows) |row| {
        for (columns, 0..) |col, i| {
            if (i > 0) stdout.writeAll("  ") catch return error.WriteFailed;
            const val = if (i < row.len) row[i] else "";
            printPadded(stdout, val, col.width) catch return error.WriteFailed;
        }
        stdout.writeAll("\n") catch return error.WriteFailed;
    }
}

/// Print a value as JSON to stdout.
pub fn printJson(
    allocator: std.mem.Allocator,
    value: anytype,
) OutputError!void {
    const json = std.json.Stringify.valueAlloc(allocator, value, .{
        .whitespace = .indent_2,
    }) catch return error.BufferOverflow;

    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.writeAll(json) catch return error.WriteFailed;
    stdout.writeAll("\n") catch return error.WriteFailed;
}

/// Print a success message to stdout (green).
pub fn printSuccess(message: []const u8) OutputError!void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print("{s}{s}{s}\n", .{
        Color.green.code(), message, Color.reset.code(),
    }) catch return error.WriteFailed;
}

/// Print an error message to stderr (red).
pub fn printError(message: []const u8) OutputError!void {
    const stderr = std.fs.File.stderr().deprecatedWriter();
    stderr.print("{s}Error: {s}{s}\n", .{
        Color.red.code(), message, Color.reset.code(),
    }) catch return error.WriteFailed;
}

/// Print a warning message to stderr (yellow).
pub fn printWarning(message: []const u8) OutputError!void {
    const stderr = std.fs.File.stderr().deprecatedWriter();
    stderr.print("{s}Warning: {s}{s}\n", .{
        Color.yellow.code(), message, Color.reset.code(),
    }) catch return error.WriteFailed;
}

/// Print a key-value detail line to stdout.
pub fn printDetail(key: []const u8, value: []const u8) OutputError!void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print("  {s}{s}:{s} {s}\n", .{
        Color.bold.code(), key, Color.reset.code(), value,
    }) catch return error.WriteFailed;
}

/// Print a section header to stdout (bold).
pub fn printHeader(title: []const u8) OutputError!void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print("\n{s}{s}{s}\n", .{
        Color.bold.code(), title, Color.reset.code(),
    }) catch return error.WriteFailed;
}

/// Prompt for confirmation. Returns true if user types "y" or "yes".
pub fn confirm(message: []const u8) OutputError!bool {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print("{s} [y/N]: ", .{message}) catch return error.WriteFailed;

    const stdin = std.fs.File.stdin().deprecatedReader();
    var buf: [16]u8 = undefined;
    const line = stdin.readUntilDelimiter(&buf, '\n') catch return false;
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    return std.mem.eql(u8, trimmed, "y") or std.mem.eql(u8, trimmed, "yes");
}

/// Format an epoch-ms timestamp as a human-readable date string.
pub fn formatTimestamp(epoch_ms: i64, buf: *[32]u8) []const u8 {
    const epoch_secs: i64 = @divTrunc(epoch_ms, 1000);
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@max(0, epoch_secs)) };
    const day = es.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();

    const result = std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        yd.year,
        @as(u16, @intFromEnum(md.month)),
        @as(u16, md.day_index) + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    }) catch return "N/A";

    return result;
}

/// Internal: print a string padded to a minimum width.
fn printPadded(writer: anytype, text: []const u8, min_width: u16) !void {
    try writer.writeAll(text);
    if (text.len < min_width) {
        var remaining: usize = min_width - text.len;
        while (remaining > 0) : (remaining -= 1) {
            try writer.writeAll(" ");
        }
    }
}

// Tests
test "Color.code returns non-empty strings" {
    try std.testing.expect(Color.reset.code().len > 0);
    try std.testing.expect(Color.green.code().len > 0);
}

test "formatTimestamp formats epoch zero" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("1970-01-01 00:00:00", formatTimestamp(0, &buf));
}

test "Column default values" {
    const col = Column{ .header = "Name" };
    try std.testing.expectEqual(@as(u16, 0), col.width);
}
