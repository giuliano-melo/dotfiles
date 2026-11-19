---
name: linear-issue-writing
description: Write or rewrite Linear issues. Covers issues only — epics, projects and initiatives use the project descriptions skill. Every issue must pass the humanizer before being saved to Linear.
---

# Issue writing

## When to use

Create or update Linear issues. Use the project descriptions skill for projects and initiatives.

## Principles

- One issue = one problem = one system. E2E issues belong to the repository owning the tests.
- Make issues self-contained. Use native Linear links for references.
- State concrete work and observable results. Do not invent requirements, dependencies, or generic open questions.
- Keep essential information and reference images visible.

## Structure

### Context
Explain the problem and expected outcome in 2–4 sentences.

### Scope
Use numbered, concrete actions.

When applicable, include:
- **Contracts:** field meanings and request examples.
- **Responses:** table with HTTP status, condition, and expected response. Separate creation, retrieval, and update scenarios.
- **Logs:** when requested or needed to investigate the behavior in scope, use the `application-logging-spec` skill and include the specification in the issue. Follow the project's logging standard; do not invent logging requirements.
- **Tests:** state what they prove, which dependencies are real or mocked, and where they run. For E2E, specify the framework and journey.

Do not duplicate work across issues or require unnecessary reports and approvals.

### Acceptance criteria
Use `- [ ]` checkboxes with verifiable outcomes, not repetitions of scope activities.

## Updating

Read the current issue and apply targeted edits. Preserve manual changes, images, attachments, and unrelated fields. Verify the saved result.

## Planning

When requested, apply relevant labels, use the team's estimation scale, and record actual blockers. Include testing effort without double-counting. Open decisions alone do not justify larger estimates.

Do not assign an owner or cycle without authorization.

## Before saving

Review with the humanizer, including subsequent edits. Confirm:
- Scope, contracts, tests, and criteria agree.
- Suggestions are distinguished from confirmed decisions.
- Logs and errors do not claim an unconfirmed outcome.
- Requested changes preserve existing work.
