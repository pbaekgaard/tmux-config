function tmux_sessionizer_launch --description 'Launch tmux-sessionizer via kitty escape sequence'
    commandline -f repaint
    tmux-sessionizer
    commandline -f repaint
end

bind \e\[777~ tmux_sessionizer_launch
