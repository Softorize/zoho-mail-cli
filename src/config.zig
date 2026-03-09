const std = @import("std");
const common = @import("model/common.zig");

/// Errors that can occur during configuration operations.
pub const ConfigError = error{
    /// Config file not found or not readable.
    ConfigNotFound,
    /// Config file contains invalid JSON.
    ConfigParseError,
    /// Failed to write config file.
    ConfigWriteError,
    /// HOME/XDG directory not found.
    HomeDirNotFound,
};

/// Persistent configuration for the CLI.
/// Stored at ~/.config/zoho-mail/config.json.
/// Field names use snake_case (we control this file format).
pub const Config = struct {
    /// Zoho datacenter region.
    region: common.Region = .com,
    /// Active account ID (empty = not set).
    active_account_id: []const u8 = "",
    /// OAuth client ID.
    client_id: []const u8 = "",
    /// OAuth client secret.
    client_secret: []const u8 = "",
    /// Default output format.
    output_format: OutputFormat = .table,

    /// Supported output formats for CLI display.
    pub const OutputFormat = enum {
        /// Tabular text output.
        table,
        /// JSON output.
        json,
        /// Comma-separated values.
        csv,
    };
};

/// Return the config directory path (~/.config/zoho-mail).
/// Caller owns returned slice.
pub fn configDir(allocator: std.mem.Allocator) ConfigError![]const u8 {
    const base = std.posix.getenv("XDG_CONFIG_HOME") orelse blk: {
        const home = std.posix.getenv("HOME") orelse
            return ConfigError.HomeDirNotFound;
        break :blk home;
    };

    if (std.posix.getenv("XDG_CONFIG_HOME") != null) {
        return std.fmt.allocPrint(allocator, "{s}/zoho-mail", .{base}) catch
            return ConfigError.ConfigWriteError;
    }

    return std.fmt.allocPrint(allocator, "{s}/.config/zoho-mail", .{base}) catch
        return ConfigError.ConfigWriteError;
}

/// Return the config file path (~/.config/zoho-mail/config.json).
/// Caller owns returned slice.
pub fn configFilePath(allocator: std.mem.Allocator) ConfigError![]const u8 {
    const dir = try configDir(allocator);
    defer allocator.free(dir);
    return std.fmt.allocPrint(allocator, "{s}/config.json", .{dir}) catch
        return ConfigError.ConfigWriteError;
}

/// Return the tokens file path (~/.config/zoho-mail/tokens.json).
/// Caller owns returned slice.
pub fn tokensFilePath(allocator: std.mem.Allocator) ConfigError![]const u8 {
    const dir = try configDir(allocator);
    defer allocator.free(dir);
    return std.fmt.allocPrint(allocator, "{s}/tokens.json", .{dir}) catch
        return ConfigError.ConfigWriteError;
}

/// Load configuration from ~/.config/zoho-mail/config.json.
/// Returns default Config if file does not exist.
/// Allocator owns the returned strings (parsed via arena).
pub fn load(allocator: std.mem.Allocator) ConfigError!Config {
    const path = try configFilePath(allocator);
    defer allocator.free(path);

    const file = std.fs.openFileAbsolute(path, .{}) catch
        return Config{};
    defer file.close();

    // Use page_allocator so the buffer won't move when arena resizes.
    // parseFromSliceLeaky returns slices pointing into this buffer.
    const content = file.readToEndAlloc(std.heap.page_allocator, 1024 * 64) catch
        return ConfigError.ConfigParseError;

    return std.json.parseFromSliceLeaky(
        Config,
        allocator,
        content,
        .{ .ignore_unknown_fields = true },
    ) catch return ConfigError.ConfigParseError;
}

/// Persist configuration to ~/.config/zoho-mail/config.json.
/// Creates parent directories if they do not exist.
pub fn save(allocator: std.mem.Allocator, config: Config) ConfigError!void {
    const dir_path = try configDir(allocator);
    defer allocator.free(dir_path);

    ensureDir(dir_path) catch return ConfigError.ConfigWriteError;

    const path = try configFilePath(allocator);
    defer allocator.free(path);

    const json = std.json.Stringify.valueAlloc(allocator, config, .{}) catch
        return ConfigError.ConfigWriteError;
    defer allocator.free(json);

    const file = std.fs.createFileAbsolute(path, .{}) catch
        return ConfigError.ConfigWriteError;
    defer file.close();

    file.writeAll(json) catch return ConfigError.ConfigWriteError;
}

/// Ensure a directory exists, creating parent directories as needed.
fn ensureDir(path: []const u8) !void {
    std.fs.makeDirAbsolute(path) catch |err| switch (err) {
        error.PathAlreadyExists => return,
        else => {
            // Try creating parent first
            if (std.fs.path.dirname(path)) |parent| {
                try ensureDir(parent);
                std.fs.makeDirAbsolute(path) catch |e| switch (e) {
                    error.PathAlreadyExists => return,
                    else => return e,
                };
            } else {
                return err;
            }
        },
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Config default values" {
    const c = Config{};
    try std.testing.expectEqual(common.Region.com, c.region);
    try std.testing.expectEqualStrings("", c.active_account_id);
    try std.testing.expectEqualStrings("", c.client_id);
    try std.testing.expectEqual(Config.OutputFormat.table, c.output_format);
}

test "configDir returns a path" {
    const allocator = std.testing.allocator;
    const dir = try configDir(allocator);
    defer allocator.free(dir);
    try std.testing.expect(dir.len > 0);
}

test "configFilePath returns a json path" {
    const allocator = std.testing.allocator;
    const path = try configFilePath(allocator);
    defer allocator.free(path);
    try std.testing.expect(std.mem.endsWith(u8, path, "/config.json"));
}

test "tokensFilePath returns a json path" {
    const allocator = std.testing.allocator;
    const path = try tokensFilePath(allocator);
    defer allocator.free(path);
    try std.testing.expect(std.mem.endsWith(u8, path, "/tokens.json"));
}
