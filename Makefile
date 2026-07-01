PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1
DOCDIR ?= $(PREFIX)/share/doc/ztrash
LICENSEDIR ?= $(PREFIX)/share/licenses/ztrash
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions
FISHCOMPDIR ?= $(PREFIX)/share/fish/vendor_completions.d

VERSION := $(shell head -5 ztrash | grep '^VERSION=' | cut -d'"' -f2)

.PHONY: install uninstall man

ztrash.1: doc/ztrash.1.scd
ifdef SCDOC
	scdoc < $< > $@
else
	@echo "scdoc not found; install scdoc or copy doc/ztrash.1.scd manually"
	@exit 1
endif

install:
	install -Dm755 ztrash $(DESTDIR)$(BINDIR)/ztrash
	install -Dm644 LICENSE $(DESTDIR)$(LICENSEDIR)/LICENSE
	install -Dm644 README.md $(DESTDIR)$(DOCDIR)/README.md
	install -Dm644 completions/ztrash.bash $(DESTDIR)$(BASHCOMPDIR)/ztrash
	install -Dm644 completions/ztrash.zsh $(DESTDIR)$(ZSHCOMPDIR)/_ztrash
	install -Dm644 completions/ztrash.fish $(DESTDIR)$(FISHCOMPDIR)/ztrash.fish
ifdef SCDOC
	install -Dm644 ztrash.1 $(DESTDIR)$(MANDIR)/ztrash.1
endif

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/ztrash
	rm -f $(DESTDIR)$(LICENSEDIR)/LICENSE
	rm -f $(DESTDIR)$(DOCDIR)/README.md
	rm -f $(DESTDIR)$(BASHCOMPDIR)/ztrash
	rm -f $(DESTDIR)$(ZSHCOMPDIR)/_ztrash
	rm -f $(DESTDIR)$(FISHCOMPDIR)/ztrash.fish
	rm -f $(DESTDIR)$(MANDIR)/ztrash.1
