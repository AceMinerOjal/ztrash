# ztrash

A polished, FreeDesktop-compliant trash manager with a touch of personality.

## Features

- **FreeDesktop.org Trash spec** — integrates with GNOME, KDE, XFCE trash
- **Rich interactive UI** — colored output, numbered menus with ranges
- **fzf integration** — fuzzy-find items to restore or delete
- **Live watcher** — real-time trash size display (`-w`)
- **Undo** — restore the most recently trashed item (`-u`)
- **Pattern restore** — restore all items matching a glob (`restore "*.bak"`)
- **Find** — search trashed items by name or path (`find important`)
- **Purge by age** — permanently delete items older than N days (`-p 30`)
- **Zero dependencies** — pure zsh (python3 used as optional fallback)

## Installation

### From AUR (recommended for Arch Linux)

```bash
yay -S ztrash
# or
paru -S ztrash
```

### Manual

```bash
git clone https://github.com/AceMinerOjal/ztrash.git
cd ztrash
sudo install -Dm755 ztrash /usr/local/bin/ztrash
```

## Usage

```bash
ztrash file1.txt file2.txt     # Move files to trash
ztrash -l                       # List trashed items
ztrash -r                       # Interactively restore items
ztrash -d                       # Interactively delete items
ztrash -e                       # Empty trash
ztrash -s                       # Show trash size
ztrash -u                       # Undo last trash
ztrash -w                       # Watch trash size live
ztrash -p 30                    # Purge items older than 30 days
ztrash --fzf                    # Fuzzy-find items with fzf
ztrash find important           # Search for trashed items
ztrash restore "*.pdf"          # Restore items matching pattern
```

## Completion

```bash
ztrash --print-completion zsh >> ~/.zshrc
ztrash --print-completion bash >> ~/.bashrc
ztrash --print-completion fish >> ~/.config/fish/completions/ztrash.fish
```

## License

MIT
