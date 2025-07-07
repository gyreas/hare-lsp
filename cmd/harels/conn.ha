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

type connection = struct {
	receiver: rt::pollfd,
	recvh: io::handle,

	sender: rt::pollfd,
	sendh: io::handle,

	mbuf: []proto::message,

	parser: proto::parser,
};

fn newconn() connection = connection {
	recvh = os::stdin,
	receiver = rt::pollfd {
		fd = os::stdin_file,
		events = rt::POLLIN,
		revents = -1,
	},
	sendh = os::stdout,
	sender = rt::pollfd {
		fd = os::stdout_file,
		events = rt::POLLOUT,
		revents = -1,
	},
	parser = proto::newparser(os::stdin_file),
	...
};

// blocks until there's a (full) message, and returns it
fn recv(conn: *connection) proto::message = {
	let pfds = [conn.receiver, conn.sender];

	for (true) {
		match (rt::poll(&pfds, len(pfds), -1)) {
		case let e: rt::errno => abort();
		case int => void;
		};

		assert((conn.receiver.revents & rt::POLLIN) == rt::POLLIN);

		match (proto::next(&conn.parser)) {
		case let msg: proto::message =>
			return msg;
		case proto::more =>
			fmt::errorfln("[more]")!;
			continue;
		case let err: proto::error =>
			fmt::fatalf("[recv] error: {}", proto::strerror(err));
		};
	};
};

fn send_response(conn: *connection, r: *rpc::response) void = {
	let serd = rpc::response_serialize(r);
	// defer json::finish(serd);

	let m = proto::message_fromjson(serd);
	defer proto::message_finish(m);

	// TODO: (non)blocking writes separation
	// doing: blocking write here
	proto::write(conn.sender.fd, &m)!;
};

fn initialize_begin(conn: *connection, ) (((i32 | str), lsp::initialize_params) | !rpc::error) = {
	let m = recv(conn);

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
		let initialize_params = match (lsp::deserialize_initialize_params(&params)) {
		case let ip: lsp::initialize_params => yield ip;
		case let de: lsp::deserialize_error =>
			fmt::fatalf("error: {}", lsp::strerror(de));
		};
		let initialize_id: (i32 | str) = req.id;

		return (initialize_id, initialize_params);
	case let notif: rpc::notification =>
		// Drop all notifications except exit notifications
		if (notif.method != "exit") {
			abort();
		};

		logerr("client requested an exit before initialization");
		os::exit(0);
	};
};

fn initialize_end(conn: *connection, initialize_id: (i32 | str)) void = {
	let pfds = [conn.receiver, conn.sender];
	let init_state = 0;

	for (true) {
		match (rt::poll(&pfds, len(pfds), -1)) {
		case let e: rt::errno =>
			fmt::fatalf("error: {}", rt::strerror(e));
		case let n: int =>
			fmt::errorfln("number of ready = {}", n)!;
		};

		switch (init_state) {
		case 0 =>
			let result = lsp::initialize_result {
				capabilities = lsp::server_capabilities {
					position_encoding = lsp::POS_ENC_UTF16,
					text_document_sync = lsp::text_document_sync_kind::INCREMENTAL,
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
			send_response(conn, &response);

			fmt::errorln("initialize result sent, accepting initialize parameters")!;
			init_state = 1;

		case 1 =>
			// TODO: the parser returning more doesn't mean there's message waiting,
			// 	just that we're constructing incomplete message yet
			// 	so, maybe figure out how to batch any constructed messages, universally
			// okay...
			let m = match (proto::next(&conn.parser)) {
			case let msg: proto::message =>
				yield msg;
			case proto::more =>
				fmt::errorfln("[more]")!;
				// for example, there shouldn't be a need for this
				abort();
			case let err: proto::error =>
				fmt::fatalf("[recv] error: {}", proto::strerror(err));
			};

			let b = memio::fixed(strings::toutf8(m.content));
			let rd = io::limitreader(&b, m.headers.content_length: size);

			match (rpc::parse(&rd)) {
			case let req: rpc::request =>
				fmt::errorfln("[rpc] got a request instaead of a notif")!;
				if (true) abort();
			case let notif: rpc::notification =>
				fmt::errorfln("[rpc] got a notif")!;

				// Drop all notifications except exit notifications
				if (notif.method != "initialized") {
					abort();
				};

				// handle exit notification
				return;
			};
			fmt::errorln("initialization complete, moving on to other thing")!;
			break;
		case => abort();
		};
	};
};

fn make_non_blocking(file: io::file) void = {
	const current = match(rt::fcntl(file, rt::F_GETFL, void)) {
	case let current: int => yield current;
	case let err: rt::errno =>
		fmt::errorfln("fcntl(F_GETFL): {}", rt::strerror(err))!;
		return;
	};

	match (rt::fcntl(file, rt::F_SETFL, current | rt::O_NONBLOCK)) {
	case let err: rt::errno =>
		fmt::errorfln("fcntl(F_SETFL): {}", rt::strerror(err))!;
		return;
	case => void;
	};
};
