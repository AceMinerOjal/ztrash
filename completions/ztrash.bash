_ztrash() {
    local cur prev ops
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    ops="-l --list -r --restore -d --delete -e --empty -s --size -u --undo"
    ops+=" -w --watch -p --purge --fzf --gc -y --yes -n --dry-run"
    ops+=" -v --verbose --json --version -h --help --print-completion"
    case "$prev" in
        -p|--purge) return ;;
        --print-completion)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "bash zsh fish" -- "${cur}") )
            return ;;
    esac
    # Splitting compgen's newline-separated output into COMPREPLY is the
    # standard completion idiom. `read -a` would split on spaces instead and
    # mangle any candidate path containing one.
    # shellcheck disable=SC2207
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${ops}" -- "${cur}") )
    else
        COMPREPLY=( $(compgen -W "${ops} restore find" -- "${cur}") )
    fi
    return 0
}
complete -F _ztrash ztrash
