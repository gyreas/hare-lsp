use io;
use rt;
use lsp;
use lsp::proto;

export type client = struct {
	in: *rt::pollfd,
	out: *rt::pollfd,
	parser: proto::parser,
};

export fn newclient(in: *rt::pollfd, out: *rt::pollfd) client = {
	// TODO this is unnecessarily circular
	// find a way to decouple the lspserver from the client
	// for example via an argument everytime the client is to be
	// used in a function call or something like that
	return client {
		in = in,
		out = out,
		parser = proto::newparser(in.fd),
	};
};
