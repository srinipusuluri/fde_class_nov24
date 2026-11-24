# Documentation-mode standard (header + method comments)

Goal: someone new to the code understands **purpose, contract, and non-obvious reasons** without reading every line.
Comments only. Never change code, names, formatting of code, or ordering.

## Apex class / trigger header (ApexDoc, directly above the declaration, above annotations)
```
/**
 * @description <one or two sentences: what this class is for and who calls it>
 * Entry points: <REST path / @InvocableMethod label / trigger events / schedulable etc.>
 * Collaborators: <classes it depends on or is used by>
 * Sharing / security: <with sharing + USER_MODE, or why not>
 * Bulk / limits: <bulk-safe? queries per call, row caps>
 * @group <layer: Selector | Service | Controller | Handler | Test>
 */
```
Keep any existing header text that is still accurate; merge rather than replace.

## Method comment (every method incl. private; skip trivial getters/setters and one-line test helpers)
```
/**
 * @description <what it does, in business terms; the "why" if not obvious>
 * @param name <meaning, units, allowed values, null behaviour>
 * @return <shape of the result; what an empty/failed result looks like>
 * @throws <ExceptionType> <when>
 * Limits: <SOQL/DML count, loops, callouts> (only when relevant)
 */
```
## Inner classes, DTO fields, @InvocableVariable
One-line `/** ... */` on inner classes; on DTO fields only when the meaning is not evident from the name (units, formats, nullability).

## Test classes
Header states what is under test and the scenarios covered; each test method gets a one-line `@description` of scenario → expected outcome.

## LWC / Aura JS
JSDoc `/** */` on the component class (purpose, events fired, slots) and on each `@api` property/method and handler; `@param`/`@returns` as needed.

## Inline comments
Add `//` only above non-obvious logic: governor-limit workarounds, ordering/ID-format assumptions, security decisions, regex, magic numbers, intentional `without sharing`.

## Rules
- Describe actual behaviour, verified from the code; do not guess or restate the signature.
- Never write secrets, org Ids, usernames or customer data into comments.
- No "TODO", changelogs, author names, or dates.
- Match existing indentation; wrap at ~100 cols; no trailing whitespace.
