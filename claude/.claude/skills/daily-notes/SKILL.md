---
name: daily-notes
description: Generate end-of-day working notes in Obsidian from Git, GitHub PRs, Jira, Confluence, Slack, and Claude session history
user-invocable: true
---

Generate my daily working notes for today (or the date passed as `$ARGUMENTS`, defaulting to today).

## File Location

Append to the note at:
`/Users/nick.allen/Library/CloudStorage/Dropbox/Documents/Obsidian Vaults/Datadog/Working Notes/<YYYY-MM-DD>.md`

If the file doesn't exist, create it.

The file may already contain manually written notes, TODOs, or earlier runs of this skill. Never overwrite existing content. Always append.

## Daily Notes Header

Each appended block must start with a horizontal rule and a dated heading:

```
---
## Daily Notes <YYYY-MM-DD>
```

This separates the generated notes from any pre-existing content and from previous runs on the same file.

## Format Reference

Read the most recent existing note in `Working Notes/` to match the current format. The sections below describe the general structure, but always defer to the latest note's conventions.

## Data Sources

Gather from all sources in parallel:

1. **Git commits** (dd-source):
   `git log --author="Nick Allen" --since="<date>T00:00:00" --until="<next-day>T00:00:00" --format="%aI %H %s" --all | grep -v "Merge " | sort`
   - Use `%aI` (author date ISO) to get when the commit was actually written, not when it was rebased or cherry-picked. Sort by this date to get chronological order.
   - The `--since`/`--until` filter uses committer date, so rebased commits from earlier days may appear. Compare author dates against the target date to identify which commits were genuinely new work vs. carried over from a prior day.
   - Use commit timestamps to anchor the Timeline, showing when coding work actually happened between sessions and reviews.

2. **PR activity** (GitHub):
   `gh pr list --author="@me" --state=all --search="updated:>=<date>"` then check reviews on each PR via `gh api repos/DataDog/dd-source/pulls/<num>/reviews`

3. **Jira tickets** (Atlassian MCP):
   JQL: `project = K9BITSAI AND assignee = currentUser() AND updated >= "<date>" ORDER BY updated DESC`

4. **Confluence pages** (Atlassian MCP):
   CQL: `contributor = currentUser() AND lastModified >= "<date>" ORDER BY lastModified DESC`
   - Include pages created, edited, and commented on.

5. **Slack messages** (Slack MCP, user ID `U037S35RD25`):
   - `from:<@U037S35RD25> on:<date>` — messages sent
   - `to:<@U037S35RD25> on:<date> -from:<@U037S35RD25>` — messages received
   - Filter out bot noise (GitHub notifications, devflow). Focus on human conversations, review requests, incidents, and cross-team interactions.

6. **Calendar events** (icalbuddy):
   `icalbuddy -nc -nrd -ea -tf "%H:%M" -ic "nick.allen@datadoghq.com,nick@nickallen.info" -iep "title,datetime" eventsFrom:<date> to:<date>`
   - Excludes all-day events (`-ea`) and attendee lists. The `to:` date is exclusive, so use the same date for both to get a single day.
   - Use calendar data to explain gaps in the Timeline (e.g., no commits from 10am-noon because of back-to-back meetings).

7. **Claude Code CLI session history** (`~/.claude/history.jsonl`):
   Each line is a JSON object with `timestamp` (ms epoch), `project` (working directory), and `display` (user prompt text). Filter to entries where the timestamp falls on `<date>`.
   - Use this to build the **Timeline** section. It shows what was being worked on, when, and in which project, filling gaps that external sources miss (e.g., code review iterations, debugging sessions, decision-making that didn't produce a commit or PR).
   - Cross-reference with the other sources to add context: a prompt asking about a PR can be matched to the PR data, a `/clear` indicates a session reset, project switches show context changes.
   - Do not quote prompts verbatim in the notes. Summarize the activity.

8. **Claude desktop app sessions** (`~/Library/Application Support/Claude/local-agent-mode-sessions/*/*/local_*/`):
   Each `local_*` directory is a session. To find sessions active on `<date>`:
   - Read `audit.jsonl` in each session directory. Each line is a JSON object. User messages have `"type": "user"` and `"_audit_timestamp"` (ISO 8601 UTC). Filter to entries where the timestamp falls on `<date>`.
   - Extract the project name from `.projects/<id>/metadata.json` (field: `name`).
   - List documents created in `.projects/<id>/docs/` and `outputs/`.
   - To summarize activity: extract user messages for the target date (same filtering as above). Summarize the topics and progression. Do not quote prompts verbatim.
   - Timestamps are UTC. Convert to local time for the Timeline.
   - This source complements the CLI history. The desktop app is used for research, exploration, and writing that doesn't happen in a terminal. Sessions may produce documents and artifacts rather than code.

## Sections

### Summary

A concise highlight reel at the top of the daily notes, immediately after the
dated heading. Contains three optional categories, each prefixed with a label:

- **Win:** A capability that now exists or a problem that's now solved. Describe
  what the system or team can do now that it couldn't before. Keep implementation
  details (PRs, commits) in the work stream sections.
- **Challenge:** Friction that consumed meaningful time. Specific and
  time-bounded when possible (e.g., "1.5 hours debugging X before discovering
  Y"). Useful for spotting systemic patterns and explaining lighter output days.
- **Lesson:** Knowledge gained that changes future behavior. General and
  forward-looking. Should describe what you'd do differently next time, not just
  what went wrong.

Only include categories that have genuine entries. If no wins, challenges, or
lessons occurred, omit the section entirely. Do not fabricate or inflate items to
fill space. A day with one win and no lessons is fine.

Each item is a single bullet, one to two sentences. Aim for 2-5 items total
across all categories on a typical day.

### Work Streams

The primary structure. Organize all evidence (PRs, commits, Slack, Confluence, Jira) under the goal it was working toward, not the data source it came from.

Each work stream has:
- **Title** — a short name describing the goal, derived from the evidence. Do not use JIRA IDs as titles. When multiple work streams relate to the same high-level project or initiative, prefix them with the project name (e.g., "Human-in-the-Loop: Interview UI", "Human-in-the-Loop: Recipient Identity").
- **Summary** — 1-3 sentences describing what was being accomplished and its current status.
- **Jira** — if the work stream is tracked by one or more JIRAs, list them as bullets with links (e.g., `[K9BITSAI-1272](https://datadoghq.atlassian.net/browse/K9BITSAI-1272) — summary — status`). Not every work stream has a JIRA.
- **PRs** — related PRs with repo, number, status, approvers.
- **Commits** — with author-date timestamps, only commits authored on the target date.
- **Activity** — notable decisions, Slack conversations, Confluence edits, staging validation, CI issues tied to this stream.

Use an **Ad Hoc** work stream for activity that doesn't belong to a specific goal: one-off Confluence comments, team discussions, tooling, demos, etc. Group related items under bold sub-headings within Ad Hoc.

### Timeline

Chronological summary of the day's work, built from Claude session history, commit timestamps, calendar events, and other timestamped sources. Show what was being worked on in each block of time, not individual prompts.

- Always put the time first in every entry, including merge events and meetings (e.g., `**~2:20pm — dd-source #395572 merged**`, not `**dd-source #395572 merged ~2:20pm**`).
- Inline meetings directly in the timeline rather than listing them separately.
- Use meetings and calendar events to explain gaps in coding activity.
- Exclude calendar events from the user's wife (Danixa).
- Exclude "Focus time" blocks — these are recurring and don't add information.

### Up Next (always the last section)

A prioritized punch list of what needs attention next. Source it from the evidence:
- Work streams with status other than "Done" (draft PRs, in-progress Jira tickets)
- The last entries in Claude session history (what was actively being worked on when the day ended)
- Slack threads that need follow-up, PR feedback not yet addressed, staging validations deferred
- Upcoming calendar events that require preparation

Each item should be one actionable line. Note blockers where relevant (e.g., "waiting on review from X" vs. "need to write code"). Order by priority: what's blocking others first, then what's closest to done, then everything else.

## Prior-day context

Before drafting, read the most recent existing note in `Working Notes/` for context. Work streams often span multiple days. Reference prior-day context to:
- Describe what a work stream was continuing from (e.g., "Continuing Thursday evening's burst of work...")
- Avoid restating background that's already established
- Track status changes across days

## Process

1. Gather all data sources in parallel, including reading the prior day's note.
2. Identify work streams from the evidence. Name them based on the goal, not the JIRA ID.
3. Draft the full update.
4. Present the draft for review before writing to the file.
5. On confirmation, append to the note.
