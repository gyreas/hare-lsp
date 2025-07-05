use encoding::json;
use fmt;
use io;
use memio;
use os;
use strings;

export def JSONRPC_VERSION: str = "2.0";

export type deserialize_error = !(invalid_json | no_jsonrpc | invalid_version | no_method);
// todo: How does this relate to message batching which
// requires array of JSON objects?
export type invalid_json    = !void;
export type no_jsonrpc      = !void;
export type invalid_version = !void;
export type no_method       = !void;

export fn strerror(err: deserialize_error) str = {
	match (err) {
	case no_jsonrpc =>
		return "jsonrpc field missing";
	case invalid_version =>
		return "wrong jsonrpc version, only \"2.0\" supported";
	case no_method =>
		return "method field missing";
	case invalid_json =>
		return "expected json object";
	};
};

// A number that indicates the error type that occured. The range -32768 to
// -32000 are reserved by the specification.
export type error_code = i32;

// Invalid JSON received by the server and could not be parsed properly
export def PARSE_ERROR: error_code = -32700;
// The JSON is valid but is not a valid request object
export def INVALID_REQUEST: error_code = -32600;
// The method does not exists or is not available
export def METHOD_NOT_FOUND: error_code = -32601;
// Invalid method parameters
export def INVALID_PARAMS: error_code = -32602;
// Internal JSON-RPC error
export def INTERNAL_ERROR: error_code = -32603;

export type error = struct {
	code: error_code,
	message: str,
	data: (json::value | void),
};

export type request = struct {
	id: (i32 | str),
	method: str,
	params: ([]json::value | json::object | void),
};

export type notification = struct {
	method: str,
	params: ([]json::value | json::object | void),
};

export type response = struct {
	id: (i32 | str),
	result: (json::value | void),
	error: (error | void),
};

// Parses either a [[request]] or a [[notification]] from an [[io::handle]]. The
// caller must free the returned value with [[finish]]. Note that allocations
// also happens on error, so the error must eventually be freed from a
// [[response]].
// TODO: implement for strings as well
export fn parse(src: io::handle) (request | notification | error) = {
	let v = match (json::load(src)) {
	case let v: json::value =>
		yield v;
	case json::error =>
		return error {
			code = PARSE_ERROR,
			message = "Parse error",
			data = void,
		};
	};
	// defer json::finish(v);

	match (deserialize(v)) {
	case let r: (request | notification) =>
		return r;
	case let e: deserialize_error =>
		return error {
			code = INVALID_REQUEST,
			message = fmt::asprintf("Invalid Request: {}", strerror(e))!,
			data = void,
		};
	};
};

export fn finish(rn: (*request | *notification)) void = {
	match (rn) {
	case let r: *request =>
		match (r.id) {
		case let id: str => free(id);
		case => void;
		};

		match (r.params) {
		case let p: ([]json::value | json::object) =>
			json::finish(p: json::value);
		case => void;
		};

		free(r.method);
	case let n: *notification =>
		match (n.params) {
		case let p: ([]json::value | json::object) =>
			json::finish(p: json::value);
		case => void;
		};

		free(n.method);
	};
};

export fn deserialize(v: json::value) (request | notification | deserialize_error) = {
	let v = v as json::object;

	match (json::get(&v, "jsonrpc")) {
	case void => return no_jsonrpc;
	case let ver: *json::value =>
		if (!(*ver is str)) return invalid_json;
		if (*ver as str != JSONRPC_VERSION) {
			return invalid_version;
		};
	};

	let m = match (json::get(&v, "method")) {
	case void => return no_method;
	case let m: *json::value =>
		if (!(*m is str)) {
			return invalid_json;
		};
		yield strings::dup((*m) as str)!;
	};

	let params = match (json::get(&v, "params")) {
	case let v: *json::value => yield (*v) as json::object;
	case void => yield void;
	};

	match (json::get(&v, "id")) {
	case void =>
		return notification {
			method = m,
			params = params,
		};
	case let i: *json::value =>
		let id = match (*i) {
		case let i: f64 => yield i: i32;
		case let s: str => yield strings::dup(s)!;
		case => return invalid_json;
		};

		return request {
			id = id,
			method = m,
			params = params,
		};
	};
};

export fn request_serialize(req: *request) json::object = {
	let o = json::newobject();
	let id = match (req.id) {
	case let i: i32 => yield i: f64;
	case str => yield req.id as str;
	};
	json::put(&o, "jsonrpc", JSONRPC_VERSION)!;
	json::put(&o, "id", id)!;
	json::put(&o, "method", req.method)!;
	match (req.params) {
	case let p: ([]json::value | json::object) =>
		json::put(&o, "params", p: json::value)!;
	case => void;
	};
	return o;
};

export fn notification_serialize(req: *notification) json::object = {
	let o = json::newobject();
	json::put(&o, "jsonrpc", JSONRPC_VERSION)!;
	json::put(&o, "method", req.method)!;
	match (req.params) {
	case let p: ([]json::value | json::object) =>
		json::put(&o, "params", p: json::value)!;
	case => void;
	};
	return o;
};

export fn response_serialize(res: *response) json::object = {
	let o = json::newobject();

	json::put(&o, "jsonrpc", JSONRPC_VERSION)!;
	match (res.id) {
	case let i: i32 => json::put(&o, "id", i: f64)!;
	case let i: str => json::put(&o, "id", i)!;
	};

	if (res.result is json::value) {
		json::put(&o, "result", res.result: json::value)!;
	};

	match (res.error) {
	case void => void;
	case let e: error =>
		let eo = json::newobject();
		json::put(&eo, "code", e.code: f64)!;
		json::put(&eo, "message", e.message)!;
		if (e.data is json::value) {
			json::put(&eo, "data", e.data: json::value)!;
		};

		json::put(&o, "error", eo)!;
	};

	return o;
};
