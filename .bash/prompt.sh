GIT_PROMPT_CACHE_DIR="${HOME}/.cache/git-prompt"
GIT_PROMPT_CACHE_TTL=5

function _git_prompt() {
    local cache_file="${GIT_PROMPT_CACHE_DIR}/$(pwd | tr '/' '_')"
    local now=$(date +%s)

    if [[ -r "$cache_file" ]]; then
        local cached=$(cat "$cache_file")
        local timestamp=$(echo "$cached" | head -1)
        local result=$(echo "$cached" | tail -n +2)

        if (( now - timestamp < GIT_PROMPT_CACHE_TTL )); then
            echo -n "$result"
            return
        fi
    fi

    local git_status="$(git status -unormal 2>&1)"
    local output=""

    if ! [[ "$git_status" =~ [Nn]ot\ a\ git\ repo ]]; then
        if [[ "$git_status" =~ nothing\ to\ commit ]]; then
            local ansi=32
        elif [[ "$git_status" =~ nothing\ added\ to\ commit\ but\ untracked\ files\ present ]]; then
            local ansi=33
        else
            local ansi=35
        fi
        if [[ "$git_status" =~ On\ branch\ ([^[:space:]]+) ]]; then
            local branch="${BASH_REMATCH[1]}"
        else
            local branch="$(git describe --all --contains --abbrev=4 HEAD 2>/dev/null || echo HEAD)"
        fi
        output='on \[\e[0;'"$ansi"'m\]'"$branch"'\[\e[0m\] '
    fi

    mkdir -p "${GIT_PROMPT_CACHE_DIR}"
    echo -e "${now}\n${output}" > "$cache_file"

    echo -n "$output"
}

function _prompt_command() {
    PS1='\[\e[1;37m\]\u@\h\[\e[0m\] \w '"$(_git_prompt)"'\n\[\e[0;31m\]>\[\e[0;33m\]>\[\e[0;32m\]>\[\e[0m\] '
}

PROMPT_COMMAND=_prompt_command
