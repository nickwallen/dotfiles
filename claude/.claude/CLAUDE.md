# Writing Style
- Avoid emdashes. Use periods, commas, or restructure the sentence instead.
  Emdashes are acceptable only in rare cases where no alternative reads naturally.

# Tone & Interaction Style
- Be a critical peer reviewer. Be direct and honest — no flattery, affirmation,
  or emotional framing.
- Use ASD-STE100 style in live session replies. Write short sentences. Put
  one idea in each sentence. Use active voice. Keep normal technical words.
  Do not avoid jargon that is precise and necessary. Do not use this style
  for PR descriptions, RFCs, or other written docs.
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

# Confluence
- Editing an existing page: use ADF (`contentFormat: "adf"`), not HTML or
  markdown. Fetch as ADF, change only the target text nodes, pass the whole
  document back. ADF round-trips faithfully; HTML/markdown can drop or mangle
  images, macros, tables, and mentions.
- Re-fetch right before editing and check the version. A full-body overwrite
  loses any UI edits made since your fetch.
- The MCP tools can't fetch old versions or revert — that's a human action in
  the UI (⋯ → Version history → Restore).

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
3. Run self-review per the Self-Review section.
4. Ensure CI is green before proceeding.
5. Run staging validation steps from the plan using available skills. Report
   results.
6. Update the PR description, checking off validation steps that passed.
7. Verify the active branch before pushing.
8. After completing, explicitly state: what files were modified, whether changes
   are committed, whether they are pushed, to which branch, and whether tests
   passed.
9. Never mark a PR as ready for review unless explicitly told to.

# Self-Review
- Run a self-review using parallel agents, each focused on a separate concern:
  - Correctness: logic errors, edge cases, race conditions, nil derefs.
  - Conventions: naming, file organization, patterns matching surrounding code.
  - Test coverage: missing cases, weak assertions, table-driven structure.
  - Security: injection, auth bypass, secrets in code, unsafe deserialization.
  - Deep dependencies: trace one level into constructors and functions called
    by the new code. Look for redundant dependency initialization,
    log.Fatal/panic paths, or options inconsistent with the service's
    existing setup.
  - Simplicity: run `/simplify` on changed code to find unnecessary complexity,
    dead code, or opportunities to reuse existing abstractions.
  - Language specialist: run `/go-review` for Go changes or `/py-review` for
    Python changes if the corresponding plugin is installed.
  - Reviewability: assess how hard the PR is for a human to load and verify,
    independent of correctness. Factors: production-vs-test size and changed-file
    count; single-theme focus (flag mixed feature/refactor/bugfix); presence of an
    entry point and reading path (flag unwired dead-on-arrival code); commit
    structure (logically themed, ordered, reviewable commit-by-commit); diff
    signal-to-noise (formatting churn, renames, generated files mixed with logic);
    per-file cognitive load (oversized functions, deep nesting, one file doing many
    jobs); justification for new abstractions; and verifiability (tests that
    document intent plus observable staging validation). Output a verdict
    (reviewable / split recommended / hard to review) with the factors that drove
    it and a concrete suggestion for each — most often splitting along named seams
    or adding a reading order to the description.
- Fix obvious issues automatically. For non-obvious findings or those
  requiring significant changes, present them for user review before acting.
- Check whether any relevant AGENTS.md files need updating to reflect the
  code changes (new commands, changed conventions, new services, modified
  build steps, etc.).

# Code Style
- Documentation files (README.md, AGENTS.md, PR descriptions, comments) must
  only describe what currently exists in the codebase. Never reference planned
  features, future endpoints, or unimplemented architecture. Update these files
  as each PR lands, not ahead of the code.
- Only add comments to tricky, hard-to-follow logic. Use naming and extraction
  instead of comments for simple code.
- Comments explain the code, not the change. Avoid referencing prior values,
  past bugs, or how we got here. By the time someone reads the file, the diff
  is gone and only the current state needs justifying.
- Do not add speculative abstractions or refactor code that isn't being
  changed. When writing new code, use the simplest structure that makes
  the code clear. A class is warranted when it eliminates parameter
  pairing, encapsulates related logic, or makes the code more testable.
- Do not add error handling for impossible conditions.
- Don't concatenate constants from other constants. Write full literal strings so
  identifiers are grep-able (e.g., `"ai-security-interview.yes"`, not
  `actionIDPrefix + "yes"`).
- Follow existing codebase conventions exactly. Before proposing API paths, handler
  names, actor keys, or naming patterns, grep the codebase for existing examples
  and match them. Do not invent naming conventions.
- 120-character line limit for new code. Do not reformat existing lines that
  exceed this limit.
# Python
- Order Python files top-down: main classes and functions first, helper
  functions at the bottom. In test files, put test classes above the helper
  functions they use.
- Prefer dependency injection over `unittest.mock.patch`. If a function
  is hard to test without patching module-level imports, add an optional
  parameter with a default (e.g., `client=None`, `factory_fn=get_factory`).
  Tests pass fakes directly. Patching is a symptom of non-modular code.
- Group values that are always created, passed, and used together into a
  dataclass. Use private fields, accessor properties, and methods that
  operate on the grouped data. This applies especially when the same two
  or more parameters appear across multiple function signatures.
- Avoid module-level mutable state and globals. Use framework dependency
  injection (e.g., FastAPI Depends) or constructor injection so
  dependencies are explicit and tests can substitute fakes without
  patching. Patching in tests usually means the production code has a
  hidden dependency that should be injected instead.
# Go
- Write dense Go. Only use blank lines to separate distinct logical sections
  within a function (e.g., setup vs act vs assert, or between unrelated blocks).
  Do not add blank lines before return, around error checks, between sequential
  statements, or for "readability."
- Never write single-line function bodies. Always use standard multi-line
  form, even for trivially short functions.
- Prefer keeping signatures on one line to minimize vertical space. When a
  signature exceeds the line limit, first try shortening parameter names
  (e.g., signalVerdictUpdater -> verdictUpdater, interviewStore -> ivStore)
  while keeping them unambiguous in context. Only split across lines if
  shortening names cannot bring the signature under the limit. When
  splitting, put each parameter on its own line. Do not group parameters
  that share a type onto one line.
- Order Go files: types/interfaces, constructors, main methods, then small
  helper functions at the bottom. Helpers are supporting details and
  shouldn't interrupt the primary code flow.
- Define interfaces where they are used, not where they are implemented.
- Don't prefix request/response types with the transport layer (e.g.,
  `FooHTTPRequest`). Just `FooRequest` — the package already provides context.
- Doc comments: first line should be a simple statement of what the function/struct
  does. Default to one line. Add follow-up lines only when there's a non-obvious
  constraint or trade-off the reader needs to know — not to recap implementation
  flow ("called at construction"), restate the WHAT in more detail, or describe
  how the result is consumed elsewhere. If the call sites explain it, the doc
  comment shouldn't.
- Use the testify `require` package, not `assert`, so tests fail fast on the first
  failure.
- Use table-driven tests in most cases. Name each test case "Should X" or
  "Should X when Y".
- Every test case must follow the same code path — no `if`/`switch` on specific
  cases. Capture variation as fields in the test table (e.g., a `setup` or
  `assert` function field), or use a separate test function.

# Git
- Avoid force-push unless explicitly needed. To resolve merge conflicts on a PR
  branch, merge the base branch in rather than rebasing. Merging avoids rewriting
  history and does not require a force-push.

# GitHub org: DataDog → ddoghq

Datadog is moving internal repos to a separate `ddoghq` GitHub org, one repo at a
time. Check `git remote -v` to see which org a repo is on.

Two accounts, one per org — switch to the matching one before running `gh`
(`git push` works either way; only `gh` needs the right account):

- `DataDog` org → account `nickwallen` → `gh auth switch --user nickwallen`
- `ddoghq` org → account `nick-allen_ddog` → `gh auth switch --user nick-allen_ddog`

Repos:

- `dd-source` → already on `ddoghq` (open PRs there; `DataDog/dd-source` is deprecated)

Details: https://datadoghq.atlassian.net/wiki/spaces/FF/pages/6818268479

# Commits
- Never include Claude attribution in commit messages.
- Commits must be GPG/SSH signed.
- Prefix with the JIRA number if known. Infer from branch name if it matches a
  pattern like `PROJ-1234/...`. Keep to 1-2 concise sentences.
- When committing accumulated changes, split into separate commits by logical
  theme (bug fix vs. new feature vs. refactor). Stage files explicitly per
  commit instead of `git add -A`.

# PR Description
- Title: Describe the capability being added or changed, not the
  implementation. Focus on what the system can do now, not how it's built.
  Put the JIRA ID at the end of the title, space-separated, no colon or
  parentheses (e.g. `Use async gRPC in the CrowdStrike query tool K9BITSAI-2813`).
- Structure:
  - `### What` — 1-3 sentences describing the capability being added or
    changed, written for someone who hasn't seen the code. Focus on what
    the system can do now that it couldn't before, not how it's built.
    The opening paragraph should state what changed and its impact.
    Don't repeat specifics (tool names, limits, implementation choices)
    that appear in the bullets below. Follow with bullets describing
    runtime behavior and operational properties: how events flow, what
    actors are used, what happens on failure, what conditions trigger
    the feature. Don't name packages, types, or functions the reviewer
    can see in the diff.
  - `### Why` — Explain the motivation: what problem this solves or what goal it
    advances. Put the JIRA ticket link on its own line, separated by a
    blank line from the prose.
  - `### Validation` — Describe staging validation steps and their expected
    results. These are intended to be run by Claude using available skills.
    Steps requiring a human should be marked with `TODO/Human`.
- Write for a reviewer who hasn't seen the code yet. Be concise — no filler.
- Do not hard-wrap prose in PR descriptions. GitHub renders Markdown with
  its own line wrapping. Hard wraps at 70-80 characters produce narrow,
  ragged text on GitHub. Write each sentence or bullet as a single long
  line and let the renderer wrap it.

# Staging Validation
The goal of staging validation is to prove to a skeptical observer that the
deployed change actually solves the stated problem in a production-like
environment. CI tests verify logic in isolation. Staging validation verifies
the deployed change works in context.

Before deploying, check whether the code depends on schema changes (new enum
values, columns, tables) that haven't been migrated yet. Identify PGSM
migration dependencies upfront and create them before validation, not after
a runtime failure reveals them.

When validation requires staging data with specific properties (e.g., a
record with a particular status or verdict), query the database directly to
find matching records. Don't guess from logs or try random IDs.

## Finding investigations by verdict

Query the `security_agent_investigation_steps` table, filtering on
`step_id = 'signalTriageVerdictStep'`. The verdict is in the `result` JSON
column (camelCase keys):

```sql
SELECT investigation_id,
       result::jsonb->'stepOutputs'->-1->>'verdict' as verdict
FROM cloud_siem.security_agent_investigation_steps
WHERE org_id = 2
  AND step_id = 'signalTriageVerdictStep'
ORDER BY created_at DESC LIMIT 10;
```

To filter for a specific verdict:

```sql
SELECT investigation_id
FROM cloud_siem.security_agent_investigation_steps
WHERE org_id = 2
  AND step_id = 'signalTriageVerdictStep'
  AND result::jsonb->'stepOutputs'->-1->>'verdict' = 'suspicious'
ORDER BY created_at DESC LIMIT 10;
```

## Calling an internal Rapid HTTP test drive from CLI (OBO-auth services)

**Applies only to services that accept OBO (on-behalf-of) user auth** — i.e.
those whose handlers go through `optional_current_user` (or equivalent) and
validate a terminator-signed `dd-auth-jwt` with `method=obo`. Services with
a different auth model (session-only, API-key, mTLS-only, custom) need a
different recipe.

**Always read the service's `AGENTS.md` before planning a live test.** Many
services already document the exact curl recipe and auth pattern. The
repo-wide pattern below is the fallback when the service doesn't have its
own.

Internal Rapid HTTP services validate requests in two layers:

1. **Rapid `InternalAuthIntegration`** — requires `Authorization: Bearer <token>`
   where `<token>` is a Vault-issued service JWT.
2. **`optional_current_user`** — requires a terminator-signed OBO user JWT in
   the `dd-auth-jwt` header. The terminator's mint endpoint is not directly
   callable; the only CLI path is `ddauth obo -o <org_id>` (staging-only).

The Fabric Developer Gateway hostname `rapid-td-<TD_NAME>.us1.staging.dog`
routes directly to the test drive, bypassing the public edge:

```bash
ISA="$(ddtool auth token rapid-<namespace> --datacenter us1.staging.dog --http-header)"
JWT="$(ddauth obo -o 2 | grep '^dd-auth-jwt:' | sed 's/^dd-auth-jwt: //')"

curl -sN -X POST "https://rapid-td-<TD_NAME>.us1.staging.dog/<path>" \
  -H "$ISA" \
  -H "dd-auth-jwt: $JWT" \
  -H 'Content-Type: application/json' \
  -d '<body>'
```

The OBO JWT expires in ~10 minutes; cache and refresh as needed. The
`-o <org_id>` flag selects which org you impersonate; use `2` for staging
Datadog HQ.

## Mapping a SIEM signal to its investigation

The UI URL's `signalId` query parameter is **not** the value stored in the
DB. The UI form is a wrapped 104-char base64 (starts `AwAAA...`); the DB
stores a 55-char canonical form (starts `AQAAA...`). They share two
byte-identical blocks; derive the DB form like this:

```bash
# Take signalId from the URL's sp parameter (URL-decode, parse JSON, read .[].p.signalId)
S='AwAAAZ3TfFflxjEVxQAAABhBWjNUZkZmbEFBRE9KQTlxb1pYclFRQUEAAAAkMTE5ZGQzZjUtZTFjMS00ZDU2LTk1ZDItMTA2YWJiNzI3ZTMyAABGmQ'
DB_SIGNAL_ID="AQAAA${S:5:13}AAAAB${S:23:32}"
```

If the derived value doesn't match a row, fall back to grabbing it from a
network request: DevTools → Network → filter `signals/investigation` →
Payload → `data.attributes.signal_id`. The `org_id` is not in the URL —
read it from the `baggage` header (`account.id=N`) on the same request.
Datacenter: `us1.prod.dog` for `app.datadoghq.com`, `us1.staging.dog` for
`dd.datad0g.com`.

```bash
ORGSTORE_DISABLE_VERSION_CHECK=1 orgstore toolbox psql \
  -x us1.prod.dog -c cloud-siem -d cloud_siem \
  -e "SELECT investigation_id, created_at,
             result::jsonb->'stepOutputs'->-1->>'verdict' as verdict
      FROM cloud_siem.security_agent_investigation_steps
      WHERE org_id = <ORG_ID>
        AND signal_id = '<DB_SIGNAL_ID>'
        AND step_id = 'signalTriageVerdictStep'
      ORDER BY created_at DESC;"
```

The `org_id` filter is required — without it the query times out. Multiple
rows means the signal was re-investigated; pick the most recent.

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
- Test public methods, not private helpers. If a private function is only
  reachable through a public method, test it through that public method.

# PR Feedback
When directed to address PR feedback:
- Read all open review comments before making changes.
- Categorize by severity (must-fix vs nice-to-have).
- Address each must-fix with a separate commit, running tests between each.
- Don't push until all fixes pass locally.

# Rules for DataDog/dd-source repo
- Generate mocks with gomock via BUILD.bazel `mockgen` rules, not by hand.
  Follow the pattern in neighboring `mock/` directories.
- Run `dd_gofmt_test -- --fix` on changed Go packages before committing. Unit
  tests do not check formatting, so passing tests does not mean CI will pass.
  This is slow, so run it once when the code is ready to commit, not repeatedly.

## Running Bazel (dd-source)
- Always use `bzl`, a wrapper around the real `bazel` binary. Never call `bazel` directly.
- Default to `--config=coding-agent` for clean, compact output.
- Add `--nocache_test_results` to force a re-run instead of a cache hit.
- For full test logs use `--test_output=all`; this overrides `--config=coding-agent`.
- Never run two `bzl` commands at once; they share an output_base lock.

# Rules for DataDog/k8s-resources repo
- When creating or reviewing OrgStore/PGSM migrations, use the `/pgsm` skill
  to load the correct conventions before writing any migration code.
