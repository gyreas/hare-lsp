prefix := "~/.local/"
bindir := prefix/"bin"
interesting_modules := "cmd/harels lsp/ paths/ rpc/ vfs/"

phony: test-init

install: build
    cp build/harels {{bindir}}

build:
	hare build cmd/harels
	@ [ ! -d build/ ] && mkdir build || true
	@mv harels build/

mcat:
	hare build -o mcat cmd/mcat.ha
	@ [ ! -d build/ ] && mkdir build || true
	@mv mcat build/

test: build mcat
	@for m in {{interesting_modules}}; do echo "\n-- testing: [$m]"; hare test $m; done
	@printf "\n"
	just test-init
	@printf "\n"
	just test-basics
	@printf "\n"

test-init: build mcat
	@build/mcat $(ls messages/init/*.json) | build/harels
	@[ $? ] && echo "\ntest-init...PASS" || echo "\ntest-init...FAIL"

test-basics: build mcat
	@build/mcat $(ls messages/didOpenCloseChangeSave/*.json) | build/harels
	@[ $? ] && echo "\ntest-basics...PASS" || echo "\ntest-basics...FAIL"

# deletes lines started with comments and blank lines in all forms
# and counts the rest
sloc:
	@hare build -o sloc cmd/sloc.ha
	@ [ ! -d build/ ] && mkdir build || true
	@mv sloc build/
	@build/sloc
