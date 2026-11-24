# fde_class_nov24

A Salesforce DX project that exposes Account lookup to an external MCP server through Apex, plus a Claude Code toolkit for reviewing and documenting the Apex code.

## What's in the repo

### Apex (`force-app/main/default/classes/`)

Two surfaces share one query layer, so both return the same fields and honor the same limits.

| Class | Role |
|---|---|
| `AccountMcpSelector` | The only place SOQL lives. Uses `WITH USER_MODE`, caps rows (default 10, max 200, related records 25), and escapes LIKE wildcards. |
| `AccountMcpService` | REST resource at `/services/apexrest/mcp/accounts/*`. `search?name=&max=` and `details?id=` or `details?name=`. Returns a `success`/`error`/`count` envelope and maps errors to 400, 404 and 500. |
| `AccountSearchInvocable` | `@InvocableMethod` for Flow or the Actions API. Bulk-safe, returns one `Result` per request. |
| `AccountDetailsInvocable` | `@InvocableMethod` returning an Account with its contacts and opportunities, using two bulk queries. |
| `AccountMcpServiceTest`, `AccountMcpInvocableTest` | Tests for the REST service and the invocables. |

## Getting started

Prerequisites: Salesforce CLI, Node.js, and an authorized org (`sf org login web`).

```bash
npm install                                   # also installs husky hooks
sf project deploy start -d force-app          # deploy to your default org
sf apex run test -n AccountMcpServiceTest -r human -w 10   # one test class
sf apex run test -l RunLocalTests -w 10       # all Apex tests
sf data query -f scripts/soql/account.soql
npm run prettier:verify                       # formatting check
npm run lint                                  # eslint for aura/lwc JS
```

There are no LWC components yet, so `npm test` has nothing to run.

## Claude Code toolkit (`.claude/`)

| Piece | What it does |
|---|---|
| `/sfdc-review [path]` | Slash command. Reviews Salesforce code and writes `code-review-report.html` with review notes only. |
| `/sfdc-review --document [path]` | Adds class headers and method comments without changing code. Backs up each file and verifies the edit is comment-only. |
| `agents/sf-code-reviewer.md` | The reviewer subagent. Review mode is read-only. |
| `skills/sf-code-review/` | Procedure, a 12-category checklist (styling, bulk handling, performance, scalability, security, observability, comments, cyclomatic complexity, architecture, advanced features, testing), and the comment standard. |
| `skills/sf-code-review/scripts/complexity.py` | Per-method cyclomatic complexity, length and nesting. |
| `skills/sf-code-review/scripts/doc_check.py` | Comment coverage, and a check that an edit changed only comments. |
| `hooks/secret_guard.py` | Hook that blocks credentials in prompts and written files, blocks reads of credential files, and blocks shell commands that print tokens. |

`CLAUDE.md` gives Claude Code the commands and architecture for this repo. `claude-architecture.html` is a diagram of how the toolkit fits together.

## Project layout

```
force-app/main/default/   Salesforce metadata (Apex today; lwc, aura, objects are empty)
scripts/                  Sample Apex and SOQL
config/                   Scratch org definition
manifest/package.xml      Retrieve/deploy manifest
.claude/                  Agent, skill, slash command, hooks, settings
```

Source API version is 68.0. Org cache folders (`.sf/`, `.sfdx/`) are git-ignored and must not be committed.
