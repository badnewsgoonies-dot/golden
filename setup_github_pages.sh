#!/usr/bin/env bash
# Deploy exports/html5 to GitHub Pages (gh-pages branch)
# Usage:
#   ./setup_github_pages.sh [--cname yourdomain.com]
# Requirements:
#   - Git remote "origin" set and you are authenticated (SSH or HTTPS w/ token)
#   - Build output present at exports/html5/
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

CNAME_DOMAIN=""
if [[ "${1:-}" == "--cname" && -n "${2:-}" ]]; then
  CNAME_DOMAIN="$2"
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo -e "${RED}Error: Not a git repository${NC}"; exit 1
fi

if [[ ! -d exports/html5 ]]; then
  echo -e "${RED}Error: exports/html5 not found. Build the web export first.${NC}"; exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo -e "${RED}Error: No git remote 'origin' configured.${NC}"; exit 1
fi

ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo -e "${BLUE}Preparing gh-pages branch...${NC}"
if git show-ref --verify --quiet refs/heads/gh-pages; then
  git checkout gh-pages
else
  git checkout --orphan gh-pages
fi

# Clean working tree
# Remove all tracked files and any untracked content
if [[ -n "$(git ls-files -z | tr -d '\0')" ]]; then
  git rm -rf . >/dev/null 2>&1 || true
fi
# Remove untracked files/dirs
find . -mindepth 1 -maxdepth 1 \
  ! -name '.' \
  ! -name '..' \
  ! -name '.git' \
  -exec rm -rf {} +

# Copy export
cp -R exports/html5/* .
# Ensure GitHub Pages does not run Jekyll
printf "" > .nojekyll

if [[ -n "$CNAME_DOMAIN" ]]; then
  echo "$CNAME_DOMAIN" > CNAME
fi

# Commit and push
if [[ -n "$(git status --porcelain)" ]]; then
  git add .
  git commit -m "Deploy Golden Battle Tower to GitHub Pages"
else
  echo -e "${YELLOW}No changes to commit on gh-pages.${NC}"
fi

echo -e "${BLUE}Pushing gh-pages...${NC}"
# Set upstream if first push
if git rev-parse --verify --quiet refs/remotes/origin/gh-pages; then
  git push origin gh-pages
else
  git push -u origin gh-pages
fi

echo -e "${GREEN}Deployed to gh-pages.${NC}"

echo -e "${BLUE}Restoring original branch: ${ORIG_BRANCH}${NC}"
# Try to restore original branch if it still exists locally
if git show-ref --verify --quiet "refs/heads/${ORIG_BRANCH}"; then
  git checkout "$ORIG_BRANCH"
else
  echo -e "${YELLOW}Original branch ${ORIG_BRANCH} not found locally. Skipping checkout.${NC}"
fi

echo -e "${GREEN}Done!${NC}"
