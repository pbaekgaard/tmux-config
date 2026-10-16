#!/usr/bin/env bash
# Installs tmux config, tmux-sessionizer, fish/kitty config, tmuxifier and tpm.
# Files are copied; re-run to update.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_DIR="$HOME/.config/tmux"
BIN_DIR="$HOME/.local/bin"
FISH_DIR="$HOME/.config/fish"
KITTY_DIR="$HOME/.config/kitty"
STAMP="$(date +%Y%m%d-%H%M%S)"

install_item() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.backup-$STAMP"
    echo "backed up existing $dst"
  fi
  cp -a "$src" "$dst"
  echo "installed $dst"
}

is_git_repo() {
  git -C "$1" rev-parse --git-dir >/dev/null 2>&1
}

# Moves aside a plugin directory that exists but is not a working git checkout
quarantine_if_broken() {
  local dir="$1"
  if [ -e "$dir" ] && ! is_git_repo "$dir"; then
    mv "$dir" "$dir.broken-$STAMP"
    echo "moved broken plugin dir aside: $dir"
  fi
}

clone_if_missing() {
  local url="$1" dir="$2"
  quarantine_if_broken "$dir"
  if [ -d "$dir" ]; then
    echo "already installed: $dir"
  else
    git clone --depth 1 "$url" "$dir"
  fi
}

# Comments out lines in a file matching a fixed string, backing the file up once
comment_out() {
  local file="$1" pattern="$2"
  [ -f "$file" ] && grep -qF -- "$pattern" "$file" || return 0
  if ! grep -qF -- "$pattern" <(grep -v '^[[:space:]]*#' "$file"); then
    return 0
  fi
  [ -e "$file.backup-$STAMP" ] || cp -a "$file" "$file.backup-$STAMP"
  local tmp
  tmp="$(mktemp)"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" != \#* && "$line" == *"$pattern"* ]]; then
      printf '# (moved to tmux-config) %s\n' "$line"
    else
      printf '%s\n' "$line"
    fi
  done <"$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
  echo "commented out '$pattern' in $file"
}

# --- dependencies ---
missing=()
for cmd in git tmux fish fzf; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "installing missing dependencies: ${missing[*]}"
  if command -v pacman >/dev/null; then
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  elif command -v apt-get >/dev/null; then
    sudo apt-get update && sudo apt-get install -y "${missing[@]}"
  elif command -v dnf >/dev/null; then
    sudo dnf install -y "${missing[@]}"
  elif command -v brew >/dev/null; then
    brew install "${missing[@]}"
  else
    echo "error: no supported package manager found; install manually: ${missing[*]}" >&2
    exit 1
  fi
fi

# --- tmux config ---
for item in tmux.conf noctalia.conf theme-colors.conf powerkit-theme.conf scripts templates layouts; do
  install_item "$REPO/config/$item" "$TMUX_DIR/$item"
done

# --- sessionizer + fish ---
install_item "$REPO/bin/tmux-sessionizer" "$BIN_DIR/tmux-sessionizer"
install_item "$REPO/fish/tmux-sessionizer.fish" "$FISH_DIR/conf.d/tmux-sessionizer.fish"
install_item "$REPO/fish/tmuxifier.fish" "$FISH_DIR/conf.d/tmuxifier.fish"

# Remove setup from config.fish that conf.d now provides
for pattern in \
  'tmuxifier/bin' 'tmuxifier init' 'TMUXIFIER_LAYOUT_PATH' 'TMUXIFIER_TEMPLATE_PATH' \
  'tmux-sessionizer.fish'; do
  comment_out "$FISH_DIR/config.fish" "$pattern"
done

# --- kitty ---
if command -v kitty >/dev/null || [ -d "$KITTY_DIR" ]; then
  tmp="$(mktemp)"
  sed "s|@HOME@|$HOME|g" "$REPO/kitty/tmux-sessionizer.conf.in" >"$tmp"
  install_item "$tmp" "$KITTY_DIR/tmux-sessionizer.conf"
  rm -f "$tmp"
  comment_out "$KITTY_DIR/kitty.conf" 'map ctrl+space>ctrl+f'
  if ! grep -qE '^include[[:space:]]+tmux-sessionizer.conf' "$KITTY_DIR/kitty.conf" 2>/dev/null; then
    printf '\ninclude tmux-sessionizer.conf\n' >>"$KITTY_DIR/kitty.conf"
    echo "added include to $KITTY_DIR/kitty.conf"
  fi
fi

# --- tpm + tmuxifier + plugins ---
clone_if_missing https://github.com/tmux-plugins/tpm "$TMUX_DIR/plugins/tpm"
clone_if_missing https://github.com/jimeh/tmuxifier "$TMUX_DIR/plugins/tmuxifier"

# tmuxifier reads templates from its own checkout (TMUXIFIER_TEMPLATE_PATH is ignored)
for t in "$REPO"/config/templates/*; do
  install_item "$t" "$TMUX_DIR/plugins/tmuxifier/templates/$(basename "$t")"
done

# Quarantine any other broken plugin checkouts so tpm can reinstall them
while read -r name; do
  quarantine_if_broken "$TMUX_DIR/plugins/${name##*/}"
done < <(grep -oE "@plugin '[^']+'" "$TMUX_DIR/tmux.conf" | sed -E "s/@plugin '([^']+)'/\1/")

"$TMUX_DIR/plugins/tpm/bin/install_plugins"

echo
echo "Done. Restart fish and kitty, and reload tmux (tmux source ~/.config/tmux/tmux.conf)."
