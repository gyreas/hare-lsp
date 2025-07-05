use encoding::json;
use fmt;
use io;
use lsp::proto;
use lsp;
use memio;
use net::uri;
use os;
use rpc;
use rt;
use strings;

export fn main() void = {
	let conn = newconn();

	let (initialize_id, initialize_params) = initialize_begin(&conn)!;
	let workspace_root = project_getroot(&initialize_params);
	initialize_end(&conn, initialize_id);

	let pfds = [conn.receiver, conn.sender];
	let s = newstate(conn, workspace_root);

	for (true) {
		match (rt::poll(&pfds, len(pfds), -1)) {
		case let e: rt::errno =>
			logerr("error: {}", rt::strerror(e));
		case int => void;
		};

		match (dispatch_one(&s)) {
		case let m: client_error =>
			logerr("client had an error: {}", m: str);
		case => void;
		};
	};
};

type client_error = !str;

fn dispatch_one(s: *state) (void | client_error) = {
	if ((s.conn.receiver.revents & rt::POLLIN) != rt::POLLIN) {
		return;
	};

	let m = match (proto::next(&s.conn.parser)) {
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
		fmt::fatalf("[parse] rpc::error: {}", e.message);
	case let req: rpc::request =>
		defer rpc::finish(&req);
		match (lsp::serve_request(&s.server, req)) {
		case let e: lsp::error =>
			fmt::fatalf("[serve_request] rpc::error: {}", e.message);
		case let r: rpc::response =>
			send_response(&s.conn, &r);
		};
	case let not: rpc::notification =>
		defer rpc::finish(&not);
		match (lsp::serve_notification(&s.server, not)) {
		case let e: lsp::error =>
			fmt::errorfln("[serve_notification] rpc::error: {}", e.message)!;
		case => void;
		};
	};
};
