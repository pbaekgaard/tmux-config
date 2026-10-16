#!/usr/bin/env bash
# Installs tmux config, tmux-sessionizer, fish bindings, tmuxifier and tpm.
# Files are symlinked so the repo stays the source of truth.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_DIR="$HOME/.config/tmux"
BIN_DIR="$HOME/.local/bin"
FISH_CONF_D="$HOME/.config/fish/conf.d"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.backup-$(date +%Y%m%d-%H%M%S)"
    echo "backed up existing $dst"
  fi
  ln -s "$src" "$dst"
  echo "linked $dst"
}

clone_if_missing() {
  local url="$1" dir="$2"
  if [ -d "$dir" ]; then
    echo "already installed: $dir"
  else
    git clone --depth 1 "$url" "$dir"
  fi
}

for cmd in git tmux fish fzf; do
  command -v "$cmd" >/dev/null || echo "warning: '$cmd' not found, please install it"
done

# tmux config
for item in tmux.conf noctalia.conf theme-colors.conf powerkit-theme.conf scripts templates layouts; do
  link "$REPO/config/$item" "$TMUX_DIR/$item"
done

# sessionizer + fish bindings
link "$REPO/bin/tmux-sessionizer" "$BIN_DIR/tmux-sessionizer"
link "$REPO/fish/tmux-sessionizer.fish" "$FISH_CONF_D/tmux-sessionizer.fish"
link "$REPO/fish/tmuxifier.fish" "$FISH_CONF_D/tmuxifier.fish"

# tpm + tmuxifier
clone_if_missing https://github.com/tmux-plugins/tpm "$TMUX_DIR/plugins/tpm"
clone_if_missing https://github.com/jimeh/tmuxifier "$TMUX_DIR/plugins/tmuxifier"

# tmux plugins
"$TMUX_DIR/plugins/tpm/bin/install_plugins" || true

echo
echo "Done. Restart fish and reload tmux (tmux source ~/.config/tmux/tmux.conf)."
echo "Note: the fish binding listens for the kitty escape sequence \\e[777~ (sent by your terminal on Ctrl+Space, Ctrl+F)."
