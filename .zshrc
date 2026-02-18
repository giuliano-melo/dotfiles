#!/usr/bin/env zsh

# Enable Powerlevel10k instant prompt
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_BEEP

# Bash eternal history equivalent
BASH_ETERNAL_HISTORY="${HOME}/.zsh_eternal_history"
autoload -U add-zsh-hook
__eternal_history() {
    print -r -- "$1" >> "$BASH_ETERNAL_HISTORY"
}
add-zsh-hook preexec __eternal_history

# Enable completion
autoload -Uz compinit
compinit

# Enable auto-correction
setopt CORRECT
setopt CORRECT_ALL

# Enable menu selection
zstyle ':completion:*' menu select

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Enable color support
autoload -U colors
colors

# Allow comments in interactive shell
setopt INTERACTIVE_COMMENTS

# Enable advanced globbing
setopt EXTENDED_GLOB

# Aliases
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
setopt NO_CLOBBER

alias ll='ls -alrtF --color'
alias la='ls -A'
alias l='ls -CF'
alias dir='ls --color=auto --format=vertical'
alias vdir='ls --color=auto --format=long'
alias ..='cd ..'
alias ...='cd ../..'
alias md='mkdir'
alias cl='clear'
alias du='du -ch --max-depth=1'

# Custom aliases
alias lss='lsof -Pnl +M -i4 -i6'
alias ls-servers='netstat -tulpn'
alias random-pass='dd if=/dev/random bs=1 count=18 2>/dev/null | base64'
alias git-graph='git log --graph --all --oneline --decorate'

# Environment variables
export DEVHOME="${HOME}/dev"
export GOPATH="${HOME}/dev/go"

# Direnv
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# Git completion
if [[ -f "${HOME}/.dotfiles/.git-completion.bash" ]]; then
    source "${HOME}/.dotfiles/.git-completion.bash"
fi

# Interactive cd with .env loading
load_env_on_cd() {
    if [[ -n "$DEVHOME" && "$PWD" == "$DEVHOME"/* && -f "$PWD/.env" ]]; then
        source "$PWD/.env"
    fi
}

if [[ -o interactive ]]; then
    add-zsh-hook chpwd load_env_on_cd
    load_env_on_cd
fi

# Functions
generate_uuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# fzf key bindings
if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
    source /usr/share/fzf/key-bindings.zsh
elif [[ -f "${HOME}/.fzf/key-bindings.zsh" ]]; then
    source "${HOME}/.fzf/key-bindings.zsh"
fi

# fzf completion
if [[ -f /usr/share/fzf/completion.zsh ]]; then
    source /usr/share/fzf/completion.zsh
elif [[ -f "${HOME}/.fzf/completion.zsh" ]]; then
    source "${HOME}/.fzf/completion.zsh"
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# enable FZF
#eval "$(fzf --zsh)"
