---
name: request-review
description: Use when the user wants to request a code review, post a PR to a team channel, ask for reviewers, or share a PR in Slack for review. Triggers on "request review", "post PR", "ask for review", "share PR".
user-invocable: true
---

Post a review request for my current PR to the team Slack channel.

## Input Handling

`$ARGUMENTS` can be:

1. **Empty** -- use the current branch's open PR.
2. **A PR number** (e.g., `1234`) -- focus on that PR in the current repo.
3. **A PR URL** -- extract owner, repo, and PR number from the URL.

When a PR number is given without a repo, detect from the working directory:
```
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

## Options

Parse these from `$ARGUMENTS` if present. Prompt only when information
cannot be inferred.

- `--dry-run` -- send as a DM to myself (user ID `U037S35RD25`) instead
  of posting to the team channel. Use this for testing.
- Reviewers -- mentioned by name in the arguments (e.g., "cc Sezen and
  Deodat"). Look up Slack user IDs with `slack_search_users`.
- Stack position -- e.g., "2/3" or "this is PR 2 of 3".
- Extra context -- any freeform text the user provides that should appear
  as an additional line in the message.

## Phase 1: Gather PR Context

1. Fetch the PR metadata:
   ```
   gh pr view <number> --repo <owner/repo> --json number,title,body,url,headRefName,isDraft,files
   ```

2. Infer the Jira ticket ID from the branch name if it matches a pattern
   like `user/PROJ-1234/...`.

3. Read the PR description body to understand the change.

4. Classify each file into categories based on filename:
   - **prod**: `.go` files (not test/mock/generated), `.py` files (not
     test), `.ts`/`.tsx`/`.js`/`.jsx` files (not test)
   - **test**: `_test.go`, `test_*.py`, `*_test.py`, files under `tests/`
     directories, `*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx`
   - **generated**: `.mockgen.go`, `.pb.go`, `_grpc.pb.go`, `.generated.go`
   - **config**: everything else (`.bazel`, `.bzl`, `.proto`, `.yaml`,
     `.json`, `.md`, `.sql`, `CODEOWNERS`, etc.)

5. Compute stats. The goal is to report lines that take real reviewer
   attention, not boilerplate.
   - Fetch the raw diff: `gh pr diff <number> --repo <owner/repo>`.
   - For **prod** and **test** files, count added (`+`) and removed (`-`)
     lines **excluding** lines that require little reviewer attention:
     - blank / whitespace-only lines
     - Go `//` line comments (after leading whitespace)
     - Go `/* ... */` block comments (single-line and multi-line spans)
     - Python `#` line comments
     - Python triple-quoted docstrings (opening through closing)
     - TypeScript/JavaScript `//` and `/* ... */` comments
   - For **generated** and **config** files, count additions/deletions
     verbatim — no filtering (these buckets are already "other" and
     typically small).
   - **prod_add/prod_del**: code-only sums across prod files.
   - **test_add/test_del**: code-only sums across test files.
   - **other_add/other_del**: raw sums across generated + config.
   - **total_files**: count of all changed files.
   - The reported numbers will **not** sum to GitHub's raw diff total;
     that is intentional and reflects filtered prod/test counts.

6. Determine the size label based on **prod code lines added** (the
   filtered count from step 5, excluding comments and blanks):

   | Label | Prod lines added | Emoji |
   |-------|-----------------|-------|
   | XS    | 0-25            | `:tiny:` |
   | S     | 26-100          | `:t-shirt-small-dark:` |
   | M     | 101-250         | `:t-shirt-medium-dark:` |
   | L     | 251-500         | `:t-shirt-large-dark:` |
   | XL    | 501+            | `:dumpstr-fire:` |

7. Detect impacted services from file paths. The pattern
   `domains/*/apps/apis/<service>/` identifies a service. Shared libraries
   (e.g., `domains/*/libs/...`) are not services. If files change shared
   libraries and the impacted service is unclear, ask the user.

## Phase 2: Compose the Message

Build the message using Slack mrkdwn syntax.

**Line 1: PR link with title**

The PR link text should include the Jira ticket ID (if present in the PR
title or inferred from the branch) and a clear title. Read the PR
description and diff summary. If you can write a clearer or more compelling
title than the PR title, use it. Prefer active voice and concrete language.

End the line with a closing emoji. Vary the emoji across requests. Good
options: `:pray:`, `:thanks-a-bunch:`, `:prettyplease:`.

If a stack position was provided, append `(N/M)` after the `:pr:` emoji:
`:pr: (2/3) <URL|Title>`.

```
:pr: <URL|JIRA-ID Title> :emoji:
```

**Line 2: Size and stats**

Start with the size emoji, then total file count, then LOC breakdown.
Always show all categories that have changes so the numbers add up to
GitHub's total diff. Append `(other)` for generated + config files when
present. Omit a category only when it has zero additions and zero
deletions. Omit `-N` when deletions are zero within a category.

```
• :size-emoji: · 8 files · +21 -13 LOC (prod) · +98 -17 LOC (test) · +37 -14 LOC (other)
```

**Line 3: Impacted services**

```
• Impacts ai-security-agent
```

For multiple services: `• Impacts ai-security-agent, secmon-public-api`

**Optional lines (append after, each as a bullet):**
- Extra context line if the user provided one.
- `cc:` line with reviewer mentions and `:pray:` if reviewers were
  specified. Format: `• cc: <@U12345> <@U67890> :pray:`

**Tone:** Direct, casual, no filler.

### Examples

Standard review request (M, with other):
```
:pr: <https://github.com/DataDog/dd-source/pull/396369|K9BITSAI-1192 Review investigation verdicts using interview responses> :pray:
• :t-shirt-medium-dark: · 9 files · +247 -10 LOC (prod) · +527 LOC (test) · +12 -3 LOC (other)
• Impacts ai-security-agent
```

Small PR (XS, no other):
```
:pr: <https://github.com/DataDog/dd-source/pull/395064|K9BITSAI-1272 Expose resolved recipient in external HTTP response> :thanks-a-bunch:
• :tiny: · 2 files · +2 LOC (prod) · +40 LOC (test)
• Impacts secmon-public-api
```

Config-only change (XS):
```
:pr: <https://github.com/DataDog/dd-source/pull/402605|K9BITSAI-1272 Enable SNAP_ISOLATED for test drive queue isolation> :thanks-a-bunch:
• :tiny: · 1 file · +2 -1 LOC (other)
• Impacts ai-security-interviewer
```

XL dumpster fire:
```
:pr: <https://github.com/DataDog/dd-source/pull/000000|K9BITSAI-0000 Example XL PR that should probably be split> :pray:
• :dumpstr-fire: · 25 files · +1200 -80 LOC (prod) · +2000 LOC (test) · +50 -8 LOC (other)
• Impacts ai-security-agent, ai-security-interviewer, secmon-public-api
```

With reviewers and context:
```
:pr: <https://github.com/DataDog/dd-source/pull/12345|K9BITSAI-1191 Handle user's Slack response> :pray:
• :t-shirt-small-dark: · 12 files · +297 -26 LOC (prod) · +323 -28 LOC (test) · +8 -4 LOC (other)
• Impacts ai-security-interviewer
• cc: <@U0878B8HZQ9> <@U09FP40770D> :pray:
```

Stacked PR:
```
:pr: (2/3) <https://github.com/DataDog/web-ui/pull/54321|[Frontend] Add Start Interview button to investigation panel actions menu> :prettyplease:
• :t-shirt-medium-dark: · 8 files · +328 -4 LOC (prod) · +163 LOC (test)
• Impacts web-ui
```

## Phase 3: Review and Send

1. Present the composed message to the user as a draft. Show it in a code
   block so formatting is visible.

2. **Use AskUserQuestion** to let the user approve or edit. Options:
   - "Send" -- post the message
   - "Edit" -- user provides changes via Other, then confirm again
   - "Cancel" -- discard

3. When approved, determine the target:
   - **Normal mode:** post to `#k9-bits-ai-security-dev` (channel ID
     `C08KXLN0XRC`).
   - **Dry-run mode:** DM to self (user ID `U037S35RD25`).

4. Send using `slack_send_message` with the channel ID and composed
   message.

5. Return the message link to the user.
