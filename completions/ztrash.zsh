#compdef ztrash

_ztrash() {
    local -a ops
    ops=(
        '-l[list trash contents]'
        '--list[list trash contents]'
        '-r[interactively restore items]'
        '--restore[interactively restore items]'
        '-d[interactively delete items]'
        '--delete[interactively delete items]'
        '-e[empty the trash]'
        '--empty[empty the trash]'
        '-s[show trash size]'
        '--size[show trash size]'
        '-u[undo last trash]'
        '--undo[undo last trash]'
        '-w[watch trash size]'
        '--watch[watch trash size]'
        '-p[purge items older than N days]:days'
        '--purge[purge items older than N days]:days'
        '--fzf[fuzzy-find items]'
        '-v[verbose output]'
        '--verbose[verbose output]'
        '-h[show help]'
        '--help[show help]'
        '--version[show version]'
        '*:: :->args'
    )
    _arguments "$ops[@]" && return

    case $state in
        args)
            case $words[1] in
                restore)
                    _arguments '*:pattern:_files'
                    ;;
                find)
                    _arguments '*:pattern:_files'
                    ;;
            esac
            ;;
    esac
}

_ztrash "$@"
