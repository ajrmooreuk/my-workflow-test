# Azlan Workflow — Onboarding Guide

This guide covers three adoption paths for the Azlan GitHub workflow.

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- Repository admin access
- (Optional) [Claude Code](https://claude.com/claude-code) for plugin skills

---

## Path 1: New Repository (one command)

### Interactive Bootstrap (recommended)

Run this directly in your **terminal** (requires a TTY for the prompts):

```bash
gh api repos/ajrmooreuk/Azlan-EA-AAA/contents/scripts/bootstrap-new-repo.sh \
  -q '.content' | base64 -d | bash -s --
```

The wizard prompts you for:

- **Repository name**
- **Project board title** (defaults to repo name)
- **Visibility** — public or private
- **Branch protection** — solo (PRs optional) or team (PRs required)
- **Claude Code plugin** — yes or no

It then creates the repo, downloads all templates/workflows/scripts, pushes to main, creates labels, configures branch protection, and sets up a project board.

> **Note:** Interactive mode requires a real terminal. It reads input from `/dev/tty`, so it works even when the script itself is piped in — but it will **not** work inside CI pipelines, Docker builds, or non-interactive tool runners (e.g. Claude Code). Use the non-interactive form below for those environments.

### Non-interactive Bootstrap

Pass all options as arguments — no TTY needed, suitable for scripts and CI:

```bash
gh api repos/ajrmooreuk/Azlan-EA-AAA/contents/scripts/bootstrap-new-repo.sh \
  -q '.content' | base64 -d | bash -s -- my-new-repo
```

### Options (non-interactive mode)

```bash
# With Claude Code plugin
... | bash -s -- my-new-repo --with-plugin

# Private repo, team-level protection
... | bash -s -- my-new-repo --private --mode team

# Custom project board name
... | bash -s -- my-new-repo --project-title "My Project"
```

### Launch the Claude Code plugin (if installed with `--with-plugin`)
```bash
cd my-new-repo
claude --plugin-dir ./azlan-github-workflow
```

Now you can use `/azlan-github-workflow:create-epic`, `/azlan-github-workflow:create-feature`, etc.

---

## Path 2: Existing Repository

### Step 1 — Copy workflow files
Copy these directories from the template into your repo:
```
.github/ISSUE_TEMPLATE/   → issue form templates
.github/pull_request_template.md
.github/workflows/        → enforcement workflows
scripts/                  → setup & migration scripts
```

### Step 2 — Run setup scripts
```bash
# Create standard labels
./scripts/setup-labels.sh --repo OWNER/my-repo

# Configure branch protection
./scripts/setup-branch-protection.sh --repo OWNER/my-repo --mode solo

# Create project board
./scripts/setup-gh-project.sh --owner OWNER --project-title "My Project" --repo OWNER/my-repo
```

### Step 3 — Migrate existing issues
Preview what would change:
```bash
./scripts/migrate-issues-into-hierarchy.sh --repo OWNER/my-repo --dry-run
```

Apply labels:
```bash
./scripts/migrate-issues-into-hierarchy.sh --repo OWNER/my-repo
```

### Step 4 — Install the Claude Code plugin (optional)
```bash
claude --plugin-dir /path/to/azlan-github-workflow
```

---

## Path 3: Without Claude Code

Everything works without the plugin. The plugin just provides convenience commands.

| Task | Without Plugin | With Plugin |
|------|---------------|-------------|
| Create epic | Use issue template form on GitHub | `/azlan-github-workflow:create-epic` |
| Create feature | Use issue template form on GitHub | `/azlan-github-workflow:create-feature` |
| Setup repo | `./scripts/setup-all.sh` | `/azlan-github-workflow:setup-repo` |
| Audit compliance | Manual review | `/azlan-github-workflow:review-hierarchy` |

The issue templates, PR template, enforcement workflows, and setup scripts all work independently.

---

## Naming Convention Quick Reference

| Type | Format | Example |
|------|--------|---------|
| Epic | `Epic N:` | `Epic 10: Customer Onboarding` |
| Feature | `FN.x:` | `F10.1: Registration Flow` |
| Story | `SN.x.y:` | `S10.1.1: Email Validation` |
| PBS | `[PBS]` | `[PBS] Auth Module` |
| WBS | `[WBS]` | `[WBS] Implement OAuth Endpoint` |

Letter suffixes for sub-epics: `Epic 9K:` → `F9K.1:` → `S9K.1.1:`

---

## What's Enforced Automatically

| Workflow | Trigger | What It Checks |
|----------|---------|---------------|
| `enforce-registry-link.yml` | PR open/edit | WBS/PBS PRs must have `Registry Artifact:` |
| `validate-issue-naming.yml` | Issue open/edit | Title matches label convention |
| `validate-labels.yml` | Issue open/edit/label | Title implies type but label is missing |

All enforcement is non-blocking (warnings) except the registry link check which fails the PR.
