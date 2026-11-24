# Salesforce review checklist (12 categories)

## 1. Styling & conventions
- PascalCase classes, camelCase methods/vars, UPPER_SNAKE constants; one top-level type per file; meaningful names (no `temp`, `data2`).
- Consistent formatting (project uses prettier + prettier-plugin-apex); no dead code, commented-out blocks, unused vars/imports/params.
- Test classes `*Test`, `@IsTest`; LWC: kebab-case folders, camelCase props; no inline styles where SLDS applies.
- Apex access modifiers minimal (`private`/`public` over `global` unless packaging/REST/invocable requires it).

## 2. Fundamentals
- `with sharing` / `inherit sharing` explicit on every class; deliberate `without sharing` documented.
- API version current; no hardcoded Ids, URLs, usernames, record type Ids (use `Schema` describe, Custom Metadata, Named Credentials, Custom Labels).
- Null-safety (`?.`, `??`), `String.isBlank`, `Map.containsKey`; correct use of `Id` vs `String`; collections initialised.
- One trigger per object, logic-less trigger delegating to handler; no logic in trigger body.
- Correct exception types; no empty catch; no swallowing of `DmlException`.

## 3. Bulk handling
- No SOQL, DML, callouts, `Database.*`, `Limits`-costly calls inside loops.
- Triggers process `Trigger.new`/`oldMap` collections; handle 200 records, and mixed insert/update contexts.
- Invocable methods accept and return `List<>`, preserve order, and one result per request.
- Maps/Sets used for lookups instead of nested loops; related-record queries batched (`IN :ids`).
- Partial-success DML (`allOrNone=false`) with per-row `SaveResult` handling where appropriate.

## 4. Performance & optimisation
- Selective SOQL: indexed filters, no leading-wildcard `LIKE` on large tables, avoid `!=`/`NOT IN` on unindexed fields, no `SELECT *`-style over-fetch; `LIMIT` present.
- Avoid repeated queries for same data (cache in static Map / `Cache.Platform` / Custom Metadata `getInstance`).
- Aggregate in SOQL (`GROUP BY`, `COUNT()`) vs Apex loops; use relationship subqueries; SOSL for text search.
- CPU: avoid nested loops O(n²), repeated `String +=` in loops (use `List<String>` + `String.join`), heavy `JSON.deserialize` on large payloads, recursion.
- Heap: avoid loading large collections; use SOQL `for` loops or Batch for volume; `Limits` checks near risky sections.
- LWC: `@wire` over imperative where cacheable, `cacheable=true` on read-only Apex, avoid unnecessary re-renders, debounce handlers, lazy-load.

## 5. Scalability
- Async chosen appropriately: `@future` vs `Queueable` (chaining/depth) vs Batch (chunk size) vs Schedulable, Platform Events/CDC for decoupling.
- Row/volume assumptions (LDV): selective queries, skinny tables, no unbounded `LIMIT`-less queries, no hardcoded `LIMIT 50000`.
- Hard caps and pagination (`OFFSET` limits, keyset pagination via Id/CreatedDate) on user-facing queries.
- Callout limits, retry/backoff, idempotency for async/event consumers; lock contention (`FOR UPDATE`, parent-skew).
- Trigger recursion guard that is correct under bulk (Set of processed Ids, not a boolean).

## 6. Security
- CRUD/FLS/sharing: `WITH USER_MODE` / `AccessLevel.USER_MODE`, `WITH SECURITY_ENFORCED`, `Security.stripInaccessible`; justify `SYSTEM_MODE`.
- SOQL/SOSL injection: bind variables, `String.escapeSingleQuotes`, allow-listed field/object names; LIKE wildcard sanitising.
- XSS in LWC/Aura/Visualforce (`innerHTML`, `lwc:dom="manual"`, `{!}` unescaped, `JSENCODE`); no secrets/tokens in code, logs, or custom labels; use Named Credentials / External Credentials.
- `@AuraEnabled`/REST/invocable endpoints validate inputs and caller authority; `global` surface minimal; no sensitive data in exception messages returned to clients.
- Permission sets over profiles; Experience Cloud guest user exposure; `without sharing` blast radius.

## 7. Observability & debugging logs
- Structured, levelled logging (`System.debug(LoggingLevel.X, …)`) with context (class.method, record Ids, correlation id), not `System.debug(obj)` dumps with PII.
- No debug statements left in hot loops (they cost CPU/heap even when level filtered); no logging of secrets/PII.
- Persistent logging for async/integration paths (custom log object or Platform Event, e.g. Nebula Logger pattern); failure paths record enough to replay.
- Error surface: return/throw typed errors with machine-readable codes; `AuraHandledException` with message set; HTTP status mapping for REST.
- Metrics hooks: `Limits.getQueries()/getCpuTime()` snapshots for key flows; Flow/invocable errors surfaced in result object.
- Debuggability: small methods with clear names, assertions in tests, replayable inputs.

## 8. Code comments & documentation
- ApexDoc (`/** @description @param @return @throws */`) on public/global API; class header describes purpose and entry points.
- Comments explain *why* (limits, business rules, workarounds), not *what*; no stale/misleading comments; TODOs have owner/ticket.
- `@InvocableVariable` labels/descriptions, REST endpoint docs, LWC `@api` JSDoc, `-meta.xml` descriptions.

## 9. Cyclomatic complexity & maintainability
Use `complexity.py` output. Thresholds: CC 1-5 good; 6-10 review; >10 refactor (Major); >20 Blocker-level maintainability risk.
- Method > 50 lines, > 4 params, nesting depth > 3, class > 500 lines → flag.
- Suggest extraction, guard clauses/early return, strategy/polymorphism replacing switch/if-else ladders, lookup Maps replacing branches.
- Cognitive complexity (nested conditionals, boolean chains) beyond what CC shows.

## 10. Architecture & design patterns
- Separation of concerns: trigger → handler → service → selector (SOQL) → domain; DTOs separate from sObjects; Apex Enterprise Patterns (fflib) alignment where used.
- Patterns used appropriately and not over-engineered: Selector, Service, Unit of Work, Domain, Factory, Strategy, Singleton (static cache), Builder, Decorator, Facade, Command, Template Method, Dependency Injection via interfaces/`Type.forName`/Custom Metadata.
- Duplicate logic across surfaces (REST vs invocable vs LWC controller) consolidated in shared layer.
- Testability seams: interfaces/stubs (`System.StubProvider`), `@TestVisible` sparingly, no hidden global state.
- Config over code: Custom Metadata / Custom Settings / Feature flags (Custom Permissions); declarative alternatives (Flow) considered; order-of-execution conflicts with Flows/Process Builders/validation rules.
- Layering of integrations: Named Credentials, retry, circuit-breaker, mapping layer.

## 11. Advanced functionality
Note where use would add value (as Suggestions): `Database.Stateful`/`Batchable` with `QueryLocator`, Queueable `Finalizer`, Platform Events + CDC, `Callable` interface, `Cache.Org/Session` Platform Cache, `Security.stripInaccessible`, `Database.queryWithBinds`, `Comparable`/custom iterators, Dynamic Apex via `Schema` describe, `System.StubProvider`/mocking, Custom Metadata-driven trigger framework, `Test.startTest` async testing, `@wire` + LDS/UI API, LWC `lightning/uiRecordApi`, Lightning Message Service, Flow-invocable `@InvocableMethod` with `callout=true`, GraphQL wire adapter, Apex cursors/`Database.getCursor`, `Assert` class.

## 12. Testing (feeds all scores)
- ≥ 75 % coverage is the floor, but judge assertion quality: `Assert.areEqual/isTrue` with messages; no `System.assert(true)`; no `SeeAllData=true`.
- Test data via factory/`@TestSetup`; bulk test with 200+ records; negative paths, permission-based tests via `System.runAs`; async via `Test.startTest/stopTest`; callout mocks (`HttpCalloutMock`).
- LWC: Jest tests for render, events, wire adapters, error states.
- Tests assert governor-safety (e.g. `Limits.getQueries()`) for bulk paths.

## Common anti-pattern quick list
SOQL/DML in loop · no sharing keyword · hardcoded Id · empty catch · trigger with logic · `@future` where Queueable fits · `LIKE '%x'` on large object without limit · `System.debug` PII · boolean recursion flag · `without sharing` by default · `Test.isRunningTest()` branches in prod code · `SeeAllData=true` · returning raw exception text to client.
