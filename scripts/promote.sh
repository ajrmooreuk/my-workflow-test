#!/usr/bin/env bash
# promote.sh — Trigger a promotion from the command line
# Part of Azlan Workflow Promotion Strategy
#
# Usage:
#   ./scripts/promote.sh dev-to-test
#   ./scripts/promote.sh test-to-prod [--bump major|minor|patch]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Colours ─────────────────────────────────────────────────
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

# ─── Defaults ────────────────────────────────────────────────
DIRECTION=""
BUMP="minor"

# ─── Parse arguments ────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    dev-to-test|test-to-prod)  DIRECTION="$1"; shift ;;
    --bump)                    BUMP="$2"; shift 2 ;;
    --help|-h)
      cat <<'HELP'
Usage: promote.sh <direction> [options]

Triggers a promotion workflow via GitHub Actions.

Arguments:
  dev-to-test          Promote convention files from dev to test repo
  test-to-prod         Promote convention files from test to prod repo

Options:
  --bump major|minor|patch   Version bump type for test-to-prod (default: minor)
  --help                     Show this help message

Examples:
  ./scripts/promote.sh dev-to-test
  ./scripts/promote.sh test-to-prod
  ./scripts/promote.sh test-to-prod --bump major

What happens:
  1. Triggers the promote.yml workflow on the current repo
  2. The workflow copies convention files to the target repo
  3. A PR is created on the target repo for review
  4. (test-to-prod) Merging the PR auto-creates a semver tag
HELP
      exit 0
      ;;
    *) fail "Unknown argument: $1 (run with --help)" ;;
  esac
done

# ─── Validation ─────────────────────────────────────────────
[[ -z "$DIRECTION" ]] && fail "Direction required: dev-to-test or test-to-prod\n  Run with --help for usage."
command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) is not installed.\n  Install it from: https://cli.github.com/"
gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated.\n  Run: gh auth login"

case "$BUMP" in
  major|minor|patch) ;;
  *) fail "Invalid bump type: $BUMP (must be major, minor, or patch)" ;;
esac

# ─── Load config ────────────────────────────────────────────
ENV_FILE="$REPO_ROOT/promotion/promotion.env"
[[ -f "$ENV_FILE" ]] || fail "Promotion config not found at $ENV_FILE"
source "$ENV_FILE"

# Determine the repo to dispatch the workflow on
CURRENT_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
if [[ -z "$CURRENT_REPO" ]]; then
  # Fall back to config
  if [[ "$DIRECTION" == "dev-to-test" ]]; then
    CURRENT_REPO="${PROMOTION_ORG}/${DEV_REPO}"
  else
    CURRENT_REPO="${PROMOTION_ORG}/${TEST_REPO}"
  fi
fi

# ─── Trigger workflow ───────────────────────────────────────
banner "Promote: $DIRECTION"

echo "  Repo:      $CURRENT_REPO"
echo "  Direction: $DIRECTION"
if [[ "$DIRECTION" == "test-to-prod" ]]; then
  echo "  Bump:      $BUMP"
fi
echo ""

info "Triggering promote.yml workflow..."

FIELDS="-f direction=$DIRECTION"
if [[ "$DIRECTION" == "test-to-prod" ]]; then
  FIELDS="$FIELDS -f bump=$BUMP"
fi

gh workflow run promote.yml --repo "$CURRENT_REPO" $FIELDS

step "Workflow triggered"
echo ""
info "Monitor progress at:"
echo "  https://github.com/$CURRENT_REPO/actions/workflows/promote.yml"
echo ""
step "Done. A PR will be created on the target repo when the workflow completes."
