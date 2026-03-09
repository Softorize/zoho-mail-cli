# Changelog

All notable changes to the Zoho Mail CLI are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-03-08

Initial release of the Zoho Mail CLI.

### Added

#### Authentication
- Interactive OAuth 2.0 login flow via `auth login` with Self Client application support.
- Automatic access token refresh when tokens expire.
- Manual token refresh via `auth refresh`.
- Authentication status check via `auth status`.
- Logout and token cleanup via `auth logout`.
- Support for all six Zoho datacenter regions: US (`com`), EU (`eu`), India (`in`), Australia (`com.au`), China (`com.cn`), Japan (`jp`).

#### Account Management
- List all accounts with `account list`.
- View detailed account information with `account info <id>`.
- Set default active account with `account set-default <id>`.

#### Email Operations
- List messages in a folder with `mail list` (supports `--folder`, `--limit`, `--start` pagination).
- Search messages with `mail search --query <term>`.
- Read full message content with `mail read <id> --folder <fid>`.
- Send email with `mail send --to <addr> --subject <subj>` (supports `--body`, `--cc`, `--bcc`).
- Delete messages with `mail delete <id> --folder <fid>`.
- Flag messages with `mail flag <id>`.
- Move messages between folders with `mail move <id> --folder <dest>`.
- Mark messages as read/unread with `mail mark-read <id>` and `mail mark-unread <id>`.
- Apply labels to messages with `mail label <id> --label <lid>`.

#### Folder Management
- List all folders with `folder list`.
- Create folders with `folder create --name <name>` (supports `--parent` for nesting).
- Rename folders with `folder rename <id> --name <new-name>`.
- Delete folders with `folder delete <id>`.

#### Label Management
- List all labels with `label list`.
- Create labels with `label create --name <name> --color <hex>`.
- Rename labels with `label rename <id> --name <new-name>`.
- Delete labels with `label delete <id>`.

#### Task Management
- List personal tasks with `task list`.
- List group tasks with `task list --group <gid>`.
- View task details with `task show <id>`.
- Create tasks with `task create --title <title>` (supports `--notes`, `--priority`).
- Update tasks with `task update <id>` (supports `--title`, `--status`, `--priority`).
- Delete tasks with `task delete <id>`.

#### Organization Administration
- List organization users with `org users --zoid <zoid>`.
- List organization domains with `org domains --zoid <zoid>`.
- List organization groups with `org groups --zoid <zoid>`.

#### Output and Configuration
- Three output formats: `table` (default), `json`, `csv`.
- Global `--format` flag to override output format per invocation.
- Global `--region` flag to override datacenter region per invocation.
- Global `--account` flag to override active account per invocation.
- Persistent configuration via `~/.config/zoho-mail/config.json`.
- XDG_CONFIG_HOME support for custom configuration directory.
- Colored terminal output (green for success, red for errors, yellow for warnings).

#### Developer Experience
- Comprehensive unit tests across all modules.
- Standalone test targets for model and library files in `build.zig`.
- Clean layered architecture: `cmd -> api -> model`.
- Arena allocator pattern for zero-leak command execution.
- Full architecture design document (`ARCHITECTURE.md`).
