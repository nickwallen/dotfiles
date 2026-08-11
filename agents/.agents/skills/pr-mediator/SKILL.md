---
name: pr-mediator
description: Analyze pending PR review feedback, explain reviewer intent with full context, and draft responses. Use when the user asks to review PR feedback, check PR comments, respond to reviewers, see what reviewers said, address PR review comments, or handle PR discussions.
user-invocable: true
---

Help me review and respond to pending PR feedback.

## Input Handling

`$ARGUMENTS` can be:

1. **Empty** — Scan all my open PRs across all GitHub repos.
2. **A PR number** (e.g., `1234`) — Focus on that PR in the current repo
   (detected from the working directory's git remote).
3. **A PR URL** (e.g., `https://github.com/DataDog/dd-source/pull/1234`) —
   Extract the owner, repo, and PR number from the URL.
4. **A comment URL** (e.g., a URL containing `/pull/1234#discussion_r56789`
   or `/pull/1234#pullrequestreview-56789`) — Extract owner, repo, PR
   number, and jump directly to that specific thread in Phase 4.

When a PR number is given without a repo, detect from the working directory:
```
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

## Phase 1: Collect

1. Find open PRs with pending review feedback. The approach depends on input:

   **No args (global scan):**
   ```
   gh search prs --author="@me" --state=open --json repository,number,title,url
   ```
   This searches across all repos. Include both draft and ready-for-review PRs.

   **PR number (current repo):**
   ```
   gh pr view <number> --repo <owner/repo> --json number,title,url,headRefName,isDraft
   ```

   **PR or comment URL:**
   Extract owner/repo/number from the URL and fetch that single PR.

2. For each PR, fetch all review threads using the GraphQL API:
   ```
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $pr: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $pr) {
           body
           reviewThreads(first: 100) {
             nodes {
               isResolved
               comments(first: 50) {
                 nodes {
                   id
                   databaseId
                   author { login }
                   body
                   path
                   line
                   createdAt
                 }
               }
             }
           }
         }
       }
     }' -F owner=<owner> -F repo=<repo> -F pr=<number>
   ```

3. Filter to actionable threads. A thread needs my attention if ALL of:
   - Thread is NOT resolved
   - The most recent comment in the thread is NOT from me
   - The PR is mine (I authored it), whether draft or ready-for-review

   Discard PRs that have zero actionable threads.

4. For each actionable thread, fetch the diff hunk around the referenced
   file and line so the comment can be understood in context.

5. Also fetch the PR description body for each PR.

If the input was a comment URL pointing to a specific thread, still collect
all threads (for dashboard context) but skip ahead to Phase 4 for the
targeted thread after completing Phase 2.

## Phase 2: Spider for Context

For each PR with actionable feedback:

1. Parse the PR description, branch name, and comment bodies for references:
   - JIRA ticket IDs (e.g., `K9BITSAI-1234`, `BITS-567`, `LVSRCH-890`)
   - Confluence links (any `datadoghq.atlassian.net/wiki/` URL)
   - Other PR references (`#1234`, `owner/repo#1234`)

2. Fetch each discovered reference:
   - JIRA tickets: use `mcp__atlassian__getJiraIssue` to get the ticket
     description, status, and linked issues
   - Confluence pages: use `mcp__atlassian__getConfluencePage` to get the
     page content
   - Related PRs: use `gh pr view <number> --repo <owner/repo> --json body,title,comments`

3. At each fetched resource, scan for additional references (linked JIRA
   issues, Confluence links in ticket descriptions, etc.). Recurse up to
   2 levels deep. Do not re-fetch resources already visited.

4. Summarize all gathered context into a concise context bundle per PR.
   This bundle is internal working memory, not shown to the user directly.

Run Phase 1 and Phase 2 using parallel agents where possible (e.g., one
agent per PR for context spidering).

## Phase 3: Dashboard

Present a numbered summary of all actionable items:

```
Pending Review Feedback

PR #1234: Add rate limiting to intake endpoint (2 threads)
  1. @reviewer-a on handler.go:45 — [one-line summary of what they're asking]
  2. @reviewer-b on config.go:12 — [one-line summary of what they're asking]

PR #5678: Update schema migration (1 thread)
  3. @reviewer-c on migrate.go:30 — [one-line summary of what they're asking]
```

Let the user pick an item by number, or say "done" to end the session.
If there are many items, the user can browse the list before committing.

## Phase 4: Understand

For the selected item, present two things:

1. **The reviewer's comment** — quoted directly, with the file path and
   diff hunk for reference.

2. **A summary** — a short paragraph (2-4 sentences) that synthesizes
   everything you know into a clear picture of what the reviewer wants and
   why. This summary should account for:
   - The emotional register (frustrated? curious? nitpicking?)
   - The deeper context (does this relate to an RFC, JIRA constraint, or
     prior discussion?)
   - Whether this is blocking, a suggestion, or just a question
   - The thread history if there are multiple exchanges

   Do not break these into separate labeled sections. Weave them into a
   single cohesive summary that reads naturally. The summary should leave
   the user with a complete understanding of the situation in one read.

**Then use AskUserQuestion** with these options:
- "Respond" — proceed to Phase 5
- "Skip" — return to the dashboard
- "Done" — end the session

## Phase 5: Respond

Generate 2-3 candidate response options based on the analysis and context.

Common response types (not all will apply to every comment):
- **Agree and describe fix** — acknowledge the issue and state what you'll change
- **Push back with rationale** — explain the constraint or context that
  justifies the current approach
- **Clarify or ask a question** — when the comment is ambiguous or you need
  more information before deciding
- **Acknowledge and defer** — agree it's worth addressing but not in this PR

**Before presenting any option to the user, run every candidate through
the Challenge Review (Phase 6).** Launch challenge reviews for all
candidates in parallel using subagents.

After challenge reviews complete:
- **Drop** any option with "weak" confidence or significant logical gaps.
  Do not show it to the user.
- **Revise** any option where the challenge review suggested edits. Apply
  the edits and note what changed.
- **Keep** options with "strong" or "moderate" confidence as-is.

Then present the surviving options. For each option show:
- A label: "Option N: [short description]" (e.g., "Option 1: Agree and fix")
- The full draft response text
- A one-line challenge summary (confidence + any notable caveats)
- Likely follow-up questions the reviewer might ask

After presenting all options, **use AskUserQuestion** to let the user
pick. Each option's label should match the "Option N: ..." label above.
The description should be the one-line challenge summary. Always include
a "Skip" option (return to dashboard). The automatic "Other" option
covers writing a custom response.

If the user selects Other and provides a rough draft, refine it for
clarity, conciseness, and tone, then run it through the challenge review
before showing the polished version.

When the user picks an option:
1. Show the final response text
2. **Use AskUserQuestion** to confirm before posting. This is a hard gate:
   never post without explicit confirmation via this tool. Options:
   - "Post" — post the response via `gh api`
   - "Edit first" — user provides edits via Other, then confirm again
   - "Cancel" — discard and return to dashboard
3. If confirmed, post via `gh api` (see Posting section below)
4. Return to the dashboard

## Phase 6: Challenge Review

Run each draft response through a critical review using a subagent before
it is shown to the user. The subagent's job is adversarial: find
weaknesses before the reviewer does.

Launch an Agent with subagent_type "general-purpose" for each candidate
response. The subagent must:

1. **Verify claims against code.** Read the actual source files referenced
   in the diff hunk and comment thread. Does the code do what the response
   claims? Are there edge cases the response glosses over? If the response
   says "this only happens when X," confirm that's true by reading the
   code path.

2. **Predict follow-up questions.** What would a skeptical reviewer ask
   next? Identify 1-2 likely follow-ups. Flag any that the response
   doesn't address but should.

3. **Check for logical fallacies.** Is the response appealing to authority
   ("this is the standard pattern") without evidence? Making a straw man
   of the reviewer's concern? Deflecting rather than addressing? Claiming
   something is impossible that's merely unlikely?

4. **Rate confidence.** strong/moderate/weak based on how well the code
   supports the response. "Strong" means reading the code confirms every
   claim. "Weak" means claims the code doesn't clearly support.

The subagent returns:

```
Confidence: strong | moderate | weak
Code verified: [which claims were confirmed by reading the source]
Gaps: [claims not fully supported, or edge cases missed]
Likely follow-ups: [1-2 questions the reviewer might ask next]
Fallacies: [any logical issues, or "none"]
Suggested edits: [specific text changes, or "none"]
```

## Posting Responses

Post replies to review comment threads using:
```
gh api repos/<owner>/<repo>/pulls/<pr_number>/comments/<comment_id>/replies \
  -f body="<response>"
```

Where `<comment_id>` is the `databaseId` of the most recent comment in the
thread (the one being replied to).

After posting, show a brief confirmation and return to the dashboard.

## Response Drafting Guidelines

- Match the formality level of the reviewer's comment
- Be direct and concise. No filler ("Great point!", "Thanks for the review!")
- If agreeing: state what you'll change and why they're right
- If pushing back: lead with the constraint or context, then your conclusion
- If the emotional read is frustrated or strongly opposed: acknowledge their
  concern before responding to the substance. One sentence, not performative.
- Never be defensive. If the reviewer is wrong, explain why neutrally. If
  they're right, say so.
- Keep responses short. One paragraph unless the topic genuinely requires more.
- Use context from spidered resources to make responses substantive: reference
  specific decisions from RFCs, constraints from JIRA tickets, or prior
  discussions rather than making vague claims.
