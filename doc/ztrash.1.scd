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

Files trashed on a different filesystem than the home trash are stored in that
filesystem's own topdirectory trash (see *TOPDIRECTORY TRASH*), so
cross-device moves stay atomic and instant. Metadata is written in the
FreeDesktop.org *.trashinfo* format, with URL-encoded paths.

An option such as *-r*, *-d*, *-y*, or *-n* may appear anywhere on the command
line, including after a subcommand pattern, as in *ztrash restore '\*.bak' -y*.
Everything after *--* is treated as a filename, so leading-dash names can be
trashed safely.

# REQUIREMENTS

*zsh*, and GNU coreutils for *stat*(1), *du*(1), *date*(1), *mv*(1), *rm*(1),
*mkdir*(1), *cp*(1), *mktemp*(1), *grep*(1), and *cat*(1). *fzf* is optional and
only used by *--fzf*, and *tput*(1) is optional, falling back to 80 columns.
*scdoc* is needed to build this page from the *ztrash.1.scd* source, not to run
*ztrash*.

# OPTIONS

*-l, --list*
	List items currently in the trash with size, deletion date, and original
	path. Long paths are shortened with an ellipsis to fit the terminal; set
	*ZTRASH_COLS* to choose the width. Add *--json* for machine-readable
	output.

*-r, --restore*
	Interactively select items to restore by number. Accepts a list such as
	*1 3 5*, a range such as *1-5*, or *all*.

*-d, --delete*
	Interactively select items to permanently delete by number. Accepts the
	same input forms as *--restore*.

*-e, --empty*
	Empty the entire trash bin (prompts for confirmation).

*-s, --size*
	Show total disk space used by trashed items.

*-u, --undo*
	Restore the most recently trashed item.

*-w, --watch*
	Show the trash size and refresh it periodically. Requires a terminal; exits
	with status 2 when stdout is not a tty.

*-p, --purge* [<days>]
	Permanently delete items at least <days> days old. With no argument the
	value of *ZTRASH_PURGE_DAYS* is used (30 by default).

*--fzf*
	Use fzf to fuzzy-find items, then choose to restore or delete. Requires
	fzf to be installed.

*--gc*
	Remove orphaned entries: metadata with no payload, and payloads with no
	metadata.

*-y, --yes*
	Assume yes for every prompt. Without a terminal, prompts fail rather than
	hanging.

*-n, --dry-run*
	Show what would happen and change nothing.

*--json*
	Emit machine-readable JSON. Currently supported by *--list* and *--size*.

*-v, --verbose*
	Print details when trashing files.

*--print-completion* <shell>
	Print a completion script for bash, zsh, or fish and exit.

*--version*
	Show version information.

*-h, --help*
	Display help and usage information.

# SUBCOMMANDS

*restore* <pattern>
	Restore all items matching the given glob pattern in name or path. The
	pattern may match anywhere in the name, and *|* is matched literally, so
	*ztrash restore 'weird|name'* works.

*find* <pattern>
	Search trashed items by name or path, showing matches.

# RESTORING OVER AN EXISTING PATH

If a file already exists at the original path, *ztrash* asks before replacing
it. The existing entry is moved aside first and the trashed payload is put in
place with a non-recursive move, so restoring a directory never nests it inside
a directory of the same name. If the move fails, the previous entry is put
back. Use *-y* to replace without asking, or answer *n* to skip the item.

# TOPDIRECTORY TRASH

When a file is trashed from a filesystem other than the one holding the home
trash, the FreeDesktop.org specification requires a trash in that filesystem.
*ztrash* tries, in order:

1. *$topdir/.Trash-$UID*, when it exists, is not a symlink, and is owned by the
	current user.
2. *$topdir/.Trash/$UID*, when the shared *.Trash* directory is sticky and the
	per-user directory can be created inside it.
3. The home trash, with a warning on stderr, falling back to a copy if the
	filesystem cannot hold it.

Items in a topdirectory trash record a path relative to the topdirectory, so
they can be moved back within their own filesystem. Note that *--list* only
covers the home trash; topdirectory trashes belong to the filesystem that owns
them.

# FILES

*$XDG_DATA_HOME/Trash/files/*
	Directory containing trashed files and directories.

*$XDG_DATA_HOME/Trash/info/*
	Directory containing .trashinfo metadata files.

*$XDG_CONFIG_HOME/ztrash/config*
	Optional shell fragment sourced at startup. Any *ZTRASH_* variable in the
	environment may be set here.

# ENVIRONMENT

*XDG_DATA_HOME*
	Overrides the trash directory location. Defaults to ~/.local/share.

*XDG_CONFIG_HOME*
	Overrides the configuration directory. Defaults to ~/.config.

*ZTRASH_TRASH_DIR*
	Use a different trash root entirely, ignoring *XDG_DATA_HOME*.

*ZTRASH_CONFIG_DIR*
	Directory holding the *config* file. Defaults to *$XDG_CONFIG_HOME/ztrash*.

*ZTRASH_PURGE_DAYS*
	Default age, in days, used by *--purge* when no number is given. Default 30.

*ZTRASH_INTERVAL*
	Watcher refresh interval, in seconds, for *--watch*. Default 2.

*ZTRASH_COLS*
	Force the assumed terminal width instead of detecting it.

*ZTRASH_NO_COLOR*, *NO_COLOR*
	Disable coloured output.

*ZTRASH_FORCE_COLOR*
	Keep coloured output even when stdout is not a terminal.

*COLUMNS*
	Affects column width for table formatting. Detected only when stdout is a
	terminal, so piping output is not blanked.

# EXIT STATUS

0
	Success.

1
	An operation failed. Some items may still have been processed; per-item
	results are printed.

2
	Usage error: an unknown option, a missing or malformed argument, or an
	action that needs a terminal when stdout is not one.

# EXAMPLES

Move files to trash:
	ztrash homework.pdf regrettable_photo.jpg

List trashed items:
	ztrash -l

Get the same list as JSON:
	ztrash -l --json | jq '.items[].path'

Preview a purge before running it:
	ztrash -p 30 -n

Restore items matching a pattern:
	ztrash restore \*.bak

Search for trashed items:
	ztrash find important

Restore the newest item without being asked:
	ztrash -u -y

Drop orphaned entries:
	ztrash --gc

Trash a file whose name starts with a dash:
	ztrash -- --weird-name

# SEE ALSO

rm(1), trash-cli(1), gio(1)

# AUTHORS

AceMinerOjal
