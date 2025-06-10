use io;
use rt;
use lsp;
use lsp::proto;

export type client = struct {
	in: io::file,
	out: io::file,

	inpolld: *rt::pollfd,
	outpollfd: *rt::pollfd,

	server: lspserver,

	parser: proto::parser,
};

export fn newclient(
	in: io::file, inpfd: *rt::pollfd,
	out: io::file, outpfd: *rt::pollfd
) client = {
	assert(in == inpfd.fd);
	assert(out == outpfd.fd);

	// TODO this is unnecessarily circular
	// find a way to decouple the lspserver from the client
	// for example via an argument everytime the client is to be
	// used in a function call or something like that
	return client {
		in = in,
		out = out,
		inpolld = inpfd,
		outpollfd = outpfd,
		parser = proto::newparser(in),
		server = lspserver {
			server = lsp::server {
				vtable = 0: uintptr: *lsp::vtable,
				...
			},
			client = 0: uintptr: *client,
		},
	};
};
