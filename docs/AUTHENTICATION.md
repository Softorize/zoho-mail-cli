# Authentication Guide

This guide covers the complete OAuth 2.0 authentication setup for the Zoho Mail CLI, from registering your application to maintaining token validity.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Register a Self Client Application](#step-1-register-a-self-client-application)
- [Step 2: Understand Required OAuth Scopes](#step-2-understand-required-oauth-scopes)
- [Step 3: Generate an Authorization Code](#step-3-generate-an-authorization-code)
- [Step 4: Authenticate via the CLI](#step-4-authenticate-via-the-cli)
- [Token Refresh Behavior](#token-refresh-behavior)
- [Troubleshooting Common Auth Errors](#troubleshooting-common-auth-errors)
- [Security Best Practices](#security-best-practices)

---

## Prerequisites

Before you begin, ensure you have:

1. **A Zoho account** -- Any Zoho account (free or paid) with Zoho Mail enabled.
2. **Access to the Zoho Developer Console** -- Available at [https://accounts.zoho.com/developerconsole](https://accounts.zoho.com/developerconsole).
3. **The `zoho-mail` CLI installed** -- See the project README for build and installation instructions.
4. **Knowledge of your Zoho region** -- The region where your Zoho account is hosted (e.g., `com`, `eu`, `in`, `com.au`, `com.cn`, `jp`).

---

## Step 1: Register a Self Client Application

The CLI uses Zoho's OAuth 2.0 "Self Client" flow. This is the recommended approach for personal CLI tools that access your own account.

1. Navigate to the Zoho Developer Console:
   ```
   https://accounts.zoho.com/developerconsole
   ```

2. Click **"Add Client"** in the top-right corner.

3. Select **"Self Client"** from the client type options.

4. Zoho will generate your credentials immediately. Take note of:
   - **Client ID** -- A long alphanumeric string (e.g., `1000.XXXXXXXXXX...`).
   - **Client Secret** -- A secret string that must be kept confidential.

5. Store these credentials securely. You will need them during the CLI login process.

> **Important:** Do not share your Client Secret with anyone. If compromised, regenerate it immediately from the Developer Console.

---

## Step 2: Understand Required OAuth Scopes

The CLI requests the following OAuth scopes during authentication. Each scope controls access to a specific set of Zoho Mail API features.

| Scope | Access Level | Description |
|-------|-------------|-------------|
| `ZohoMail.messages.ALL` | Full | Read, send, search, delete, flag, move, and label email messages. Required for all `mail` commands. |
| `ZohoMail.folders.ALL` | Full | List, create, rename, and delete mail folders. Required for all `folder` commands. |
| `ZohoMail.labels.ALL` | Full | List, create, rename, and delete labels. Required for all `label` commands. |
| `ZohoMail.accounts.READ` | Read-only | List and view account details. Required for `account list`, `account info`, and `account set-default` commands. |
| `ZohoMail.tasks.ALL` | Full | List, create, update, and delete tasks. Required for all `task` commands. |
| `ZohoMail.organization.ALL` | Full | List organization users, domains, and groups. Required for all `org` commands. This scope is only needed if you are an organization administrator. |

### Scope Notes

- If you do not need organization admin features, you may omit `ZohoMail.organization.ALL` from the scope list when generating your authorization code manually (see Step 3 alternative flow below).
- The `accounts.READ` scope is read-only by design. The CLI only needs to read account information, not modify it.
- All `.ALL` scopes grant both read and write access for their respective resource type.

---

## Step 3: Generate an Authorization Code

There are two ways to generate an authorization code:

### Option A: Through the CLI (Recommended)

The `auth login` command generates the authorization URL for you with all required scopes pre-configured. Simply follow the interactive prompts (see Step 4).

### Option B: Through the Developer Console

If you need to customize scopes or prefer manual control:

1. Go to the **Zoho Developer Console**.
2. Find your Self Client application and click **"Generate Code"**.
3. In the **Scope** field, enter the scopes you need, separated by commas:
   ```
   ZohoMail.messages.ALL,ZohoMail.folders.ALL,ZohoMail.labels.ALL,ZohoMail.accounts.READ,ZohoMail.tasks.ALL,ZohoMail.organization.ALL
   ```
4. Set the **Time Duration** (the authorization code is valid for a limited time, typically 1-10 minutes).
5. Provide a **Scope Description** (e.g., "Zoho Mail CLI access").
6. Click **"Create"** to generate the authorization code.
7. Copy the generated code immediately -- it expires quickly.

---

## Step 4: Authenticate via the CLI

Run the interactive login command:

```bash
zoho-mail auth login
```

The CLI will prompt you for three pieces of information:

1. **Client ID** -- Enter the Client ID from Step 1.
2. **Client Secret** -- Enter the Client Secret from Step 1.
3. **Authorization Code** -- The CLI will display a URL. Open it in your browser, authorize the application, then enter the code from the redirect URL (or from the Developer Console if using Option B above).

### Complete Login Flow

```
$ zoho-mail auth login
Enter client ID: 1000.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Enter client secret: YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY

Open this URL in your browser:
https://accounts.zoho.com/oauth/v2/auth?scope=ZohoMail.messages.ALL,...&client_id=1000.XXX...&response_type=code&access_type=offline&redirect_uri=http://localhost

Enter authorization code: 1000.ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
Login successful!
```

### What Happens During Login

1. The CLI stores your Client ID and Client Secret in `~/.config/zoho-mail/config.json`.
2. The authorization code is exchanged for an **access token** and a **refresh token** via the Zoho OAuth token endpoint.
3. Both tokens are stored in `~/.config/zoho-mail/tokens.json`.
4. The access token is used for all subsequent API requests.

---

## Token Refresh Behavior

### Automatic Refresh

The CLI handles token refresh automatically. Before each API request, the CLI checks whether the current access token has expired:

- If the token is **still valid**, it is used directly.
- If the token has **expired**, the CLI uses the stored refresh token to obtain a new access token from Zoho's OAuth endpoint (`https://accounts.zoho.{tld}/oauth/v2/token`).
- The new access token is persisted to `tokens.json` so subsequent commands do not need to refresh again.

Access tokens typically expire after **1 hour** (3600 seconds), as specified by Zoho's `expires_in` response field.

### Manual Refresh

You can force a token refresh at any time:

```bash
zoho-mail auth refresh
```

This is useful if you suspect token corruption or want to ensure a fresh token before a batch operation.

### Check Authentication Status

To verify whether you are currently authenticated:

```bash
zoho-mail auth status
```

This checks whether a valid, non-expired access token exists locally. It does **not** make a network request to validate the token with Zoho.

---

## Troubleshooting Common Auth Errors

### "Not authenticated or token expired"

**Cause:** No tokens are stored, or the access token has expired and automatic refresh failed.

**Fix:**
1. Check your network connection.
2. Run `zoho-mail auth refresh` to attempt a manual refresh.
3. If refresh fails, run `zoho-mail auth login` to re-authenticate from scratch.

### "Not logged in. Run 'auth login' first."

**Cause:** No `tokens.json` file exists. You have never logged in, or you previously ran `auth logout`.

**Fix:** Run `zoho-mail auth login` to authenticate.

### "Token refresh failed"

**Cause:** The refresh token has been revoked or the Client ID/Secret are invalid.

**Fix:**
1. Verify your Client ID and Client Secret in `~/.config/zoho-mail/config.json`.
2. Check if the Self Client application still exists in the Zoho Developer Console.
3. Generate a new authorization code and run `zoho-mail auth login` again.

### "Error: unknown auth subcommand"

**Cause:** You passed an unrecognized subcommand to `zoho-mail auth`.

**Fix:** Valid subcommands are `login`, `refresh`, `status`, and `logout`. Run `zoho-mail auth --help` for usage.

### Authorization Code Expired

**Cause:** Authorization codes are short-lived (typically 1-10 minutes). If you waited too long before entering the code, it may have expired.

**Fix:** Generate a new authorization code (via the CLI URL or Developer Console) and try again.

### Wrong Region

**Cause:** Your Zoho account is hosted in a different region than the default (`com`).

**Fix:** Set the correct region before logging in:
1. Use the `--region` flag: `zoho-mail --region eu auth login`
2. Or update `config.json` manually to set the `region` field.

---

## Security Best Practices

### File Permissions

After authenticating, restrict access to your configuration and token files:

```bash
chmod 600 ~/.config/zoho-mail/config.json
chmod 600 ~/.config/zoho-mail/tokens.json
```

This ensures only your user account can read the credentials.

### Token Storage

- Tokens are stored in plaintext JSON files at `~/.config/zoho-mail/tokens.json`.
- The `config.json` file contains your OAuth Client ID and Client Secret.
- Both files should be treated as sensitive credentials.
- Never commit these files to version control. Add them to your `.gitignore`.

### Credential Rotation

- Periodically regenerate your Client Secret in the Zoho Developer Console and re-authenticate.
- If you suspect your credentials have been compromised:
  1. Revoke the Self Client application in the Zoho Developer Console.
  2. Run `zoho-mail auth logout` to clear local tokens.
  3. Create a new Self Client application and re-authenticate.

### Logout

When you no longer need CLI access, clear your stored tokens:

```bash
zoho-mail auth logout
```

This deletes the `tokens.json` file. Your Client ID and Client Secret in `config.json` are not removed; delete that file manually if needed.

### Environment Considerations

- On shared systems, ensure your home directory permissions prevent other users from reading `~/.config/zoho-mail/`.
- The CLI supports `XDG_CONFIG_HOME` for custom configuration directory placement. If set, files are stored at `$XDG_CONFIG_HOME/zoho-mail/` instead.
