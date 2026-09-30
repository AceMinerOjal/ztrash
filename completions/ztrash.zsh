#compdef ztrash

_ztrash() {
    local -a ops
    ops=(
        '(-l --list)'{-l,--list}'[list items in the trash]'
        '(-r --restore)'{-r,--restore}'[interactively restore items]'
        '(-d --delete)'{-d,--delete}'[interactively delete items]'
        '(-e --empty)'{-e,--empty}'[empty the trash]'
        '(-s --size)'{-s,--size}'[show trash size]'
        '(-u --undo)'{-u,--undo}'[restore the most recently trashed item]'
        '(-w --watch)'{-w,--watch}'[live-updating trash size display]'
        '(-p --purge)'{-p,--purge}'[purge items older than N days]:days:'
        '--fzf[fuzzy-find items to restore or delete]'
        '--gc[remove orphaned trash entries]'
        '(-y --yes)'{-y,--yes}'[assume yes, do not prompt]'
        '(-n --dry-run)'{-n,--dry-run}'[show what would happen, change nothing]'
        '(-v --verbose)'{-v,--verbose}'[verbose output]'
        '--json[emit machine-readable JSON]'
        '--version[show version]'
        '(-h --help)'{-h,--help}'[show help]'
        '--print-completion[print a shell completion script]:shell:(bash zsh fish)'
        'restore:restore items matching a pattern:pattern:'
        'find:search trashed items:pattern:'
    )
    _arguments -s -S "$ops[@]" '*:file:_files'
}
