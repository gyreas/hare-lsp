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

test-init:
	@build/mcat $(ls messages/init/*.json) | build/harels
	@[ $? ] && echo "\ntest-init...PASS" || echo "\ntest-init...FAIL"
