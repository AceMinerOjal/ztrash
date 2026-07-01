_ztrash() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-l --list -r --restore -d --delete -e --empty -s --size -u --undo -w --watch -p --purge --fzf -v --verbose --version -h --help"
    case "$prev" in
        -p|--purge) return ;;
    esac
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    else
        COMPREPLY=( $(compgen -W "${opts} restore find" -- "${cur}") )
    fi
}
complete -F _ztrash ztrash
