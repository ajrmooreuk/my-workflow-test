# ADR-001: Packaging Approach for Azlan GitHub Workflow

**Status**: Accepted
**Date**: 2026-02-12
**Epic**: Epic 9K (#155)

## Context

The Azlan workflow (Epic/Feature/Story/PBS/WBS hierarchy, naming conventions, label taxonomy, project board fields) was developed and proven in the `Azlan-EA-AAA` repository. Sibling projects need to adopt the same conventions without copying files manually or reinventing configuration.

## Decision

Package the workflow as **three complementary layers**:

### Layer 1: GitHub Template Repository
- `.github/ISSUE_TEMPLATE/` — issue forms (epic, feature, story, PBS, WBS)
- `.github/pull_request_template.md` — PR template with registry traceability
- `.github/labels.yml` — label definitions
- `.github/workflows/` — enforcement workflows

**Rationale**: Templates are the simplest adoption path. A new repo created from the template gets everything pre-configured with zero commands.

### Layer 2: Idempotent Setup Scripts
- `scripts/setup-labels.sh` — create labels via `gh` CLI
- `scripts/setup-branch-protection.sh` — configure main branch rules
- `scripts/setup-gh-project.sh` — create project board with standard fields
- `scripts/migrate-issues-into-hierarchy.sh` — classify existing issues
- `scripts/setup-all.sh` — orchestrate all scripts

**Rationale**: Existing repos can't use templates retroactively. Scripts provide the same result for repos that already exist. Idempotency means they're safe to re-run.

### Layer 3: Claude Code Plugin
- `azlan-github-workflow/` — plugin with 6 skills
- Skills: setup-repo, create-epic, create-feature, create-story, setup-project-board, review-hierarchy

**Rationale**: Claude Code users get intelligent, convention-aware commands that auto-detect numbering, validate naming, and audit compliance. Non-Claude users lose nothing — Layers 1 and 2 work independently.

## Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| **Monorepo only** | Forces all projects into one repo; doesn't scale to independent repos |
| **GitHub Actions reusable workflows only** | Good for enforcement but can't create labels, project boards, or issue templates |
| **MCP server instead of skills** | Over-engineered for this use case; skills are simpler and don't require a running server |
| **npm/pip package** | Adds a package manager dependency; `gh` CLI is sufficient |

## Conventions: Mandatory vs Recommended

### Mandatory
- Title format: `Epic N:`, `FN.x:`, `SN.x.y:`, `[PBS]`, `[WBS]`
- Labels: `type:epic`, `type:feature`, `type:story`, `type:pbs`, `type:wbs`
- PR traceability: `Resolves: #N` for all PRs
- Registry artifact: Required on WBS/PBS PRs

### Recommended
- Project-specific labels (e.g., `visualiser`)
- Domain labels (`domain:*`)
- Tier labels (`tier:*`)
- Phase labels (`phase:*`)
- Project board with standard fields

## Consequences

- **Positive**: Any repo can adopt in under 15 minutes via any of the three paths
- **Positive**: No runtime dependencies beyond `gh` CLI
- **Positive**: Claude Code users get convention-aware intelligence
- **Negative**: Plugin requires Claude Code — but Layer 1+2 work without it
- **Negative**: Three layers means three things to maintain — mitigated by the fact that they share conventions, not code
