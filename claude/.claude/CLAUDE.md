# Tone & Interaction Style
- Be a critical peer reviewer. Be direct and honest — no flattery, affirmation, or emotional framing.
- If something is unclear or flawed, say so explicitly and explain how to fix it.

# Code Style
- Only add comments to tricky, hard-to-follow logic. Use naming and extraction instead of comments for simple code.
- Do not refactor, add abstractions, or "improve" code beyond what was requested.
- Do not add error handling for impossible conditions.

# Branching & Change Management
- Work in feature branches off main: `nick.allen/<JIRA-ID>/<goal-of-change>`. If the JIRA ID or goal is unknown, ask.
- Break large changes into multiple logical, sequential commits. Keep each commit reviewable on its own.
- Separate functional changes from refactoring — different commits at minimum, ideally separate PRs.
- If a change is too large for one PR, split it across stacked PRs.

# Commits
- Never include Claude attribution in commit messages.
- Prefix with the JIRA number if known. Infer from branch name if it matches a pattern like `PROJ-1234/...`. Keep to 1-2 concise sentences.

# PR Description
- Structure:
  - `### What` — Start with 1-3 sentences summarizing the change at a high level. Follow with bullet points covering the specific, notable changes (behavioral differences, new/removed components, config changes). Skip obvious mechanical details a reviewer can see in the diff.
  - `### Why` — Explain the motivation: what problem this solves or what goal it advances. Reference the JIRA ticket if known.
  - `### Validation` — Describe manual validation steps performed in staging (not unit tests — those are assumed). If validation hasn't been done yet, use `- [ ] TODO`.
- Write for a reviewer who hasn't seen the code yet. Be concise — no filler.

# Testing
- Run unit tests before calling a code change finished.
- Do not run unit tests prematurely — only when the change is ready to validate.

# Go Testing
- Use the testify `require` package, not `assert`, so tests fail fast on the first failure.
- Use table-driven tests in most cases so that multiple scenarios can be tested. Name each test case "Should X" or "Should X when Y".
- Every test case must follow the same code path in the test body. No `if`/`switch` on specific test cases. If cases need different behavior, capture the variation as fields in the test table (e.g., a `setup` or `assert` function field), or use a separate test function.
