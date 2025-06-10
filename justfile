run: build
	printf 'Content-Length: %d\r\nContent-Type: application/hare-jsonrpc\r\n\r\n%s' $(wc -c messages/initialise.json | cut -d' ' -f 1) > .init.rpc
	cat messages/initialise.json >> .init.rpc
	./harels < .init.rpc
build:
