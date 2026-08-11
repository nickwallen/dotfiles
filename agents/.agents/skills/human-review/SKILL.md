---
name: human-review
description: Use when reviewing code changes before committing, when the user wants to walk through agent-made changes, or when the user invokes /human-review
user-invocable: true
---

# Human Review

Walk through code changes as a structured narrative before committing.

## Change Detection

Determine what to review by checking git state in priority order:

1. Run `git diff` — if output is non-empty, review unstaged changes
2. Run `git diff --cached` — if output is non-empty, review staged changes
3. Run `git show HEAD` — review the last commit

Use only the first non-empty source. Do not merge sources.

If all three are empty, report "No changes to review" and stop.

Store which source you're using (unstaged, staged, or last-commit) — you'll
need it for the commit step.

## Preparation Phase

Before presenting anything to the user, generate ALL steps upfront. This
ensures instant navigation between steps during the review.

1. Analyze the full diff and group changes into logical steps. Group by
   concern, not by file. Examples: "added the validation handler," "updated
   tests for validation," "wired the new route."
2. Order steps in a logical narrative sequence (e.g., foundation first, then
   features, then tests), not by file path.
3. For each step, pre-generate the complete presentation text including:
   - **Title** — short name for the logical change (imperative voice)
   - **Why** — one sentence explaining the reasoning. Use session context if
     available (you may remember why you made these changes). If invoked cold
     with no session context, infer from the diff and surrounding code.
   - **Files** — list of files in this step with modification type (M/A/D)
     and line counts (+N -N)
   - **Risk** — critical risks or tradeoffs only. Omit if none.
   - **Code** — the relevant code changes, formatted as described below
4. Once all steps are generated, begin the walkthrough.

## Step Presentation

Present one step at a time. Since all steps were pre-generated, display
each one immediately without re-analyzing the diff. Use this format:

━━━ Step {n}/{total}: {title} ━━━

WHY: {reasoning}

CHANGES:
  {M/A/D}  {filepath}  (+N -N)
  ...

RISK: {critical risk, only if present — omit this line otherwise}

─── {filepath} ───
{diff-formatted code block showing changes}

─── {filepath2} ───
{diff-formatted code block showing changes}

[a] accept    [q] question    [r] reject

### Code Formatting

Show code changes as plain text (no fenced code blocks) to avoid rendering
issues on narrow terminals.
- Prefix added lines with `+`
- Prefix removed lines with `-`
- Prefix context lines with a space (` `) so all lines align
- Include enough surrounding context (3-5 lines) to understand placement

For large changes in a single file, show the most important hunks and note
"[f] show full diff" as an option. If the user presses `f`, show the
complete diff for the current step.

For new files, show the full file content.

## Per-Step Actions

After presenting a step, wait for the user's single-character input:

- **`a`** — Accept this step. Record it as accepted. Move to the next step.
- **`q`** — Question. Ask the user to type their question. Answer it using
  your session context and codebase knowledge (read files if needed). After
  answering, re-present the same step in full (title, WHY, CHANGES, code
  diffs, action prompt). Do not abbreviate the re-presentation.
- **`r`** — Reject. Ask the user to type a directive describing what to
  change. Immediately rework the code based on the directive (discuss the
  approach with the user if needed, then implement the changes). Once
  rework is complete, restart the entire review from step 1 with fresh
  change detection and new step grouping. Do not continue to the next step.
- **`f`** — Show the full diff for the current step (when truncated).

Track decisions for each step as you go.

## Review Outcomes

When the user moves past the last step, present a summary:

━━━ Review Summary ━━━
Step 1: {title} ✓
Step 2: {title} ✓
Step 3: {title} ✗ "{directive}"
Step 4: {title} ✓

If any steps lack a decision, prompt the user to go back and decide.

### All Accepted

If every step is accepted:

For **unstaged** changes:
1. Stage the changed files (`git add` the specific files from the diff)
2. Generate a commit message following the user's preferences:
   - GPG/SSH signed
   - Prefixed with JIRA ticket number if inferrable from the branch name
   - 1-2 concise sentences
   - No Claude attribution
3. Show the proposed commit message and ask the user to confirm or edit
4. On confirmation, run the commit
5. Show the commit hash and exit

For **staged** changes:
1. Files are already staged. Skip to generating the commit message (same
   rules as above).

For **last-commit** changes:
1. The commit already exists. Report "Review complete. Commit {hash}
   accepted as-is." and exit. Do not amend or create a new commit.

### Rejection and Rework

Rejection is handled immediately, not batched. When the user rejects a step:

1. The user provides a directive describing what to change
2. Discuss the approach if needed, then implement the changes. You are not
   constrained to only the rejected step's files. Modify whatever is needed
   to address the feedback, including files from previously accepted steps.
3. Once rework is complete, restart the entire review from step 1. Re-run
   change detection fresh (the source may have shifted, e.g., from
   last-commit to unstaged). Re-analyze ALL changes, generate new steps,
   and present the walkthrough again.
4. Repeat until all steps are accepted and committed.
