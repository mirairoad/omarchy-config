#!/usr/bin/env bash
set -euo pipefail

readonly REPOSITORY="mirairoad/omarchy-config"
readonly SOURCE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"

if ! command -v omarchy >/dev/null 2>&1; then
  echo "This installer is intended for an existing Omarchy installation." >&2
  exit 1
fi

echo "Installing ${REPOSITORY}"
echo "You may be asked for this computer's sudo password and machine role."
echo "Passwords, keys, and account credentials are never read or stored."

if ! command -v chezmoi >/dev/null 2>&1; then
  omarchy pkg add chezmoi
fi

if [[ -d "$SOURCE_DIR/.git" ]] &&
   [[ "$(git -C "$SOURCE_DIR" remote get-url origin 2>/dev/null || true)" == *"${REPOSITORY}"* ]]; then
  echo "Existing checkout found; enforcing the latest configuration."
  chezmoi git -- pull --ff-only
  exec "$SOURCE_DIR/update.sh"
else
  chezmoi init --apply "$REPOSITORY"
fi

echo
echo "Omarchy configuration installed."
echo "Review monitor outputs with: hyprctl monitors all"
echo "Future updates: $SOURCE_DIR/update.sh"
