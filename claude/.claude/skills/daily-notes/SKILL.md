---
name: daily-notes
description: Generate end-of-day working notes in Obsidian from Git, GitHub PRs, Jira, and Slack activity
user-invocable: true
---

Generate my daily working notes for today (or the date passed as `$ARGUMENTS`, defaulting to today).

## File Location

Append to (do not overwrite) the note at:
`/Users/nick.allen/Library/CloudStorage/Dropbox/Documents/Obsidian Vaults/Datadog/Working Notes/<YYYY-MM-DD>.md`

If the file doesn't exist, create it.

## Format Reference

Read the most recent existing note in `Working Notes/` to match the current format. The sections below describe the general structure, but always defer to the latest note's conventions.

## Data Sources

Gather from all sources in parallel:

1. **Git commits** (dd-source):
   `git log --author="Nick Allen" --since="<date>T00:00:00" --format="%H %s" --all | grep -v "Merge "`

2. **PR activity** (GitHub):
   `gh pr list --author="@me" --state=all --search="updated:>=<date>"` then check reviews on each PR via `gh api repos/DataDog/dd-source/pulls/<num>/reviews`

3. **Jira tickets** (Atlassian MCP):
   JQL: `project = K9BITSAI AND assignee = currentUser() AND updated >= "<date>" ORDER BY updated DESC`

4. **Slack messages** (Slack MCP, user ID `U037S35RD25`):
   - `from:<@U037S35RD25> on:<date>` — messages sent
   - `to:<@U037S35RD25> on:<date> -from:<@U037S35RD25>` — messages received
   - Filter out bot noise (GitHub notifications, devflow). Focus on human conversations, review requests, incidents, and cross-team interactions.

## Sections

- **PRs Merged** — number, title link, ticket, approximate merge time, who approved
- **PRs Opened** — number, title link, ticket, stacking info if applicable
- **Other PR Activity** — reviews received, PRs closed without merge, feedback addressed
- **Commits on <ticket>** — grouped by ticket/branch, summarized (not full commit messages)
- **JIRA Status** — table of active tickets with current status
- **Notes** — CI issues, cross-team interactions, staging validation, notable Slack conversations

## Process

1. Gather all data sources in parallel.
2. Draft the full update.
3. Present the draft for review before writing to the file.
4. On confirmation, append to today's note.
