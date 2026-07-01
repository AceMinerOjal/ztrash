ztrash(1)

# NAME

ztrash - A polished, FreeDesktop-compliant trash manager

# SYNOPSIS

*ztrash* [options] [file...]
*ztrash* restore <pattern>
*ztrash* find <pattern>

# DESCRIPTION

*ztrash* moves files and directories to the FreeDesktop.org Trash, the same
trash used by GNOME, KDE, and XFCE. Files can be listed, restored, or
permanently deleted using the various options.

# OPTIONS

*-l, --list*
	List items currently in the trash with size, deletion date, and original
	path.

*-r, --restore*
	Interactively select items to restore by number.

*-d, --delete*
	Interactively select items to permanently delete by number.

*-e, --empty*
	Empty the entire trash bin (prompts for confirmation).

*-s, --size*
	Show total disk space used by trashed items.

*-u, --undo*
	Restore the most recently trashed item.

*-w, --watch*
	Display a live-updating trash size display (updates every 2 seconds).

*-p, --purge* <days>
	Permanently delete items older than N days.

*--fzf*
	Use fzf to fuzzy-find items, then choose to restore or delete.

*-v, --verbose*
	Print details when trashing files.

*--version*
	Show version information.

*-h, --help*
	Display help and usage information.

# SUBCOMMANDS

*restore* <pattern>
	Restore all items matching the given glob pattern in name or path.

*find* <pattern>
	Search trashed items by name or path, showing matches.

# FILES

*~/.local/share/Trash/files/*
	Directory containing trashed files and directories.

*~/.local/share/Trash/info/*
	Directory containing .trashinfo metadata files.

# ENVIRONMENT

*XDG_DATA_HOME*
	Overrides the trash directory location. Defaults to ~/.local/share.

*COLUMNS*
	Affects column width for table formatting.

# EXIT STATUS

0
	Success.

1
	General error, invalid option, or missing argument.

# EXAMPLES

Move files to trash:
	ztrash homework.pdf regrettable_photo.jpg

List trashed items:
	ztrash -l

Restore items matching a pattern:
	ztrash restore \*.bak

Search for trashed items:
	ztrash find important

Purge items older than 30 days:
	ztrash -p 30

Restore most recently trashed item:
	ztrash -u

# AUTHORS

AceMinerOjal

# SEE ALSO

rm(1), trash-cli(1), gio(1)
