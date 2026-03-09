# zoho-mail

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zig](https://img.shields.io/badge/Zig-0.15.0+-f7a41d?logo=zig&logoColor=white)]()

A fast, native command-line interface for [Zoho Mail](https://www.zoho.com/mail/), built in Zig. Manage your email, folders, labels, tasks, and organization -- all from the terminal.

---

## Overview

`zoho-mail` is a zero-dependency CLI tool that wraps the Zoho Mail REST API into a set of composable subcommands. It authenticates via OAuth 2.0, supports all six Zoho datacenter regions, and outputs results as formatted tables, JSON, or CSV. Because it compiles to a single static binary, it runs anywhere with no runtime overhead.

## Features

- **Email management** -- list, search, read, send, delete, flag, move, and label messages
- **Folder management** -- list, create, rename, and delete mail folders
- **Label management** -- list, create, rename, and delete labels with custom colors
- **Task management** -- list, show, create, update, and delete tasks (personal and group)
- **Account management** -- list accounts, view details, set default account
- **Organization admin** -- list users, domains, and groups
- **OAuth 2.0 authentication** -- interactive login, token refresh, status check, logout
- **Multiple output formats** -- table (default), JSON, CSV
- **Multi-region support** -- US, EU, India, Australia, China, Japan datacenters
- **Multi-account support** -- switch between accounts with `--account` or `set-default`
- **Single binary** -- compiles to a static executable with zero runtime dependencies
- **XDG-compliant config** -- stores configuration in `~/.config/zoho-mail/`

---

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/download/) 0.15.0 or later
- A Zoho Mail account

### Build from Source

```bash
git clone https://github.com/your-username/zoho-mail.git
cd zoho-mail
zig build -Doptimize=ReleaseSafe
```

The binary is placed at `./zig-out/bin/zoho-mail`. You can copy it to a directory on your `$PATH`:

```bash
cp zig-out/bin/zoho-mail /usr/local/bin/
```

### Verify Installation

```bash
zoho-mail --version
# zoho-mail 0.1.0
```

---

## Authentication Setup

`zoho-mail` uses OAuth 2.0 with Zoho's Self Client flow. Follow these steps to authenticate.

### Step 1: Register a Self Client

1. Go to the [Zoho API Console](https://api-console.zoho.com/)
2. Click **Add Client** and select **Self Client**
3. Note the **Client ID** and **Client Secret**

### Step 2: Generate an Authorization Code

In the Self Client page of the API Console:

1. Under **Generate Code**, enter the following scopes (comma-separated):

```
ZohoMail.messages.ALL,ZohoMail.folders.ALL,ZohoMail.labels.ALL,ZohoMail.accounts.READ,ZohoMail.tasks.ALL,ZohoMail.organization.ALL
```

2. Set the **Time Duration** (e.g., 10 minutes)
3. Provide a **Scope Description** (e.g., "CLI access")
4. Click **Create** and copy the generated authorization code

### Step 3: Run the Login Command

```bash
zoho-mail auth login
```

You will be prompted for:

```
Enter client ID: 1000.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Enter client secret: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Open this URL in your browser:
https://accounts.zoho.com/oauth/v2/auth?scope=ZohoMail.messages.ALL,...

Enter authorization code: 1000.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

On success, the CLI stores your access and refresh tokens locally. Tokens are automatically refreshed as needed.

### Verify Authentication

```bash
zoho-mail auth status
# Authenticated (token valid).
```

---

## Configuration

### Config File Location

Configuration is stored in JSON format at:

```
~/.config/zoho-mail/config.json
```

If `$XDG_CONFIG_HOME` is set, the path is `$XDG_CONFIG_HOME/zoho-mail/config.json` instead.

Tokens are stored separately at:

```
~/.config/zoho-mail/tokens.json
```

### Config File Structure

```json
{
  "region": "com",
  "active_account_id": "1234567890",
  "client_id": "1000.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "client_secret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "output_format": "table"
}
```

| Field                | Description                         | Default   |
|----------------------|-------------------------------------|-----------|
| `region`             | Zoho datacenter region              | `com`     |
| `active_account_id`  | Default account for all operations  | (empty)   |
| `client_id`          | OAuth client ID                     | (empty)   |
| `client_secret`      | OAuth client secret                 | (empty)   |
| `output_format`      | Default output format               | `table`   |

### Environment Variables

| Variable            | Description                                         |
|---------------------|-----------------------------------------------------|
| `XDG_CONFIG_HOME`   | Override base config directory (default: `~/.config`) |
| `HOME`              | User home directory (used if `XDG_CONFIG_HOME` is unset) |

---

## Command Reference

### auth -- Authentication

Manage OAuth 2.0 authentication with Zoho.

#### `auth login`

Interactive OAuth login flow. Prompts for client credentials and authorization code.

```bash
zoho-mail auth login
```

#### `auth refresh`

Force a token refresh using the stored refresh token.

```bash
zoho-mail auth refresh
# Token refreshed successfully.
```

#### `auth status`

Check whether the current session is authenticated.

```bash
zoho-mail auth status
# Authenticated (token valid).
```

#### `auth logout`

Clear all stored tokens.

```bash
zoho-mail auth logout
# Logged out. Tokens cleared.
```

---

### account -- Account Management

Manage Zoho Mail accounts.

#### `account list`

List all accounts associated with the authenticated user.

```bash
zoho-mail account list
```

```
ID                    Email                           Name                  Primary
--------------------  ------------------------------  --------------------  --------
1234567890            user@example.com                John Doe              yes
9876543210            work@example.com                John Doe              no
```

#### `account info`

Show detailed information for a specific account.

```bash
zoho-mail account info 1234567890
```

```
Account Details
  ID: 1234567890
  Email: user@example.com
  Name: John Doe
  Type: personal
  Primary: yes
  Incoming: imappro.zoho.com
  Outgoing: smtp.zoho.com
```

#### `account set-default`

Set the default account for all subsequent operations.

```bash
zoho-mail account set-default 1234567890
# Default account updated.
```

---

### mail -- Email Operations

Send, list, search, read, and manage email messages.

#### `mail list`

List messages in a folder. Defaults to INBOX.

```bash
# List the latest 20 messages in INBOX
zoho-mail mail list

# List messages in a specific folder with pagination
zoho-mail mail list --folder INBOX --limit 50 --start 0
```

| Option      | Description                      | Default  |
|-------------|----------------------------------|----------|
| `--folder`  | Folder ID or name                | `INBOX`  |
| `--limit`   | Maximum number of messages       | `20`     |
| `--start`   | Pagination offset                | `0`      |

#### `mail search`

Search messages by keyword.

```bash
zoho-mail mail search --query "quarterly report"
```

| Option    | Description                | Required |
|-----------|----------------------------|----------|
| `--query` | Search keyword or phrase   | Yes      |

#### `mail read`

Read a single message by ID. Requires the folder ID.

```bash
zoho-mail mail read 17300000000000001 --folder INBOX
```

```
Message
  From: sender@example.com
  To: user@example.com
  Subject: Meeting Tomorrow
  Date: 2026-03-07 14:30:00

Content
Hello, just confirming our meeting tomorrow at 3 PM...
```

| Argument       | Description            | Required |
|----------------|------------------------|----------|
| `<message-id>` | The message ID         | Yes      |
| `--folder`     | Folder containing the message | Yes |

#### `mail send`

Send an email message.

```bash
zoho-mail mail send \
  --to "recipient@example.com" \
  --subject "Project Update" \
  --body "Please find the latest status report attached."
```

```bash
# With CC and BCC
zoho-mail mail send \
  --to "recipient@example.com" \
  --cc "manager@example.com" \
  --bcc "archive@example.com" \
  --subject "Weekly Summary" \
  --body "Here is this week's summary."
```

| Option      | Description                  | Required |
|-------------|------------------------------|----------|
| `--to`      | Recipient email address      | Yes      |
| `--subject` | Email subject line           | No       |
| `--body`    | Email body text              | No       |
| `--cc`      | CC recipient(s)              | No       |
| `--bcc`     | BCC recipient(s)             | No       |

#### `mail delete`

Delete a message by ID.

```bash
zoho-mail mail delete 17300000000000001 --folder INBOX
# Message deleted.
```

| Argument       | Description            | Required |
|----------------|------------------------|----------|
| `<message-id>` | The message ID         | Yes      |
| `--folder`     | Folder containing the message | Yes |

#### `mail flag`

Toggle the flag on a message.

```bash
zoho-mail mail flag 17300000000000001
# Message flagged.
```

#### `mail move`

Move a message to a different folder.

```bash
zoho-mail mail move 17300000000000001 --folder 17300000000000050
# Message moved.
```

| Argument       | Description                        | Required |
|----------------|------------------------------------|----------|
| `<message-id>` | The message ID                     | Yes      |
| `--folder`     | Destination folder ID              | Yes      |

#### `mail mark-read`

Mark a message as read.

```bash
zoho-mail mail mark-read 17300000000000001
# Message marked as read.
```

#### `mail mark-unread`

Mark a message as unread.

```bash
zoho-mail mail mark-unread 17300000000000001
# Message marked as unread.
```

#### `mail label`

Apply a label to a message.

```bash
zoho-mail mail label 17300000000000001 --label 17300000000000099
# Label applied.
```

| Argument       | Description            | Required |
|----------------|------------------------|----------|
| `<message-id>` | The message ID         | Yes      |
| `--label`      | Label ID to apply      | Yes      |

---

### folder -- Folder Management

Create, list, rename, and delete mail folders.

#### `folder list`

List all folders for the active account.

```bash
zoho-mail folder list
```

```
ID                  Name                  Path                       Unread    Total
------------------  --------------------  -------------------------  --------  --------
INBOX               Inbox                 /Inbox                     12        847
SENT                Sent                  /Sent                      0         234
DRAFTS              Drafts                /Drafts                    0         3
17300000000000050   Projects              /Projects                  5         42
```

#### `folder create`

Create a new folder.

```bash
# Create a top-level folder
zoho-mail folder create --name "Clients"

# Create a nested folder under an existing parent
zoho-mail folder create --name "Invoices" --parent 17300000000000050
```

| Option     | Description                    | Required |
|------------|--------------------------------|----------|
| `--name`   | Folder name                    | Yes      |
| `--parent` | Parent folder ID for nesting   | No       |

#### `folder rename`

Rename an existing folder.

```bash
zoho-mail folder rename 17300000000000050 --name "Active Projects"
# Folder renamed.
```

| Argument      | Description         | Required |
|---------------|---------------------|----------|
| `<folder-id>` | Folder ID to rename | Yes      |
| `--name`      | New folder name     | Yes      |

#### `folder delete`

Delete a folder by ID.

```bash
zoho-mail folder delete 17300000000000050
# Folder deleted.
```

---

### label -- Label Management

Create, list, rename, and delete message labels.

#### `label list`

List all labels for the active account.

```bash
zoho-mail label list
```

```
ID                  Name                  Color       Messages
------------------  --------------------  ----------  ----------
17300000000000099   Urgent                #ff0000     15
17300000000000100   Follow Up             #ff9900     8
17300000000000101   Personal              #3366ff     23
```

#### `label create`

Create a new label with a name and color.

```bash
zoho-mail label create --name "Review" --color "#9900ff"
# Label created.
```

| Option    | Description           | Required |
|-----------|-----------------------|----------|
| `--name`  | Label name            | Yes      |
| `--color` | Hex color code        | Yes      |

#### `label rename`

Rename an existing label.

```bash
zoho-mail label rename 17300000000000099 --name "Critical"
# Label renamed.
```

| Argument     | Description         | Required |
|--------------|---------------------|----------|
| `<label-id>` | Label ID to rename | Yes      |
| `--name`     | New label name      | Yes      |

#### `label delete`

Delete a label by ID.

```bash
zoho-mail label delete 17300000000000099
# Label deleted.
```

---

### task -- Task Management

Create, list, update, and manage tasks.

#### `task list`

List personal tasks, or tasks for a specific group.

```bash
# List personal tasks
zoho-mail task list

# List tasks for a group
zoho-mail task list --group 17300000000000200
```

```
ID                  Title                           Status        Priority
------------------  ------------------------------  ------------  ----------
17300000000000300   Review Q1 financials            open          High
17300000000000301   Update team wiki                in-progress   Medium
17300000000000302   Order office supplies            open          Low
```

| Option    | Description             | Required |
|-----------|-------------------------|----------|
| `--group` | Group ID to filter by   | No       |

#### `task show`

Display detailed information for a single task.

```bash
zoho-mail task show 17300000000000300
```

```
Task Details
  ID: 17300000000000300
  Title: Review Q1 financials
  Status: open
  Priority: High
  Notes: Need to review before Friday's board meeting
  Assignee: user@example.com
  Progress: 25%
```

#### `task create`

Create a new task.

```bash
zoho-mail task create \
  --title "Prepare presentation" \
  --notes "For the Q2 kickoff meeting" \
  --priority 3
# Task created.
```

| Option       | Description                              | Required | Default |
|--------------|------------------------------------------|----------|---------|
| `--title`    | Task title                               | Yes      | --      |
| `--notes`    | Task description / notes                 | No       | (empty) |
| `--priority` | Priority level: 1 (Low), 2 (Medium), 3 (High) | No | 2       |

#### `task update`

Update one or more fields on an existing task.

```bash
zoho-mail task update 17300000000000300 \
  --status completed \
  --priority 1

# Update just the title
zoho-mail task update 17300000000000300 --title "Review Q1 & Q2 financials"
# Task updated.
```

| Argument    | Description                       | Required |
|-------------|-----------------------------------|----------|
| `<task-id>` | Task ID to update                 | Yes      |
| `--title`   | New title                         | No       |
| `--status`  | New status (e.g., open, completed)| No       |
| `--priority`| New priority (1-3)                | No       |

#### `task delete`

Delete a task by ID.

```bash
zoho-mail task delete 17300000000000300
# Task deleted.
```

---

### org -- Organization Administration

Query organization-level resources. All subcommands require the `--zoid` (Zoho Organization ID) flag.

#### `org users`

List all users in the organization.

```bash
zoho-mail org users --zoid 70000000001
```

```
ZUID                Email                           Name                  Status      Role
------------------  ------------------------------  --------------------  ----------  ------------
80000000001         admin@company.com               Jane Admin            active      admin
80000000002         dev@company.com                 John Dev              active      member
```

#### `org domains`

List all domains registered to the organization.

```bash
zoho-mail org domains --zoid 70000000001
```

```
Domain                          Verified    MX Status
------------------------------  ----------  ------------
company.com                     yes         active
company.io                      yes         active
staging.company.com             no          pending
```

#### `org groups`

List all email groups in the organization.

```bash
zoho-mail org groups --zoid 70000000001
```

```
ID                  Email                           Name                  Members
------------------  ------------------------------  --------------------  ----------
90000000001         engineering@company.com         Engineering           12
90000000002         sales@company.com               Sales                 8
```

---

## Global Options

These options can be placed before any command and apply globally.

```bash
zoho-mail [global-options] <command> [subcommand] [options]
```

| Option                       | Description                                  |
|------------------------------|----------------------------------------------|
| `--format <json\|table\|csv>` | Override the output format for this invocation |
| `--account <id>`             | Override the active account for this invocation|
| `--region <region>`          | Override the Zoho datacenter region            |
| `-h`, `--help`               | Show help text                                |
| `-v`, `--version`            | Show version information                      |

### Examples

```bash
# Get folder list as JSON
zoho-mail --format json folder list

# Use a specific account for one command
zoho-mail --account 9876543210 mail list

# Query the EU datacenter
zoho-mail --region eu account list
```

---

## Supported Regions

Zoho operates independent datacenters in multiple regions. Set the region in your config file or override it per-command with `--region`.

| Region Code | Datacenter Location | API Domain              |
|-------------|---------------------|-------------------------|
| `com`       | United States       | `mail.zoho.com`         |
| `eu`        | Europe              | `mail.zoho.eu`          |
| `in`        | India               | `mail.zoho.in`          |
| `com.au`    | Australia           | `mail.zoho.com.au`      |
| `com.cn`    | China               | `mail.zoho.com.cn`      |
| `jp`        | Japan               | `mail.zoho.jp`          |

---

## Output Formats

### Table (default)

Human-readable, column-aligned output with headers.

```bash
zoho-mail mail list
```

```
ID                  Subject                                   From                       Date                  Read
------------------  ----------------------------------------  -------------------------  --------------------  -----
17300000000000001   Meeting Tomorrow                          sender@example.com         2026-03-07 14:30:00   yes
17300000000000002   Invoice #4521                             billing@vendor.com         2026-03-07 09:15:00   no
```

### JSON

Machine-readable JSON output, suitable for piping to `jq` or other tools.

```bash
zoho-mail --format json mail list
```

```json
[
  {
    "messageId": "17300000000000001",
    "subject": "Meeting Tomorrow",
    "sender": "sender@example.com",
    "receivedTime": 1741361400000,
    "isRead": true
  }
]
```

### CSV

Comma-separated values for spreadsheet import or data processing.

```bash
zoho-mail --format csv folder list
```

---

## Project Architecture

```
zoho-mail/
  build.zig            Build configuration
  build.zig.zon        Package manifest (Zig 0.15+)
  src/
    main.zig           Entry point, allocator setup
    config.zig          Config load/save (~/.config/zoho-mail/config.json)
    auth.zig            Token storage and refresh logic
    http.zig            HTTP client wrapper for Zoho API calls
    output.zig          Table, JSON, and CSV formatters; ANSI colors
    cmd/
      root.zig          Global flag parsing, command dispatch
      auth.zig          auth login|refresh|status|logout
      account.zig       account list|info|set-default
      mail.zig          mail list|search|read (+ dispatch to mail_send, mail_update)
      mail_send.zig     mail send|delete
      mail_update.zig   mail flag|move|mark-read|mark-unread|label
      folder.zig        folder list|create|rename|delete
      label.zig         label list|create|rename|delete
      task.zig          task list|show|create|update|delete
      org.zig           org users|domains|groups
    api/
      accounts.zig      Zoho Mail Accounts API client
      messages.zig      Zoho Mail Messages API client
      folders.zig       Zoho Mail Folders API client
      labels.zig        Zoho Mail Labels API client
      tasks.zig         Zoho Mail Tasks API client
      org.zig           Zoho Mail Organization API client
    model/
      common.zig        Region enum, ApiResponse generic, Pagination
      account.zig       Account data model
      message.zig       Message data model
      folder.zig        Folder data model
      label.zig         Label data model
      task.zig          Task data model
      org.zig           OrgUser, Domain, Group data models
```

The architecture follows a clean three-layer pattern:

- **cmd/** -- Command-line argument parsing and user interaction
- **api/** -- HTTP calls to the Zoho Mail REST API, response deserialization
- **model/** -- Data structures matching the Zoho API JSON schema

---

## Building and Testing

### Build

```bash
# Debug build (fast compilation, runtime safety checks)
zig build

# Release build (optimized)
zig build -Doptimize=ReleaseSafe

# Release build (smallest binary)
zig build -Doptimize=ReleaseSmall
```

### Run Directly

```bash
# Run without installing
zig build run -- mail list --folder INBOX --limit 10
```

### Run Tests

```bash
# Run all unit tests (main + models + libs)
zig build test
```

The test suite covers:

- All command modules via `src/main.zig` transitive reference
- Standalone model tests (`common.zig`, `account.zig`, `message.zig`, `folder.zig`, `label.zig`, `task.zig`, `org.zig`)
- Standalone library tests (`http.zig`, `config.zig`)

### Cross-Compilation

Zig supports cross-compilation out of the box:

```bash
# Linux x86_64
zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseSafe

# Linux ARM64 (e.g., Raspberry Pi 4)
zig build -Dtarget=aarch64-linux-gnu -Doptimize=ReleaseSafe

# Windows x86_64
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSafe
```

---

## Contributing

Contributions are welcome. To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes, ensuring all tests pass (`zig build test`)
4. Commit with a descriptive message
5. Open a pull request against `main`

### Guidelines

- Follow idiomatic Zig style
- Add tests for new functionality
- Keep command modules focused -- parsing in `cmd/`, HTTP in `api/`, data in `model/`
- Update this README if adding new commands or flags

---

## Rate Limits

The Zoho Mail API enforces rate limits per organization. Be aware of the following when scripting:

| Plan        | API Calls / Day | Calls / Minute |
|-------------|-----------------|----------------|
| Free        | 100             | 10             |
| Standard    | 1,000           | 20             |
| Professional| 2,000           | 30             |
| Enterprise  | 5,000           | 60             |

When rate-limited, the API returns HTTP 429. The CLI will report the error; retry after the limit window resets.

For the most current rate limit information, consult the [Zoho Mail API documentation](https://www.zoho.com/mail/help/api/).

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
