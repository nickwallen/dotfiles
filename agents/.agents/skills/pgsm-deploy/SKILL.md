---
name: pgsm-deploy
description: Trigger a PGSM migration deployment after a k8s-resources PR is merged, instead of waiting for the scheduled run. Use when the user says "deploy migration", "trigger pgsm", "pgsm deploy", "deploy pgsm", "run migration", or wants to speed up a PGSM deployment after merge.
user-invocable: true
allowed-tools: Bash(gh:*), Bash(ddr:*), Bash(git:*)
---

# Trigger PGSM Migration Deployment

After a PGSM migration PR merges to k8s-resources, the migration deploys on
a schedule. This skill triggers the deployment immediately by re-running the
GitLab CI pipeline for the merge commit.

## Input Handling

`$ARGUMENTS` can be:

1. **Empty** -- use the current branch's most recently merged PR.
2. **A PR number** (e.g., `85400`) -- use that PR from DataDog/k8s-resources.
3. **A PR URL** -- extract the PR number from the URL.

## Step 1: Resolve the PR and Merge Commit

```bash
# If PR number is known:
gh pr view <PR_NUMBER> --repo DataDog/k8s-resources --json state,mergeCommit,title

# If no PR number, find the most recent merged PR for the current user:
gh pr list --repo DataDog/k8s-resources --state merged --author @me --limit 5 --json number,title,mergedAt
```

Verify the PR is in `MERGED` state. If not, stop and tell the user.

Extract the merge commit SHA from the `mergeCommit.oid` field.

## Step 2: Confirm Before Triggering

Present the user with:
- PR number and title
- Merge commit SHA (short form)
- The command that will run

Ask the user to confirm before proceeding. This re-runs the full post-merge
CI pipeline, not just the PGSM job.

## Step 3: Trigger the Pipeline

```bash
ddr devflow ddci trigger --head <MERGE_COMMIT_SHA> --branch master --repository k8s-resources
```

This re-runs the GitLab CI pipeline for the merge commit. The
`upload:pgsm-deploy-migrations` job runs as part of that pipeline, which
internally calls `bzl run` on the appropriate `{env}-delta-{db_cluster}`
targets.

Authentication uses existing `ddr` / Devflow credentials. No separate
GitLab token is required.

## Step 4: Verify Deployment

After triggering, suggest these follow-up actions:

1. **Check pipeline status** -- The user can monitor the pipeline in GitLab.
   The `upload:pgsm-deploy-migrations` job should appear in the pipeline.
2. **Check revision** -- Use the `/check-revision` skill to verify the
   migration revision is deployed across datacenters. The heartbeat metric
   takes a few minutes to update after deployment.
3. **Monitor Mosaic** -- Link to Mosaic filtered for the relevant cluster:
   `https://mosaic.us1.ddbuild.io/deployments?query=service%3Apostgres-alembic`

## Known Caveat

The `.gitlab-ci.yml` has a `never-on-conductor-pipeline` rule that skips
PGSM jobs when `$CI_PIPELINE_SOURCE == "api" && $DDR == "true"`. The
OrgStore docs recommend this `ddci trigger` approach, so it presumably
works. If the PGSM job is skipped in the triggered pipeline, investigate
whether `manual:pgsm-deploy-migrations` (a `when: manual` job) can be
played via the GitLab API instead.
