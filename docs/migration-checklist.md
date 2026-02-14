# Azlan Workflow — Migration Checklist

Use this checklist when retrofitting the Azlan workflow onto an existing repository.

## Prerequisites

- [ ] `gh` CLI installed and authenticated (`gh auth status`)
- [ ] Repository admin access
- [ ] Current branch is up to date with `main`

## Step 1: Labels

- [ ] Run `./scripts/setup-labels.sh --repo OWNER/REPO`
- [ ] Verify labels visible at `https://github.com/OWNER/REPO/labels`
- [ ] Verify hierarchy labels: `type:epic`, `type:feature`, `type:story`, `type:pbs`, `type:wbs`, `type:registry`
- [ ] Add any project-specific labels manually (e.g., `visualiser`)

## Step 2: Issue Templates

- [ ] Copy `.github/ISSUE_TEMPLATE/` to your repo
- [ ] Copy `.github/ISSUE_TEMPLATE/config.yml` (disables blank issues)
- [ ] Verify templates appear at `https://github.com/OWNER/REPO/issues/new/choose`

## Step 3: PR Template

- [ ] Copy `.github/pull_request_template.md` to your repo
- [ ] Verify template appears when creating a new PR

## Step 4: Enforcement Workflows

- [ ] Copy `.github/workflows/enforce-registry-link.yml`
- [ ] Copy `.github/workflows/validate-issue-naming.yml`
- [ ] Copy `.github/workflows/validate-labels.yml`
- [ ] Push to `main` and verify workflows appear in Actions tab

## Step 5: Branch Protection

- [ ] Run `./scripts/setup-branch-protection.sh --repo OWNER/REPO --mode solo`
- [ ] Verify: `git push --force origin main` should be rejected
- [ ] For team repos: use `--mode team` instead

## Step 6: Project Board

- [ ] Run `./scripts/setup-gh-project.sh --owner OWNER --project-title "Project Name" --repo OWNER/REPO`
- [ ] Verify project has 7 standard fields (Type, Status, Priority, Estimate, Registry ID, PBS ID, WBS Code)
- [ ] Verify repo is linked to project

## Step 7: Classify Existing Issues

- [ ] Preview: `./scripts/migrate-issues-into-hierarchy.sh --repo OWNER/REPO --dry-run`
- [ ] Review output — check for false positives
- [ ] Apply: `./scripts/migrate-issues-into-hierarchy.sh --repo OWNER/REPO`
- [ ] Manually fix any issues that weren't auto-classified

## Step 8: Plugin (Optional)

- [ ] Install: `claude --plugin-dir /path/to/azlan-github-workflow`
- [ ] Test: `/azlan-github-workflow:review-hierarchy OWNER/REPO`
- [ ] Fix any compliance issues flagged by the audit

## Verification

- [ ] Create a test epic using the issue template form
- [ ] Create a test feature linked to the epic
- [ ] Create a PR referencing a WBS issue — verify registry enforcement fires
- [ ] Run `/azlan-github-workflow:review-hierarchy` — all checks pass
