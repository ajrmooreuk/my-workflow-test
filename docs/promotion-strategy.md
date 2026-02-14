# Promotion Strategy: Three-Repo Dev → Test → Prod

**Purpose**: Team discussion document — how we stage, validate, and promote workflow conventions across projects.

---

## The Three Repos

| Repo | Purpose | Who Uses It | Stability |
|------|---------|-------------|-----------|
| `azlan-workflow-dev` | Iterate freely. Break things. | Developers | Unstable — changes daily |
| `azlan-workflow-test` | SME validation. Acceptance testing. | SMEs + testers | Stable — changes per sprint |
| `azlan-workflow-prod` | Source of truth. Feeds all live repos. | All projects | Locked — changes per release |

Each repo is a **complete, working instance** of the workflow package — templates, workflows, scripts, plugin. A colleague can bootstrap a sandbox from any of the three to test at that maturity level.

---

## Why Three Repos, Not Three Branches

| Concern | Branch-based | Three repos |
|---------|-------------|-------------|
| **Blast radius** | One bad merge to `main` breaks every prod repo | Prod repo is untouched until explicit promotion |
| **Access control** | Branch protection is all-or-nothing per repo | Separate repo permissions: devs write to dev, only leads write to prod |
| **Independent testing** | Test branch shares CI config with dev | Test repo has its own Actions, its own webhook secrets, its own project board |
| **Rollback** | Revert commits on a shared branch — messy history | Point prod consumers back to previous prod tag — clean |
| **Audit trail** | PR history mixed across environments | Each repo has isolated, reviewable history per environment |
| **Parallel work** | Feature branches compete on one repo | Dev repo absorbs churn; test and prod stay quiet |
| **CI/CD isolation** | All environments share one Actions quota and secrets | Each repo has its own secrets, runners, and rate limits |
| **Repo-level hooks** | Webhooks fire for all environments | Prod repo can notify Slack on release; dev repo stays silent |

**The core argument**: branches share everything (secrets, Actions config, webhooks, permissions, CI quota). Repos share nothing. For a workflow package that gets pushed to live projects, isolation is a feature, not overhead.

---

## How Promotion Works

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
                                                     (Azlan-EA-AAA, siblings)
```

### Promote dev → test
- **Trigger**: Developer runs `/azlan-github-workflow:promote dev-to-test` or manually creates a PR
- **What happens**: Script diffs the two repos, opens a PR on `azlan-workflow-test` with a changelog
- **Gate**: CI validates YAML syntax, script `--help` checks, template parsing
- **Who merges**: Any team member

### Promote test → prod
- **Trigger**: Lead runs `/azlan-github-workflow:promote test-to-prod` after SME sign-off
- **What happens**: Script diffs test vs prod, opens a PR on `azlan-workflow-prod` with full changelog
- **Gate**: CI validation + mandatory SME approval label + lead approval
- **Who merges**: Project lead only
- **On merge**: Semver tag created automatically (v1.0.0, v1.1.0, etc.)

### Sync prod → live repos
- **Trigger**: New tag on `azlan-workflow-prod`
- **What happens**: GitHub Action opens PRs on all registered live repos with the updated files
- **Gate**: Each live repo reviews and merges its own PR (repos control their own pace)
- **Drift detection**: Weekly scheduled Action compares live repos against prod and flags divergence

---

## What Gets Promoted

Only the convention files cross repo boundaries — never application code:

```
.github/ISSUE_TEMPLATE/*           ← issue forms
.github/pull_request_template.md   ← PR template
.github/labels.yml                 ← label definitions
.github/workflows/enforce-*.yml    ← enforcement workflows
.github/workflows/validate-*.yml   ← validation workflows
scripts/*.sh                       ← setup and migration scripts
azlan-github-workflow/             ← Claude Code plugin (optional)
```

---

## Version Pinning

Live repos don't auto-update. Each repo's `azlan-workflow-version` file pins to a prod tag:

```
v1.2.0
```

The sync workflow respects this pin. A repo on `v1.1.0` won't receive `v1.2.0` changes until it updates its pin. This lets teams upgrade on their own schedule.

---

## Setup Cost

| Item | One-time effort |
|------|----------------|
| Create `azlan-workflow-dev` | `bootstrap-new-repo.sh azlan-workflow-dev` |
| Create `azlan-workflow-test` | `bootstrap-new-repo.sh azlan-workflow-test` |
| Create `azlan-workflow-prod` | `bootstrap-new-repo.sh azlan-workflow-prod` |
| Promotion workflow | One reusable Action (~100 lines) |
| Sync workflow | One reusable Action (~80 lines) |
| Drift detection | One scheduled Action (~50 lines) |
| Promote plugin skills | Two SKILL.md files |

Total: half a day to build. After that, promotion is a one-command operation.

---

## Decision Required

1. **Do we version-pin live repos** or auto-sync on every prod release?
2. **Who has write access to prod repo** — lead only, or any approver?
3. **Do we need drift detection** or trust that teams won't edit convention files locally?
