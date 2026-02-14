# Team Operations Guide

How to set up, operate, and maintain the three-repo promotion pipeline as a team of 2–4 people — plus worked examples for staging real deliverables.

---

## Contents

1. [Team Roles](#1-team-roles)
2. [Initial Setup (One-Time)](#2-initial-setup-one-time)
3. [Day-to-Day Operations](#3-day-to-day-operations)
4. [Branch Protection Modes](#4-branch-protection-modes)
5. [Maintenance](#5-maintenance)
6. [Replicating for Another Project](#6-replicating-for-another-project)
7. [Worked Example A: Staging Ontology Visualiser Pre-Release](#7-worked-example-a-staging-ontology-visualiser-pre-release)
8. [Worked Example B: Staging File Transfers](#8-worked-example-b-staging-file-transfers)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Team Roles

| Role | Who | Permissions | Responsibilities |
|------|-----|-------------|------------------|
| **Pipeline Owner** | 1 person (repo admin) | Admin on all three repos, PAT owner | Creates PAT, manages secrets, approves prod merges |
| **Developer** | 1–2 people | Write on `dev`, read on `test`/`prod` | Iterates on convention files, triggers dev-to-test |
| **SME / Reviewer** | 1–2 people | Write on `test`, read on `prod` | Reviews promotion PRs, validates changes, applies `needs-sme-approval` |
| **All members** | Everyone | Read on `prod` | Can trigger drift detection, view release history |

For a **2-person team**: one person is Pipeline Owner + Developer, the other is SME/Reviewer.
For a **4-person team**: one Owner, two Developers, one SME.

### Adding Collaborators

```bash
# Add a developer to the dev repo
gh api repos/OWNER/azlan-workflow-dev/collaborators/USERNAME \
  --method PUT --field permission=push

# Add an SME reviewer to the test repo
gh api repos/OWNER/azlan-workflow-test/collaborators/USERNAME \
  --method PUT --field permission=push

# Add read access to prod for everyone
gh api repos/OWNER/azlan-workflow-prod/collaborators/USERNAME \
  --method PUT --field permission=push
```

---

## 2. Initial Setup (One-Time)

### Prerequisites

Every team member needs:
- [GitHub CLI](https://cli.github.com/) installed and authenticated (`gh auth login`)
- Git configured (`git config --global user.name` / `user.email`)
- `jq` installed (`brew install jq` on macOS)

The Pipeline Owner also needs:
- Admin access to the GitHub org or personal account hosting the repos
- A **classic** Personal Access Token (see below)

### Step 2a: Clone the Template

```bash
git clone https://github.com/ajrmooreuk/my-workflow-test.git
cd my-workflow-test
```

### Step 2b: Create the Three Repos

```bash
./scripts/setup-promotion-repos.sh --org YOUR_ORG --prefix azlan-workflow --private
```

This creates:
- `azlan-workflow-dev` — developer iteration (solo branch protection)
- `azlan-workflow-test` — SME validation (team branch protection, 1 review required)
- `azlan-workflow-prod` — source of truth (team branch protection, 1 review required)

Each repo receives the correct tier workflows, convention files, and promotion config automatically.

### Step 2c: Create the Classic PAT

> **Important**: You must use a **classic** PAT, not a fine-grained PAT. Fine-grained PATs do not support the `workflow` scope, which is required to push files under `.github/workflows/`.

1. Go to https://github.com/settings/tokens (classic tab)
2. Click **Generate new token (classic)**
3. Note: `azlan-workflow-promotion`
4. Expiration: 90 days (or your preference)
5. Select scopes: **`repo`** and **`workflow`** only
6. Click **Generate token** and copy the `ghp_...` value immediately

Full instructions: [docs/pat-setup-guide.md](pat-setup-guide.md)

### Step 2d: Set the Secret on All Three Repos

```bash
echo -n "ghp_YOUR_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-dev
echo -n "ghp_YOUR_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-test
echo -n "ghp_YOUR_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-prod
```

### Step 2e: Add Collaborators

```bash
# For each team member:
gh api repos/YOUR_ORG/azlan-workflow-dev/collaborators/THEIR_USERNAME \
  --method PUT --field permission=push
gh api repos/YOUR_ORG/azlan-workflow-test/collaborators/THEIR_USERNAME \
  --method PUT --field permission=push
gh api repos/YOUR_ORG/azlan-workflow-prod/collaborators/THEIR_USERNAME \
  --method PUT --field permission=push
```

### Step 2f: Verify

```bash
# Confirm secrets
gh secret list --repo YOUR_ORG/azlan-workflow-dev
gh secret list --repo YOUR_ORG/azlan-workflow-test
gh secret list --repo YOUR_ORG/azlan-workflow-prod

# Test promotion
./scripts/promote.sh dev-to-test
```

---

## 3. Day-to-Day Operations

### The Promotion Flow

```
Developer makes changes         SME reviews and merges        Owner approves release
on azlan-workflow-dev            PR on azlan-workflow-test     PR on azlan-workflow-prod
         │                                │                            │
         └──── promote dev-to-test ──────►│                            │
                   (PR created)           └──── promote test-to-prod ─►│
                                                  (PR + SME label)     │
                                                                       ▼
                                                            Auto-tag → sync to live repos
```

### Making Changes (Developer)

1. **Clone and work on the dev repo**:
   ```bash
   cd azlan-workflow-dev
   # Edit convention files, templates, workflows, scripts
   git add -A && git commit -m "feat: add new issue template for RFCs"
   git push
   ```

2. **When ready, trigger promotion to test**:
   ```bash
   ./scripts/promote.sh dev-to-test
   ```
   Or via GitHub Actions UI: go to the dev repo → Actions → "Promote Convention Files" → Run workflow → select `dev-to-test`.

3. **Notify the SME reviewer** that a PR is waiting on `azlan-workflow-test`.

### Reviewing a Promotion PR (SME / Reviewer)

1. Open the PR on `azlan-workflow-test` (link is in the workflow run summary)
2. Review the changed files — these are convention files only, not application code
3. Check the CI status (validate-conventions workflow runs automatically)
4. If satisfied, approve and merge the PR
5. If changes needed, comment on the PR and ask the developer to fix in dev, then re-promote

### Promoting to Prod (Pipeline Owner)

1. Ensure the changes have been validated in test
2. Trigger promotion:
   ```bash
   ./scripts/promote.sh test-to-prod --bump minor
   ```
   Use `--bump major` for breaking changes, `--bump patch` for small fixes.

3. The PR on `azlan-workflow-prod` will have the `needs-sme-approval` label
4. Review and merge — this triggers:
   - **auto-tag.yml**: creates a semver tag (e.g. `v1.2.0`) and GitHub release
   - **sync-to-live.yml**: opens PRs on all registered live repos

### Monitoring

```bash
# Check recent workflow runs
gh run list --repo YOUR_ORG/azlan-workflow-dev --limit 5
gh run list --repo YOUR_ORG/azlan-workflow-test --limit 5
gh run list --repo YOUR_ORG/azlan-workflow-prod --limit 5

# Check drift detection issues
gh issue list --repo YOUR_ORG/azlan-workflow-prod --label drift-detection
```

---

## 4. Branch Protection Modes

The setup script configures branch protection per tier:

| Tier | Mode | Reviews Required | Enforce on Admins | Use Case |
|------|------|-----------------|-------------------|----------|
| dev | solo | 0 | No | Developer pushes freely |
| test | team | 1 | Yes | SME must approve before merge |
| prod | team | 1 | Yes | Owner must approve before release |

### Adjusting for Solo Testing

If you're testing the pipeline solo (no second reviewer), temporarily switch test/prod to solo mode:

```bash
# Remove review requirement on test
gh api repos/YOUR_ORG/azlan-workflow-test/branches/main/protection \
  --method PUT --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON

# To restore team mode later:
gh api repos/YOUR_ORG/azlan-workflow-test/branches/main/protection \
  --method PUT --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "restrictions": null
}
JSON
```

---

## 5. Maintenance

### PAT Rotation (Every 90 Days)

The classic PAT expires based on the expiration you set. To rotate:

1. Create a new classic PAT (same scopes: `repo` + `workflow`)
2. Re-set the secret on all three repos:
   ```bash
   echo -n "ghp_NEW_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-dev
   echo -n "ghp_NEW_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-test
   echo -n "ghp_NEW_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-prod
   ```
3. Revoke the old PAT at https://github.com/settings/tokens

### Adding a New Live Repo

When a new project repo should receive convention updates from prod:

1. Edit `promotion/live-repos.json` on the **dev** repo:
   ```json
   {
     "name": "YOUR_ORG/new-project-repo",
     "pin": true,
     "notes": "Description of the repo"
   }
   ```
2. Promote through the pipeline (dev → test → prod)
3. Ensure the PAT has access to the new repo

### Removing a Live Repo

1. Remove the entry from `promotion/live-repos.json` on dev
2. Promote through the pipeline

### Updating Convention Files

All convention changes follow the same path:

1. Edit files on `azlan-workflow-dev`
2. Commit and push
3. Run `./scripts/promote.sh dev-to-test`
4. SME reviews and merges PR on test
5. Run `./scripts/promote.sh test-to-prod`
6. Owner reviews and merges PR on prod
7. Auto-tag creates a release, sync opens PRs on live repos

### Weekly Drift Detection

Drift detection runs automatically every Monday at 9am UTC. It compares convention files in registered live repos against prod and creates a GitHub issue if divergence is found.

To trigger manually:
```bash
gh workflow run drift-detection.yml --repo YOUR_ORG/azlan-workflow-prod
```

---

## 6. Replicating for Another Project

Any team member can create their own three-repo promotion pipeline for a different project.

### Quick Replication

```bash
# Clone the template
git clone https://github.com/ajrmooreuk/my-workflow-test.git my-new-pipeline
cd my-new-pipeline

# Create three repos with a different prefix
./scripts/setup-promotion-repos.sh --org YOUR_ORG --prefix my-project-workflow --private

# Set up PAT secrets (create a new PAT or reuse existing if same org)
echo -n "ghp_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/my-project-workflow-dev
echo -n "ghp_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/my-project-workflow-test
echo -n "ghp_TOKEN" | gh secret set PROMOTION_PAT --repo YOUR_ORG/my-project-workflow-prod
```

### Customising the Manifest

Edit `promotion/convention-manifest.json` to control which files get promoted. Only files listed in the `files` array are copied during promotion — everything else stays in its source repo.

```json
{
  "version": "1.0.0",
  "description": "Convention files promoted across dev/test/prod repos",
  "files": [
    ".github/ISSUE_TEMPLATE/epic.yml",
    ".github/ISSUE_TEMPLATE/feature.yml",
    ".github/labels.yml",
    "scripts/setup-labels.sh"
  ],
  "optional": []
}
```

### Customising Live Repos

Edit `promotion/live-repos.json` to register which downstream repos receive convention updates when a new prod tag is created.

### Sharing a Single PAT

One classic PAT can serve multiple promotion pipelines if:
- The PAT owner has write access to all repos across all pipelines
- The PAT has `repo` + `workflow` scopes
- The same `ghp_...` token is set as `PROMOTION_PAT` on each pipeline's three repos

---

## 7. Worked Example A: Staging Ontology Visualiser Pre-Release

This example shows how to stage a pre-release version of the Ontology Visualiser from `Azlan-EA-AAA` into the dev repo, validate it through test, and release via prod.

### Context

The Ontology Visualiser lives at `PBS/TOOLS/ontology-visualiser/` in the Azlan-EA-AAA repo. You want to test a new version (e.g. v4.6.0) through the promotion pipeline before syncing to live repos.

### Step 1: Add the Visualiser to the Dev Repo

```bash
cd azlan-workflow-dev

# Create the destination directory structure
mkdir -p PBS/TOOLS/ontology-visualiser

# Copy the visualiser from the source repo
cp -R /path/to/Azlan-EA-AAA/PBS/TOOLS/ontology-visualiser/* PBS/TOOLS/ontology-visualiser/

# Commit
git add PBS/TOOLS/ontology-visualiser/
git commit -m "feat: add ontology-visualiser v4.6.0-rc.1 for staging"
git push
```

### Step 2: Add Visualiser to the Convention Manifest

To include the visualiser in promotions, add it to the manifest on the dev repo:

```bash
# Edit promotion/convention-manifest.json on dev
# Add to the "files" array (for individual files) or "optional" array (for directories):
```

```json
{
  "optional": [
    "azlan-github-workflow/",
    "PBS/TOOLS/ontology-visualiser/"
  ]
}
```

> **Note**: The `optional` array is for directories that are copied as a whole. Individual files go in the `files` array. The promote.yml workflow currently processes the `files` array. To promote directories, either list key files individually or extend the workflow (see below).

### Step 3: Extend the Promotion Workflow for Directory Copies

If you want the `promote.yml` workflow to handle optional directories, add this step after the convention files copy:

```yaml
- name: Copy optional directories
  run: |
    MANIFEST="source/promotion/convention-manifest.json"
    for dir in $(jq -r '.optional[]' "$MANIFEST"); do
      if [[ -d "source/$dir" ]]; then
        mkdir -p "target/$dir"
        cp -R "source/$dir"* "target/$dir"
        echo "  copied dir: $dir"
      fi
    done
```

### Step 4: Promote Dev to Test

```bash
cd azlan-workflow-dev
./scripts/promote.sh dev-to-test
```

A PR appears on `azlan-workflow-test`. The SME reviewer:
1. Opens the PR
2. Checks the visualiser files are complete and correct
3. Optionally clones the test repo and runs the visualiser locally:
   ```bash
   cd azlan-workflow-test/PBS/TOOLS/ontology-visualiser
   # Open index.html in browser — it's a zero-build-step app
   open index.html
   ```
4. Approves and merges

### Step 5: Promote Test to Prod

```bash
cd azlan-workflow-dev
./scripts/promote.sh test-to-prod --bump minor
```

A PR appears on `azlan-workflow-prod` with the `needs-sme-approval` label. The Pipeline Owner:
1. Reviews the final changeset
2. Merges the PR
3. Auto-tag creates `v1.3.0` (or next version)
4. Sync-to-live opens PRs on registered live repos (e.g. `Azlan-EA-AAA`)

### Step 6: Live Repo Receives the Update

On `Azlan-EA-AAA`, a PR appears with the updated visualiser. The repo maintainer reviews and merges on their own schedule.

### Summary Flow

```
Azlan-EA-AAA (source)
  └── Copy visualiser files manually ──► azlan-workflow-dev
                                              │
                                    promote dev-to-test
                                              │
                                         azlan-workflow-test
                                         (SME validates)
                                              │
                                    promote test-to-prod
                                              │
                                         azlan-workflow-prod
                                         (auto-tag v1.3.0)
                                              │
                                         sync-to-live
                                              │
                                         Azlan-EA-AAA (PR)
                                         + any other live repos
```

---

## 8. Worked Example B: Staging File Transfers

This example shows the simplest use case: staging a set of updated files (e.g. new issue templates or updated scripts) through the pipeline.

### Scenario

You've updated the Epic issue template to add a new "Business Value" field and want to stage it through test before releasing to all live repos.

### Step 1: Make the Change on Dev

```bash
cd azlan-workflow-dev

# Edit the issue template
# (modify .github/ISSUE_TEMPLATE/epic.yml to add the new field)

git add .github/ISSUE_TEMPLATE/epic.yml
git commit -m "feat: add Business Value field to Epic template"
git push
```

### Step 2: Promote to Test

```bash
./scripts/promote.sh dev-to-test
```

This triggers the promote workflow which:
1. Checks out both dev and test repos
2. Reads `promotion/convention-manifest.json` for the file list
3. Copies each listed file from dev to test
4. Compares — if `epic.yml` differs, it creates a PR

### Step 3: Review on Test

The SME reviewer opens the PR on `azlan-workflow-test`:
- Sees the diff: the new "Business Value" field
- Checks CI passes (validate-conventions ensures YAML is valid)
- Approves and merges

### Step 4: Promote to Prod

```bash
./scripts/promote.sh test-to-prod --bump patch
```

Using `--bump patch` because this is a small addition, not a breaking change.

### Step 5: Release

Pipeline Owner merges the PR on prod → auto-tag creates `v1.2.1` → sync-to-live opens PRs on all registered repos.

### Bulk File Updates

For multiple files at once, the same flow applies — just commit them all on dev before promoting:

```bash
cd azlan-workflow-dev

# Update multiple convention files
# Edit .github/ISSUE_TEMPLATE/epic.yml
# Edit .github/ISSUE_TEMPLATE/feature.yml
# Edit .github/labels.yml
# Edit scripts/setup-labels.sh

git add -A
git commit -m "feat: update templates and labels for Q2 conventions"
git push

# Promote
./scripts/promote.sh dev-to-test
```

The promotion PR will show all changed files in a single diff.

### Adding Entirely New Files

To stage a new file that doesn't exist yet:

1. **Create the file on dev**:
   ```bash
   cd azlan-workflow-dev
   # Create .github/ISSUE_TEMPLATE/rfc.yml
   git add .github/ISSUE_TEMPLATE/rfc.yml
   git commit -m "feat: add RFC issue template"
   git push
   ```

2. **Add it to the manifest** (if not already covered by an existing entry):
   ```bash
   # Edit promotion/convention-manifest.json
   # Add ".github/ISSUE_TEMPLATE/rfc.yml" to the files array
   git add promotion/convention-manifest.json
   git commit -m "chore: add rfc.yml to convention manifest"
   git push
   ```

3. **Promote through the pipeline** as normal. The manifest update and the new file both travel together.

---

## 9. Troubleshooting

### Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| `Bad credentials` on promotion | PAT expired or invalid | Rotate PAT — see [Section 5](#5-maintenance) |
| `refusing to allow a PAT to create or update workflow` | Using fine-grained PAT | Must use classic PAT with `repo` + `workflow` scopes |
| "No changes to promote" | Dev and test already identical | Make a change on dev first, then re-promote |
| PR blocked: "1 approving review required" | Team-mode branch protection | Add a reviewer, or switch to solo mode — see [Section 4](#4-branch-protection-modes) |
| Drift detection finds no issues | Live repos match prod | Nothing to do — conventions are in sync |
| Sync PR not created on live repo | Repo not in `live-repos.json` | Add it and promote the config through the pipeline |
| Workflow not found when triggering | Workflow not installed on that tier | Check `tier_workflows()` in setup script — each tier gets specific workflows |

### Checking Workflow Logs

```bash
# List recent runs
gh run list --repo YOUR_ORG/azlan-workflow-dev --workflow promote.yml --limit 5

# View a failed run's logs
gh run view RUN_ID --repo YOUR_ORG/azlan-workflow-dev --log-failed
```

### Resetting a Repo to Match Another

If a tier gets out of sync and you need to force-reset:

```bash
# Re-run the setup script (it's idempotent)
./scripts/setup-promotion-repos.sh --org YOUR_ORG --prefix azlan-workflow
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Promote dev → test | `./scripts/promote.sh dev-to-test` |
| Promote test → prod | `./scripts/promote.sh test-to-prod --bump minor` |
| Check promotion status | `gh run list --repo ORG/azlan-workflow-dev --workflow promote.yml --limit 1` |
| Trigger drift detection | `gh workflow run drift-detection.yml --repo ORG/azlan-workflow-prod` |
| Rotate PAT | Create new classic PAT, re-set `PROMOTION_PAT` on all 3 repos |
| Add live repo | Edit `promotion/live-repos.json` on dev, promote through pipeline |
| Switch to solo mode | See [Section 4](#4-branch-protection-modes) |
| View workflow logs | `gh run view RUN_ID --repo ORG/REPO --log-failed` |

---

## Related Docs

- [PAT Setup Guide](pat-setup-guide.md) — Definitive token creation instructions
- [Promotion Strategy](promotion-strategy.md) — Architecture and rationale
- [Quick Reference](quick-reference.md) — Naming conventions, labels, commands
- [SME Test Guide](sme-test-guide.md) — Step-by-step validation walkthrough
- [Onboarding](onboarding.md) — New repo adoption paths
