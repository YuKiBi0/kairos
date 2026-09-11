---
name: kairos-cli-planning
description: Use the Kairos CLI to create and maintain user plans, deadlines (DDL), daily plans, and other actionable task schedules. Activate when the user asks to make, record, organize, or update a plan in Kairos; do not activate for generic advice that should not create tasks.
---

# Kairos CLI Planning

Use this skill when the user's intent is to put a plan into Kairos. Treat a plan as one or more actionable Kairos tasks, not as prose that exists only in the chat.

## Required workflow

1. Extract the user's requested outcome, task titles, details, DDL, preferred schedule, priority, and any dependencies. Keep the user's wording and timezone when known.
2. Decide whether the request is one task or a small set of tasks. Split a daily plan or multi-step plan when each step can be independently completed or tracked. Do not create speculative tasks.
3. Before a write, check the CLI context if it is not already known:
   - `kairos whoami`
   - `kairos workspace current` (or `kairos workspace list` when the target is unclear)
   - use `kairos workspace use WORKSPACE_ID` only after the user selects or clearly names a workspace.
4. Ensure the CLI is authenticated. If it reports that login is required, explain the prerequisite and use `kairos login --server NAME` only when the user has supplied credentials through flags or `KAIROS_USERNAME`/`KAIROS_PASSWORD`. Never ask the user to paste a password into a task description or log.
5. Create each confirmed task with the real CLI. Prefer JSON input when there are fields beyond title/description/priority, for example:

   ```json
   {
     "title": "发布 v2.1",
     "description": "步骤：\n1. ...\n2. ...\nDDL: 2026-09-18T17:00:00-07:00",
     "quadrant": 1,
     "due_at": "2026-09-18T17:00:00-07:00"
   }
   ```

   ```text
   kairos task create --json-file plan-task.json --idempotency-key REQUEST_UUID
   ```

   For a simple task, use `kairos task create --title "TITLE" --description "DETAILS" --priority N`. Use `--output json` for machine-readable results. The CLI accepts `--json-file -` for stdin and `@FILE` where documented.
6. Report the created task IDs, titles, workspace, and DDL back to the user. For follow-up changes, retrieve the task with `kairos task get TASK_ID`, then use `kairos task update TASK_ID`; preserve the current version or let the CLI fetch it.

## Intent mapping

- “建立计划/制定计划/项目计划/行动计划”: create one task for the outcome or split into explicit steps.
- “DDL/截止日期/最晚什么时候完成”: store the deadline in `due_at` as an ISO 8601 timestamp with offset, and repeat it in the description in human-readable form. If the date or timezone is ambiguous, ask before writing.
- “每日计划/今天计划/明日计划”: create only the requested day's actionable tasks, each with a clear title and `due_at` when a time is given. Do not invent recurring automation; ask whether the user wants another day's tasks.
- “整理/更新计划”: list or fetch existing tasks first (`kairos task list` / `kairos task get`) and update only the requested fields.

Use quadrant/priority values 1–4 when the user gives urgency or importance. If no priority is stated, omit it rather than guessing. A DDL is not the same as running a task: do not call `kairos task run` unless the user explicitly asks to execute it.

## Safety and reliability

- Never fabricate a `kairos plan`, `kairos ddl`, or `kairos daily` subcommand. The current CLI creates plans through `task create` and updates them through `task update`.
- Do not write until required information is sufficient: a non-empty title and the intended workspace. Ask one concise clarification for missing material details; otherwise use a reasonable description derived from the request.
- Use a stable UUID `--idempotency-key` for a retry of the same create request. On timeout, retry with the same key; do not create a second task with a new key.
- Do not expose passwords, access tokens, runner tokens, or credential files in output. Prefer `KAIROS_TOKEN` for CI and `--output json` when another command must parse the response.
- Treat CLI errors as authoritative. Surface the error code/message and stop rather than silently retrying permission, validation, or authentication failures.

For the complete command reference, consult the repository's `cli/README.md` when a less common CLI option is needed.
