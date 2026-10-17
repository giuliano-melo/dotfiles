---
name: linear-project-descriptions
description: Draft, refine, and standardize Linear projects, initiatives, subinitiatives, and related fields. Use when the user asks to create, update, structure, or normalize Linear planning items and their descriptions.
---

# Linear guidelines

## Write protection

Treat Linear as write-protected until the user explicitly approves the exact proposed content and fields in the current conversation.

The workflow is:

1. Inspect the existing item, its parent, sibling items, and relevant references.
2. Draft the name, summary when applicable, description, and fields.
3. Show the exact proposal, including parent, owner, team, status, priority, dates, and links.
4. Ask for explicit confirmation, such as “Posso subir exatamente assim?”.
5. Only after confirmation, write to Linear and fetch the item again to verify the saved result.

Requests to prepare, experiment, show, or draft are not approval to write. Approval is valid only after the exact proposal has been shown.

## Item hierarchy and visible fields

Use each Linear level for a different amount of information. Do not copy project-level detail into initiatives or subinitiatives.

### Projects

- Use `summary` when a concise card-level explanation helps people scan the project.
- Put the operational detail in the description: context, objective, scope, expected result, success criteria, and dependencies or references.
- Keep the description outcome-oriented; do not turn it into an issue list or technical design.

### Initiatives

- Use a concise `summary` as the initiative's only short description. It should explain the strategic outcome or purpose of the topic in one sentence.
- Do not add a detailed multi-section description to an initiative by default. Context, scope, outcomes, success criteria, and execution details belong in its subinitiatives and projects.
- Add initiative-level description content only when the user explicitly asks for strategic documentation that cannot live in the summary.

### Subinitiatives

- Do not add a subtitle or `summary`. Omit the field or leave it empty.
- Use a clear, specific name so the hierarchy remains scannable.
- Keep the description intentionally minimal so the initiative overview does not become a second project plan.
- By default, use only these sections: `Contexto`, `Objetivo`, and `Dependências e referências`.
- Put scope, expected result, success criteria, and detailed execution information in the projects below the subinitiative.
- Do not duplicate the full context in the name, a visible summary, or project-level sections.
- Do not add an `Entregáveis` section by default. Detailed results and completion criteria belong in the projects; add them to the subinitiative only when the user explicitly asks for them or the hierarchy would otherwise be materially ambiguous.

This distinction is intentional: initiatives provide strategic orientation at a glance; subinitiatives organize a theme with minimal context; projects carry the execution detail.

## Description structures by level

Use only sections that add information, following the level-specific defaults below.

### Project description

```markdown
## Contexto

[Problem, opportunity, or reason]

## Objetivo

[Change intended and why]

## Escopo

- [Included outcome or workstream]
- [Included outcome or workstream]

## Resultado esperado

[What should be true when complete]

## Critérios de sucesso

- [Observable success condition]

## Dependências e referências

- [Dependency, source, or link]
```

### Subinitiative description

```markdown
## Contexto

[Why this theme exists and how it relates to the parent initiative]

## Objetivo

[What this subinitiative organizes or enables]

## Dependências e referências

- [Dependency, source, or link]
```

Do not add `Escopo`, `Resultado esperado`, `Critérios de sucesso`, `Critério de conclusão`, or `Entregáveis` to a subinitiative by default. Add one only when the user explicitly requests it or when omitting it would make the item materially ambiguous.

### Initiative description

By default, do not create a detailed description. Put the one-sentence purpose in `summary` and leave the description empty. If an initiative-level description is explicitly requested, keep it strategic and short; do not reproduce the project template.

## General rules

- Write in Portuguese unless the user requests another language.
- Use sentence case for names and preserve the workspace's terminology.
- Write the company name as “Sympla” and use “Linear”, “GitLab”, “Codex”, and “MRs” with this casing.
- Inspect the parent and sibling items before creating a new item to avoid duplicates or overlapping scope.
- Keep each fact in one place. The summary, name, and description should complement one another rather than repeat one another.
- Separate context and outcomes from implementation tasks. Tasks belong in issues or project milestones.
- Do not invent owners, teams, dates, metrics, dependencies, commitments, or scope. Ask when the missing value could materially change the item.
- If the user says the owner should be them, resolve the authenticated Linear user and use that identity; otherwise ask or preserve the existing owner.
- Set a target date only when it represents a real commitment or regulatory deadline. Put recurring or event-dependent deadlines in the description instead.
- Preserve existing fields unless the user explicitly asks to change them.
- Use source links for regulatory, legal, market, or other externally grounded context. Prefer the primary source when available.
- Keep cross-functional alignment, budgeting, FP&A, and rebudgeting in dependencies unless they are explicit outcomes.
- Include operational prerequisites in dependencies when they are required for delivery.
- Do not create projects, initiatives, subinitiatives, or issues merely to capture speculative follow-up work.

## Proposal checklist

Before asking for approval, show:

- Current item and link when updating or adding under an existing parent.
- Proposed name.
- Proposed summary only when the item type allows or needs it. For subinitiatives, explicitly show `summary: vazio` or omit it.
- Full proposed description.
- Parent initiative or project.
- Owner, team, status, priority, dates, labels, and links that will change.
- Any assumptions or unresolved questions.

## After approval

Write only the approved fields. Fetch the saved item again and verify:

- It is attached to the intended parent.
- The name, summary policy, description, owner, status, priority, and dates match the approved proposal.
- No unapproved fields or duplicate items were created.

If the saved content differs materially from the approved content, stop and report the difference.
