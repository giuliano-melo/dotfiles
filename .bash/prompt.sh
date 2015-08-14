function _git_prompt() {
    local git_status="$(git status -unormal 2>&1)"
    if ! [[ "$git_status" =~ Not\ a\ git\ repo ]]; then
        if [[ "$git_status" =~ nothing\ to\ commit ]]; then
            local ansi=32
        elif [[ "$git_status" =~ nothing\ added\ to\ commit\ but\ untracked\ files\ present ]]; then
            local ansi=33
        else
            local ansi=35
        fi
        if [[ "$git_status" =~ On\ branch\ ([^[:space:]]+) ]]; then
            branch=${BASH_REMATCH[1]}
            #test "$branch" != master || branch=' '
        else
            # Detached HEAD.  (branch=HEAD is a faster alternative.)
            branch="$(git describe --all --contains --abbrev=4 HEAD 2> /dev/null ||
                echo HEAD)"
        fi
        echo -n 'on \[\e[0;'"$ansi"'m\]'"$branch"'\[\e[0m\] '
    fi
}

function _prompt_command() {
    PS1='\[\e[1;37m\]\u@\h\[\e[0m\] \w '"$(_git_prompt)"'\n\[\e[0;31m\]>\[\e[0;33m\]>\[\e[0;32m\]>\[\e[0m\] '
}

PROMPT_COMMAND=_prompt_command
