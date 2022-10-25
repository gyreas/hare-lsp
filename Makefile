.POSIX:
.SUFFIXES:
HARE=hare
HAREFLAGS=
HAREDOC=haredoc

DESTDIR=
PREFIX=/usr/local
SRCDIR=$(PREFIX)/src
HARESRCDIR=$(SRCDIR)/hare
THIRDPARTYDIR=$(HARESRCDIR)/third-party

all:
	@true # no-op

check:
	$(HARE) test

clean:
	rm -rf docs

docs:
	mkdir -p docs/encoding/json
	$(HAREDOC) -Fhtml encoding > docs/encoding/index.html
	$(HAREDOC) -Fhtml encoding::json > docs/encoding/json/index.html

install:
	mkdir -p "$(DESTDIR)$(THIRDPARTYDIR)"/encoding
	mkdir -p "$(DESTDIR)$(THIRDPARTYDIR)"/encoding/json
	install -m644 encoding/json/README "$(DESTDIR)$(THIRDPARTYDIR)"/encoding/json/README
	install -m644 encoding/json/*.ha "$(DESTDIR)$(THIRDPARTYDIR)"/encoding/json

uninstall:
	rm -rf $(DESTDIR)$(THIRDPARTYDIR)/encoding

.PHONY: all docs clean check install uninstall
