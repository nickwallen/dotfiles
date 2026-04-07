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

# Tools
- Prefer `rg` (ripgrep) for code search. It is faster than `grep` and `find`.
  Examples: `rg 'pattern'` instead of `grep -r 'pattern'`,
  `rg --files -g '*.go'` instead of `find . -name '*.go'`.
- **Confluence Page Updates**: When updating Confluence pages via the Atlassian
  MCP, **ALWAYS** use the ADF (Atlassian Document Format) instead of Markdown if
  the page contains complex formatting (tables, expands, columns). Read as ADF,
  save locally, modify via Python AST traversal, write back as ADF, and delete
  local files. For blog posts, pass `contentType: "blog"` to
  `updateConfluencePage` — the default `page` type returns 404 for blog post IDs.

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
- Every PR plan must include staging validation steps that prove to a
  skeptical observer that the change solves the stated problem. Steps should
  be executable by Claude unless they explicitly require a human (e.g., UI
  verification). If a change alone isn't observable in staging (e.g., a new
  proto definition), extend the scope so something can be validated — at
  minimum, the service should process and log the new data.

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
- Don't concatenate constants from other constants. Write full literal strings so
  identifiers are grep-able (e.g., `"ai-security-interview.yes"`, not
  `actionIDPrefix + "yes"`).
- Follow existing codebase conventions exactly. Before proposing API paths, handler
  names, actor keys, or naming patterns, grep the codebase for existing examples
  and match them. Do not invent naming conventions.
- 120-character line limit for new code. Do not reformat existing lines that
  exceed this limit.
# Go
- Write dense Go. Only use blank lines to separate distinct logical sections
  within a function (e.g., setup vs act vs assert, or between unrelated blocks).
  Do not add blank lines before return, around error checks, between sequential
  statements, or for "readability."
- Never write single-line function bodies. Always use standard multi-line
  form, even for trivially short functions.
- When a function or method signature exceeds the line limit, put each
  parameter on its own line. Do not group parameters that share a type
  onto one line.
- Define interfaces where they are used, not where they are implemented.
- Don't prefix request/response types with the transport layer (e.g.,
  `FooHTTPRequest`). Just `FooRequest` — the package already provides context.
- Doc comments: first line should be a simple statement of what the function/struct
  does. Following lines explain why — constraints, non-obvious choices, or context
  that isn't clear from the signature.
- Use the testify `require` package, not `assert`, so tests fail fast on the first
  failure.
- Use table-driven tests in most cases. Name each test case "Should X" or
  "Should X when Y".
- Every test case must follow the same code path — no `if`/`switch` on specific
  cases. Capture variation as fields in the test table (e.g., a `setup` or
  `assert` function field), or use a separate test function.
- When working in dd-source, generate mocks with gomock via BUILD.bazel
  `mockgen` rules, not by hand. Follow the pattern in neighboring `mock/`
  directories.

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

# Staging Validation
The goal of staging validation is to prove to a skeptical observer that the
deployed change actually solves the stated problem in a production-like
environment. CI tests verify logic in isolation. Staging validation verifies
the deployed change works in context.

Good staging validation steps:
- Exercise the real end-to-end path that the change affects, not a
  simplified proxy for it.
- Observe real system behavior (logs, metrics, traces, API responses) rather
  than asserting on internal state.
- Verify infrastructure concerns that CI cannot: permissions, connectivity,
  config, schema migrations, feature flags, credential access.
- Confirm the deployment itself succeeded: service starts, health checks
  pass, no crash loops or error spikes.
- Are safe to run repeatedly without corrupting shared staging state.
- Connect back to the original problem. If the motivation is "users see
  error X," the validation should show that error X no longer occurs, not
  just that the new code path executes.

When asked to validate a change in staging, look for an AGENTS.md in the
service directory being validated. Read it before planning or executing
validation steps.

# Testing
- Run unit tests before calling a code change finished.
- Do not run unit tests prematurely — only when the change is ready to validate.

# PR Feedback
When directed to address PR feedback:
- Read all open review comments before making changes.
- Categorize by severity (must-fix vs nice-to-have).
- Address each must-fix with a separate commit, running tests between each.
- Don't push until all fixes pass locally.
