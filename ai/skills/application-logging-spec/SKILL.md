---
name: application-logging-spec
description: Specify application logs in issues or technical documents, including event tables, severity, example lines, and data protection.
---

# Application logging specification

## When to use

Define application logging requirements. Do not implement logging, configure alerts, or specify business history and audit interfaces unless requested.

## Workflow

1. Read the operation's scope and the project's logging standard.
2. Identify events useful for investigation.
3. Write the event table and example lines.
4. Add verifiable acceptance criteria when requested.
5. Review prose with the humanizer before saving.

If no project standard is available, present conventions as proposals.

## Event table

Use:

| MSGID | Severity | Emission condition |
|---|---|---|
| Stable English identifier | INFO, WARN, or ERROR | Exact condition that triggers the log |

Distinguish application behavior from dependency failures. Follow project decisions for severity; do not classify every rejected input as an internal error.

## Example lines

Place examples immediately below the table. Use fictitious identifiers and the application's actual name.

Each line must identify:
- What happened.
- Why, only when known.
- Who acted, using an opaque internal identifier or process name.
- When it happened.
- Where it happened.

Follow the project's output format. If illustrating a Datadog display rather than the emitted format, state that distinction.

## Rules

- Use stable MSGIDs and short messages.
- Log success only after confirmation; for database writes, after transaction confirmation.
- After a timeout, do not claim the operation failed when its outcome is unknown.
- Never invent a cause.
- Do not log personal data, credentials, tokens, or complete payloads.
- For validation failures, log field and reason, not the rejected value.
- Include only identifiers needed for investigation.
- Avoid duplicate logs across layers without additional context.

## Acceptance criteria

When requested, use `- [ ]` checkboxes covering event emission, severity, required context, and absence of sensitive data.

Do not require dashboards, alerts, or attached reports unless they are part of the request.
