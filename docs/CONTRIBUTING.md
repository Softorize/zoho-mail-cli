# Contributing Guide

Thank you for your interest in contributing to the Zoho Mail CLI. This guide covers everything you need to set up a development environment, understand the codebase, and submit changes.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [Code Quality Rules](#code-quality-rules)
- [Testing](#testing)
- [How to Add a New Command](#how-to-add-a-new-command)
- [Pull Request Guidelines](#pull-request-guidelines)

---

## Prerequisites

- **Zig 0.15.x** -- The project requires Zig version 0.15.0 or later (currently developed with 0.15.2). Install from [ziglang.org/download](https://ziglang.org/download/).
- **Git** -- For version control.
- **A Zoho Mail account** -- Required only for manual/integration testing against the live API.

### Verify Your Setup

```bash
zig version
# Expected: 0.15.2 (or compatible 0.15.x)
```

---

## Getting Started

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd zoho-mail
   ```

2. Build the project:
   ```bash
   zig build
   ```

3. Run the CLI:
   ```bash
   zig build run -- --help
   ```

4. Run tests:
   ```bash
   zig build test
   ```

---

## Project Structure

```
zoho-mail/
  build.zig            Build configuration
  build.zig.zon        Package manifest (name, version, dependencies)
  ARCHITECTURE.md      Detailed architecture design document
  src/
    main.zig           Entry point: creates GPA, delegates to cmd/root.zig
    config.zig         Configuration loading/saving (config.json)
    auth.zig           OAuth token management (tokens.json)
    http.zig           HTTP client wrapper (GET, POST, PUT, DELETE)
    output.zig         Terminal output formatting (tables, JSON, colors)
    cmd/
      root.zig         Top-level argument parsing and command dispatch
      auth.zig         `auth` command (login, refresh, status, logout)
      account.zig      `account` command (list, info, set-default)
      mail.zig         `mail` command (list, search, read) + dispatch
      mail_send.zig    `mail send` and `mail delete` subcommands
      mail_update.zig  `mail flag|move|mark-read|mark-unread|label`
      folder.zig       `folder` command (list, create, rename, delete)
      label.zig        `label` command (list, create, rename, delete)
      task.zig         `task` command (list, show, create, update, delete)
      org.zig          `org` command (users, domains, groups)
    api/
      accounts.zig     Account API calls
      messages.zig     Message API calls (list, search, get, send, delete, update)
      folders.zig      Folder API calls (list, get, create, rename, delete)
      labels.zig       Label API calls (list, create, rename, delete)
      tasks.zig        Task API calls (list, get, create, update, delete)
      org.zig          Organization API calls (users, domains, groups)
    model/
      common.zig       Shared types: Region, ApiResponse, Pagination
      account.zig      Account data type
      message.zig      Message, SendRequest, SearchParams, UpdateParams
      folder.zig       Folder data type
      label.zig        Label data type
      task.zig         Task data type
      org.zig          User, Domain, Group data types
  docs/
    AUTHENTICATION.md  Authentication setup guide
    CONFIGURATION.md   Configuration reference
    COMMANDS.md        Full command reference
    API_REFERENCE.md   Zoho API endpoints reference
    CONTRIBUTING.md    This file
    CHANGELOG.md       Release history
```

---

## Architecture Overview

The codebase follows a strict layered architecture with clear dependency rules. See `ARCHITECTURE.md` for the full design document.

### Layer Diagram

```
cmd/* --> api/* --> model/*
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

### Key Principles

1. **cmd -> api -> model**: Command handlers call API functions, which return model types. Commands never construct HTTP requests directly.

2. **model has zero dependencies**: Model types are pure data structs with no imports from other project modules. They exist solely to define JSON-serializable data shapes.

3. **http.zig is API-agnostic**: The HTTP layer knows nothing about Zoho-specific endpoints or data structures. It provides generic `get`, `post`, `put`, `delete`, and `postForm` functions.

4. **auth.zig bridges config and http**: Authentication depends on `config.zig` (for client credentials) and `http.zig` (for token refresh), but nothing else depends on auth except `api/*`.

5. **output.zig has no side-effect dependencies**: Output formatting depends only on `model/*` types and the standard library.

### Allocator Ownership

```
main.zig        Creates GPA (GeneralPurposeAllocator)
  |
  v
cmd/root.zig    Creates ArenaAllocator(GPA) per command invocation
  |
  v
cmd/*.zig       Receives arena allocator as parameter
  |
  v
api/*.zig       Receives arena allocator as parameter
  |
  v
model/*.zig     Pure data types -- no allocations needed
```

**Rules:**
- The arena is created in `cmd/root.zig` and freed after the command returns.
- All API response parsing uses `parseFromSliceLeaky` with the arena allocator.
- No module stores an allocator in a file-scope `var`.

---

## Code Quality Rules

The following rules are enforced across the codebase:

### File Length

- **Maximum 200 lines per file.** If a file exceeds this limit, split it into logical submodules.
- Exception: test blocks at the end of a file are included in the count but are given slightly more leniency.

### Function Length

- **Maximum 50 lines per function.** If a function is longer, extract helper functions.
- This includes all code within the function body, excluding blank lines and comments.

### Documentation Comments

- **Every public function, type, and field must have a `///` doc comment.**
- Doc comments describe *what* and *why*, not *how*.
- Use imperative mood: "Return the config directory path" (not "Returns").

### Naming Conventions

- File names: `snake_case.zig`
- Types: `PascalCase` (e.g., `Config`, `Message`, `ApiResponse`)
- Functions: `camelCase` (e.g., `loadTokens`, `buildUrl`)
- Constants: `snake_case` or `camelCase` following Zig conventions
- Model field names: `camelCase` when matching Zoho API JSON keys; `snake_case` for CLI-internal structures (like `Config`)

### Error Handling

- Define domain-specific error sets (e.g., `ConfigError`, `AuthError`, `HttpError`).
- Compose error sets using `||` to combine with upstream errors (e.g., `MessageApiError = error{...} || auth.AuthError || http.HttpError`).
- Never use `catch unreachable` except in tests.
- Return meaningful errors rather than panicking.

### Imports

- Group imports: standard library first, then project modules.
- Use explicit imports (`@import("../auth.zig")`) rather than `@import("root")`.

### Testing

- Every file must have a `// Tests` section at the bottom.
- Tests should cover default values, parsing, and error variants at minimum.
- Tests must not depend on external state (no network calls, no file system side effects).

---

## Testing

### Running All Tests

```bash
zig build test
```

This runs:
- Integration tests via `src/main.zig` (discovers tests in `cmd/*`, `api/*`, and transitively imported modules).
- Standalone model tests for each file in `src/model/`.
- Standalone lib tests for `src/http.zig` and `src/config.zig`.

### Test Categories

| Category | Location | Description |
|----------|----------|-------------|
| Model tests | `src/model/*.zig` | Default values, JSON parsing, field validation |
| Config tests | `src/config.zig` | Path construction, default values |
| HTTP tests | `src/http.zig` | URL building, region coverage |
| Auth tests | `src/auth.zig` | Token defaults, error variants |
| Command tests | `src/cmd/*.zig` | Usage printing, argument parsing, helper functions |
| API tests | `src/api/*.zig` | Error set composition, body building |

### Writing Tests

Every test should:
1. Use `std.testing.allocator` (the testing allocator that detects leaks).
2. Be self-contained -- no dependencies on prior test state.
3. Clean up all allocations (use `defer allocator.free(...)` for allocated values).
4. Test one specific behavior per `test` block.

Example:

```zig
test "Region.tld returns correct strings" {
    try std.testing.expectEqualStrings("com", Region.com.tld());
    try std.testing.expectEqualStrings("in", Region.in_.tld());
    try std.testing.expectEqualStrings("com.au", Region.com_au.tld());
}
```

---

## How to Add a New Command

This section walks through adding a hypothetical `zoho-mail contact list` command.

### Step 1: Define the Model

Create `src/model/contact.zig`:

```zig
const std = @import("std");

/// Zoho Mail contact representation.
pub const Contact = struct {
    contactId: []const u8,
    firstName: []const u8 = "",
    lastName: []const u8 = "",
    emailAddress: []const u8 = "",
};

test "Contact default field values" {
    const c = Contact{ .contactId = "c1" };
    try std.testing.expectEqualStrings("c1", c.contactId);
    try std.testing.expectEqualStrings("", c.firstName);
}
```

### Step 2: Create the API Module

Create `src/api/contacts.zig`:

```zig
const std = @import("std");
const Contact = @import("../model/contact.zig").Contact;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

pub const ContactApiError = error{
    ApiRequestFailed,
    ParseError,
} || auth.AuthError || http.HttpError;

pub fn listContacts(
    allocator: std.mem.Allocator,
    config: Config,
    account_id: []const u8,
) ContactApiError![]const Contact {
    const path = std.fmt.allocPrint(
        allocator,
        "/api/accounts/{s}/contacts",
        .{account_id},
    ) catch return error.ApiRequestFailed;

    const token = auth.getAccessToken(allocator, config) catch
        return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch
        return error.ApiRequestFailed;

    const response = try http.get(allocator, url, token);

    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const Contact },
        allocator,
        response.body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;

    return parsed.data;
}
```

### Step 3: Create the Command Handler

Create `src/cmd/contact.zig`:

```zig
const std = @import("std");
const Config = @import("../config.zig").Config;
const root = @import("root.zig");
const output = @import("../output.zig");
const api = @import("../api/contacts.zig");

pub fn execute(
    allocator: std.mem.Allocator,
    cfg: Config,
    flags: root.GlobalFlags,
    args: *std.process.ArgIterator,
) root.CliError!void {
    const subcmd = args.next() orelse {
        printUsage();
        return;
    };
    if (std.mem.eql(u8, subcmd, "list")) {
        list(allocator, cfg, flags) catch return error.CommandFailed;
    } else {
        output.printError("unknown contact subcommand") catch {};
        return error.UnknownCommand;
    }
}

// ... list function, printUsage, tests
```

### Step 4: Register in Root

Edit `src/cmd/root.zig`:

1. Add the import: `const contact_cmd = @import("contact.zig");`
2. Add the dispatch branch in the `dispatch` function.
3. Update the help text.

### Step 5: Add Tests to build.zig

If the model file has standalone tests, add it to the `model_files` array in `build.zig`.

### Step 6: Update Documentation

- Add command documentation to `docs/COMMANDS.md`.
- Add API endpoint documentation to `docs/API_REFERENCE.md`.
- Update `docs/CHANGELOG.md`.

---

## Pull Request Guidelines

### Before Submitting

1. **Run all tests**: `zig build test` must pass with zero failures.
2. **Build successfully**: `zig build` must complete without errors or warnings.
3. **Follow code quality rules**: File length, function length, doc comments.
4. **Update documentation**: If you add, change, or remove commands or behavior.

### PR Format

- **Title**: Short, descriptive (under 70 characters). Use imperative mood ("Add contact command", not "Added contact command").
- **Description**: Explain *what* changed and *why*. Reference related issues if applicable.
- **One concern per PR**: Do not bundle unrelated changes.

### Review Checklist

Reviewers will check:

- [ ] Tests pass (`zig build test`)
- [ ] Build succeeds (`zig build`)
- [ ] New public items have doc comments
- [ ] Files are under 200 lines
- [ ] Functions are under 50 lines
- [ ] Error handling follows project conventions
- [ ] No file-scope mutable state
- [ ] Arena allocator is used correctly (no leaks in non-arena paths)
- [ ] Model types have JSON parsing tests
- [ ] Documentation is updated if behavior changed

### Commit Messages

- Use imperative mood: "Add folder rename command" (not "Added").
- First line: 50 characters or less.
- If needed, add a blank line followed by a longer description.
- Reference issues where applicable: "Fix #42: handle expired tokens gracefully".
