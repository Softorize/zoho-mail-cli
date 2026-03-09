# Configuration Reference

This document describes all configuration files, fields, and options used by the Zoho Mail CLI.

---

## Table of Contents

- [File Locations](#file-locations)
- [Config File Reference](#config-file-reference)
- [Tokens File Reference](#tokens-file-reference)
- [XDG_CONFIG_HOME Support](#xdg_config_home-support)
- [Example Configurations](#example-configurations)
- [Per-Region Configuration](#per-region-configuration)
- [Multiple Account Management](#multiple-account-management)
- [Global CLI Flags](#global-cli-flags)

---

## File Locations

The CLI uses two JSON files for persistent state:

| File | Default Path | Purpose |
|------|-------------|---------|
| Config | `~/.config/zoho-mail/config.json` | OAuth credentials, region, output preferences |
| Tokens | `~/.config/zoho-mail/tokens.json` | OAuth access and refresh tokens |

Both files are created automatically during `zoho-mail auth login`. The parent directory (`~/.config/zoho-mail/`) is created recursively if it does not exist.

---

## Config File Reference

**Path:** `~/.config/zoho-mail/config.json`

The config file stores persistent settings that do not change between commands. It is written during `auth login` and `account set-default`.

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `region` | string (enum) | `"com"` | Zoho datacenter region. Determines the base URL for all API requests. |
| `active_account_id` | string | `""` (empty) | The default account ID used when `--account` is not specified on the command line. Set via `account set-default`. |
| `client_id` | string | `""` (empty) | OAuth Client ID from the Zoho Developer Console. Set during `auth login`. |
| `client_secret` | string | `""` (empty) | OAuth Client Secret from the Zoho Developer Console. Set during `auth login`. |
| `output_format` | string (enum) | `"table"` | Default output format for commands that display data. |

### Region Values

The `region` field accepts the following values, each corresponding to a Zoho datacenter:

| Value | TLD | Datacenter Location | API Base URL |
|-------|-----|---------------------|-------------|
| `com` | `.com` | United States | `https://mail.zoho.com/api/` |
| `eu` | `.eu` | Europe | `https://mail.zoho.eu/api/` |
| `in` | `.in` | India | `https://mail.zoho.in/api/` |
| `com.au` | `.com.au` | Australia | `https://mail.zoho.com.au/api/` |
| `com.cn` | `.com.cn` | China | `https://mail.zoho.com.cn/api/` |
| `jp` | `.jp` | Japan | `https://mail.zoho.jp/api/` |

> **Note:** The Zig source uses `in_` internally (because `in` is a reserved keyword in Zig). In the config file and CLI flags, use `in` (without underscore).

### Output Format Values

The `output_format` field accepts:

| Value | Description |
|-------|-------------|
| `table` | Human-readable tabular output with column headers and separators. Default. |
| `json` | JSON output with 2-space indentation. Suitable for piping to `jq` or other tools. |
| `csv` | Comma-separated values. Suitable for import into spreadsheet applications. |

---

## Tokens File Reference

**Path:** `~/.config/zoho-mail/tokens.json`

The tokens file stores the current OAuth tokens. This file is managed entirely by the CLI and should not be edited manually.

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `access_token` | string | `""` | Current OAuth access token. Used in the `Authorization` header for API requests. |
| `refresh_token` | string | `""` | Long-lived refresh token. Used to obtain new access tokens when the current one expires. |
| `expires_at` | integer | `0` | Unix timestamp (seconds since epoch) when the access token expires. |
| `token_type` | string | `"Zoho-oauthtoken"` | Token type identifier. Always `"Zoho-oauthtoken"` for Zoho OAuth. |

### Token Lifecycle

- **Access tokens** expire after approximately 1 hour (3600 seconds).
- **Refresh tokens** do not expire under normal circumstances but can be revoked from the Zoho Developer Console.
- The CLI automatically refreshes expired access tokens before making API requests.

---

## XDG_CONFIG_HOME Support

The CLI respects the `XDG_CONFIG_HOME` environment variable for configuration directory placement, following the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html).

### Behavior

| Environment | Config Directory |
|-------------|-----------------|
| `XDG_CONFIG_HOME` not set | `~/.config/zoho-mail/` |
| `XDG_CONFIG_HOME=/custom/path` | `/custom/path/zoho-mail/` |

### Examples

```bash
# Default location
ls ~/.config/zoho-mail/config.json

# Custom XDG location
export XDG_CONFIG_HOME="$HOME/.local/config"
# Config will be at: ~/.local/config/zoho-mail/config.json

# One-off override
XDG_CONFIG_HOME=/tmp/test-config zoho-mail auth status
# Reads from: /tmp/test-config/zoho-mail/config.json
```

---

## Example Configurations

### Minimal Configuration (US Region)

```json
{
  "region": "com",
  "active_account_id": "",
  "client_id": "1000.ABC123DEF456GHI789",
  "client_secret": "xyz987wvu654tsr321",
  "output_format": "table"
}
```

### European Region with JSON Output

```json
{
  "region": "eu",
  "active_account_id": "1234567890",
  "client_id": "1000.EURO_CLIENT_ID_HERE",
  "client_secret": "euro_client_secret_here",
  "output_format": "json"
}
```

### India Region with Active Account

```json
{
  "region": "in",
  "active_account_id": "9876543210",
  "client_id": "1000.IN_CLIENT_ID_HERE",
  "client_secret": "in_client_secret_here",
  "output_format": "table"
}
```

### Corresponding Tokens File

```json
{
  "access_token": "1000.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy",
  "refresh_token": "1000.zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz.wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
  "expires_at": 1709910000,
  "token_type": "Zoho-oauthtoken"
}
```

---

## Per-Region Configuration

Zoho operates isolated datacenters in multiple regions. Your account exists in exactly one region, and all API requests must be directed to that region's endpoints.

### Determining Your Region

Your region is determined by the URL you use to access Zoho Mail in your browser:

| Login URL | Region Value |
|-----------|-------------|
| `mail.zoho.com` | `com` |
| `mail.zoho.eu` | `eu` |
| `mail.zoho.in` | `in` |
| `mail.zoho.com.au` | `com.au` |
| `mail.zoho.com.cn` | `com.cn` |
| `mail.zoho.jp` | `jp` |

### Setting the Region

There are three ways to configure the region, listed by precedence (highest first):

1. **Command-line flag** (per-invocation):
   ```bash
   zoho-mail --region eu mail list
   ```

2. **Config file** (persistent):
   Edit `~/.config/zoho-mail/config.json` and set `"region": "eu"`.

3. **Default value**: If neither is set, the region defaults to `com`.

### OAuth Endpoints Per Region

The OAuth token endpoint also varies by region:

| Region | OAuth Endpoint |
|--------|---------------|
| `com` | `https://accounts.zoho.com/oauth/v2/token` |
| `eu` | `https://accounts.zoho.eu/oauth/v2/token` |
| `in` | `https://accounts.zoho.in/oauth/v2/token` |
| `com.au` | `https://accounts.zoho.com.au/oauth/v2/token` |
| `com.cn` | `https://accounts.zoho.com.cn/oauth/v2/token` |
| `jp` | `https://accounts.zoho.jp/oauth/v2/token` |

---

## Multiple Account Management

A single Zoho user may have multiple mail accounts (e.g., personal and alias accounts). The CLI supports switching between them.

### Listing Accounts

```bash
zoho-mail account list
```

This returns all accounts associated with your Zoho credentials, including the account ID, email address, display name, and whether it is the primary account.

### Setting the Default Account

```bash
zoho-mail account set-default <account-id>
```

This writes the account ID to the `active_account_id` field in `config.json`. All subsequent commands will use this account by default.

### Per-Command Account Override

Use the `--account` global flag to override the default account for a single command:

```bash
zoho-mail --account 9876543210 mail list
```

### Resolution Order

The CLI resolves the active account ID using the following precedence:

1. `--account <id>` flag (highest priority)
2. `active_account_id` in `config.json`
3. Empty string (some commands may fail if no account is set)

---

## Global CLI Flags

These flags can be placed before any command and override the corresponding config file values for that invocation only.

| Flag | Value | Description |
|------|-------|-------------|
| `--format <fmt>` | `json`, `table`, `csv` | Override the output format. |
| `--region <region>` | `com`, `eu`, `in`, `com.au`, `com.cn`, `jp` | Override the Zoho datacenter region. |
| `--account <id>` | Account ID string | Override the active account ID. |
| `-h`, `--help` | (none) | Show the help message and exit. |
| `-v`, `--version` | (none) | Show the version number and exit. |

### Example

```bash
# List mail from the EU datacenter in JSON format, using a specific account
zoho-mail --region eu --format json --account 1234567890 mail list
```
