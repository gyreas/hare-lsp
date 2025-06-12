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

	let p = proto::newparser(os::stdin_file);

	let (initialize_id, initialize_params) = initialize_begin(&p)!;
	let workspace_root = project_getroot(&initialize_params);
	initialize_end(&p, initialize_id);

	// make this less crazy
	let s = newstate(&pfds[0], &pfds[1], workspace_root);
	s.server.initialized = true;

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

fn message_recv(p: *proto::parser) proto::message = {
	for (true) match (proto::next(p)) {
	case let m: proto::message =>
		return m;
	case proto::more => continue;
	case let e: proto::error =>
		fmt::fatalf("error: [proto::next]: {}", proto::strerror(e));
	};
};

fn initialize_begin(p: *proto::parser) (((i32 | str), lsp::initialize_params) | !rpc::error) = {
	let m: proto::message = message_recv(p);
	defer proto::message_finish(m);

	let b = memio::fixed(strings::toutf8(m.content));
	let rd = io::limitreader(&b, m.headers.content_length: size);

	match (rpc::parse(&rd)) {
	case let req: rpc::request =>
		if (req.method != "initialize") {
			return rpc::error {
				code = proto::SERVER_NOT_INITIALIZED,
				message = "Server not initialdidiized",
				data = void,
			};
		};

		let params = lsp::getobj(req.params)?;
		let initialize_params = lsp::deserialize_initialize_params(&params)!;
		let initialize_id: (i32 | str) = req.id;

		return (initialize_id, initialize_params);
	case let notif: rpc::notification =>
		// Drop all notifications except exit notifications
		if (notif.method != "exit") {
			abort();
		};

		// handle exit notification
		abort();
	};
};

fn initialize_end(p: *proto::parser, initialize_id: (i32 | str)) void = {
	let result = lsp::initialize_result {
		capabilities = lsp::server_capabilities {
			position_encoding = lsp::POS_ENC_UTF16,
			text_document_sync = void,
			definition_provider = void,
			hover_provider = void,
		},
		server_info = lsp::server_info {
			name = "harels",
			version = "",
		},
	};
	let result = lsp::serialize_initialize_result(&result);
	let response = lsp::to_response(initialize_id, result);
	send_response(os::stdout, &response);

	// wait for Initialized Notification
	let m: proto::message = message_recv(p);
	defer proto::message_finish(m);

	let b = memio::fixed(strings::toutf8(m.content));
	let rd = io::limitreader(&b, m.headers.content_length: size);

	match (rpc::parse(&rd)) {
	case let req: rpc::request =>
		abort();
	case let notif: rpc::notification =>
		// Drop all notifications except exit notifications
		if (notif.method != "initialized") {
			abort();
		};

		// handle exit notification
		return;
	};
};

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
			send_response(s.out.fd, &r);
		};
	case let not: rpc::notification =>
		match (lsp::serve_notification(&s.server, not)) {
		case let e: lsp::error =>
			fmt::fatalf("rpc::error: {}", e.message);
		case => void;
		};
	};
};

fn send_response(sink: io::handle, r: *rpc::response) void = {
	let rser = rpc::response_serialize(r);
	defer json::finish(rser);

	let m = proto::message_fromjson(rser);
	defer proto::message_finish(m);

	// TODO: (non)blocking writes separation
	// doing: blocking write here
	proto::write(sink, &m)!;
};
