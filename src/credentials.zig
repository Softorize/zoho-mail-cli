//! Embedded OAuth credentials for the Zoho Mail CLI.
//!
//! Set these values before building the binary for distribution.
//! Register a "Server-based Application" at:
//!   https://accounts.zoho.com/developerconsole
//!
//! Set redirect URI to: http://localhost:8749/callback

/// OAuth client ID from Zoho Developer Console.
pub const client_id = "REPLACE_WITH_YOUR_CLIENT_ID";

/// OAuth client secret from Zoho Developer Console.
pub const client_secret = "REPLACE_WITH_YOUR_CLIENT_SECRET";

/// Localhost port for the OAuth callback server.
pub const callback_port: u16 = 8749;

/// Redirect URI registered with Zoho.
pub const redirect_uri = "http://localhost:8749/callback";

/// OAuth scopes requested during authorization.
pub const scopes = "ZohoMail.messages.ALL," ++
    "ZohoMail.folders.ALL," ++
    "ZohoMail.labels.ALL," ++
    "ZohoMail.accounts.READ," ++
    "ZohoMail.tasks.ALL," ++
    "ZohoMail.organization.ALL";

/// Check whether credentials have been configured.
pub fn isConfigured() bool {
    return !std.mem.eql(u8, client_id, "REPLACE_WITH_YOUR_CLIENT_ID");
}

const std = @import("std");

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "constants are non-empty" {
    try std.testing.expect(client_id.len > 0);
    try std.testing.expect(client_secret.len > 0);
    try std.testing.expect(redirect_uri.len > 0);
    try std.testing.expect(scopes.len > 0);
}

test "callback_port is valid" {
    try std.testing.expect(callback_port > 1024);
}

test "redirect_uri contains port" {
    try std.testing.expect(std.mem.indexOf(u8, redirect_uri, "8749") != null);
}
