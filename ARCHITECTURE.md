# Zoho Mail CLI — Architecture Design Document

**Version:** 1.0
**Zig version:** 0.15.2
**Date:** 2026-03-08
**Role:** Architect

---

## Allocator Ownership

```
main.zig          Creates GPA (GeneralPurposeAllocator)
  |
  v
cmd/root.zig      Creates ArenaAllocator(GPA) per command invocation
  |
  v
cmd/*.zig         Receives arena allocator as parameter
  |
  v
api/*.zig         Receives arena allocator as parameter
  |
  v
model/*.zig       Pure data types — no allocations, no allocator needed
  |
output.zig        Receives arena allocator; uses stack FixedBufferAllocator where possible
config.zig        Receives GPA (persistent across commands for config caching)
auth.zig          Receives arena allocator for token ops
http.zig          Receives arena allocator; passes to std.http.Client
```

**Rules:**
- Arena is created in `cmd/root.zig`, freed after command returns
- All API response parsing uses `parseFromSliceLeaky` with the arena
- No module stores an allocator in file-scope `var`
- Every `init` that takes an allocator documents ownership in `///`

---

## Dependency Graph

```
cmd/* ──> api/* ──> model/*
  |         |
  |         v
  |       auth.zig
  |         |
  |         v
  +-----> http.zig
  |
  +-----> output.zig
  +-----> config.zig
```

`model/*` has ZERO internal dependencies.
`http.zig` has ZERO dependencies on `api/*` or `cmd/*`.
`auth.zig` depends on `config.zig` and `http.zig`.
`config.zig` has ZERO internal dependencies.
`output.zig` has ZERO internal dependencies (except `model/*` for formatting).

---

## Module Designs

### Module: `src/model/common.zig`

```zig
const std = @import("std");

/// Domain-specific error returned by all API operations.
pub const ApiError = struct {
    /// Zoho error code string (e.g., "INVALID_TOKEN").
    code: []const u8,
    /// Human-readable error message from the API.
    message: []const u8,
};

/// Generic wrapper for Zoho API JSON responses.
/// `T` is the payload type (e.g., Account, Message).
pub fn ApiResponse(comptime T: type) type {
    return struct {
        /// Parsed status object from the response.
        status: Status,
        /// Parsed data payload; null when the response is an error.
        data: ?T = null,

        pub const Status = struct {
            /// Numeric status code from Zoho (200, 400, etc.).
            code: i32,
            /// Status description string.
            description: []const u8,
        };
    };
}

/// Generic wrapper for list responses with pagination metadata.
pub fn ApiListResponse(comptime T: type) type {
    return struct {
        /// Parsed status object.
        status: ApiResponse(void).Status,
        /// Array of parsed items.
        data: []const T = &.{},
        /// Pagination info; null if not present.
        paging: ?Pagination = null,
    };
}

/// Pagination metadata returned by list endpoints.
/// Field names match Zoho API JSON keys (camelCase).
pub const Pagination = struct {
    /// Total number of results available.
    total: ?i64 = null,
    /// Whether more results are available.
    hasMore: bool = false,
    /// Index of first result in this page.
    start: i64 = 0,
    /// Number of results per page.
    limit: i64 = 50,
};

/// Zoho datacenter region, determines base URL TLD.
pub const Region = enum {
    com,
    eu,
    in_,
    com_au,
    com_cn,
    jp,

    /// Return the TLD string for URL construction.
    pub fn tld(self: Region) []const u8 {
        return switch (self) {
            .com => "com",
            .eu => "eu",
            .in_ => "in",
            .com_au => "com.au",
            .com_cn => "com.cn",
            .jp => "jp",
        };
    }
};
```

---

### Module: `src/model/account.zig`

```zig
/// Zoho Mail account representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Account = struct {
    /// Unique account identifier.
    accountId: []const u8,
    /// Display name for the account.
    displayName: []const u8 = "",
    /// Primary email address.
    emailAddress: []const u8,
    /// Account type (e.g., "premium", "free").
    type: []const u8 = "",
    /// Whether this is the primary account.
    primary: bool = false,
    /// Incoming mail server name.
    incomingServer: []const u8 = "",
    /// Outgoing mail server name.
    outgoingServer: []const u8 = "",
};
```

---

### Module: `src/model/message.zig`

```zig
/// Email message as returned by the Zoho Mail API.
/// Field names match Zoho API JSON keys (camelCase).
pub const Message = struct {
    /// Unique message identifier.
    messageId: []const u8,
    /// Folder containing this message.
    folderId: []const u8 = "",
    /// Subject line.
    subject: []const u8 = "",
    /// Sender address (display format).
    sender: []const u8 = "",
    /// Comma-separated To recipients.
    toAddress: []const u8 = "",
    /// Comma-separated Cc recipients.
    ccAddress: []const u8 = "",
    /// Received timestamp (epoch ms).
    receivedTime: i64 = 0,
    /// Read/unread status.
    isRead: bool = false,
    /// Flagged status.
    isFlagged: bool = false,
    /// Message summary (snippet).
    summary: []const u8 = "",
    /// Full message content (only populated on read).
    content: []const u8 = "",
    /// Whether the message has attachments.
    hasAttachment: bool = false,
    /// Message status code from Zoho.
    status: []const u8 = "",
};

/// Request payload for sending an email.
/// Field names match Zoho API JSON keys for serialization.
pub const SendRequest = struct {
    /// Sender email address.
    fromAddress: []const u8,
    /// Comma-separated To recipients.
    toAddress: []const u8,
    /// Email subject.
    subject: []const u8 = "",
    /// Email body content.
    content: []const u8 = "",
    /// Comma-separated Cc recipients.
    ccAddress: []const u8 = "",
    /// Comma-separated Bcc recipients.
    bccAddress: []const u8 = "",
    /// MIME content type ("text/html" or "text/plain").
    mailFormat: []const u8 = "html",
};

/// Parameters for searching messages.
/// Field names match Zoho API query parameter keys.
pub const SearchParams = struct {
    /// Search query string.
    searchKey: []const u8,
    /// Maximum results to return.
    limit: i64 = 50,
    /// Start index for pagination.
    start: i64 = 0,
};

/// Parameters for updating a message (flag/move/mark-read/label).
/// These are CLI-internal; serialized to Zoho JSON manually.
pub const UpdateParams = struct {
    /// Message IDs to update.
    message_id: []const u8,
    /// Update mode: "markAsRead", "markAsUnread", "moveToFolder", etc.
    mode: []const u8,
    /// Target folder ID (for move operations).
    dest_folder_id: []const u8 = "",
    /// Flag value (for flag operations).
    flag_value: []const u8 = "",
    /// Label ID (for label operations).
    label_id: []const u8 = "",
};
```

---

### Module: `src/model/folder.zig`

```zig
/// Zoho Mail folder representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Folder = struct {
    /// Unique folder identifier.
    folderId: []const u8,
    /// Folder display name.
    folderName: []const u8,
    /// Parent folder ID (empty for root folders).
    parentFolderId: []const u8 = "",
    /// Folder path string.
    folderPath: []const u8 = "",
    /// Unread message count.
    unreadCount: i64 = 0,
    /// Total message count.
    messageCount: i64 = 0,
    /// Folder type (system or custom).
    folderType: []const u8 = "",
};
```

---

### Module: `src/model/label.zig`

```zig
/// Zoho Mail label representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Label = struct {
    /// Unique label identifier.
    labelId: []const u8,
    /// Label display name.
    labelName: []const u8,
    /// Label color hex code.
    color: []const u8 = "",
    /// Number of messages with this label.
    messageCount: i64 = 0,
};
```

---

### Module: `src/model/task.zig`

```zig
/// Zoho Mail task representation.
/// Field names match Zoho API JSON keys (camelCase).
pub const Task = struct {
    /// Unique task identifier.
    taskId: []const u8,
    /// Task title.
    title: []const u8,
    /// Task description/notes.
    notes: []const u8 = "",
    /// Due date (epoch ms, 0 = no due date).
    dueDate: i64 = 0,
    /// Task priority (1=Low, 2=Medium, 3=High).
    priority: i32 = 2,
    /// Completion percentage (0-100).
    percentage: i32 = 0,
    /// Task status: "notstarted", "inprogress", "completed".
    status: []const u8 = "notstarted",
    /// Assignee email address.
    assignee: []const u8 = "",
    /// Group ID (for group tasks).
    groupId: []const u8 = "",
};
```

---

### Module: `src/model/org.zig`

```zig
/// Organization user account.
/// Field names match Zoho API JSON keys (camelCase).
pub const User = struct {
    /// Zoho user ID.
    zuid: []const u8,
    /// User email address.
    emailAddress: []const u8,
    /// Display name.
    displayName: []const u8 = "",
    /// Account status ("active", "suspended").
    accountStatus: []const u8 = "",
    /// User role in the organization.
    role: []const u8 = "",
};

/// Organization domain.
/// Field names match Zoho API JSON keys (camelCase).
pub const Domain = struct {
    /// Domain name string.
    domainName: []const u8,
    /// Verification status.
    isVerified: bool = false,
    /// MX record status.
    mxStatus: []const u8 = "",
};

/// Organization user group.
/// Field names match Zoho API JSON keys (camelCase).
pub const Group = struct {
    /// Unique group identifier.
    groupId: []const u8,
    /// Group email address.
    emailAddress: []const u8,
    /// Group display name.
    groupName: []const u8 = "",
    /// Number of members.
    memberCount: i64 = 0,
    /// Group description.
    description: []const u8 = "",
};
```

---

### Module: `src/config.zig`

```zig
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

    pub const OutputFormat = enum {
        table,
        json,
        csv,
    };
};

/// Load configuration from ~/.config/zoho-mail/config.json.
/// Returns default Config if file does not exist.
/// Allocator owns the returned strings (parsed via arena).
pub fn load(allocator: std.mem.Allocator) ConfigError!Config;

/// Persist configuration to ~/.config/zoho-mail/config.json.
/// Creates parent directories if they do not exist.
pub fn save(allocator: std.mem.Allocator, config: Config) ConfigError!void;

/// Return the config directory path (~/.config/zoho-mail).
/// Caller owns returned slice.
pub fn configDir(allocator: std.mem.Allocator) ConfigError![]const u8;

/// Return the config file path (~/.config/zoho-mail/config.json).
/// Caller owns returned slice.
pub fn configFilePath(allocator: std.mem.Allocator) ConfigError![]const u8;
```

---

### Module: `src/auth.zig`

```zig
const std = @import("std");
const Config = @import("config.zig").Config;
const common = @import("model/common.zig");

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
/// Field names use snake_case for the local tokens file (we control the format).
/// Zoho OAuth responses use snake_case too (access_token, refresh_token, etc.).
pub const TokenData = struct {
    /// Current access token.
    access_token: []const u8 = "",
    /// Refresh token for obtaining new access tokens.
    refresh_token: []const u8 = "",
    /// Expiry timestamp (epoch seconds, computed by us).
    expires_at: i64 = 0,
    /// Token type (always "Zoho-oauthtoken").
    token_type: []const u8 = "Zoho-oauthtoken",
};

/// Load stored tokens from disk.
/// Returns null if no tokens file exists.
/// Allocator owns the returned strings (parsed via arena).
pub fn loadTokens(allocator: std.mem.Allocator) AuthError!?TokenData;

/// Persist tokens to ~/.config/zoho-mail/tokens.json.
pub fn saveTokens(allocator: std.mem.Allocator, tokens: TokenData) AuthError!void;

/// Return a valid access token, refreshing if expired.
/// Uses config for client_id/secret/region.
/// Allocator is used for HTTP request/response buffers.
pub fn getAccessToken(
    allocator: std.mem.Allocator,
    config: Config,
) AuthError![]const u8;

/// Refresh the access token using the stored refresh token.
/// Returns updated TokenData with new access_token and expires_at.
pub fn refreshToken(
    allocator: std.mem.Allocator,
    config: Config,
    refresh_token: []const u8,
) AuthError!TokenData;

/// Check whether the user is authenticated and token is valid.
/// Returns true if a non-expired access token exists.
pub fn isAuthenticated(allocator: std.mem.Allocator) AuthError!bool;

/// Delete stored tokens (logout).
pub fn clearTokens(allocator: std.mem.Allocator) AuthError!void;
```

---

### Module: `src/http.zig`

```zig
const std = @import("std");

/// Errors from the HTTP transport layer.
pub const HttpError = error{
    /// Failed to connect to the server.
    ConnectionFailed,
    /// HTTP request timed out.
    Timeout,
    /// Server returned non-2xx status.
    RequestFailed,
    /// Response body could not be read.
    ReadFailed,
    /// Request body could not be sent.
    WriteFailed,
    /// URL could not be parsed.
    InvalidUrl,
};

/// HTTP method for requests.
pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
};

/// Result of an HTTP request.
pub const Response = struct {
    /// HTTP status code.
    status_code: u16,
    /// Response body as bytes.
    body: []const u8,
};

/// Perform a GET request to the given URL with auth header.
/// Allocator owns the returned Response.body bytes.
pub fn get(
    allocator: std.mem.Allocator,
    url: []const u8,
    access_token: []const u8,
) HttpError!Response;

/// Perform a POST request with a JSON body.
/// Allocator owns the returned Response.body bytes.
pub fn post(
    allocator: std.mem.Allocator,
    url: []const u8,
    access_token: []const u8,
    body: []const u8,
) HttpError!Response;

/// Perform a PUT request with a JSON body.
/// Allocator owns the returned Response.body bytes.
pub fn put(
    allocator: std.mem.Allocator,
    url: []const u8,
    access_token: []const u8,
    body: []const u8,
) HttpError!Response;

/// Perform a DELETE request.
/// Allocator owns the returned Response.body bytes.
pub fn delete(
    allocator: std.mem.Allocator,
    url: []const u8,
    access_token: []const u8,
) HttpError!Response;

/// Perform an unauthenticated POST (used for OAuth token exchange).
/// Allocator owns the returned Response.body bytes.
pub fn postForm(
    allocator: std.mem.Allocator,
    url: []const u8,
    form_body: []const u8,
) HttpError!Response;

/// Build a full API URL from region, path, and optional query params.
/// Caller owns returned slice.
pub fn buildUrl(
    allocator: std.mem.Allocator,
    region: @import("model/common.zig").Region,
    path: []const u8,
    query: ?[]const u8,
) HttpError![]const u8;

/// Build a full accounts server URL for OAuth operations.
/// Caller owns returned slice.
pub fn buildAccountsUrl(
    allocator: std.mem.Allocator,
    region: @import("model/common.zig").Region,
    path: []const u8,
) HttpError![]const u8;
```

---

### Module: `src/output.zig`

```zig
const std = @import("std");
const Config = @import("config.zig").Config;

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
    pub fn code(self: Color) []const u8;
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
/// Rows are slices of string slices; first row is data (headers from columns).
/// Uses stack FixedBufferAllocator for line formatting.
pub fn printTable(
    columns: []const Column,
    rows: []const []const []const u8,
) OutputError!void;

/// Print a value as JSON to stdout.
/// Uses the arena allocator for serialization buffer.
pub fn printJson(
    allocator: std.mem.Allocator,
    value: anytype,
) OutputError!void;

/// Print a success message to stdout (green).
pub fn printSuccess(message: []const u8) OutputError!void;

/// Print an error message to stderr (red).
pub fn printError(message: []const u8) OutputError!void;

/// Print a warning message to stderr (yellow).
pub fn printWarning(message: []const u8) OutputError!void;

/// Print a key-value detail line to stdout.
/// Format: "  Key: Value\n"
pub fn printDetail(key: []const u8, value: []const u8) OutputError!void;

/// Print a section header to stdout (bold).
pub fn printHeader(title: []const u8) OutputError!void;

/// Format an epoch-ms timestamp as a human-readable date string.
/// Uses a stack buffer; returns a slice into the stack buffer.
pub fn formatTimestamp(epoch_ms: i64, buf: *[32]u8) []const u8;
```

---

### Module: `src/api/accounts.zig`

```zig
const std = @import("std");
const common = @import("../model/common.zig");
const Account = @import("../model/account.zig").Account;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from account API operations.
pub const AccountApiError = error{
    /// API returned an error response.
    ApiRequestFailed,
    /// Response JSON could not be parsed.
    ParseError,
} || auth.AuthError || http.HttpError;

/// Fetch all accounts for the authenticated user.
/// Allocator owns all returned Account slices (use arena).
pub fn listAccounts(
    allocator: std.mem.Allocator,
    config: Config,
) AccountApiError![]const Account;

/// Fetch a single account by ID.
/// Allocator owns returned Account strings.
pub fn getAccount(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
) AccountApiError!Account;
```

---

### Module: `src/api/messages.zig`

```zig
const std = @import("std");
const common = @import("../model/common.zig");
const msg = @import("../model/message.zig");
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from message API operations.
pub const MessageApiError = error{
    ApiRequestFailed,
    ParseError,
    InvalidParameter,
} || auth.AuthError || http.HttpError;

/// List messages in a folder.
/// Allocator owns all returned Message slices.
pub fn listMessages(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
    start: i64,
    limit: i64,
) MessageApiError![]const msg.Message;

/// Search messages with a query string.
/// Allocator owns all returned Message slices.
pub fn searchMessages(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    params: msg.SearchParams,
) MessageApiError![]const msg.Message;

/// Read full message content by ID.
/// Allocator owns returned Message.
pub fn getMessage(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
    message_id: []const u8,
) MessageApiError!msg.Message;

/// Send an email message.
/// Allocator owns returned Message (sent message details).
pub fn sendMessage(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    request: msg.SendRequest,
) MessageApiError!msg.Message;

/// Delete a message by ID.
pub fn deleteMessage(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
    message_id: []const u8,
) MessageApiError!void;

/// Update message properties (flag, move, mark-read, label).
pub fn updateMessage(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    params: msg.UpdateParams,
) MessageApiError!void;
```

---

### Module: `src/api/folders.zig`

```zig
const std = @import("std");
const Folder = @import("../model/folder.zig").Folder;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from folder API operations.
pub const FolderApiError = error{
    ApiRequestFailed,
    ParseError,
} || auth.AuthError || http.HttpError;

/// List all folders for an account.
/// Allocator owns returned Folder slices.
pub fn listFolders(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
) FolderApiError![]const Folder;

/// Get a single folder by ID.
pub fn getFolder(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
) FolderApiError!Folder;

/// Create a new folder.
/// Returns the created Folder.
pub fn createFolder(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_name: []const u8,
    parent_folder_id: []const u8,
) FolderApiError!Folder;

/// Rename a folder.
pub fn renameFolder(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
    new_name: []const u8,
) FolderApiError!Folder;

/// Delete a folder by ID.
pub fn deleteFolder(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    folder_id: []const u8,
) FolderApiError!void;
```

---

### Module: `src/api/labels.zig`

```zig
const std = @import("std");
const Label = @import("../model/label.zig").Label;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from label API operations.
pub const LabelApiError = error{
    ApiRequestFailed,
    ParseError,
} || auth.AuthError || http.HttpError;

/// List all labels for an account.
/// Allocator owns returned Label slices.
pub fn listLabels(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
) LabelApiError![]const Label;

/// Create a new label.
/// Returns the created Label.
pub fn createLabel(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    label_name: []const u8,
    color: []const u8,
) LabelApiError!Label;

/// Rename a label.
pub fn renameLabel(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    label_id: []const u8,
    new_name: []const u8,
) LabelApiError!Label;

/// Delete a label by ID.
pub fn deleteLabel(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
    label_id: []const u8,
) LabelApiError!void;
```

---

### Module: `src/api/tasks.zig`

```zig
const std = @import("std");
const Task = @import("../model/task.zig").Task;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from task API operations.
pub const TaskApiError = error{
    ApiRequestFailed,
    ParseError,
} || auth.AuthError || http.HttpError;

/// List personal tasks (GET /api/tasks/me).
/// Allocator owns returned Task slices.
pub fn listMyTasks(
    allocator: std.mem.Allocator,
    config: Config,
) TaskApiError![]const Task;

/// List group tasks (GET /api/tasks/groups/{zgid}).
/// Allocator owns returned Task slices.
pub fn listGroupTasks(
    allocator: std.mem.Allocator,
    config: Config,
    group_id: []const u8,
) TaskApiError![]const Task;

/// Get a single task by ID.
pub fn getTask(
    allocator: std.mem.Allocator,
    config: Config,
    task_id: []const u8,
) TaskApiError!Task;

/// Create a new task.
/// Returns the created Task.
pub fn createTask(
    allocator: std.mem.Allocator,
    config: Config,
    title: []const u8,
    notes: []const u8,
    due_date: i64,
    priority: i32,
) TaskApiError!Task;

/// Update an existing task.
pub fn updateTask(
    allocator: std.mem.Allocator,
    config: Config,
    task_id: []const u8,
    title: ?[]const u8,
    notes: ?[]const u8,
    status: ?[]const u8,
    priority: ?i32,
) TaskApiError!Task;

/// Delete a task by ID.
pub fn deleteTask(
    allocator: std.mem.Allocator,
    config: Config,
    task_id: []const u8,
) TaskApiError!void;
```

---

### Module: `src/api/org.zig`

```zig
const std = @import("std");
const org_model = @import("../model/org.zig");
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from organization admin API operations.
pub const OrgApiError = error{
    ApiRequestFailed,
    ParseError,
    Unauthorized,
} || auth.AuthError || http.HttpError;

/// List organization users.
/// Allocator owns returned User slices.
pub fn listUsers(
    allocator: std.mem.Allocator,
    config: Config,
    zoid: []const u8,
) OrgApiError![]const org_model.User;

/// List organization domains.
/// Allocator owns returned Domain slices.
pub fn listDomains(
    allocator: std.mem.Allocator,
    config: Config,
    zoid: []const u8,
) OrgApiError![]const org_model.Domain;

/// List organization groups.
/// Allocator owns returned Group slices.
pub fn listGroups(
    allocator: std.mem.Allocator,
    config: Config,
    zoid: []const u8,
) OrgApiError![]const org_model.Group;
```

---

### Module: `src/cmd/root.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;

/// Errors from command dispatch.
pub const CliError = error{
    /// Unknown command or subcommand.
    UnknownCommand,
    /// Required argument missing.
    MissingArgument,
    /// Invalid argument value.
    InvalidArgument,
    /// Command execution failed.
    CommandFailed,
};

/// Global flags parsed from the command line.
pub const GlobalFlags = struct {
    /// Override output format (--format json|table|csv).
    format: ?Config.OutputFormat = null,
    /// Override region (--region com|eu|in|...).
    region: ?@import("../model/common.zig").Region = null,
    /// Override account ID (--account ID).
    account_id: ?[]const u8 = null,
    /// Show help (--help or -h).
    help: bool = false,
    /// Show version (--version or -v).
    version: bool = false,
};

/// Parse global flags and dispatch to the appropriate subcommand.
/// Creates an ArenaAllocator from the provided GPA for per-command use.
/// The arena is freed when this function returns.
pub fn run(gpa: std.mem.Allocator) CliError!void;

/// Parse global flags from the argument iterator.
/// Returns remaining args after global flags are consumed.
pub fn parseGlobalFlags(
    args: *std.process.ArgIterator,
) CliError!struct { flags: GlobalFlags, command: ?[]const u8 };

/// Print top-level help text to stdout.
pub fn printHelp() void;

/// Print version information to stdout.
pub fn printVersion() void;
```

---

### Module: `src/cmd/auth.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");

/// Execute the "auth" subcommand.
/// Subcommands: login, refresh, status, logout.
pub fn execute(
    allocator: std.mem.Allocator,
    config: Config,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// Perform interactive OAuth login flow.
/// Prints authorization URL, reads auth code from stdin.
pub fn login(allocator: std.mem.Allocator, config: Config) root.CliError!void;

/// Force token refresh.
pub fn refresh(allocator: std.mem.Allocator, config: Config) root.CliError!void;

/// Print current authentication status.
pub fn status(allocator: std.mem.Allocator) root.CliError!void;

/// Clear stored tokens (logout).
pub fn logout(allocator: std.mem.Allocator) root.CliError!void;
```

---

### Module: `src/cmd/account.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");

/// Execute the "account" subcommand.
/// Subcommands: list, info, set-default.
pub fn execute(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// List all accounts and print as table or JSON.
pub fn list(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
) root.CliError!void;

/// Show details for a single account.
pub fn info(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    account_id: []const u8,
) root.CliError!void;

/// Set the default active account.
pub fn setDefault(
    allocator: std.mem.Allocator,
    config: *Config,
    account_id: []const u8,
) root.CliError!void;
```

---

### Module: `src/cmd/mail.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");

/// Execute the "mail" subcommand.
/// Subcommands: send, list, search, read, delete.
pub fn execute(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// Send an email. Reads recipients, subject, body from args/stdin.
pub fn send(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// List messages in a folder. Supports --folder, --limit, --start.
pub fn listMail(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// Search messages. Requires --query.
pub fn search(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// Read a single message by ID. Requires message-id positional arg.
pub fn read(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// Delete a message by ID. Requires message-id and --folder.
pub fn deleteMail(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;
```

---

### Module: `src/cmd/mail_update.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");

/// Execute message update subcommands.
/// Subcommands: flag, unflag, move, mark-read, mark-unread, label.
pub fn execute(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// Toggle flag on a message.
pub fn flag(
    allocator: std.mem.Allocator,
    config: Config,
    message_id: []const u8,
    flag_value: bool,
) root.CliError!void;

/// Move a message to a different folder.
pub fn move(
    allocator: std.mem.Allocator,
    config: Config,
    message_id: []const u8,
    dest_folder_id: []const u8,
) root.CliError!void;

/// Mark a message as read or unread.
pub fn markRead(
    allocator: std.mem.Allocator,
    config: Config,
    message_id: []const u8,
    is_read: bool,
) root.CliError!void;

/// Apply a label to a message.
pub fn applyLabel(
    allocator: std.mem.Allocator,
    config: Config,
    message_id: []const u8,
    label_id: []const u8,
) root.CliError!void;
```

---

### Module: `src/cmd/folder.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");

/// Execute the "folder" subcommand.
/// Subcommands: list, create, rename, delete.
pub fn execute(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// List all folders for the active account.
pub fn list(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
) root.CliError!void;

/// Create a new folder with the given name.
pub fn create(
    allocator: std.mem.Allocator,
    config: Config,
    name: []const u8,
    parent_id: []const u8,
) root.CliError!void;

/// Rename an existing folder.
pub fn rename(
    allocator: std.mem.Allocator,
    config: Config,
    folder_id: []const u8,
    new_name: []const u8,
) root.CliError!void;

/// Delete a folder by ID.
pub fn deleteFn(
    allocator: std.mem.Allocator,
    config: Config,
    folder_id: []const u8,
) root.CliError!void;
```

---

### Module: `src/cmd/label.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");

/// Execute the "label" subcommand.
/// Subcommands: list, create, rename, delete.
pub fn execute(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// List all labels for the active account.
pub fn list(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
) root.CliError!void;

/// Create a new label.
pub fn create(
    allocator: std.mem.Allocator,
    config: Config,
    name: []const u8,
    color: []const u8,
) root.CliError!void;

/// Rename an existing label.
pub fn renameFn(
    allocator: std.mem.Allocator,
    config: Config,
    label_id: []const u8,
    new_name: []const u8,
) root.CliError!void;

/// Delete a label by ID.
pub fn deleteFn(
    allocator: std.mem.Allocator,
    config: Config,
    label_id: []const u8,
) root.CliError!void;
```

---

### Module: `src/cmd/task.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");

/// Execute the "task" subcommand.
/// Subcommands: list, create, update, delete, show.
pub fn execute(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// List tasks (personal or group with --group flag).
pub fn list(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    group_id: ?[]const u8,
) root.CliError!void;

/// Show a single task's details.
pub fn show(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    task_id: []const u8,
) root.CliError!void;

/// Create a new task from command-line arguments.
pub fn create(
    allocator: std.mem.Allocator,
    config: Config,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// Update a task's fields from command-line arguments.
pub fn update(
    allocator: std.mem.Allocator,
    config: Config,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// Delete a task by ID.
pub fn deleteFn(
    allocator: std.mem.Allocator,
    config: Config,
    task_id: []const u8,
) root.CliError!void;
```

---

### Module: `src/cmd/org.zig`

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");

/// Execute the "org" subcommand.
/// Subcommands: users, domains, groups.
pub fn execute(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void;

/// List organization users. Requires --zoid.
pub fn users(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    zoid: []const u8,
) root.CliError!void;

/// List organization domains. Requires --zoid.
pub fn domains(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    zoid: []const u8,
) root.CliError!void;

/// List organization groups. Requires --zoid.
pub fn groups(
    allocator: std.mem.Allocator,
    config: Config,
    flags: root.GlobalFlags,
    zoid: []const u8,
) root.CliError!void;
```

---

### Module: `src/main.zig`

```zig
const std = @import("std");
const root = @import("cmd/root.zig");

/// Entry point. Creates GPA, delegates to cmd/root.zig.
pub fn main() !void {
    // 1. Create GPA
    // 2. defer gpa.deinit() — checks for leaks in debug
    // 3. Call root.run(gpa.allocator())
    // 4. Handle CliError by printing to stderr and exiting with code 1
}
```

---

### Module: `build.zig`

```zig
const std = @import("std");

/// Configure the zoho-mail executable build.
pub fn build(b: *std.Build) void {
    // 1. Standard target and optimize options
    // 2. Add executable "zoho-mail" with root source "src/main.zig"
    // 3. Install artifact
    // 4. Add "run" step
    // 5. Add "test" step that runs tests on all source files
}
```

---

### Module: `build.zig.zon`

```zig
.{
    .name = .zoho_mail,
    .version = "0.1.0",
    .fingerprint = .auto,
    .minimum_zig_version = "0.15.2",
    .paths = .{ "build.zig", "build.zig.zon", "src" },
}
```

---

## Comptime Interfaces

No comptime interfaces (`@hasDecl`/`@typeInfo` patterns) are needed for this project. The architecture uses simple struct composition and explicit function calls. The model types are plain data types consumed by `std.json.parseFromSliceLeaky`. The dependency injection is handled via allocator parameters, not generic interfaces.

**Rationale:** This is a CLI tool with a fixed set of API endpoints and model types. Generic abstractions would add complexity without benefit. If future needs arise (e.g., pluggable API backends), a comptime interface can be added to `api/` at that time.

---

## Error Handling Strategy

Each domain has its own error set:

| Module | Error Set | Errors |
|--------|-----------|--------|
| `config.zig` | `ConfigError` | `ConfigNotFound`, `ConfigParseError`, `ConfigWriteError`, `HomeDirNotFound` |
| `auth.zig` | `AuthError` | `TokenRefreshFailed`, `NoRefreshToken`, `NotAuthenticated`, `TokenStorageError`, `NetworkError` |
| `http.zig` | `HttpError` | `ConnectionFailed`, `Timeout`, `RequestFailed`, `ReadFailed`, `WriteFailed`, `InvalidUrl` |
| `output.zig` | `OutputError` | `BufferOverflow`, `WriteFailed` |
| `cmd/root.zig` | `CliError` | `UnknownCommand`, `MissingArgument`, `InvalidArgument`, `CommandFailed` |
| `api/accounts.zig` | `AccountApiError` | `ApiRequestFailed`, `ParseError` + `AuthError` + `HttpError` |
| `api/messages.zig` | `MessageApiError` | `ApiRequestFailed`, `ParseError`, `InvalidParameter` + `AuthError` + `HttpError` |
| `api/folders.zig` | `FolderApiError` | `ApiRequestFailed`, `ParseError` + `AuthError` + `HttpError` |
| `api/labels.zig` | `LabelApiError` | `ApiRequestFailed`, `ParseError` + `AuthError` + `HttpError` |
| `api/tasks.zig` | `TaskApiError` | `ApiRequestFailed`, `ParseError` + `AuthError` + `HttpError` |
| `api/org.zig` | `OrgApiError` | `ApiRequestFailed`, `ParseError`, `Unauthorized` + `AuthError` + `HttpError` |

API error sets compose via `||` (error set union). No function uses `anyerror`.

---

## Allocation & Lifetime Summary

| Allocator | Created By | Lifetime | Used For |
|-----------|-----------|----------|----------|
| GPA | `main.zig` | Process lifetime | Backing allocator for arena; config persistence |
| ArenaAllocator | `cmd/root.zig` | Single command invocation | All API calls, JSON parsing, string formatting |
| FixedBufferAllocator (stack) | `output.zig` functions | Function scope | Line formatting buffers |

**Key rules:**
- `cmd/root.zig` creates `var arena = std.heap.ArenaAllocator.init(gpa)` and calls `defer arena.deinit()`
- All `api/*.zig` functions receive the arena allocator and use `parseFromSliceLeaky` (no individual free needed)
- `http.zig` functions allocate response body via the arena; caller does not free individually
- `config.zig` `save()` receives GPA because it may outlive a single command (config is written then the arena is destroyed)

---

## JSON Field Mapping

Zig 0.15.2 `std.json.ParseOptions` does NOT support automatic `snake_case`-to-`camelCase` renaming. Struct field names must match the JSON keys exactly. Therefore, all model struct fields use `camelCase` to match Zoho API JSON responses directly.

The model structs above use `camelCase` field names. Here is the corrected mapping (Zig field name = JSON key):

| Zig field | JSON key |
|-----------|----------|
| `accountId` | `accountId` |
| `messageId` | `messageId` |
| `folderId` | `folderId` |
| `toAddress` | `toAddress` |
| `receivedTime` | `receivedTime` |
| `isRead` | `isRead` |
| `folderName` | `folderName` |
| `labelName` | `labelName` |
| `emailAddress` | `emailAddress` |

All model types parse via `std.json.parseFromSliceLeaky(T, arena, body, .{ .ignore_unknown_fields = true })`.
Unknown fields are ignored to tolerate API additions without breaking the client.

---

## File Size Budget

Each file is budgeted to stay under 200 lines:

| File | Estimated Lines |
|------|----------------|
| `src/main.zig` | ~30 |
| `src/config.zig` | ~120 |
| `src/auth.zig` | ~150 |
| `src/output.zig` | ~180 |
| `src/http.zig` | ~160 |
| `src/cmd/root.zig` | ~130 |
| `src/cmd/auth.zig` | ~120 |
| `src/cmd/account.zig` | ~100 |
| `src/cmd/mail.zig` | ~180 |
| `src/cmd/mail_update.zig` | ~130 |
| `src/cmd/folder.zig` | ~110 |
| `src/cmd/label.zig` | ~110 |
| `src/cmd/task.zig` | ~140 |
| `src/cmd/org.zig` | ~110 |
| `src/api/accounts.zig` | ~80 |
| `src/api/messages.zig` | ~160 |
| `src/api/folders.zig` | ~130 |
| `src/api/labels.zig` | ~110 |
| `src/api/tasks.zig` | ~140 |
| `src/api/org.zig` | ~100 |
| `src/model/common.zig` | ~65 |
| `src/model/account.zig` | ~25 |
| `src/model/message.zig` | ~70 |
| `src/model/folder.zig` | ~30 |
| `src/model/label.zig` | ~25 |
| `src/model/task.zig` | ~35 |
| `src/model/org.zig` | ~45 |
| `build.zig` | ~40 |

Total: ~28 files, all under 200 lines.
