#!/usr/bin/env bash
# setup-promotion-repos.sh — Create the three-repo promotion structure (dev/test/prod)
# Part of Azlan Workflow Promotion Strategy
#
# Usage:
#   ./scripts/setup-promotion-repos.sh [--org OWNER] [--prefix azlan-workflow] [--private]
#
# Creates three repos: {prefix}-dev, {prefix}-test, {prefix}-prod
# Installs convention files and tier-appropriate promotion workflows in each.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Defaults ───────────────────────────────────────────────
ORG=""
PREFIX="azlan-workflow"
VISIBILITY="--public"

# ─── Colours (if terminal supports them) ────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

banner()  { echo -e "\n${BLUE}${BOLD}══════════════════════════════════════════${NC}"; echo -e "${BLUE}${BOLD}  $1${NC}"; echo -e "${BLUE}${BOLD}══════════════════════════════════════════${NC}\n"; }
step()    { echo -e "${GREEN}✓${NC} $1"; }
info()    { echo -e "${YELLOW}→${NC} $1"; }
fail()    { echo -e "${RED}✗ $1${NC}"; exit 1; }

# ─── Parse arguments ────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)       ORG="$2"; shift 2 ;;
    --prefix)    PREFIX="$2"; shift 2 ;;
    --private)   VISIBILITY="--private"; shift ;;
    --help|-h)
      cat <<'HELP'
Usage: setup-promotion-repos.sh [options]

Creates the three-repo promotion structure for Azlan workflow conventions:
  {prefix}-dev   — developer iteration (solo mode)
  {prefix}-test  — SME validation (team mode)
  {prefix}-prod  — source of truth (team mode, auto-tagging)

Options:
  --org OWNER        GitHub user or org (default: current user)
  --prefix NAME      Repo name prefix (default: azlan-workflow)
  --private          Create private repos (default: public)
  --help             Show this help message

What it does:
  1. Creates three GitHub repos
  2. Copies convention files and promotion config to each
  3. Installs tier-appropriate workflows:
     - dev:  promote.yml, validate-conventions.yml
     - test: validate-conventions.yml
     - prod: auto-tag.yml, sync-to-live.yml, drift-detection.yml
  4. Configures branch protection (solo for dev, team for test/prod)
  5. Creates promotion labels on test and prod

After setup, add a PROMOTION_PAT secret to all three repos:
  gh secret set PROMOTION_PAT --repo owner/{prefix}-dev
  gh secret set PROMOTION_PAT --repo owner/{prefix}-test
  gh secret set PROMOTION_PAT --repo owner/{prefix}-prod

Examples:
  ./scripts/setup-promotion-repos.sh
  ./scripts/setup-promotion-repos.sh --org myorg --prefix my-workflow
  ./scripts/setup-promotion-repos.sh --private --prefix team-workflow
HELP
      exit 0
      ;;
    *) fail "Unknown option: $1 (run with --help)" ;;
  esac
done

# ─── Validation ─────────────────────────────────────────────
command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) is not installed.\n  Install it from: https://cli.github.com/"
command -v jq >/dev/null 2>&1 || fail "jq is not installed.\n  Install it: brew install jq (macOS) or apt install jq (Linux)"
gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated.\n  Run: gh auth login"

if [[ -z "$ORG" ]]; then
  ORG=$(gh api user --jq '.login')
fi

# ─── Tier definitions ───────────────────────────────────────
TIERS="dev test prod"

# Lookup functions (bash 3.2 compatible — no associative arrays)
tier_mode() {
  case "$1" in
    dev)  echo "solo" ;;
    test) echo "team" ;;
    prod) echo "team" ;;
  esac
}

tier_workflows() {
  case "$1" in
    dev)  echo "promote.yml validate-conventions.yml" ;;
    test) echo "validate-conventions.yml" ;;
    prod) echo "auto-tag.yml sync-to-live.yml drift-detection.yml" ;;
  esac
}

banner "Azlan Workflow — Promotion Setup"
echo "  Owner:      $ORG"
echo "  Prefix:     $PREFIX"
echo "  Visibility: ${VISIBILITY#--}"
echo "  Repos:      ${PREFIX}-dev, ${PREFIX}-test, ${PREFIX}-prod"
echo ""

# ─── Read manifest for convention files ─────────────────────
MANIFEST="$REPO_ROOT/promotion/convention-manifest.json"
[[ -f "$MANIFEST" ]] || fail "Convention manifest not found at $MANIFEST"

# ─── Create each tier repo ──────────────────────────────────
for tier in $TIERS; do
  REPO_NAME="${PREFIX}-${tier}"
  FULL_REPO="${ORG}/${REPO_NAME}"

  banner "Setting up ${tier} tier — ${FULL_REPO}"

  # Create repo if it doesn't exist
  if gh repo view "$FULL_REPO" >/dev/null 2>&1; then
    info "Repository $FULL_REPO already exists — using it."
  else
    gh repo create "$REPO_NAME" $VISIBILITY --clone 2>/dev/null || true
    step "Created $FULL_REPO"
  fi

  # Clone if not already local
  if [[ ! -d "$REPO_NAME" ]]; then
    gh repo clone "$FULL_REPO" "$REPO_NAME" -- --quiet 2>/dev/null || true
  fi

  pushd "$REPO_NAME" > /dev/null

  # Ensure initial commit
  if ! git log --oneline -1 >/dev/null 2>&1; then
    echo "# ${REPO_NAME}" > README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    git push --quiet 2>/dev/null || git push --set-upstream origin main --quiet
  fi

  # Copy convention files from manifest
  info "Copying convention files..."
  for file in $(jq -r '.files[]' "$MANIFEST"); do
    if [[ -f "$REPO_ROOT/$file" ]]; then
      mkdir -p "$(dirname "$file")"
      cp "$REPO_ROOT/$file" "$file"
    fi
  done
  step "Convention files copied"

  # Copy promotion config
  mkdir -p promotion
  cp "$REPO_ROOT/promotion/convention-manifest.json" promotion/
  cp "$REPO_ROOT/promotion/live-repos.json" promotion/
  # Template promotion.env with actual values
  cat > promotion/promotion.env <<ENVEOF
# Promotion configuration — auto-generated by setup-promotion-repos.sh
PROMOTION_ORG="${ORG}"
DEV_REPO="${PREFIX}-dev"
TEST_REPO="${PREFIX}-test"
PROD_REPO="${PREFIX}-prod"
MANIFEST_PATH="promotion/convention-manifest.json"
LIVE_REPOS_PATH="promotion/live-repos.json"
ENVEOF
  step "Promotion config installed (templated for ${ORG})"

  # Install tier-appropriate workflows
  info "Installing ${tier} tier workflows..."
  mkdir -p .github/workflows
  for wf in $(tier_workflows "$tier"); do
    if [[ -f "$REPO_ROOT/.github/workflows/$wf" ]]; then
      cp "$REPO_ROOT/.github/workflows/$wf" ".github/workflows/$wf"
      step "  $wf"
    else
      info "  $wf not found in source — skipping"
    fi
  done

  # Copy promote.sh to dev tier
  if [[ "$tier" == "dev" ]]; then
    mkdir -p scripts
    if [[ -f "$REPO_ROOT/scripts/promote.sh" ]]; then
      cp "$REPO_ROOT/scripts/promote.sh" scripts/promote.sh
      chmod +x scripts/promote.sh
      step "  promote.sh (CLI shortcut)"
    fi
  fi

  # Commit and push
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "feat: configure ${tier} tier for Azlan workflow promotion" --quiet
    git push --quiet
    step "Committed and pushed"
  else
    info "No changes to commit"
  fi

  # Branch protection
  MODE=$(tier_mode "$tier")
  if [[ -f "$REPO_ROOT/scripts/setup-branch-protection.sh" ]]; then
    bash "$REPO_ROOT/scripts/setup-branch-protection.sh" --repo "$FULL_REPO" --mode "$MODE" 2>/dev/null || info "Branch protection skipped (may need admin access)"
    step "Branch protection set ($MODE mode)"
  fi

  # Labels
  if [[ -f "$REPO_ROOT/scripts/setup-labels.sh" ]]; then
    bash "$REPO_ROOT/scripts/setup-labels.sh" --repo "$FULL_REPO" 2>/dev/null || true
    step "Standard labels created"
  fi

  # Tier-specific labels
  if [[ "$tier" == "test" || "$tier" == "prod" ]]; then
    gh label create "needs-sme-approval" --color "FBCA04" --description "SME approval required for promotion" --repo "$FULL_REPO" 2>/dev/null || true
    step "Promotion label: needs-sme-approval"
  fi
  if [[ "$tier" == "prod" ]]; then
    gh label create "drift-detection" --color "D93F0B" --description "Convention drift detected in live repos" --repo "$FULL_REPO" 2>/dev/null || true
    gh label create "bump:major" --color "B60205" --description "Semver major bump" --repo "$FULL_REPO" 2>/dev/null || true
    gh label create "bump:patch" --color "0E8A16" --description "Semver patch bump" --repo "$FULL_REPO" 2>/dev/null || true
    step "Prod labels: drift-detection, bump:major, bump:patch"
  fi

  popd > /dev/null
  step "${tier} tier complete"
  echo ""
done

# ─── Summary ─────────────────────────────────────────────────
banner "Promotion Setup Complete"

echo "  Three repos created:"
for tier in $TIERS; do
  echo "    https://github.com/${ORG}/${PREFIX}-${tier}"
done

echo ""
echo -e "  ${YELLOW}ACTION REQUIRED:${NC} Add a Personal Access Token as a secret to all three repos."
echo "  The PAT needs 'repo' scope for cross-repo promotion."
echo ""
echo "  Run these commands (you'll be prompted for the token):"
for tier in $TIERS; do
  echo "    gh secret set PROMOTION_PAT --repo ${ORG}/${PREFIX}-${tier}"
done

echo ""
echo "  Then trigger your first promotion from the dev repo:"
echo "    cd ${PREFIX}-dev"
echo "    ./scripts/promote.sh dev-to-test"
echo ""
echo "  Or use the GitHub Actions UI:"
echo "    https://github.com/${ORG}/${PREFIX}-dev/actions/workflows/promote.yml"
echo ""
step "All done. Your three-repo promotion pipeline is ready."
