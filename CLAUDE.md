# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Salesforce DX project (`sfdc1`, source API version 68.0, single package dir `force-app`). Currently the only metadata is Apex under `force-app/main/default/classes/`; the `lwc`, `aura`, `triggers`, `objects`, etc. directories are empty scaffolding. Not a git repository.

## Commands

```
npm install                      # also installs husky hooks
npm run lint                     # eslint on aura/lwc JS
npm run prettier                 # format cls, xml, js, json, etc. (prettier-plugin-apex)
npm run prettier:verify
npm test                         # LWC jest (sfdx-lwc-jest); no LWC exists yet
npx sfdx-lwc-jest -- <path>      # single LWC test

sf project deploy start -d force-app                 # deploy
sf apex run test -n AccountMcpServiceTest -r human -w 10   # run one Apex test class (add -c for coverage)
sf apex run test -l RunLocalTests -w 10              # all Apex tests
sf data query -f scripts/soql/account.soql
sf apex run -f scripts/apex/hello.apex
```

The Salesforce DX MCP server (`mcp__salesforce-dx__*`: deploy_metadata, run_apex_test, run_soql_query, etc.) is also available. Lint-staged (husky pre-commit) runs prettier, eslint, and related LWC jest tests.

## Architecture

The Apex code exposes Account lookup to an external MCP server ("apex-server") through two parallel surfaces that share one query layer:

- `AccountMcpSelector` — the single source of truth for SOQL. All queries use `WITH USER_MODE`, cap results (`DEFAULT_LIMIT` 10, `MAX_LIMIT` 200, `RELATED_LIMIT` 25 for contacts/opportunities), and escape LIKE wildcards via `sanitizeForLike`. Throws `InvalidInputException` for bad input.
- `AccountMcpService` — `@RestResource(urlMapping='/mcp/accounts/*')`; the action is the last URI segment (`search` or `details`). Returns an `ApiResponse` envelope (`success`/`error`/`count`) and maps errors to HTTP status codes (400 invalid input, 404 not found, 500 unexpected).
- `AccountSearchInvocable` / `AccountDetailsInvocable` — `@InvocableMethod` actions (category "MCP Account Tools") callable from Flow or via the Actions API (`/actions/custom/apex/<ClassName>`). They are bulk-safe, return per-request `Result` objects with `success`/`errorMessage` rather than throwing, and return raw sObjects, whereas the REST service returns flattened summary DTOs.

When changing returned fields or limits, update `AccountMcpSelector` (queried fields must cover both the REST DTO mapping in `AccountMcpService.toSummary` and the invocables' sObject output) and keep both surfaces consistent. Tests: `AccountMcpServiceTest` (REST) and `AccountMcpInvocableTest` (invocables).
