#!/usr/bin/env bash
# pi-toolkit — sync current live Pi config into this repo, scan for secrets,
# then commit. Never pushes.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="${HOME}/.pi/agent"
AGENTS_SKILLS="${HOME}/.agents/skills"
# skills curated out of this repo on purpose (they stay in ~/.agents/skills locally)
SKIP_SKILLS="codex-prove rendercv sol-control"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mABORT\033[0m %s\n' "$*" >&2; exit 1; }

cd "$REPO_DIR"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo"

# ---------------------------------------------------------------------------
# 1. Copy live configs into the repo
# ---------------------------------------------------------------------------
log "Syncing live config into repo…"
cp "$PI_DIR/settings.json" "$REPO_DIR/agent/settings.json"
cp "$PI_DIR/open-tui.json" "$REPO_DIR/agent/open-tui.json" 2>/dev/null || true
cp "$PI_DIR/themes/"*.json "$REPO_DIR/agent/themes/" 2>/dev/null || true
cp "$PI_DIR/extensions/effort.ts" "$REPO_DIR/agent/extensions/effort.ts" 2>/dev/null || true
cp "$PI_DIR/lazy.json" "$REPO_DIR/agent/lazy.json" 2>/dev/null || true
cp "$PI_DIR/hermes-memory-config.json" "$REPO_DIR/agent/hermes-memory-config.json" 2>/dev/null || true
# snapshot of pi-managed dependency graph (record only — bootstrap re-installs)
cp "$PI_DIR/npm/package.json" "$PI_DIR/npm/package-lock.json" "$REPO_DIR/agent/npm/" 2>/dev/null || true

# skills (true location ~/.agents/skills; ~/.pi/agent/skills holds symlinks)
mkdir -p "$REPO_DIR/skills"
for skill_dir in "$AGENTS_SKILLS"/*/; do
  [[ -d "$skill_dir" ]] || continue
  name="$(basename "$skill_dir")"
  [[ " $SKIP_SKILLS " != *" $name "* ]] || continue
  rm -rf "$REPO_DIR/skills/$name"
  cp -a "$skill_dir" "$REPO_DIR/skills/$name"
done

# MCP config is NEVER copied — pi-mcp-adapter keeps the live token in
# mcp-adapter.json. Keep the sanitized example in sync by hand:
if [[ -f "$PI_DIR/mcp-adapter.json" ]] && ! grep -q 'bearerTokenEnv' "$PI_DIR/mcp-adapter.json" 2>/dev/null; then
  log "NOTE: live mcp-adapter.json contains a literal token — update agent/mcp.example.json manually if servers changed."
fi

# ---------------------------------------------------------------------------
# 2. Secret scan — abort commit if anything looks like a credential
# ---------------------------------------------------------------------------
log "Scanning for secrets…"
SECRET_RE='(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|glpat-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY|sm_[A-Za-z0-9]{40,}|"bearerToken"[[:space:]]*:[[:space:]]*"[^"$]|"api[Kk]ey"[[:space:]]*:[[:space:]]*"[^"$]{8,}|"password"[[:space:]]*:[[:space:]]*"[^"$]{4,}")'
FOUND="$(grep -rInE "$SECRET_RE" "$REPO_DIR" --exclude-dir=.git --exclude=package-lock.json || true)"
if [[ -n "$FOUND" ]]; then
  echo "$FOUND"
  die "suspected secrets above — fix or move to env vars before committing"
fi
log "No secrets detected."

# ---------------------------------------------------------------------------
# 3. Commit (never push)
# ---------------------------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "sync pi config $(date +%Y-%m-%d)"
  log "Committed. Push when ready: git push"
else
  log "No changes to commit."
fi
