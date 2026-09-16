#!/usr/bin/env bash
# pi-toolkit — one-shot restore of Pi Agent config on a new Linux/WSL machine.
# Idempotent: safe to re-run. Existing files that would be overwritten are
# backed up to ~/.pi-backup-<timestamp>/ first.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="${HOME}/.pi/agent"
AGENTS_SKILLS="${HOME}/.agents/skills"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${HOME}/.pi-backup-${STAMP}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*"; }

# backup_if_exists <live-path> — snapshot before we overwrite
backup_if_exists() {
  local f="$1"
  if [[ -e "$f" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "${f#"$HOME"/}")"
    cp -a "$f" "$BACKUP_DIR/$(dirname "${f#"$HOME"/}")/"
    echo "$f" >> "$BACKUP_DIR/.manifest"
  fi
}

# ---------------------------------------------------------------------------
# 1. Node.js + pi itself
# ---------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  log "Node.js not found — install Node.js >= 20 first (nvm recommended):"
  echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
  echo "  nvm install --lts"
  exit 1
fi

if ! command -v pi >/dev/null 2>&1; then
  log "Installing pi (@earendil-works/pi-coding-agent)…"
  npm install -g @earendil-works/pi-coding-agent
else
  log "pi already installed: $(pi --version 2>/dev/null || echo unknown)"
fi

# ---------------------------------------------------------------------------
# 2. Backup existing config pieces we are about to touch
# ---------------------------------------------------------------------------
log "Backing up existing config (if any) to $BACKUP_DIR"
mkdir -p "$PI_DIR"
for f in settings.json open-tui.json mcp.json; do
  backup_if_exists "$PI_DIR/$f"
done
for d in themes extensions skills; do
  if [[ -d "$PI_DIR/$d" && -n "$(ls -A "$PI_DIR/$d" 2>/dev/null)" ]]; then
    mkdir -p "$BACKUP_DIR/.pi/agent"
    cp -a "$PI_DIR/$d" "$BACKUP_DIR/.pi/agent/"
  fi
done
[[ -d "$AGENTS_SKILLS" && -n "$(ls -A "$AGENTS_SKILLS" 2>/dev/null)" ]] && {
  mkdir -p "$BACKUP_DIR/.agents"
  cp -a "$AGENTS_SKILLS" "$BACKUP_DIR/.agents/"
} || true

# ---------------------------------------------------------------------------
# 3. Install all packages declared in settings.json (npm: and git:)
# ---------------------------------------------------------------------------
log "Installing declared packages via 'pi install'…"
PACKAGES="$(node -e "JSON.parse(require('fs').readFileSync('$REPO_DIR/agent/settings.json','utf8')).packages.forEach(p=>console.log(p))")"
while IFS= read -r pkg; do
  [[ -z "$pkg" ]] && continue
  log "  pi install $pkg"
  pi install "$pkg" || warn "pi install $pkg failed (network? renamed package?)"
done <<< "$PACKAGES"

# ---------------------------------------------------------------------------
# 4. Copy static config files
# ---------------------------------------------------------------------------
log "Copying config files…"
# settings.json: the repo version is the source of truth for a restore
# (packages above were re-installed from it); overwrite any live copy.
cp "$REPO_DIR/agent/settings.json" "$PI_DIR/settings.json"
cp "$REPO_DIR/agent/open-tui.json" "$PI_DIR/open-tui.json"
mkdir -p "$PI_DIR/themes"
cp "$REPO_DIR/agent/themes/"*.json "$PI_DIR/themes/"
mkdir -p "$PI_DIR/extensions"
cp "$REPO_DIR/agent/extensions/effort.ts" "$PI_DIR/extensions/"

# MCP config: never overwrite an existing mcp.json
if [[ -f "$PI_DIR/mcp.json" ]]; then
  log "mcp.json already exists — left untouched"
else
  cp "$REPO_DIR/agent/mcp.example.json" "$PI_DIR/mcp.json"
  warn "mcp.json created from example. Export the real token before use:"
  warn "  export SUPERMEMORY_API_KEY=your-token   # add to ~/.bashrc / ~/.zshrc"
fi

# ---------------------------------------------------------------------------
# 5. Custom skills -> ~/.agents/skills + symlink into ~/.pi/agent/skills
# ---------------------------------------------------------------------------
log "Restoring custom skills…"
mkdir -p "$AGENTS_SKILLS" "$PI_DIR/skills"
for skill_dir in "$REPO_DIR/skills"/*/; do
  name="$(basename "$skill_dir")"
  rm -rf "$AGENTS_SKILLS/$name"
  cp -a "$skill_dir" "$AGENTS_SKILLS/$name"
  # symlink so pi user-scope discovery picks it up (matches original setup)
  ln -sfn "$AGENTS_SKILLS/$name" "$PI_DIR/skills/$name"
  log "  skill: $name"
done

# ---------------------------------------------------------------------------
# 6. Optional system tools used by pi (best-effort)
# ---------------------------------------------------------------------------
for tool in rg fd; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    warn "'$tool' not found — install with: sudo apt install ${tool/fd/fd-find} (optional)"
  fi
done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "Restore complete. Remaining manual steps:"
echo "  1. Provider auth: run 'pi' and complete OAuth login, or set API keys."
echo "     Check readiness:  pi auth status"
echo "  2. MCP secret:    export SUPERMEMORY_API_KEY=<your-token>  (persist in shell rc)"
echo "  3. Review themes/model defaults in ~/.pi/agent/settings.json"
echo "  4. (Optional) pi update   # refresh pi + model catalogs"
