#!/usr/bin/env zsh

# Git prompt function for zsh
# Uses vcs_info for better performance than calling git directly

autoload -Uz vcs_info

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr '%F{green}'
zstyle ':vcs_info:*' unstagedstr '%F{magenta}'
zstyle ':vcs_info:*' formats 'on %F{white}%b%f'
zstyle ':vcs_info:*' actionformats 'on %F{white}%b|%a%f'

precmd() {
    vcs_info
}

setopt PROMPT_SUBST

# Prompt with git status
PS1='%F{white}%n@%m%f %F{blue}%~%f ${vcs_info_msg_0_}%f
%F{red}>%F{yellow}>%F{green}>%f '

# Alternative simple prompt without git
# PS1='%F{white}%n@%m%f %F{blue}%~%f
# %F{red}>%F{yellow}>%F{green}>%f '
