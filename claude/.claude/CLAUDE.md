# Writing Style
- Avoid emdashes. Use periods, commas, or restructure the sentence instead.
  Emdashes are acceptable only in rare cases where no alternative reads naturally.

# Tone & Interaction Style
- Be a critical peer reviewer. Be direct and honest — no flattery, affirmation,
  or emotional framing.
- If something is unclear or flawed, say so explicitly and explain how to fix it.
- If asked to review a resource (Confluence page, PR, etc.) and you cannot access
  it, report the access problem immediately — do not attempt workarounds.
- When editing writing or communications (Slack messages, PR descriptions, slide
  decks, Jira tickets), present a draft and wait for feedback. Do not
  over-elaborate — prefer the user's phrasing and framing over your own.
- When a decision involves judgment (approach, naming, structure), present options
  rather than deciding autonomously.

# Planning
- Use feature branches named `nick.allen/<JIRA-ID>/<goal-of-change>`.
  If the JIRA ID or goal is unknown, ask.
- Before implementing non-trivial features, use agents to study the surrounding
  codebase for existing patterns. Summarize conventions found before proposing a
  plan.
- Plan down to the commit level. Each commit should focus on a single theme, step,
  or stage leading toward the goal.
- Group commits into PRs. A PR should not span multiple services — split the work
  if it does.
- Keep PRs small. Smaller PRs are easier to review. When a feature is too large
  for one PR, split it across stacked PRs.
- If refactoring existing code would make the functional change clearer, plan it
  as separate preceding commits or PRs.
- Every PR plan must include staging validation steps. These steps should be
  executable by Claude unless they explicitly require a human (e.g., UI
  verification). If a change alone isn't observable in staging (e.g., a new proto
  definition), extend the scope so something can be validated — at minimum, the
  service should process and log the new data.

# Implementation
When directed to implement a planned change:
1. Implement each commit per the plan.
2. Open the PR in draft status. When implementing stacked PRs, branch each
   subsequent PR off the previous PR's branch.
3. Run a self-review using parallel agents, each focused on a separate concern
   (correctness, conventions, test coverage, security).
4. Fix obvious issues found by self-review. For non-obvious findings or those
   requiring significant changes, present them for user review before acting.
5. Ensure CI is green before proceeding.
6. Run staging validation steps from the plan using available skills. Report
   results.
7. Update the PR description, checking off validation steps that passed.
8. Verify the active branch before pushing.
9. After completing, explicitly state: what files were modified, whether changes
   are committed, whether they are pushed, to which branch, and whether tests
   passed.
9. Never mark a PR as ready for review unless explicitly told to.

# Code Style
- Only add comments to tricky, hard-to-follow logic. Use naming and extraction
  instead of comments for simple code.
- Do not refactor, add abstractions, or "improve" code beyond what was requested.
- Do not add error handling for impossible conditions.
- Don't prefix request/response types with the transport layer (e.g.,
  `FooHTTPRequest`). Just `FooRequest` — the package already provides context.
- Don't concatenate constants from other constants. Write full literal strings so
  identifiers are grep-able (e.g., `"ai-security-interview.yes"`, not
  `actionIDPrefix + "yes"`).
- Go doc comments: first line should be a simple statement of what the
  function/struct does. Following lines explain why — constraints, non-obvious
  choices, or context that isn't clear from the signature.
- Follow existing codebase conventions exactly. Before proposing API paths, handler
  names, actor keys, or naming patterns, grep the codebase for existing examples
  and match them. Do not invent naming conventions.
- Don't use blank lines to separate sequential setup statements within a function.
  Use blank lines to separate logical sections (e.g., setup vs act vs assert) or
  groups of unrelated logic, not individual declarations.

# Commits
- Never include Claude attribution in commit messages.
- Commits must be GPG/SSH signed.
- Prefix with the JIRA number if known. Infer from branch name if it matches a
  pattern like `PROJ-1234/...`. Keep to 1-2 concise sentences.

# PR Description
- Title: Describe the capability being added or changed, not the
  implementation. Focus on what the system can do now, not how it's built.
- Structure:
  - `### What` — 1-3 sentences describing the capability being added or
    changed, written for someone who hasn't seen the code. Focus on what
    the system can do now that it couldn't before, not how it's built.
    Follow with bullets on how: implementation choices that affect
    behavior, interfaces, or operational properties. Skip details
    (function names, arguments, code structure) visible in the diff.
  - `### Why` — Explain the motivation: what problem this solves or what goal it
    advances. Reference the JIRA ticket at the end of the explanation if known.
  - `### Validation` — Describe staging validation steps and their expected
    results. These are intended to be run by Claude using available skills.
    Steps requiring a human should be marked with `TODO/Human`.
- Write for a reviewer who hasn't seen the code yet. Be concise — no filler.

# Testing
- Run unit tests before calling a code change finished.
- Do not run unit tests prematurely — only when the change is ready to validate.

# Go Testing
- Use the testify `require` package, not `assert`, so tests fail fast on the first
  failure.
- Use table-driven tests in most cases. Name each test case "Should X" or
  "Should X when Y".
- Every test case must follow the same code path — no `if`/`switch` on specific
  cases. Capture variation as fields in the test table (e.g., a `setup` or
  `assert` function field), or use a separate test function.

# PR Feedback
When directed to address PR feedback:
- Read all open review comments before making changes.
- Categorize by severity (must-fix vs nice-to-have).
- Address each must-fix with a separate commit, running tests between each.
- Don't push until all fixes pass locally.
