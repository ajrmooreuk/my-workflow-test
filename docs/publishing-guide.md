# Publishing Guide: Making the Workflow Available Without Repo Access

**Problem**: The bootstrap one-liner fetches scripts and assets from `Azlan-EA-AAA` via the GitHub API. Users need read access to that repo. If you want external collaborators (or future public users) to bootstrap repos without giving them access to `Azlan-EA-AAA`, you need a **public distribution repo**.

---

## Architecture

```
Azlan-EA-AAA (private / limited access)
    │
    │  manual publish (scripts/publish-workflow.sh)
    │
    ▼
ajrmooreuk/azlan-github-workflow (public)
    │
    │  users run bootstrap one-liner from here
    │
    ▼
user's new repo (fully configured)
```

- `Azlan-EA-AAA` remains your private working repo with ontologies, visualiser, and IP
- `azlan-github-workflow` is a **public read-only mirror** of just the workflow assets
- External users never need access to `Azlan-EA-AAA`

---

## What Gets Published

Only convention and tooling files cross into the public repo — never ontologies, visualiser code, or proprietary content:

```
azlan-github-workflow/          (public repo root)
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── epic.yml
│   │   ├── feature.yml
│   │   ├── story.yml
│   │   ├── pbs.yml
│   │   ├── wbs.yml
│   │   └── config.yml
│   ├── pull_request_template.md
│   ├── labels.yml
│   └── workflows/
│       ├── enforce-registry-link.yml
│       ├── validate-issue-naming.yml
│       └── validate-labels.yml
├── scripts/
│   ├── setup-labels.sh
│   ├── setup-branch-protection.sh
│   ├── setup-gh-project.sh
│   ├── migrate-issues-into-hierarchy.sh
│   ├── setup-all.sh
│   └── bootstrap-new-repo.sh
├── azlan-github-workflow/       ← Claude Code plugin
│   ├── .claude-plugin/plugin.json
│   ├── skills/
│   │   ├── setup-repo/SKILL.md
│   │   ├── create-epic/SKILL.md
│   │   ├── create-feature/SKILL.md
│   │   ├── create-story/SKILL.md
│   │   ├── setup-project-board/SKILL.md
│   │   └── review-hierarchy/SKILL.md
│   ├── docs/
│   │   ├── onboarding.md
│   │   ├── quick-reference.md
│   │   ├── migration-checklist.md
│   │   └── adr-001-packaging-approach.md
│   └── README.md
└── README.md                    ← public-facing quick start
```

---

## One-Time Setup

### 1. Create the public repo

```bash
gh repo create azlan-github-workflow --public --clone \
  --description "Azlan GitHub Workflow — Epic/Feature/Story conventions, templates, and setup scripts"
```

### 2. Run the publish script

From your local `Azlan-EA-AAA` checkout:

```bash
./scripts/publish-workflow.sh
```

This copies all distributable files into the public repo, commits, and pushes.

### 3. Update SOURCE_REPO in the published bootstrap script

The publish script automatically patches `SOURCE_REPO` in the published copy of `bootstrap-new-repo.sh` so it points to the public repo instead of `Azlan-EA-AAA`.

After publishing, external users run:

```bash
gh api repos/ajrmooreuk/azlan-github-workflow/contents/scripts/bootstrap-new-repo.sh \
  -q '.content' | base64 -d | bash -s --
```

No access to `Azlan-EA-AAA` needed.

---

## Publishing Workflow (Ongoing)

When you've made changes in `Azlan-EA-AAA` that you want to release to the public:

### Step 1 — Review what changed

```bash
# From Azlan-EA-AAA root
git log --oneline --since="last publish date" -- \
  .github/ scripts/ azlan-github-workflow/
```

### Step 2 — Run the publish script

```bash
./scripts/publish-workflow.sh
```

The script will:

1. Verify the public repo exists and is cloned locally (sibling directory)
2. Copy all distributable files from `Azlan-EA-AAA` to the public repo
3. Patch `SOURCE_REPO` in `bootstrap-new-repo.sh` to point to the public repo
4. Show a diff of what changed
5. Prompt for a commit message
6. Commit and push

### Step 3 — Verify

```bash
# Quick smoke test from the public repo
gh api repos/ajrmooreuk/azlan-github-workflow/contents/scripts/bootstrap-new-repo.sh \
  -q '.content' | base64 -d | bash -s -- publish-verify-test --with-plugin

# Clean up
gh repo delete ajrmooreuk/publish-verify-test --yes
```

---

## What NOT to Publish

These files live in `Azlan-EA-AAA` only and must never be copied to the public repo:

| Path | Reason |
|------|--------|
| `PBS/` | Ontology library — proprietary IP |
| `PBS/TOOLS/` | Visualiser source code |
| `docs/` (root-level) | Internal architecture docs |
| `.claude/` | Project-specific Claude config |
| `azlan-github-workflow/docs/publishing-guide.md` | This guide (internal process) |
| `azlan-github-workflow/docs/promotion-strategy.md` | Internal promotion strategy |
| `azlan-github-workflow/docs/sme-test-guide.md` | Internal testing guide |

The publish script has an explicit allowlist — only listed files are copied, so nothing leaks by accident.

---

## Rollback

If a bad publish goes out:

```bash
cd /path/to/azlan-github-workflow   # the public repo
git log --oneline -5                # find the last good commit
git revert HEAD                     # revert the bad publish
git push
```

---

## Future: Automating the Publish

When the publish cadence justifies it, you can replace the manual script with a GitHub Action on `Azlan-EA-AAA` that auto-publishes on tagged releases. See [promotion-strategy.md](promotion-strategy.md) for the full three-repo approach.

For now, the manual process gives you full control over what goes public and when.
