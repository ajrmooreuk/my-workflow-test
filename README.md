# Azlan Workflow Template

Reusable template for GitHub workflow conventions with automated dev → test → prod promotion.

## What's Included

### Convention Files (Layer 1)
- **Issue templates**: Epic, Feature, Story, PBS, WBS (`.github/ISSUE_TEMPLATE/`)
- **PR template**: Traceability fields with registry artifact linking
- **Label taxonomy**: 21 standard labels (type, domain, tier, phase)
- **Enforcement workflows**: Naming validation, label checks, registry link enforcement

### Setup Scripts (Layer 2)
- `scripts/bootstrap-new-repo.sh` — One-command new repo provisioning
- `scripts/setup-all.sh` — Orchestrate labels, branch protection, project board
- `scripts/setup-labels.sh` — Idempotent label creation
- `scripts/setup-branch-protection.sh` — Solo or team mode protection
- `scripts/setup-gh-project.sh` — Project board with 7 standard fields
- `scripts/migrate-issues-into-hierarchy.sh` — Auto-classify existing issues

### Promotion Pipeline (Layer 3)
- `scripts/setup-promotion-repos.sh` — Create the three-repo structure in one command
- `scripts/promote.sh` — CLI shortcut for triggering promotions
- Automated workflows for promotion, tagging, sync, and drift detection

## Three-Repo Promotion Model

```
azlan-workflow-dev          azlan-workflow-test          azlan-workflow-prod
       │                           │                            │
  Developer pushes            SME validates               Owner approves
  freely here                 here                        release here
       │                           │                            │
       └──── promote ─────────────►│                            │
              (PR + CI gate)       └──── promote ──────────────►│
                                          (PR + SME approval)   │
                                                                ▼
                                                     All registered live repos
```

Each tier is an isolated repo with its own Actions, secrets, and permissions. See [docs/promotion-strategy.md](docs/promotion-strategy.md) for rationale.

## Quick Start

### Option A: Set up the full promotion pipeline

```bash
# Clone this template
git clone https://github.com/ajrmooreuk/my-workflow-test.git
cd my-workflow-test

# Create dev/test/prod repos
./scripts/setup-promotion-repos.sh --org YOUR_ORG --prefix azlan-workflow

# Add the cross-repo PAT as a secret (you'll be prompted for the token)
gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-dev
gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-test
gh secret set PROMOTION_PAT --repo YOUR_ORG/azlan-workflow-prod
```

### Option B: Bootstrap a single repo with conventions

```bash
./scripts/bootstrap-new-repo.sh my-project --mode team
```

## Required Secrets

| Secret | Scope | Purpose |
|--------|-------|---------|
| `PROMOTION_PAT` | `repo` on all promotion + live repos | Cross-repo PR creation, sync, drift detection |

Create a [fine-grained PAT](https://github.com/settings/tokens?type=beta) with `repo` scope covering all relevant repos.

## Promotion Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `promote.yml` | Manual dispatch | Copies convention files to target repo, creates PR |
| `validate-conventions.yml` | PR to main | CI gate: validates YAML, scripts, templates |
| `auto-tag.yml` | Merged promotion PR | Creates semver tag + GitHub release on prod |
| `sync-to-live.yml` | New `v*` tag | Opens sync PRs on all registered live repos |
| `drift-detection.yml` | Weekly + manual | Compares live repos against prod, flags divergence |

## Docs

- [Team Operations Guide](docs/team-operations-guide.md) — Setup, operate, and maintain the pipeline (2–4 person team)
- [Promotion Strategy](docs/promotion-strategy.md) — Three-repo architecture and rationale
- [Onboarding](docs/onboarding.md) — Three adoption paths
- [Quick Reference](docs/quick-reference.md) — Naming conventions, labels, commands
- [Migration Checklist](docs/migration-checklist.md) — Retrofit existing repos
- [SME Test Guide](docs/sme-test-guide.md) — Step-by-step validation walkthrough
- [Publishing Guide](docs/publishing-guide.md) — Public distribution strategy
- [PAT Setup Guide](docs/pat-setup-guide.md) — Classic PAT creation and troubleshooting
- [ADR-001](docs/adr-001-packaging-approach.md) — Packaging approach decision record

## Config Files

| File | Purpose |
|------|---------|
| `promotion/convention-manifest.json` | Files that get promoted (single source of truth) |
| `promotion/live-repos.json` | Registry of repos receiving prod releases |
| `promotion/promotion.env` | Org/repo names (templated during setup) |
