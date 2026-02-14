# SME Test Guide — Azlan GitHub Workflow

A step-by-step guide for testing the Azlan workflow package on a fresh repository.
No prior Git or command-line experience required.

---

## Before You Start

You need these tools installed. If any are missing, follow the links.

| Tool | What It Does | Install |
|------|-------------|---------|
| **GitHub account** | Hosts your code and issues | [github.com/signup](https://github.com/signup) |
| **GitHub CLI (`gh`)** | Lets you run GitHub commands from Terminal | [cli.github.com](https://cli.github.com/) |
| **Claude Code** (Stage 2 only) | AI coding assistant with plugin support | [claude.com/claude-code](https://claude.com/claude-code) |

### One-time setup: authenticate GitHub CLI

Open **Terminal** (Mac: Spotlight → type "Terminal" → Enter) and paste:

```
gh auth login
```

Follow the prompts:
1. Choose **GitHub.com**
2. Choose **HTTPS**
3. Choose **Login with a web browser**
4. Copy the one-time code, press Enter, paste it in the browser, and authorise

You only need to do this once.

---

## Stage 1: Automated Repo Setup (one command)

This creates a test repository with everything pre-configured — issue templates, labels, branch protection, project board, enforcement workflows, and setup scripts.

### The Command

Open Terminal and paste this single command:

```
gh api repos/ajrmooreuk/Azlan-EA-AAA/contents/scripts/bootstrap-new-repo.sh -q '.content' | base64 -d | bash -s -- my-workflow-test
```

That's it. Sit back and watch it run.

**What it does automatically (in order):**

| Step | What Happens | Time |
|------|-------------|------|
| 1 | Creates a new public GitHub repo called `my-workflow-test` | ~3s |
| 2 | Downloads all issue templates (Epic, Feature, Story, PBS, WBS) | ~5s |
| 3 | Downloads setup scripts and enforcement workflows | ~3s |
| 4 | Commits and pushes everything to the repo | ~3s |
| 5 | Creates 21 standard labels (type, domain, tier, phase) | ~15s |
| 6 | Configures branch protection on `main` | ~2s |
| 7 | Creates a project board with 7 standard fields | ~5s |

**Total: about 30 seconds.**

When it finishes, you'll see a summary with links to your new repo.

### Options

If you need different settings, add flags:

```
# Shorthand for the one-liner (used in examples below)
# BOOTSTRAP = gh api repos/ajrmooreuk/Azlan-EA-AAA/contents/scripts/bootstrap-new-repo.sh -q '.content' | base64 -d | bash -s --

# Private repo with team-level branch protection
BOOTSTRAP my-workflow-test --private --mode team

# Include the Claude Code plugin (for Stage 2)
BOOTSTRAP my-workflow-test --with-plugin

# Custom project board name
BOOTSTRAP my-workflow-test --project-title "Sprint Board"

# All options at once
BOOTSTRAP my-workflow-test --private --mode team --with-plugin --project-title "My Project"
```

To run any of these for real, replace `BOOTSTRAP` with the full command from "The Command" above.

### If you prefer to run it locally

```
cd /path/to/Azlan-EA-AAA
./scripts/bootstrap-new-repo.sh my-workflow-test
```

### Verify It Worked

Open these links in your browser (replace `YOUR_USERNAME` with your GitHub username):

1. **Issue templates**: `https://github.com/YOUR_USERNAME/my-workflow-test/issues/new/choose`
   - You should see 5 issue types: Epic, Feature, Story, PBS Component, WBS Task

2. **Labels**: `https://github.com/YOUR_USERNAME/my-workflow-test/labels`
   - You should see 21+ labels in colour-coded groups

3. **Workflows**: `https://github.com/YOUR_USERNAME/my-workflow-test/actions`
   - You should see 3 enforcement workflows

4. **Project board**: `https://github.com/users/YOUR_USERNAME/projects/`
   - Click your project → you should see 7 fields (Type, Status, Priority, Estimate, Registry ID, PBS ID, WBS Code)

### Test the Issue Templates

| Test | How | Expected Result |
|------|-----|-----------------|
| **Create an Epic** | Issue chooser → Epic → title: `Epic 1: Test Workflow` → Submit | Created with `type:epic` label |
| **Create a Feature** | Issue chooser → Feature → title: `F1.1: Test Feature` → Parent Epic: `#1` → Submit | Created with `type:feature` label |
| **Create a Story** | Issue chooser → Story → title: `S1.1.1: Test Story` → Parent Feature: `#2` → Submit | Created with `type:story` label |

### Stage 1 Checklist

- [ ] Bootstrap script ran without errors
- [ ] 5 issue templates appear on the chooser page
- [ ] 21+ labels exist with correct colours
- [ ] 3 enforcement workflows appear in Actions tab
- [ ] Project board has 7 custom fields
- [ ] Test epic, feature, and story created with correct labels

---

## Stage 2: Claude Code Plugin (one command)

This adds intelligent, convention-aware commands to Claude Code.

### Setup

If you didn't use `--with-plugin` in Stage 1, run the bootstrap again with the flag:

```
cd my-workflow-test
gh api repos/ajrmooreuk/Azlan-EA-AAA/contents/scripts/bootstrap-new-repo.sh -q '.content' | base64 -d | bash -s -- my-workflow-test --with-plugin
```

Or if you already ran Stage 1, just add the plugin:

```
cd my-workflow-test
mkdir -p azlan-github-workflow/.claude-plugin
mkdir -p azlan-github-workflow/skills/{setup-repo,create-epic,create-feature,create-story,setup-project-board,review-hierarchy}

gh api repos/ajrmooreuk/Azlan-EA-AAA/contents/azlan-github-workflow/.claude-plugin/plugin.json?ref=main -q '.content' | base64 -d > azlan-github-workflow/.claude-plugin/plugin.json

for skill in setup-repo create-epic create-feature create-story setup-project-board review-hierarchy; do
  gh api "repos/ajrmooreuk/Azlan-EA-AAA/contents/azlan-github-workflow/skills/$skill/SKILL.md?ref=main" -q '.content' | base64 -d > "azlan-github-workflow/skills/$skill/SKILL.md"
done
```

### Launch Claude Code with the plugin

```
claude --plugin-dir ./azlan-github-workflow
```

Claude Code opens. You should see the 6 Azlan skills available.

### Test the Plugin Skills

Type each command at the Claude Code prompt:

| Test | Command | Expected Result |
|------|---------|-----------------|
| **Audit** | `/azlan-github-workflow:review-hierarchy YOUR_USERNAME/my-workflow-test` | Compliance report — your test issues from Stage 1 should pass |
| **Create Epic** | `/azlan-github-workflow:create-epic Automated Test Epic` | Creates `Epic 2: Automated Test Epic` (auto-detects next number) |
| **Create Feature** | `/azlan-github-workflow:create-feature Plugin Feature --epic 2` | Creates `F2.1: Plugin Feature` linked to Epic 2 |
| **Create Story** | `/azlan-github-workflow:create-story Plugin Story --feature F2.1` | Creates `S2.1.1: Plugin Story` linked to F2.1 |

### Stage 2 Checklist

- [ ] Claude Code launched with 6 skills visible
- [ ] `review-hierarchy` produced a compliance report
- [ ] `create-epic` auto-numbered correctly (Epic 2)
- [ ] `create-feature` linked to parent epic
- [ ] `create-story` linked to parent feature
- [ ] All issues have correct titles, labels, and body content

---

## Cleanup

When you're done testing, delete the test repo:

```
gh repo delete YOUR_USERNAME/my-workflow-test --yes
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `gh: command not found` | Install GitHub CLI: [cli.github.com](https://cli.github.com/) |
| `not logged in` or `401` | Run `gh auth login` and re-authenticate |
| `permission denied` on scripts | Run `chmod +x scripts/*.sh` |
| `claude: command not found` | Install Claude Code: [claude.com/claude-code](https://claude.com/claude-code) |
| Labels already exist errors | Safe to ignore — the script skips existing labels |
| Issue templates not showing | Wait 30 seconds and refresh — GitHub caches template lists |
| Bootstrap says repo exists | Safe — it will re-use the existing repo |
| `base64: invalid input` | Check your internet connection and try again |

---

## Naming Convention Cheatsheet

```
Epic 1: Customer Outcome          → type:epic
  F1.1: Feature Capability        → type:feature
    S1.1.1: User Story            → type:story
      [PBS] Deliverable           → type:pbs
        [WBS] Work Package        → type:wbs
```

Each level links to its parent. Labels are applied automatically by the templates.
