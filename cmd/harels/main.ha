use encoding::json;
use fmt;
use io;
use lsp::proto;
use lsp;
use memio;
use os;
use rpc;
use rt;
use strings;

export fn main() void = {
	let pfds = [rt::pollfd {
		fd = os::stdin_file,
		events = rt::POLLIN,
		revents = -1,
	}, rt::pollfd {
		fd = os::stdout_file,
		events = rt::POLLOUT,
		revents = -1,
	}];

	let s = newstate(&pfds[0], &pfds[1]);

	for (true) {
		match (rt::poll(&pfds, len(pfds), -1)) {
		case let e: rt::errno =>
			fmt::fatalf("error: {}", rt::strerror(e));
		case int => void;
		};

		match (dispatch_client(&s)) {
		case let m: client_error =>
			fmt::errorfln("client had an error: {}", m: str)!;
		case => void;
		};
	};
};

type client_error = !str;

fn dispatch_client(s: *state) (void | client_error) = {
	if ((s.in.revents & rt::POLLIN) != rt::POLLIN) {
		return;
	};

	let m = match (proto::next(&s.parser)) {
	case let m: proto::message =>
		yield m;
	case proto::more =>
		return; // message still constructing
	case let e: proto::error =>
		fmt::fatalf("error: proto::next: {}", proto::strerror(e));
	};
	defer proto::message_finish(m);

	let b = memio::fixed(strings::toutf8(m.content));
	let rd = io::limitreader(&b, m.headers.content_length: size);

	match (rpc::parse(&rd)) {
	case let e: rpc::error =>
		fmt::fatalf("rpc::error: {}", e.message);
	case let req: rpc::request =>
		match (lsp::serve_request(&s.server, req)) {
		case let e: lsp::error =>
			fmt::fatalf("rpc::error: {}", e.message);
		case let r: rpc::response =>
			send_response(s, &r);
		};
	case let not: rpc::notification =>
		match (lsp::serve_notification(&s.server, not)) {
		case let e: lsp::error =>
			fmt::fatalf("rpc::error: {}", e.message);
		case => void;
		};
	};
};

fn send_response(s: *state, r: *rpc::response) void = {
	let rser = rpc::response_serialize(r);
	defer json::finish(rser);

	let m = proto::message_fromjson(rser);
	defer proto::message_finish(m);

	// TODO: (non)blocking writes separation
	// doing: blocking write here
	proto::write(s.out.fd, &m)!;
};
