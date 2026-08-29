#!/usr/bin/env bash
set -euo pipefail

readonly REPOSITORY="mirairoad/omarchy-config"
readonly SOURCE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"
readonly BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-config/backups"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi is not installed. Run the repository install.sh first." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR/.git" ]] ||
   [[ "$(git -C "$SOURCE_DIR" remote get-url origin 2>/dev/null || true)" != *"${REPOSITORY}"* ]]; then
  echo "The chezmoi source is not ${REPOSITORY}. Run install.sh first." >&2
  exit 1
fi

timestamp=$(date +%Y%m%d-%H%M%S)
backup_path="$BACKUP_DIR/config-$timestamp.tar.gz"
managed_paths=(
  .config/hypr
  .config/omarchy/shell.json
  .config/omarchy/extensions
  .config/omarchy/plugins/leo.workspaces
  .config/omarchy/plugins/leo.nanoleaf-pegboard
  .config/omarchy/themes/wifus
  .config/fastfetch/config.jsonc
  .config/foot/foot.ini
)
existing_paths=()

for path in "${managed_paths[@]}"; do
  if [[ -e "$HOME/$path" || -L "$HOME/$path" ]]; then
    existing_paths+=("$path")
  fi
done

mkdir -p "$BACKUP_DIR"
if ((${#existing_paths[@]})); then
  tar -C "$HOME" -czf "$backup_path" -- "${existing_paths[@]}"
  echo "Backup: $backup_path"
else
  echo "No existing managed configuration needed a backup."
fi

echo "Fetching and enforcing the latest configuration..."
chezmoi update --force

if command -v omarchy >/dev/null 2>&1 && [[ -d "$HOME/.config/omarchy/themes/wifus" ]]; then
  OMARCHY_THEME_HEADLESS=1 omarchy theme set wifus
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1; then
  config_errors=$(hyprctl configerrors)
  if [[ -n "$config_errors" ]]; then
    echo "Hyprland reported configuration errors:" >&2
    echo "$config_errors" >&2
    echo "Restore with: tar -xzf '$backup_path' -C '$HOME'" >&2
    exit 1
  fi
  echo "Hyprland reload: OK"
else
  echo "Hyprland is not running in this session; reload validation was skipped."
fi

echo "Sync complete. Local changes to managed files were replaced by GitHub."
if [[ -f "$backup_path" ]]; then
  echo "Restore this run with: tar -xzf '$backup_path' -C '$HOME'"
fi
