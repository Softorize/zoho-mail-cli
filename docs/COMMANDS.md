# Command Reference

Complete reference for every command and subcommand in the Zoho Mail CLI.

---

## Table of Contents

- [Global Options](#global-options)
- [auth -- Authentication Management](#auth----authentication-management)
- [account -- Account Management](#account----account-management)
- [mail -- Email Operations](#mail----email-operations)
- [folder -- Folder Management](#folder----folder-management)
- [label -- Label Management](#label----label-management)
- [task -- Task Management](#task----task-management)
- [org -- Organization Administration](#org----organization-administration)

---

## Global Options

These options can be placed before any command.

```
zoho-mail [options] <command> [subcommand] [args]
```

| Option | Description |
|--------|-------------|
| `--format <json\|table\|csv>` | Override default output format |
| `--account <id>` | Override active account ID |
| `--region <region>` | Override Zoho datacenter region (`com`, `eu`, `in`, `com.au`, `com.cn`, `jp`) |
| `-h`, `--help` | Show top-level help |
| `-v`, `--version` | Show version number |

---

## auth -- Authentication Management

Manage OAuth authentication, tokens, and sessions.

```
zoho-mail auth <subcommand>
```

### auth login

Authenticate with Zoho interactively. Prompts for Client ID, Client Secret, and authorization code.

**Synopsis:**
```
zoho-mail auth login
```

**Description:**
Starts an interactive OAuth login flow. The command stores your Client ID and Client Secret in the config file, generates an authorization URL, and exchanges the resulting authorization code for access and refresh tokens.

**Options:** None (interactive prompts).

**Examples:**
```bash
# Standard login
zoho-mail auth login

# Login with EU region
zoho-mail --region eu auth login
```

**Notes:**
- The authorization code generated during this flow is single-use and expires within minutes.
- Running `auth login` again will overwrite existing credentials and tokens.
- Client ID and Client Secret are persisted to `config.json`; tokens to `tokens.json`.

---

### auth refresh

Force an immediate token refresh.

**Synopsis:**
```
zoho-mail auth refresh
```

**Description:**
Uses the stored refresh token to obtain a new access token from Zoho, regardless of whether the current token has expired. The new token is saved to disk.

**Options:** None.

**Examples:**
```bash
# Force refresh
zoho-mail auth refresh
```

**Notes:**
- Requires a prior successful `auth login` (a refresh token must exist).
- Useful before batch operations to ensure a fresh token.

---

### auth status

Show current authentication status.

**Synopsis:**
```
zoho-mail auth status
```

**Description:**
Checks whether a valid, non-expired access token exists locally. Reports "Authenticated" or "Not authenticated" accordingly.

**Options:** None.

**Examples:**
```bash
zoho-mail auth status
# Output: "Authenticated (token valid)."
# or:     "Not authenticated or token expired."
```

**Notes:**
- This is a local check only. It does not validate the token against Zoho's servers.
- An "Authenticated" status does not guarantee the token has not been revoked server-side.

---

### auth logout

Clear stored tokens and log out.

**Synopsis:**
```
zoho-mail auth logout
```

**Description:**
Deletes the `tokens.json` file, removing the stored access and refresh tokens. Does not revoke the tokens on Zoho's servers. Does not remove the Client ID or Client Secret from `config.json`.

**Options:** None.

**Examples:**
```bash
zoho-mail auth logout
# Output: "Logged out. Tokens cleared."
```

**Notes:**
- To fully remove credentials, manually delete `~/.config/zoho-mail/config.json` after logout.

---

## account -- Account Management

List, inspect, and manage Zoho Mail accounts.

```
zoho-mail account <subcommand>
```

### account list

List all accounts associated with the authenticated user.

**Synopsis:**
```
zoho-mail account list
```

**Description:**
Fetches and displays all mail accounts linked to your Zoho credentials. Output includes account ID, email address, display name, and primary status.

**Options:** Supports [global options](#global-options).

**Examples:**
```bash
# Table output (default)
zoho-mail account list

# JSON output
zoho-mail --format json account list
```

**Output columns:** ID, Email, Name, Primary.

---

### account info

Show detailed information for a specific account.

**Synopsis:**
```
zoho-mail account info <account-id>
```

**Description:**
Fetches full details for a single account, including server configuration.

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<account-id>` | Yes | The account ID to inspect |

**Examples:**
```bash
zoho-mail account info 1234567890

# JSON output
zoho-mail --format json account info 1234567890
```

**Output fields:** ID, Email, Name, Type, Primary, Incoming (server), Outgoing (server).

---

### account set-default

Set the default active account for all subsequent commands.

**Synopsis:**
```
zoho-mail account set-default <account-id>
```

**Description:**
Writes the specified account ID to the `active_account_id` field in `config.json`. This account will be used by default for all commands that require an account ID.

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<account-id>` | Yes | The account ID to set as default |

**Examples:**
```bash
# Set default account
zoho-mail account set-default 1234567890

# Verify by listing accounts
zoho-mail account list
```

**Notes:**
- The account ID is not validated against Zoho. Ensure the ID is correct.
- You can always override the default with `--account <id>`.

---

## mail -- Email Operations

Send, list, search, read, delete, and update email messages.

```
zoho-mail mail <subcommand> [options]
```

### mail list

List messages in a folder.

**Synopsis:**
```
zoho-mail mail list [--folder <id>] [--limit <n>] [--start <n>]
```

**Description:**
Lists email messages in the specified folder. Defaults to the INBOX folder.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--folder <id>` | `INBOX` | Folder ID or name to list messages from |
| `--limit <n>` | `20` | Maximum number of messages to return |
| `--start <n>` | `0` | Pagination offset (0-indexed) |

**Examples:**
```bash
# List latest 20 messages in INBOX
zoho-mail mail list

# List 50 messages from a specific folder
zoho-mail mail list --folder 1234567890 --limit 50

# Paginate: get messages 20-39
zoho-mail mail list --start 20 --limit 20
```

**Output columns:** ID, Subject, From, Date, Read.

---

### mail search

Search messages by query string.

**Synopsis:**
```
zoho-mail mail search --query <search-key>
```

**Description:**
Searches for messages matching the given query string. The query syntax follows Zoho Mail's search format (supports sender, subject, content, and date-based searches).

**Options:**

| Option | Required | Description |
|--------|----------|-------------|
| `--query <search-key>` | Yes | Search query string |

**Examples:**
```bash
# Search by keyword
zoho-mail mail search --query "quarterly report"

# Search by sender
zoho-mail mail search --query "from:boss@company.com"

# Search with JSON output
zoho-mail --format json mail search --query "invoice"
```

**Notes:**
- The `--query` option is required. The command will error without it.

---

### mail read

Read a single message's full content.

**Synopsis:**
```
zoho-mail mail read <message-id> --folder <folder-id>
```

**Description:**
Fetches and displays the full content of a single email message, including headers (From, To, Subject, Date) and body text.

**Options:**

| Argument/Option | Required | Description |
|-----------------|----------|-------------|
| `<message-id>` | Yes | The message ID to read |
| `--folder <folder-id>` | Yes | The folder containing the message |

**Examples:**
```bash
# Read a specific message
zoho-mail mail read 17000000001 --folder INBOX

# Read with JSON output (includes all fields)
zoho-mail --format json mail read 17000000001 --folder INBOX
```

**Notes:**
- Both `<message-id>` and `--folder` are required.
- In table mode, the message is displayed with formatted headers followed by the content body.

---

### mail send

Send an email message.

**Synopsis:**
```
zoho-mail mail send --to <address> --subject <subject> [--body <body>] [--cc <addresses>] [--bcc <addresses>]
```

**Description:**
Composes and sends an email message from the active account.

**Options:**

| Option | Required | Description |
|--------|----------|-------------|
| `--to <address>` | Yes | Recipient email address (comma-separated for multiple) |
| `--subject <subject>` | No | Email subject line |
| `--body <body>` | No | Email body content (HTML format by default) |
| `--cc <addresses>` | No | CC recipients (comma-separated) |
| `--bcc <addresses>` | No | BCC recipients (comma-separated) |

**Examples:**
```bash
# Simple email
zoho-mail mail send --to "user@example.com" --subject "Hello" --body "Hi there!"

# Email with CC and BCC
zoho-mail mail send \
  --to "user@example.com" \
  --subject "Meeting Notes" \
  --body "Please see attached." \
  --cc "manager@example.com" \
  --bcc "archive@example.com"

# Minimal email (subject and body optional)
zoho-mail mail send --to "user@example.com"
```

**Notes:**
- The sender address (`fromAddress`) is automatically set to the active account ID.
- The default mail format is HTML.

---

### mail delete

Delete a message by ID.

**Synopsis:**
```
zoho-mail mail delete <message-id> --folder <folder-id>
```

**Description:**
Permanently deletes a message from the specified folder.

**Options:**

| Argument/Option | Required | Description |
|-----------------|----------|-------------|
| `<message-id>` | Yes | The message ID to delete |
| `--folder <folder-id>` | Yes | The folder containing the message |

**Examples:**
```bash
# Delete a specific message
zoho-mail mail delete 17000000001 --folder INBOX

# Delete from a custom folder
zoho-mail mail delete 17000000002 --folder 9876543210
```

**Notes:**
- This operation is irreversible. The message is permanently removed.

---

### mail flag

Toggle the flag on a message.

**Synopsis:**
```
zoho-mail mail flag <message-id>
```

**Description:**
Sets the flagged status on a message.

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<message-id>` | Yes | The message ID to flag |

**Examples:**
```bash
zoho-mail mail flag 17000000001
```

---

### mail move

Move a message to a different folder.

**Synopsis:**
```
zoho-mail mail move <message-id> --folder <dest-folder-id>
```

**Description:**
Moves a message from its current folder to the specified destination folder.

**Options:**

| Argument/Option | Required | Description |
|-----------------|----------|-------------|
| `<message-id>` | Yes | The message ID to move |
| `--folder <dest-folder-id>` | Yes | Destination folder ID |

**Examples:**
```bash
# Move to archive folder
zoho-mail mail move 17000000001 --folder 5555555555

# Move to trash
zoho-mail mail move 17000000001 --folder TRASH
```

---

### mail mark-read

Mark a message as read.

**Synopsis:**
```
zoho-mail mail mark-read <message-id>
```

**Description:**
Updates the read status of a message to "read".

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<message-id>` | Yes | The message ID to mark as read |

**Examples:**
```bash
zoho-mail mail mark-read 17000000001
```

---

### mail mark-unread

Mark a message as unread.

**Synopsis:**
```
zoho-mail mail mark-unread <message-id>
```

**Description:**
Updates the read status of a message to "unread".

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<message-id>` | Yes | The message ID to mark as unread |

**Examples:**
```bash
zoho-mail mail mark-unread 17000000001
```

---

### mail label

Apply a label to a message.

**Synopsis:**
```
zoho-mail mail label <message-id> --label <label-id>
```

**Description:**
Adds the specified label to a message.

**Options:**

| Argument/Option | Required | Description |
|-----------------|----------|-------------|
| `<message-id>` | Yes | The message ID to label |
| `--label <label-id>` | Yes | The label ID to apply |

**Examples:**
```bash
# Apply a label to a message
zoho-mail mail label 17000000001 --label 8888888888
```

**Notes:**
- Use `zoho-mail label list` to find available label IDs.

---

## folder -- Folder Management

Create, list, rename, and delete mail folders.

```
zoho-mail folder <subcommand> [options]
```

### folder list

List all folders for the active account.

**Synopsis:**
```
zoho-mail folder list
```

**Description:**
Fetches and displays all mail folders, including system folders (Inbox, Sent, Drafts, etc.) and custom folders.

**Options:** Supports [global options](#global-options).

**Examples:**
```bash
# Table output
zoho-mail folder list

# JSON output
zoho-mail --format json folder list
```

**Output columns:** ID, Name, Path, Unread, Total.

---

### folder create

Create a new folder.

**Synopsis:**
```
zoho-mail folder create --name <name> [--parent <parent-folder-id>]
```

**Description:**
Creates a new mail folder with the specified name. Optionally specify a parent folder to create a nested folder.

**Options:**

| Option | Required | Description |
|--------|----------|-------------|
| `--name <name>` | Yes | Folder name |
| `--parent <id>` | No | Parent folder ID for nesting |

**Examples:**
```bash
# Create a top-level folder
zoho-mail folder create --name "Projects"

# Create a nested folder
zoho-mail folder create --name "Q1 Reports" --parent 1234567890
```

---

### folder rename

Rename an existing folder.

**Synopsis:**
```
zoho-mail folder rename <folder-id> --name <new-name>
```

**Description:**
Renames a folder to the specified new name.

**Options:**

| Argument/Option | Required | Description |
|-----------------|----------|-------------|
| `<folder-id>` | Yes | The folder ID to rename |
| `--name <new-name>` | Yes | New folder name |

**Examples:**
```bash
zoho-mail folder rename 1234567890 --name "Archived Projects"
```

---

### folder delete

Delete a folder by ID.

**Synopsis:**
```
zoho-mail folder delete <folder-id>
```

**Description:**
Permanently deletes a folder and its contents.

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<folder-id>` | Yes | The folder ID to delete |

**Examples:**
```bash
zoho-mail folder delete 1234567890
```

**Notes:**
- This operation is irreversible. All messages in the folder may be lost.
- System folders (Inbox, Sent, etc.) cannot be deleted.

---

## label -- Label Management

Create, list, rename, and delete message labels.

```
zoho-mail label <subcommand> [options]
```

### label list

List all labels for the active account.

**Synopsis:**
```
zoho-mail label list
```

**Description:**
Fetches and displays all labels, including their color and message count.

**Options:** Supports [global options](#global-options).

**Examples:**
```bash
zoho-mail label list

zoho-mail --format json label list
```

**Output columns:** ID, Name, Color, Messages.

---

### label create

Create a new label.

**Synopsis:**
```
zoho-mail label create --name <name> --color <hex-color>
```

**Description:**
Creates a new label with the specified name and color.

**Options:**

| Option | Required | Description |
|--------|----------|-------------|
| `--name <name>` | Yes | Label display name |
| `--color <hex>` | Yes | Color hex code (e.g., `#FF0000`) |

**Examples:**
```bash
# Create a red "Urgent" label
zoho-mail label create --name "Urgent" --color "#FF0000"

# Create a blue "Review" label
zoho-mail label create --name "Review" --color "#0066CC"
```

---

### label rename

Rename an existing label.

**Synopsis:**
```
zoho-mail label rename <label-id> --name <new-name>
```

**Description:**
Renames a label to the specified new name.

**Options:**

| Argument/Option | Required | Description |
|-----------------|----------|-------------|
| `<label-id>` | Yes | The label ID to rename |
| `--name <new-name>` | Yes | New label name |

**Examples:**
```bash
zoho-mail label rename 8888888888 --name "Critical"
```

---

### label delete

Delete a label by ID.

**Synopsis:**
```
zoho-mail label delete <label-id>
```

**Description:**
Permanently deletes a label. Messages that had this label applied will no longer have it, but the messages themselves are not deleted.

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<label-id>` | Yes | The label ID to delete |

**Examples:**
```bash
zoho-mail label delete 8888888888
```

---

## task -- Task Management

Create, list, view, update, and delete tasks in Zoho Mail.

```
zoho-mail task <subcommand> [options]
```

### task list

List tasks.

**Synopsis:**
```
zoho-mail task list [--group <group-id>]
```

**Description:**
Lists personal tasks by default, or group tasks if `--group` is specified.

**Options:**

| Option | Required | Description |
|--------|----------|-------------|
| `--group <group-id>` | No | List tasks for a specific group instead of personal tasks |

**Examples:**
```bash
# List personal tasks
zoho-mail task list

# List group tasks
zoho-mail task list --group 5555555555

# JSON output
zoho-mail --format json task list
```

**Output columns:** ID, Title, Status, Priority.

**Priority values:** Low (1), Medium (2), High (3).

---

### task show

Show detailed information for a specific task.

**Synopsis:**
```
zoho-mail task show <task-id>
```

**Description:**
Fetches and displays full details for a single task, including notes, assignee, and completion percentage.

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<task-id>` | Yes | The task ID to display |

**Examples:**
```bash
zoho-mail task show 7777777777

zoho-mail --format json task show 7777777777
```

**Output fields:** ID, Title, Status, Priority, Notes, Assignee, Progress.

---

### task create

Create a new task.

**Synopsis:**
```
zoho-mail task create --title <title> [--notes <notes>] [--priority <1-3>]
```

**Description:**
Creates a new personal task with the specified title and optional attributes.

**Options:**

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `--title <title>` | Yes | -- | Task title |
| `--notes <notes>` | No | `""` | Task description or notes |
| `--priority <n>` | No | `2` | Priority level: 1 (Low), 2 (Medium), 3 (High) |

**Examples:**
```bash
# Simple task
zoho-mail task create --title "Review pull request"

# Task with notes and priority
zoho-mail task create --title "Deploy v2.0" --notes "Coordinate with ops team" --priority 3

# Low priority task
zoho-mail task create --title "Update docs" --priority 1
```

---

### task update

Update an existing task's fields.

**Synopsis:**
```
zoho-mail task update <task-id> [--title <title>] [--status <status>] [--priority <1-3>]
```

**Description:**
Updates one or more fields on an existing task. Only the specified fields are changed; others remain unchanged.

**Options:**

| Argument/Option | Required | Description |
|-----------------|----------|-------------|
| `<task-id>` | Yes | The task ID to update |
| `--title <title>` | No | New task title |
| `--status <status>` | No | New status (`notstarted`, `inprogress`, `completed`) |
| `--priority <n>` | No | New priority: 1 (Low), 2 (Medium), 3 (High) |

**Examples:**
```bash
# Mark task as in progress
zoho-mail task update 7777777777 --status inprogress

# Update title and priority
zoho-mail task update 7777777777 --title "Deploy v2.1" --priority 3

# Mark task as completed
zoho-mail task update 7777777777 --status completed
```

---

### task delete

Delete a task by ID.

**Synopsis:**
```
zoho-mail task delete <task-id>
```

**Description:**
Permanently deletes a task.

**Options:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<task-id>` | Yes | The task ID to delete |

**Examples:**
```bash
zoho-mail task delete 7777777777
```

---

## org -- Organization Administration

Manage organization users, domains, and groups. Requires administrator privileges and the `ZohoMail.organization.ALL` scope.

```
zoho-mail org <subcommand> --zoid <zoid>
```

> **Note:** All `org` subcommands require the `--zoid` flag, which specifies the Zoho Organization ID.

### org users

List organization users.

**Synopsis:**
```
zoho-mail org users --zoid <zoid>
```

**Description:**
Lists all user accounts in the organization.

**Options:**

| Option | Required | Description |
|--------|----------|-------------|
| `--zoid <zoid>` | Yes | Zoho Organization ID |

**Examples:**
```bash
zoho-mail org users --zoid 12345

zoho-mail --format json org users --zoid 12345
```

**Output columns:** ZUID, Email, Name, Status, Role.

---

### org domains

List organization domains.

**Synopsis:**
```
zoho-mail org domains --zoid <zoid>
```

**Description:**
Lists all domains registered with the organization, including verification and MX status.

**Options:**

| Option | Required | Description |
|--------|----------|-------------|
| `--zoid <zoid>` | Yes | Zoho Organization ID |

**Examples:**
```bash
zoho-mail org domains --zoid 12345

zoho-mail --format json org domains --zoid 12345
```

**Output columns:** Domain, Verified, MX Status.

---

### org groups

List organization groups.

**Synopsis:**
```
zoho-mail org groups --zoid <zoid>
```

**Description:**
Lists all user groups in the organization, including member count.

**Options:**

| Option | Required | Description |
|--------|----------|-------------|
| `--zoid <zoid>` | Yes | Zoho Organization ID |

**Examples:**
```bash
zoho-mail org groups --zoid 12345

zoho-mail --format json org groups --zoid 12345
```

**Output columns:** ID, Email, Name, Members.
