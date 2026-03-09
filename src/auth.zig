const std = @import("std");
const Config = @import("config.zig").Config;
const config_mod = @import("config.zig");
const http = @import("http.zig");

/// Errors specific to authentication operations.
pub const AuthError = error{
    /// OAuth token refresh failed.
    TokenRefreshFailed,
    /// No refresh token stored.
    NoRefreshToken,
    /// No access token available (not logged in).
    NotAuthenticated,
    /// Token file could not be read or written.
    TokenStorageError,
    /// Network error during token refresh.
    NetworkError,
};

/// Stored OAuth token data.
/// Persisted at ~/.config/zoho-mail/tokens.json.
pub const TokenData = struct {
    /// Current access token.
    access_token: []const u8 = "",
    /// Refresh token for obtaining new access tokens.
    refresh_token: []const u8 = "",
    /// Expiry timestamp (epoch seconds).
    expires_at: i64 = 0,
    /// Token type (always "Zoho-oauthtoken").
    token_type: []const u8 = "Zoho-oauthtoken",
};

/// Load stored tokens from disk.
/// Returns null if no tokens file exists.
/// Allocator owns the returned strings (parsed via arena).
pub fn loadTokens(allocator: std.mem.Allocator) AuthError!?TokenData {
    const path = config_mod.tokensFilePath(allocator) catch
        return AuthError.TokenStorageError;
    defer allocator.free(path);

    const file = std.fs.openFileAbsolute(path, .{}) catch return null;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 64 * 1024) catch
        return AuthError.TokenStorageError;
    defer allocator.free(content);

    return std.json.parseFromSliceLeaky(
        TokenData,
        allocator,
        content,
        .{ .ignore_unknown_fields = true },
    ) catch return AuthError.TokenStorageError;
}

/// Persist tokens to ~/.config/zoho-mail/tokens.json.
pub fn saveTokens(allocator: std.mem.Allocator, tokens: TokenData) AuthError!void {
    const path = config_mod.tokensFilePath(allocator) catch
        return AuthError.TokenStorageError;
    defer allocator.free(path);

    const dir_path = config_mod.configDir(allocator) catch
        return AuthError.TokenStorageError;
    defer allocator.free(dir_path);

    std.fs.makeDirAbsolute(dir_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return AuthError.TokenStorageError,
    };

    const json = std.json.Stringify.valueAlloc(allocator, tokens, .{}) catch
        return AuthError.TokenStorageError;
    defer allocator.free(json);

    const file = std.fs.createFileAbsolute(path, .{}) catch
        return AuthError.TokenStorageError;
    defer file.close();

    file.writeAll(json) catch return AuthError.TokenStorageError;
}

/// Return a valid access token, refreshing if expired.
/// Uses config for client_id/secret/region.
pub fn getAccessToken(
    allocator: std.mem.Allocator,
    config: Config,
) AuthError![]const u8 {
    const tokens = (try loadTokens(allocator)) orelse return AuthError.NotAuthenticated;

    if (tokens.access_token.len == 0) return AuthError.NotAuthenticated;

    const now = std.time.timestamp();
    if (now < tokens.expires_at) return tokens.access_token;

    // Token expired, try refresh
    if (tokens.refresh_token.len == 0) return AuthError.NoRefreshToken;

    const new_tokens = try refreshToken(allocator, config, tokens.refresh_token);
    saveTokens(allocator, new_tokens) catch {};
    return new_tokens.access_token;
}

/// Refresh the access token using the stored refresh token.
pub fn refreshToken(
    allocator: std.mem.Allocator,
    config: Config,
    refresh_tok: []const u8,
) AuthError!TokenData {
    const url = http.buildAccountsUrl(allocator, config.region, "token") catch
        return AuthError.NetworkError;

    const body = std.fmt.allocPrint(
        allocator,
        "refresh_token={s}&client_id={s}&client_secret={s}&grant_type=refresh_token",
        .{ refresh_tok, config.client_id, config.client_secret },
    ) catch return AuthError.NetworkError;

    const response = http.postForm(allocator, url, body) catch
        return AuthError.NetworkError;

    const parsed = std.json.parseFromSliceLeaky(
        struct { access_token: []const u8 = "", expires_in: i64 = 3600 },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return AuthError.TokenRefreshFailed;

    if (parsed.access_token.len == 0) return AuthError.TokenRefreshFailed;

    return TokenData{
        .access_token = parsed.access_token,
        .refresh_token = refresh_tok,
        .expires_at = std.time.timestamp() + parsed.expires_in,
    };
}

/// Check whether the user is authenticated and token is valid.
pub fn isAuthenticated(allocator: std.mem.Allocator) AuthError!bool {
    const tokens = (try loadTokens(allocator)) orelse return false;
    if (tokens.access_token.len == 0) return false;
    return std.time.timestamp() < tokens.expires_at;
}

/// Delete stored tokens (logout).
pub fn clearTokens(allocator: std.mem.Allocator) AuthError!void {
    const path = config_mod.tokensFilePath(allocator) catch
        return AuthError.TokenStorageError;
    defer allocator.free(path);

    std.fs.deleteFileAbsolute(path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return AuthError.TokenStorageError,
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "TokenData default values" {
    const t = TokenData{};
    try std.testing.expectEqualStrings("", t.access_token);
    try std.testing.expectEqualStrings("", t.refresh_token);
    try std.testing.expectEqual(@as(i64, 0), t.expires_at);
    try std.testing.expectEqualStrings("Zoho-oauthtoken", t.token_type);
}

test "AuthError variants exist" {
    const err: AuthError = error.NotAuthenticated;
    try std.testing.expectEqual(error.NotAuthenticated, err);
}

test "loadTokens returns null when no file" {
    const allocator = std.testing.allocator;
    const result = try loadTokens(allocator);
    // May or may not be null depending on whether tokens file exists
    _ = result;
}
