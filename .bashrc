# Initialize Starship prompt
eval "$(starship init bash)"

# Set editor
export EDITOR=nano

# Enable colored output for 'ls' and grep
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Common aliases
alias ll='ls -alF'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias gc='git commit'
alias gp='git push'