# Azlan Workflow — Quick Reference Card

## Naming Conventions

```
Epic N: <customer outcome>          → type:epic
  FN.x: <capability>               → type:feature
    SN.x.y: <user action>          → type:story
      [PBS] <deliverable>           → type:pbs
        [WBS] <work package>        → type:wbs
```

**Sub-epic suffix**: `Epic 9K:` → `F9K.1:` → `S9K.1.1:`

## Required Labels

| Issue Type | Required Label | Optional |
|-----------|---------------|----------|
| Epic | `type:epic` | project label, `domain:*` |
| Feature | `type:feature` | project label |
| Story | `type:story` | `tier:*`, `phase:*` |
| PBS | `type:pbs` | — |
| WBS | `type:wbs` | — |

## Label Colors

| Category | Color | Labels |
|----------|-------|--------|
| Type | `#BFD4F2` | `type:epic`, `type:feature`, `type:story`, `type:pbs`, `type:wbs`, `type:registry` |
| Domain | `#D4C5F9` | `domain:pf-core`, `domain:baiv`, `domain:w4m`, `domain:air` |
| Tier | `#FBCA04` | `tier:t1`, `tier:t2`, `tier:t3` |
| Phase | `#C2E0C6` | `phase:0` through `phase:5` |

## PR Template Fields

```
## Summary         ← what changed and why
## Links           ← Resolves: #N, Parent: #N
## Registry Artifact ← required for WBS/PBS PRs
## Changes         ← bullet list
## Test Plan       ← checklist
## Checklist       ← conventions, secrets, title
```

## Project Board Fields

| Field | Type | Values |
|-------|------|--------|
| Type | Select | Epic, Feature, Story, PBS, WBS, Registry |
| Status | Select | Backlog, Ready, In Progress, In Review, Done |
| Priority | Select | P0, P1, P2, P3 |
| Estimate | Number | — |
| Registry ID | Text | `namespace:type:name:version` |
| PBS ID | Text | `PBS-X.Y` |
| WBS Code | Text | `X.Y.Z` |

## Common gh Commands

```bash
# Create an epic
gh issue create --label "type:epic" --title "Epic N: Title"

# Create a feature under epic
gh issue create --label "type:feature" --title "FN.x: Title"

# List all epics
gh issue list --label "type:epic"

# List features under epic 10
gh issue list --json title --jq '.[].title' | grep "^F10\."

# Add issue to project board
gh project item-add NUMBER --owner OWNER --url ISSUE_URL
```

## Plugin Skills (Claude Code)

```
/azlan-github-workflow:setup-repo        owner/repo [--mode solo|team]
/azlan-github-workflow:create-epic       [title]
/azlan-github-workflow:create-feature    [title] [--epic N]
/azlan-github-workflow:create-story      [title] [--feature FN.x]
/azlan-github-workflow:setup-project-board [title] [--owner login]
/azlan-github-workflow:review-hierarchy  [owner/repo]
```

## Bootstrap (New Repo)

```bash
# Interactive (run in terminal — requires TTY)
gh api repos/ajrmooreuk/Azlan-EA-AAA/contents/scripts/bootstrap-new-repo.sh \
  -q '.content' | base64 -d | bash -s --

# Non-interactive (works anywhere — CI, scripts, tool runners)
... | bash -s -- my-repo [--private] [--mode team] [--with-plugin] [--project-title "Name"]
```

## Setup Scripts

```bash
./scripts/setup-labels.sh           [--repo owner/repo]
./scripts/setup-branch-protection.sh [--repo owner/repo] [--mode solo|team]
./scripts/setup-gh-project.sh       --owner login --project-title name [--repo owner/repo]
./scripts/migrate-issues-into-hierarchy.sh --repo owner/repo [--dry-run]
./scripts/setup-all.sh              --repo owner/repo --owner login --project-title name [--mode solo|team]
```
