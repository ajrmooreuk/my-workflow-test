# PROMOTION_PAT Setup Guide

Step-by-step instructions for creating and configuring the classic Personal Access Token required by the Azlan workflow promotion pipeline.

---

## Why a Classic PAT

GitHub Actions workflows in this pipeline push commits that include `.github/workflows/*.yml` files to other repos. GitHub treats workflow file modifications as a privileged operation. Only **classic** PATs support the `workflow` scope — fine-grained PATs do not.

---

## Step 1: Create the Classic PAT

1. Open: **https://github.com/settings/tokens** (not the fine-grained tab)
2. Click **Generate new token** → **Generate new token (classic)**
3. Fill in:
   - **Note**: `azlan-workflow-promotion`
   - **Expiration**: 90 days (or your preference)
4. Select **exactly these scopes** (tick the checkboxes):

   | Scope | Why |
   |-------|-----|
   | `repo` | Full control — checkout, push branches, create PRs on private repos |
   | `workflow` | Push files under `.github/workflows/` to target repos |

   You do **not** need any other scopes. Do not tick `admin:org`, `gist`, `notifications`, etc.

5. Click **Generate token**
6. **Copy the token immediately** — it starts with `ghp_` and is only shown once

---

## Step 2: Set the Secret on All Three Repos

Run each command in your terminal. Each will prompt `? Paste your secret` — paste the `ghp_...` token and press Enter.

```bash
gh secret set PROMOTION_PAT --repo ajrmooreuk/azlan-workflow-dev
gh secret set PROMOTION_PAT --repo ajrmooreuk/azlan-workflow-test
gh secret set PROMOTION_PAT --repo ajrmooreuk/azlan-workflow-prod
```

If copy/paste causes issues (whitespace, extra newline), use the pipe method instead:

```bash
echo -n "ghp_YOUR_TOKEN_HERE" | gh secret set PROMOTION_PAT --repo ajrmooreuk/azlan-workflow-dev
echo -n "ghp_YOUR_TOKEN_HERE" | gh secret set PROMOTION_PAT --repo ajrmooreuk/azlan-workflow-test
echo -n "ghp_YOUR_TOKEN_HERE" | gh secret set PROMOTION_PAT --repo ajrmooreuk/azlan-workflow-prod
```

Replace `ghp_YOUR_TOKEN_HERE` with the actual token. The `-n` flag prevents a trailing newline.

---

## Step 3: Verify

Confirm the secrets are set:

```bash
gh secret list --repo ajrmooreuk/azlan-workflow-dev
gh secret list --repo ajrmooreuk/azlan-workflow-test
gh secret list --repo ajrmooreuk/azlan-workflow-prod
```

Each should show `PROMOTION_PAT` with a recent timestamp.

---

## Step 4: Test

Trigger a dev-to-test promotion:

```bash
gh workflow run promote.yml --repo ajrmooreuk/azlan-workflow-dev -f direction=dev-to-test
```

Wait 30 seconds, then check:

```bash
gh run list --repo ajrmooreuk/azlan-workflow-dev --workflow promote.yml --limit 1
```

If the status is `completed` with `success`, the PAT is working. If it shows `failure`, check:

```bash
gh run view <RUN_ID> --repo ajrmooreuk/azlan-workflow-dev --log-failed
```

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Bad credentials` | Token is invalid, expired, or corrupted during paste | Regenerate the token and re-set the secret using the pipe method |
| `Resource not accessible` | Token lacks required scope | Ensure both `repo` and `workflow` are ticked |
| `refusing to allow a PAT to create or update workflow` | Using a fine-grained PAT (starts with `github_pat_`) | Must use a classic PAT (starts with `ghp_`) |
| `HttpError: Not Found` | Token does not have access to the target repo | Ensure the PAT owner has write access to all three repos |

---

## Token Checklist

Before re-attempting, confirm all of these:

- [ ] Token type is **classic** (not fine-grained)
- [ ] Token value starts with `ghp_`
- [ ] Scope `repo` is ticked
- [ ] Scope `workflow` is ticked
- [ ] Token is **not expired**
- [ ] Token was created by `ajrmooreuk` (the repo owner)
- [ ] Token was copied in full (no truncation, no extra whitespace)
- [ ] Secret was set on all three repos using `gh secret set`
