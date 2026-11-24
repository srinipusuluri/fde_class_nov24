#!/usr/bin/env python3
"""Claude Code hook: keep passwords, tokens and keys out of the session and the repo.

Events handled (read from the hook JSON on stdin):
  UserPromptSubmit  block prompts that contain a credential
  PreToolUse        block (a) writing credentials into files,
                          (b) reading credential files / auth stores,
                          (c) shell commands that print or exfiltrate credentials
Exit 2 + stderr blocks the action and tells Claude/the user why. Exit 0 allows.
"""
import json, re, sys

# --- 1. credential patterns (content) -------------------------------------
SECRET_PATTERNS = [
    ("Salesforce access/session token", r"\b00D[A-Za-z0-9]{12,15}![A-Za-z0-9_.]{20,}"),
    ("Salesforce SFDX auth URL",        r"force://[A-Za-z0-9_]*:[^\s@]*@[\w.\-]+"),
    ("Anthropic API key",               r"\bsk-ant-[A-Za-z0-9_\-]{20,}"),
    ("OpenAI-style API key",            r"\bsk-[A-Za-z0-9]{32,}"),
    ("AWS access key id",               r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"),
    ("GitHub token",                    r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{40,}"),
    ("Slack token",                     r"\bxox[baprs]-[A-Za-z0-9\-]{10,}"),
    ("Private key block",               r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY"),
    ("Bearer token",                    r"(?i)\bauthorization\W{1,4}bearer\s+[A-Za-z0-9._\-]{20,}"),
    ("JWT",                             r"\beyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}"),
    ("Hard-coded credential assignment",
        r"""(?ix)\b(?:pass(?:word|wd)?|pwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|security[_-]?token)
            ["']?\s*[:=]\s*["'](?!\s*["'])(?!<|\{|\$|%|xxx|\*\*|changeme|example|your|test|dummy|placeholder|null|none|todo)[^"'\s]{8,}["']"""),
]
PLACEHOLDER = re.compile(r"(?i)(example|dummy|placeholder|your[_-]|<.*>|xxxx|fake)")

# --- 2. sensitive file paths (Read/Grep/Glob/Edit/Write) --------------------
SENSITIVE_PATH = re.compile(
    r"""(?ix)(
        (^|/)\.env(\.[\w.-]+)?$ |
        (^|/)\.(netrc|npmrc|pypirc|git-credentials)$ |
        (^|/)(id_rsa|id_ed25519|id_ecdsa)(\.pub)?$ |
        \.(pem|key|p12|pfx|jks|keystore)$ |
        (^|/)server\.key$ |
        (^|/)\.aws/credentials$ |
        (^|/)\.ssh/ |
        /\.sfdx?/[^/]*@[^/]*\.json$ |            # SF CLI stored org auth (access + refresh tokens)
        /\.sfdx?/(alias|key)\.(json|key)$ |
        (^|/)\.sf/[^/]*@[^/]*\.json$ |
        authinfo | sfdx[-_]?auth[-_]?url | (^|/)auth[-_]?url\.txt$
    )""")

# --- 3. shell commands that expose credentials --------------------------------
BASH_BLOCKS = [
    ("prints the org access token",   r"\bsf(dx)?\s+(org\s+display|force:org:display)\b[^|;&\n]*(--verbose|--json)"),
    ("exports an SFDX auth URL",      r"--sfdx-?url|sfdx[-_]?auth[-_]?url|\bsf\s+org\s+login\s+sfdx-url"),
    ("reads a credential file",       r"\b(cat|less|more|head|tail|bat|cp|mv|scp|base64|xxd|strings|open)\b[^|;&\n]*(\.env\b|id_rsa|id_ed25519|\.netrc|\.npmrc|\.git-credentials|\.aws/credentials|\.pem\b|\.key\b|/\.sfdx?/[^\s/]*@)"),
    ("dumps environment secrets",     r"(?i)\b(printenv|env|export\s+-p|set)\b\s*(\||$|;)|echo\s+\"?\$\{?\w*(TOKEN|SECRET|PASSWORD|API_?KEY)\w*"),
    ("reads the macOS keychain",      r"\bsecurity\s+(find|dump)-(generic|internet)-password|\bsecurity\s+dump-keychain"),
    ("sends data to an external host with a credential",
        r"(?i)\bcurl\b[^\n]*(-H|--header)[^\n]*(authorization|x-api-key)[^\n]*\bhttps?://(?!localhost|127\.0\.0\.1)"),
]

def block(reason, hint=""):
    sys.stderr.write(f"[secret_guard] BLOCKED: {reason}.{(' ' + hint) if hint else ''}\n")
    sys.exit(2)

def find_secret(text):
    for label, pat in SECRET_PATTERNS:
        for m in re.finditer(pat, text or ""):
            if not PLACEHOLDER.search(m.group(0)):
                return label
    return None

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # never break the session on malformed input

    event = data.get("hook_event_name", "")
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}

    if event == "UserPromptSubmit":
        label = find_secret(data.get("prompt", ""))
        if label:
            block(f"your prompt appears to contain a {label}",
                  "Remove it, rotate it if it is real, and reference it by name (env var / Named Credential) instead.")
        return

    if event != "PreToolUse":
        return

    path = inp.get("file_path") or inp.get("path") or inp.get("notebook_path") or ""
    if path and SENSITIVE_PATH.search(path.replace("\\", "/")):
        block(f"{tool} on credential file '{path}'", "Ask the user to provide only the non-secret values you need.")

    if tool in ("Write", "Edit", "NotebookEdit", "MultiEdit"):
        text = " ".join(str(inp.get(k, "")) for k in ("content", "new_string", "new_source"))
        for e in inp.get("edits", []) or []:
            text += " " + str(e.get("new_string", ""))
        label = find_secret(text)
        if label:
            block(f"the content you are writing contains a {label}",
                  "Use a Named Credential / External Credential, Custom Metadata, or an environment variable instead.")

    if tool == "Bash":
        cmd = inp.get("command", "")
        label = find_secret(cmd)
        if label:
            block(f"the command contains a {label}", "Pass secrets through environment variables, not the command line.")
        for why, pat in BASH_BLOCKS:
            if re.search(pat, cmd):
                block(f"this command {why}", "Use `sf org display` without --verbose, or ask the user to run it themselves.")

    if tool in ("Grep", "Glob"):
        pat = str(inp.get("pattern", ""))
        if SENSITIVE_PATH.search(pat.replace("\\", "/")):
            block(f"{tool} targeting credential files")

if __name__ == "__main__":
    main()
