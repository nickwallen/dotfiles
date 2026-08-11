---
name: dd-disk-cleanup
description: Free disk space on a Datadog dev machine by removing stale git worktrees, orphaned Bazel output bases, and (optionally) shared build caches. Use when the user says "disk is full", "free disk space", "clean worktrees", "clear bazel cache", "disk usage", or notices low free space.
user-invocable: true
allowed-tools: Bash(df:*), Bash(du:*), Bash(ls:*), Bash(git:*), Bash(gh:*), Bash(bzl:*), Bash(rm:*), Bash(chmod:*), Bash(mkdir:*), Bash(go:*), Bash(yarn:*), AskUserQuestion
---

# Datadog Dev Disk Cleanup

Reclaim disk space on a Datadog dev mac. The big consumers, in typical order:

1. Bazel output bases under `/private/var/tmp/_bazel_$USER/` (per-worktree, ~20-30G each)
2. Shared Bazel disk cache at `~/Library/Caches/bazel/disk` (grows toward ~120G)
3. Stale git worktrees under `.claude/worktrees/` in each DD repo (~3-17G each)
4. Go caches (`~/Library/Caches/go-build`, `~/go/pkg/mod`)

This skill removes orphan Bazel bases and stale worktrees automatically and
prompts before touching shared caches.

## Step 1: Baseline

Record `df -h ~` (free / used / pct). Display to the user.

## Step 2: Worktree Inventory

For each Datadog repo under `~/dd/` (typically `dd-source`, `web-ui`; also any
sibling repos with a `.git/worktrees/` directory):

```bash
git -C <repo> worktree list
```

For each worktree, capture: path, branch, `git status --porcelain` count, last
commit relative date, `du -sh` size.

Cross-reference branches with PR state:

```bash
cd <repo> && gh pr list --author '@me' --state all --limit 40 \
  --json number,title,headRefName,state,url
```

Classify each worktree:
- **KEEP** -- main checkout, or branch maps to an OPEN PR
- **MERGED** -- branch maps to a MERGED PR
- **CLOSED** -- branch maps to a CLOSED PR
- **ORPHAN** -- no matching PR. Before treating as cleanup-eligible, verify
  HEAD is reachable from at least one `origin/*` ref:
  ```bash
  git -C <wt> branch -a --contains <HEAD-SHA>
  ```
  If no `remotes/origin/*` line appears, escalate to the user.

## Step 3: Uncommitted-Work Guard

For each cleanup-candidate worktree with `git status --porcelain` non-empty,
inspect the changes:

```bash
git -C <wt> status --short
git -C <wt> diff --stat
```

- **Real tracked-file diff** (staged or unstaged): save patch before removal:
  ```bash
  mkdir -p ~/dd-source-patches
  git -C <wt> diff > ~/dd-source-patches/<branch-slug>-uncommitted-<YYYYMMDD>.patch
  ```
  Tell the user where it was saved.
- **Only generated junk** (e.g. symlinks to parent checkout, build outputs,
  IDE caches): note it and proceed without patching.

## Step 4: Remove Stale Worktrees

For each MERGED / CLOSED / verified-ORPHAN worktree:

```bash
git -C <repo> worktree remove --force <relative-path>
```

After removal, run `git worktree list` to confirm.

## Step 5: Orphaned Bazel Output Bases

For each remaining worktree (including main checkouts), find the active output
base:

```bash
( cd <wt> && bzl info output_base )
```

Build a set of "live" bases. Anything in `/private/var/tmp/_bazel_$USER/` not
in that set, except the `cache`, `install`, and `bzl-gc.lock` entries, is
orphaned.

For each orphan:

```bash
chmod -R u+w <orphan-path> 2>/dev/null
rm -rf <orphan-path>
```

The `chmod` is required because Bazel marks outputs read-only. `rm` will
otherwise fail with `Permission denied` on most files.

## Step 6: Optional Cache Wipes

Measure these caches and present them with `AskUserQuestion`:

| Path | Typical size | Recovery cost |
|---|---|---|
| `~/Library/Caches/bazel/disk` | 50-120G | Slower next clean `bzl build`; rebuilds incrementally |
| `~/Library/Caches/bazel/repository` | 10-15G | Re-fetches external deps on next workspace fetch |
| `~/Library/Caches/go-build` | 5-10G | `go clean -cache`; rebuilds fast |
| `~/go/pkg/mod` | 15-25G | `go clean -modcache`; re-downloads on next `go mod` |

Offer 4 options:

1. **Worktrees only** -- stop here (already done by step 4).
2. **Worktrees + Go caches** -- add `go clean -cache && go clean -modcache`.
3. **Worktrees + Bazel caches** -- add `rm -rf ~/Library/Caches/bazel/{disk,repository}`.
4. **Everything** -- both.

Wipe only what the user picks. For Bazel caches, `chmod -R u+w` first if `rm`
fails on read-only files.

## Step 7: Optional Cache Repopulation

After step 6, the action cache and (if wiped) repository cache are empty.
The next time the user starts work, the first build will be slow.

Offer to pre-warm one or both repos with `AskUserQuestion`:

| Option | Action | Cost |
|---|---|---|
| Skip | Don't pre-warm | Fast first session start, slow first build |
| dd-source only | `bzl build //domains/chatbot/apps/apis/ai-security-agent:ai-security-agent` (or another active service target) | Few minutes; populates Go toolchain + active-domain cache |
| web-ui only | `cd ~/dd/web-ui && yarn install` | Quick if `.yarn` / `node_modules` were not wiped; ~10 min for a clean install |
| Both | Run dd-source then web-ui | Sum of above |

If the user is unsure which dd-source target to build, ask. Default suggestion:
the active service from their main worktree, found by inspecting recent commits
or open PR titles.

Record disk usage before and after each build so the report shows cache
repopulation cost.

## Step 8: Report

Print a table:

```
| Phase                  | Free  | Used  | %    |
|------------------------|-------|-------|------|
| Start                  | ...   | ...   | ...  |
| After worktree removal | ...   | ...   | ...  |
| After orphan bases     | ...   | ...   | ...  |
| After cache wipes      | ...   | ...   | ...  |
| After repopulation     | ...   | ...   | ...  |
```

Then list:
- Worktrees removed (path + PR number + state)
- Patches saved (path)
- Orphaned Bazel bases deleted (path + size)
- Caches wiped (path + size)
- Worktrees kept (path + branch + PR URL)

## Safety Invariants

- **Never** remove a worktree whose branch maps to an OPEN PR.
- **Never** remove a worktree with tracked-file uncommitted changes without
  first saving a `.patch` and telling the user where.
- **Never** remove a Bazel output base that `bzl info output_base` reported
  for a live worktree.
- **Never** wipe shared caches (`~/Library/Caches/bazel/*`, `~/go/pkg/mod`,
  `~/Library/Caches/go-build`) without explicit user confirmation via
  `AskUserQuestion`.

## Out of Scope

- Deciding whether to abandon open-PR worktrees -- ask the user.
- Inspecting Docker, `~/Library/Application Support/*`, Chrome profile size --
  surface in the report but don't touch.
- Running `dd-doctor` -- separate tool; recommend if disk pressure persists
  after this skill runs.
