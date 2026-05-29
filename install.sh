#!/usr/bin/env bash
# Abstract — install script
# Copies the four abstract* skill folders into ~/.claude/skills/ (or
# the path in $ABSTRACT_INSTALL_DIR if set).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${ABSTRACT_INSTALL_DIR:-$HOME/.claude/skills}"

SKILLS=(abstract abstract-history abstract-config abstract-rule abstract-update abstract-compile)

mkdir -p "$TARGET"

for skill in "${SKILLS[@]}"; do
  src="$SCRIPT_DIR/$skill"
  dst="$TARGET/$skill"
  if [[ ! -d "$src" ]]; then
    echo "warning: $src missing, skipping" >&2
    continue
  fi
  rm -rf "$dst"
  cp -r "$src" "$dst"
  echo "installed $skill -> $dst"
done

echo ""
echo "Done. Restart Claude Code to pick up the new skills."
echo "Then run /abstract-config to set your recap destination."
