use encoding::json;
use fmt;
use memio;
use strings;

fn ideq(id: (i32 | str), id0: (i32 | str)) bool = {
	match (id) {
	case i32 =>
		if (!(id0 is i32)) return false;
		return id as i32 == id0 as i32;
	case str =>
		if (!(id0 is str)) return false;
		return id as str == id0 as str;
	};
};

fn wantgot(want: str, got: str) void = {
	fmt::errorfln("=== want {}\n=== got {}", want, got)!;
	abort();
};

fn check(message: str, rn: (notification | request)) void = {
	let buf = strings::toutf8(message);
	let src = memio::fixed(buf);

	let (rp, r0p) = match (parse(&src)) {
	case let r: request =>
		if (rn is notification) wantgot("request", "notification");
		let r0 = rn as request;

		match (r.id) {
		case i32 => if (r0.id is str) wantgot("i32", "str");
		case str => if (r0.id is i32) wantgot("str", "i32");
		};
		if (r.method != r0.method) {
			wantgot(r.method, r0.method);
		};
		yield (r.params, r0.params);
	case let n: notification =>
		if (rn is request) wantgot("notification", "request");
		let n0 = rn as notification;
		if (n.method != n0.method) {
			wantgot(n.method, n0.method);
		};
		yield (n.params, n0.params);
	case let e: error =>
		fmt::errorfln("error[{}]: {}", e.code: i32, e.message)!;
		abort();
	};

	match (rp) {
	case void =>
		match (r0p) {
		case void => void;
		case json::object => wantgot("void", "object");
		case []json::value => wantgot("void", "[value]");
		};
	case json::object  =>
		match (r0p) {
		case void => wantgot("object", "void");
		case json::object => void;
		case []json::value => wantgot("object", "[value]");
		};
	case []json::value  =>
		match (r0p) {
		case void => wantgot("[value]", "void");
		case json::object => wantgot("[value]", "object");
		case []json::value => void;
		};
	};
};

// generates a stub request to be used for typechecks in [[check]]
fn req(p: int, id: (i32|str), m: str) request = {
	let params = switch (p) {
	case 0 => yield void;
	case 1 => yield json::newobject();
	case => yield [json::newobject()]: []json::value;
	};
	return request {
		params = params,
		id = id,
		method = m,
	};
};

@test fn ok() void = {
	check(`{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"key":"value"},"id":1}`,
		req(1, 1, "textDocument/didOpen"));
	check(`{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"key":"value"},"id":"1"}`,
		req(1, "1", "textDocument/didOpen"));

	check(`{"jsonrpc":"2.0","method":"textDocument/didOpen","id":1}`, req(0, 1, "textDocument/didOpen"));
	check(`{"jsonrpc":"2.0","method":"textDocument/didOpen","id":"1"}`, req(0, "1", "textDocument/didOpen"));
};
