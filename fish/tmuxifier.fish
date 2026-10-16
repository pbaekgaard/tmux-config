set -gx TMUXIFIER_LAYOUT_PATH $HOME/.config/tmux/layouts
set -gx TMUXIFIER_TEMPLATE_PATH $HOME/.config/tmux/templates
fish_add_path -g $HOME/.config/tmux/plugins/tmuxifier/bin
if type -q tmuxifier
    tmuxifier init - fish | source
end
