# Append to history
# See: http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x329.html
shopt -s histappend

# Make prompt informative
# See:  http://www.ukuug.org/events/linux2003/papers/bash_tips/
#PS1="\[\033[0;34m\][\u@\h:\w]$\[\033[0m\]"

## -----------------------
## -- 2) Set up aliases --
## -----------------------

# 2.1) Safety
alias rm="rm -i"
alias mv="mv -i"
alias cp="cp -i"
set -o noclobber

# 2.2) Listing, directories, and motion
alias ll="ls -alrtF --color"
alias la="ls -A"
alias l="ls -CF"
alias dir='ls --color=auto --format=vertical'
alias vdir='ls --color=auto --format=long'
alias m='less'
alias ..='cd ..'
alias ...='cd ..;cd ..'
alias md='mkdir'
alias cl='clear'
alias du='du -ch --max-depth=1'
alias treeacl='tree -A -C -L 2'

# 2.4) grep options
unset GREP_OPTIONS
#export GREP_COLOR='1;31' # green for matches

## ------------------------------
## -- 3) User-customized code  --
## ------------------------------

SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"

## Define any user-specific variables you want here.
CUSTOM_BASHRC="$DIR/.bashrc_custom"
if [ -f "$CUSTOM_BASHRC" ]; then
  . $CUSTOM_BASHRC
fi

BASH_COMPLETION_SCRIPT="$DIR/.git-completion.bash"
if [ -f "$BASH_COMPLETION_SCRIPT" ]; then
  . $BASH_COMPLETION_SCRIPT
fi

if command -v direnv &>/dev/null; then
  eval "$(direnv hook bash)"
fi

