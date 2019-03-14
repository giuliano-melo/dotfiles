# Bash eternal history
# --------------------
# This snippet allows infinite recording of every command you've ever
# entered on the machine, without using a large HISTFILESIZE variable,
# and keeps track if you have multiple screens and ssh sessions into the
# same machine. It is adapted from:
# http://www.debian-administration.org/articles/543.
#
# The way it works is that after each command is executed and
# before a prompt is displayed, a line with the last command (and
# some metadata) is appended to ~/.bash_eternal_history.
#
# This file is a tab-delimited, timestamped file, with the following
# columns:
#
# 1) user
# 2) hostname
# 3) screen window (in case you are using GNU screen)
# 4) date/time
# 5) current working directory (to see where a command was executed)
# 6) the last command you executed
#
# The only minor bug: if you include a literal newline or tab (e.g. with
# awk -F"\t"), then that will be included verbatime. It is possible to
# define a bash function which escapes the string before writing it; if you
# have a fix for that which doesn't slow the command down, please submit
# a patch or pull request.
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND ; }"'echo -e $$\\t$USER\\t$HOSTNAME\\tscreen $WINDOW\\t`date +%D%t%T%t%Y%t%s`\\t$PWD"$(history 1)" >> ~/.bash_eternal_history'

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
if [ -f $CUSTOM_BASHRC ]; then
  . $CUSTOM_BASHRC
fi

BASH_COMPLETION_SCRIPT="$DIR/.git-completion.bash"
if [ -f $BASH_COMPLETION_SCRIPT ]; then
  . $BASH_COMPLETION_SCRIPT
fi

if [ -t direnv ]; then
  eval "$(direnv hook bash)"
fi

