---
name: linear-issue-writing
description: Write or rewrite Linear issues. Covers issues only — epics, projects and initiatives use the project descriptions skill. Every issue must pass the humanizer before being saved to Linear.
---

# Issue writing

## When to use

Creating or rewriting issues in Linear. Do not use for epics, projects, or initiatives — those use the project descriptions skill.

## Core principle

One issue = one problem = one system.

Each issue addresses a single problem in a single system. An issue that covers more than one problem (or more than one system) grows too large and complex, which makes it hard to develop and hard to validate. When the scope grows into two problems, split it into two issues and link them with blockedBy.

## Mandatory flow

1. Write the issue using the template below.
2. Review it with the humanizer skill before saving to Linear. No issue is saved without this pass.
3. Only then save it to Linear.

## Required template

Every issue has three sections, in this order:

### Context

2-4 sentences answering: what problem exists today in this system, and what happens if the issue is not done. No jargon from the source document (plan, RFC): if a technical term appears, explain it at first occurrence.

### Scope

Numbered steps, each with one concrete action. If order matters (migrations, windows, deploys), the numbering is the execution order. No loose actions crammed into a running sentence.

### Acceptance criteria

Numbered items, each verifiable with yes/no. Forbidden: "works", "handled", "green", "coherent", "known". Required: a concrete expected result ("zero differences outside the manifest", "stockAllocated does not change when the call is repeated").

## Hard rules

1. Self-contained issue: someone reading only the issue understands why it exists, can execute it, and can verify it. External references only with a link, and the essentials copied into the issue.
2. References to other issues: SYM identifier with a native Linear issue link, never local numbering (US-xx).
3. Deliverables have a destination and an owner: "report attached" becomes "dated report attached as a document in the project"; "approved" becomes "reviewed by <team> before <event>".
4. Never require protection against a problem that does not exist in the environment; every requirement points to the real risk it mitigates.
5. "Do not do X" instructions state the reason ("do not change TypeORM: 0.3.x is the only line compatible with Vendure 3.8.1").

## Anti-patterns (before → after)

1. Untranslated jargon from the source plan ("ledger", "rescale", "manifesto", "apiType=admin", "section 7 of the plan") → explain the term at first occurrence; the reader has not read the plan.
2. Vague acceptance criteria ("totals, stock and history correct after edit and cancel") → verifiable items ("after canceling, stock is fully returned and no fulfillment remains pending").
3. Deliverables with no owner or destination ("approved in writing", "report attached") → "reviewed by Platform and Store teams before the window", "dated report attached as a document in the project".
4. References that only exist outside the issue ("treatments from US-15 to US-20", "baseline comes from US-02") → native SYM links.
5. Scope crammed into one sentence (eight actions separated by commas) → numbered steps in execution order.
6. Context that states a fact without the problem ("the plan describes the sequence") → the risk if the issue is not done ("on the day, only an executable checklist can be used").
7. Contradictions between issues (one asks for DDL "separated", the next for "a single file") → clarify: separated for review, together at execution.
8. Protection against nonexistent problems ("audit tables safe from automatic retention") → cut; the environment has no such policy.
9. Ambiguous instructions that sound like wrong decisions ("keep TypeORM 0.3") → state the reason ("do not change TypeORM: 0.3.x is the current TypeORM line and the only one compatible with Vendure 3.8.1").
10. AI writing residue (not-X-but-Y contrasts, one-line closers, forced triads, subjectless passive, decorative bold) → run the humanizer pass.

## Final check (before saving)

- [ ] One problem only, one system only?
- [ ] Context explained with no external reading required?
- [ ] Scope in numbered steps?
- [ ] Every criterion verifiable with yes/no?
- [ ] References are SYM with native links?
- [ ] Every deliverable has a defined destination?
- [ ] Reviewed with the humanizer?
