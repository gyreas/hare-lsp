interesting_modules := "cmd/ lsp/ paths/ rpc/ vfs/memfs/"

phony: test-init

build:
	hare build cmd/harels
	@ [ ! -d build/ ] && mkdir build || true
	@mv harels build/

mcat:
	hare build -o mcat cmd/mcat.ha
	@ [ ! -d build/ ] && mkdir build || true
	@mv mcat build/

test: build mcat
	@for m in rpc/ lsp/; do echo "\n-- testing: [$m]"; hare test $m; done
	just test-init
	just test-didOpen

test-init: build mcat
	@build/mcat $(ls messages/init/*.json) | build/harels
	@[ $? ] && echo "\ntest-init...PASS" || echo "\ntest-init...FAIL"

test-didOpen: build mcat
	@build/mcat $(ls messages/didOpen/*.json) | build/harels
	@[ $? ] && echo "\ntest-didOpen...PASS" || echo "\ntest-didOpen...FAIL"

# deletes lines started with comments and blank lines in all forms
# and counts the rest
sloc:
	@hare build -o sloc cmd/sloc.ha
	@ [ ! -d build/ ] && mkdir build || true
	@mv sloc build/
	@build/sloc
