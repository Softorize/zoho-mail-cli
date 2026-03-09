# Zoho Mail API Reference

This document describes the Zoho Mail API endpoints used by the CLI, organized by resource type. It includes rate limits, error codes, response formats, and region-specific base URLs.

---

## Table of Contents

- [Base URLs and Regions](#base-urls-and-regions)
- [Authentication Headers](#authentication-headers)
- [Rate Limits](#rate-limits)
- [Response Format](#response-format)
- [Error Codes](#error-codes)
- [Endpoints by Resource](#endpoints-by-resource)
  - [Accounts](#accounts)
  - [Messages](#messages)
  - [Folders](#folders)
  - [Labels](#labels)
  - [Tasks](#tasks)
  - [Organization](#organization)
- [OAuth Token Endpoints](#oauth-token-endpoints)

---

## Base URLs and Regions

All API requests are sent to a region-specific base URL. The region is determined by where the user's Zoho account is hosted.

### Mail API Base URLs

| Region | Base URL | TLD |
|--------|----------|-----|
| United States | `https://mail.zoho.com/api/` | `.com` |
| Europe | `https://mail.zoho.eu/api/` | `.eu` |
| India | `https://mail.zoho.in/api/` | `.in` |
| Australia | `https://mail.zoho.com.au/api/` | `.com.au` |
| China | `https://mail.zoho.com.cn/api/` | `.com.cn` |
| Japan | `https://mail.zoho.jp/api/` | `.jp` |

### OAuth Base URLs

| Region | OAuth Base URL |
|--------|---------------|
| United States | `https://accounts.zoho.com/oauth/v2/` |
| Europe | `https://accounts.zoho.eu/oauth/v2/` |
| India | `https://accounts.zoho.in/oauth/v2/` |
| Australia | `https://accounts.zoho.com.au/oauth/v2/` |
| China | `https://accounts.zoho.com.cn/oauth/v2/` |
| Japan | `https://accounts.zoho.jp/oauth/v2/` |

---

## Authentication Headers

All API requests (except OAuth token exchange) include an authorization header:

```
Authorization: Zoho-oauthtoken {access_token}
```

The CLI constructs this header automatically using the stored access token. The `Zoho-oauthtoken` prefix is specific to Zoho's API and differs from the standard `Bearer` prefix.

---

## Rate Limits

Zoho Mail API enforces the following rate limits:

| Limit | Value |
|-------|-------|
| Requests per minute | **30** |
| Requests per day | Varies by plan |

### Rate Limit Behavior

- When the rate limit is exceeded, the API returns an HTTP 429 status code.
- The CLI does not currently implement automatic retry or backoff for rate-limited requests.
- For batch operations, space your requests to stay within the 30 requests/minute limit.

### Recommendations

- Use `--limit` to reduce the number of API calls when listing large datasets.
- For scripts, add delays between commands (at least 2 seconds per request).
- Monitor the response status codes for 429 errors.

---

## Response Format

All Zoho Mail API responses follow a standard JSON envelope structure:

### Successful Response

```json
{
  "status": {
    "code": 200,
    "description": "success"
  },
  "data": [ ... ]
}
```

### Paginated Response

```json
{
  "status": {
    "code": 200,
    "description": "success"
  },
  "data": [ ... ],
  "paging": {
    "total": 150,
    "hasMore": true,
    "start": 0,
    "limit": 50
  }
}
```

### Error Response

```json
{
  "status": {
    "code": 400,
    "description": "Invalid parameter"
  },
  "data": {
    "errorCode": "INVALID_INPUT",
    "moreInfo": "Detailed error message"
  }
}
```

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.code` | integer | Zoho-specific status code (not always the same as HTTP status) |
| `status.description` | string | Human-readable status message |
| `data` | array or object | Response payload. Array for list endpoints, object for single-item endpoints. |
| `paging.total` | integer | Total number of results available (may be null) |
| `paging.hasMore` | boolean | Whether additional pages of results exist |
| `paging.start` | integer | Starting index of the current page |
| `paging.limit` | integer | Number of results per page (default: 50) |

---

## Error Codes

### HTTP Status Codes

| Code | Meaning | Common Cause |
|------|---------|-------------|
| 200 | Success | Request completed successfully |
| 400 | Bad Request | Invalid parameters, malformed request body |
| 401 | Unauthorized | Invalid or expired access token |
| 403 | Forbidden | Insufficient scopes or permissions |
| 404 | Not Found | Resource does not exist (wrong ID) |
| 405 | Method Not Allowed | Wrong HTTP method for the endpoint |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Zoho server-side error |

### Zoho-Specific Error Codes

| Error Code | Description |
|------------|-------------|
| `INVALID_INPUT` | One or more request parameters are invalid |
| `RESOURCE_NOT_FOUND` | The requested resource (message, folder, etc.) does not exist |
| `PERMISSION_DENIED` | The authenticated user does not have access to this resource |
| `RATE_LIMIT_EXCEEDED` | Too many requests in the current time window |
| `INVALID_OAUTHTOKEN` | The access token is invalid or has expired |
| `SCOPE_MISMATCH` | The token does not have the required scope for this operation |

### CLI Error Mapping

The CLI maps API errors to internal error types:

| CLI Error | Cause |
|-----------|-------|
| `ApiRequestFailed` | API returned a non-success response |
| `ParseError` | Response JSON could not be parsed |
| `NotAuthenticated` | No valid access token available |
| `TokenRefreshFailed` | Refresh token exchange returned an error |
| `NetworkError` | Connection failed, timeout, or DNS error |
| `ConnectionFailed` | Could not establish TCP connection to Zoho servers |
| `Timeout` | HTTP request timed out |
| `Unauthorized` | Insufficient permissions for organization operations |

---

## Endpoints by Resource

### Accounts

Endpoints used by `zoho-mail account` commands.

| CLI Command | Method | Endpoint | Scope Required |
|-------------|--------|----------|----------------|
| `account list` | GET | `/api/accounts` | `ZohoMail.accounts.READ` |
| `account info <id>` | GET | `/api/accounts/{accountId}` | `ZohoMail.accounts.READ` |

**Note:** `account set-default` is a local-only operation and does not call any API endpoint.

#### GET /api/accounts

Returns all mail accounts for the authenticated user.

**Response data (array):**

| Field | Type | Description |
|-------|------|-------------|
| `accountId` | string | Unique account identifier |
| `displayName` | string | Account display name |
| `emailAddress` | string | Primary email address |
| `type` | string | Account type (e.g., `"premium"`, `"free"`) |
| `primary` | boolean | Whether this is the primary account |
| `incomingServer` | string | Incoming mail server hostname |
| `outgoingServer` | string | Outgoing mail server hostname |

---

### Messages

Endpoints used by `zoho-mail mail` commands.

| CLI Command | Method | Endpoint | Scope Required |
|-------------|--------|----------|----------------|
| `mail list` | GET | `/api/accounts/{accountId}/messages/view?folderId={fid}&start={s}&limit={l}` | `ZohoMail.messages.ALL` |
| `mail search` | GET | `/api/accounts/{accountId}/messages/search?searchKey={q}&start={s}&limit={l}` | `ZohoMail.messages.ALL` |
| `mail read` | GET | `/api/accounts/{accountId}/folders/{folderId}/messages/{messageId}/content` | `ZohoMail.messages.ALL` |
| `mail send` | POST | `/api/accounts/{accountId}/messages` | `ZohoMail.messages.ALL` |
| `mail delete` | DELETE | `/api/accounts/{accountId}/folders/{folderId}/messages/{messageId}` | `ZohoMail.messages.ALL` |
| `mail flag` | PUT | `/api/accounts/{accountId}/updatemessage` | `ZohoMail.messages.ALL` |
| `mail move` | PUT | `/api/accounts/{accountId}/updatemessage` | `ZohoMail.messages.ALL` |
| `mail mark-read` | PUT | `/api/accounts/{accountId}/updatemessage` | `ZohoMail.messages.ALL` |
| `mail mark-unread` | PUT | `/api/accounts/{accountId}/updatemessage` | `ZohoMail.messages.ALL` |
| `mail label` | PUT | `/api/accounts/{accountId}/updatemessage` | `ZohoMail.messages.ALL` |

#### GET /api/accounts/{accountId}/messages/view

List messages in a folder.

**Query parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `folderId` | string | Yes | Folder ID to list messages from |
| `start` | integer | No | Pagination offset (default: 0) |
| `limit` | integer | No | Max results per page (default: 20) |

**Response data (array of Message):**

| Field | Type | Description |
|-------|------|-------------|
| `messageId` | string | Unique message identifier |
| `folderId` | string | Containing folder ID |
| `subject` | string | Subject line |
| `sender` | string | Sender display address |
| `toAddress` | string | Comma-separated To recipients |
| `ccAddress` | string | Comma-separated CC recipients |
| `receivedTime` | integer | Received timestamp (epoch milliseconds) |
| `isRead` | boolean | Read/unread status |
| `isFlagged` | boolean | Flagged status |
| `summary` | string | Message snippet/preview |
| `hasAttachment` | boolean | Whether message has attachments |
| `status` | string | Message status code |

#### POST /api/accounts/{accountId}/messages

Send a new email message.

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fromAddress` | string | Yes | Sender email address |
| `toAddress` | string | Yes | Comma-separated recipients |
| `subject` | string | No | Subject line |
| `content` | string | No | Message body |
| `ccAddress` | string | No | CC recipients |
| `bccAddress` | string | No | BCC recipients |
| `mailFormat` | string | No | `"html"` (default) or `"plaintext"` |

#### PUT /api/accounts/{accountId}/updatemessage

Update message properties. Uses different `mode` values for different operations.

**Request body (JSON):**

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | Operation type (see below) |
| `messageId` | string | Target message ID |
| `destFolderId` | string | Destination folder (for `moveToFolder` mode) |
| `flagValue` | string | Flag value (for `flagMail` mode) |
| `labelId` | string | Label ID (for `addLabel` mode) |

**Mode values:**

| Mode | Description |
|------|-------------|
| `markAsRead` | Mark message as read |
| `markAsUnread` | Mark message as unread |
| `moveToFolder` | Move message to a different folder (requires `destFolderId`) |
| `flagMail` | Set/unset flag on message (requires `flagValue`) |
| `addLabel` | Apply a label to message (requires `labelId`) |

---

### Folders

Endpoints used by `zoho-mail folder` commands.

| CLI Command | Method | Endpoint | Scope Required |
|-------------|--------|----------|----------------|
| `folder list` | GET | `/api/accounts/{accountId}/folders` | `ZohoMail.folders.ALL` |
| `folder create` | POST | `/api/accounts/{accountId}/folders` | `ZohoMail.folders.ALL` |
| `folder rename` | PUT | `/api/accounts/{accountId}/folders/{folderId}` | `ZohoMail.folders.ALL` |
| `folder delete` | DELETE | `/api/accounts/{accountId}/folders/{folderId}` | `ZohoMail.folders.ALL` |

#### GET /api/accounts/{accountId}/folders

Returns all folders for an account.

**Response data (array of Folder):**

| Field | Type | Description |
|-------|------|-------------|
| `folderId` | string | Unique folder identifier |
| `folderName` | string | Display name |
| `parentFolderId` | string | Parent folder ID (empty for root) |
| `folderPath` | string | Full folder path |
| `unreadCount` | integer | Number of unread messages |
| `messageCount` | integer | Total number of messages |
| `folderType` | string | Folder type (system or custom) |

#### POST /api/accounts/{accountId}/folders

Create a new folder.

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `folderName` | string | Yes | New folder name |
| `parentFolderId` | string | No | Parent folder ID for nesting |

#### PUT /api/accounts/{accountId}/folders/{folderId}

Rename a folder.

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `folderName` | string | Yes | New folder name |

---

### Labels

Endpoints used by `zoho-mail label` commands.

| CLI Command | Method | Endpoint | Scope Required |
|-------------|--------|----------|----------------|
| `label list` | GET | `/api/accounts/{accountId}/labels` | `ZohoMail.labels.ALL` |
| `label create` | POST | `/api/accounts/{accountId}/labels` | `ZohoMail.labels.ALL` |
| `label rename` | PUT | `/api/accounts/{accountId}/labels/{labelId}` | `ZohoMail.labels.ALL` |
| `label delete` | DELETE | `/api/accounts/{accountId}/labels/{labelId}` | `ZohoMail.labels.ALL` |

#### GET /api/accounts/{accountId}/labels

Returns all labels for an account.

**Response data (array of Label):**

| Field | Type | Description |
|-------|------|-------------|
| `labelId` | string | Unique label identifier |
| `labelName` | string | Display name |
| `color` | string | Color hex code (e.g., `"#FF0000"`) |
| `messageCount` | integer | Number of messages with this label |

#### POST /api/accounts/{accountId}/labels

Create a new label.

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `labelName` | string | Yes | Label display name |
| `color` | string | Yes | Color hex code |

#### PUT /api/accounts/{accountId}/labels/{labelId}

Rename a label.

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `labelName` | string | Yes | New label name |

---

### Tasks

Endpoints used by `zoho-mail task` commands.

| CLI Command | Method | Endpoint | Scope Required |
|-------------|--------|----------|----------------|
| `task list` | GET | `/api/tasks/me` | `ZohoMail.tasks.ALL` |
| `task list --group <id>` | GET | `/api/tasks/groups/{groupId}` | `ZohoMail.tasks.ALL` |
| `task show <id>` | GET | `/api/tasks/me/{taskId}` | `ZohoMail.tasks.ALL` |
| `task create` | POST | `/api/tasks/me` | `ZohoMail.tasks.ALL` |
| `task update <id>` | PUT | `/api/tasks/me/{taskId}` | `ZohoMail.tasks.ALL` |
| `task delete <id>` | DELETE | `/api/tasks/me/{taskId}` | `ZohoMail.tasks.ALL` |

#### GET /api/tasks/me

Returns all personal tasks for the authenticated user.

**Response data (array of Task):**

| Field | Type | Description |
|-------|------|-------------|
| `taskId` | string | Unique task identifier |
| `title` | string | Task title |
| `notes` | string | Task description/notes |
| `dueDate` | integer | Due date (epoch milliseconds, 0 = none) |
| `priority` | integer | Priority: 1 (Low), 2 (Medium), 3 (High) |
| `percentage` | integer | Completion percentage (0-100) |
| `status` | string | Status: `"notstarted"`, `"inprogress"`, `"completed"` |
| `assignee` | string | Assignee email address |
| `groupId` | string | Group ID (for group tasks) |

#### POST /api/tasks/me

Create a new personal task.

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Task title |
| `notes` | string | No | Task description |
| `dueDate` | integer | No | Due date (epoch milliseconds) |
| `priority` | integer | No | Priority: 1, 2, or 3 (default: 2) |

#### PUT /api/tasks/me/{taskId}

Update an existing task. Only non-null fields are updated.

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | No | New title |
| `notes` | string | No | New notes |
| `status` | string | No | New status |
| `priority` | integer | No | New priority |

---

### Organization

Endpoints used by `zoho-mail org` commands. These require administrator privileges.

| CLI Command | Method | Endpoint | Scope Required |
|-------------|--------|----------|----------------|
| `org users` | GET | `/api/organization/{zoid}/users` | `ZohoMail.organization.ALL` |
| `org domains` | GET | `/api/organization/{zoid}/domains` | `ZohoMail.organization.ALL` |
| `org groups` | GET | `/api/organization/{zoid}/groups` | `ZohoMail.organization.ALL` |

#### GET /api/organization/{zoid}/users

Returns all users in the organization.

**Response data (array of User):**

| Field | Type | Description |
|-------|------|-------------|
| `zuid` | string | Zoho User ID |
| `emailAddress` | string | User email address |
| `displayName` | string | Display name |
| `accountStatus` | string | Status: `"active"`, `"suspended"` |
| `role` | string | Organization role |

#### GET /api/organization/{zoid}/domains

Returns all domains registered with the organization.

**Response data (array of Domain):**

| Field | Type | Description |
|-------|------|-------------|
| `domainName` | string | Domain name |
| `isVerified` | boolean | Whether the domain is verified |
| `mxStatus` | string | MX record configuration status |

#### GET /api/organization/{zoid}/groups

Returns all groups in the organization.

**Response data (array of Group):**

| Field | Type | Description |
|-------|------|-------------|
| `groupId` | string | Unique group identifier |
| `emailAddress` | string | Group email address |
| `groupName` | string | Group display name |
| `memberCount` | integer | Number of members |
| `description` | string | Group description |

---

## OAuth Token Endpoints

These endpoints are used during authentication and token refresh. They are not part of the Mail API proper but are essential for the OAuth flow.

### Authorization URL

```
GET https://accounts.zoho.{tld}/oauth/v2/auth
```

**Query parameters:**

| Parameter | Value |
|-----------|-------|
| `scope` | Comma-separated list of OAuth scopes |
| `client_id` | Your Client ID |
| `response_type` | `code` |
| `access_type` | `offline` (to receive a refresh token) |
| `redirect_uri` | `http://localhost` |

### Token Exchange

```
POST https://accounts.zoho.{tld}/oauth/v2/token
```

**Form parameters (for authorization code exchange):**

| Parameter | Description |
|-----------|-------------|
| `code` | The authorization code |
| `client_id` | Your Client ID |
| `client_secret` | Your Client Secret |
| `grant_type` | `authorization_code` |
| `redirect_uri` | `http://localhost` |

**Form parameters (for token refresh):**

| Parameter | Description |
|-----------|-------------|
| `refresh_token` | The stored refresh token |
| `client_id` | Your Client ID |
| `client_secret` | Your Client Secret |
| `grant_type` | `refresh_token` |

**Response:**

```json
{
  "access_token": "1000.xxxx....",
  "refresh_token": "1000.yyyy....",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

**Note:** The `refresh_token` is only returned during the initial authorization code exchange, not during token refresh.
