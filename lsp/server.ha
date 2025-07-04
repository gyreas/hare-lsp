use encoding::json;
use fmt;
use lsp::proto;
use rpc;

export type error = !rpc::error;

// requests
export type shutdown = fn (s: *server) (void | error);
export type text_document_definition = fn (s: *server, params: *text_document_position_params) (location | void | error);
export type text_document_hover = fn (s: *server, params: *hover_params) (hover | void | error);

// notifications
export type exit = fn (s: *server) void;
export type text_document_did_change = fn (s: *server, params: *did_change_text_params) (void | error);
export type text_document_did_close = fn (s: *server, params: *did_close_text_params) (void | error);
export type text_document_did_open = fn (s: *server, params: *did_open_text_params) (void | error);

export type server = struct {
	vtable: *vtable,
	shutdown: bool,
};

export type vtable = struct {
	// requests

	// The shutdown request is sent from the client to the server. It asks
	// the server to shut down, but to not exit (otherwise the response
	// might not be delivered correctly to the client).
	// More info here:
	// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#shutdown
	shutdown: *shutdown,

	// Resolve the definition location of a symbol.
	// More info here:
	// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_definition
	text_document_definition: nullable *text_document_definition,

	// The hover request is sent from the client to the server to request
	// hover information at a given text document position.
	// More info here:
	// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_hover
	text_document_hover: nullable *text_document_hover,

	// notifications

	// A notification to ask the server to exit its process. The server
	// should exit with success code 0 if the shutdown request has been
	// received before; otherwise with error code 1.
	exit: *exit,

	// Signals the LSP server that this file has changed. This contains the
	// updated content of the file. You MUST make sure to have received a
	// textDocument/didOpen notification prior.
	// More info here:
	// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didChange
	text_document_did_change: nullable *text_document_did_change,

	// Signals the LSP server that this file is no longer managed by the
	// client and instead its location pointed to is the source of truth.
	// More info here:
	// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didClose
	text_document_did_close: nullable *text_document_did_close,

	// Signals the LSP server that this file is managed by the client, so
	// the LSP server shouldn't read it elsewhere (eg: filesystem).
	// More info here:
	// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didOpen
	text_document_did_open: nullable *text_document_did_open,
};

export fn serve_notification(s: *server, notif: rpc::notification) (void | error) = {
	match (_serve_notification(s, notif)) {
	case let result: (void | error) =>
		return result;
	case deserialize_error =>
		return rpc::error {
			code = rpc::INVALID_PARAMS,
			message = "Invalid params",
			data = void,
		};
	};
};

fn _serve_notification(s: *server, notif: rpc::notification) (void | deserialize_error | error) = {
	fmt::errorfln("[RECV] method='{}'", notif.method)!;

	// Drop all notifications except exit notifications
	if (notif.method == "exit") {
		return s.vtable.exit(s);
	};

	let params = getobj(notif.params)?;
	switch (notif.method) {
	case "textDocument/didChange" =>
		match (s.vtable.text_document_did_change) {
		case *text_document_did_change =>
			return serve_text_document_did_change(s, params)?;
		case null => return;
		};
	case "textDocument/didClose" =>
		match (s.vtable.text_document_did_close) {
		case *text_document_did_close =>
			return serve_text_document_did_close(s, params)?;
		case null => return;
		};
	case "textDocument/didOpen" =>
		match (s.vtable.text_document_did_open) {
		case *text_document_did_open =>
			return serve_text_document_did_open(s, params)?;
		case null => return;
		};
	case =>
		return rpc::error {
			code = rpc::METHOD_NOT_FOUND,
			message = fmt::asprintf("Method not found: '{}'", notif.method)!,
			data = void,
		};
	};
};

export fn serve_request(s: *server, req: rpc::request) (rpc::response | error) = {
	match (_serve_request(s, req)) {
	case let result: (rpc::response | error) =>
		return result;
	case deserialize_error =>
		return rpc::error {
			code = rpc::INVALID_PARAMS,
			message = "Invalid params",
			data = void,
		};
	};
};

fn _serve_request(s: *server, req: rpc::request) (rpc::response | deserialize_error | error) = {
	if (s.shutdown) {
		return rpc::error {
			code = rpc::INVALID_REQUEST,
			message = "Server is shutdown",
			data = void,
		};
	};

	if (req.method == "initialize") {
		// Does not seem to be specified in the spec so let's just
		// return an error
		return rpc::error {
			code = rpc::INVALID_REQUEST,
			message = "Server is already initialized",
			data = void,
		};
	};

	if (req.method == "shutdown") {
		s.shutdown = true;
		s.vtable.shutdown(s)?;
		return to_response(req.id, json::_null);
	};

	return rpc::error {
		code = rpc::METHOD_NOT_FOUND,
		message = fmt::asprintf("Method not found: '{}'", req.method)!,
		data = void,
	};
};

// fn serve_text_document_definition(s: *server, params: json::object) (json::object | json::_null | deserialize_error | error) = {
// 	const handler = s.vtable.text_document_definition as *text_document_definition;
// 	const params = unmarshal_text_document_position_params(&params)?;
// 	match (handler(s, &params)?) {
// 	case let location: location =>
// 		return marshal_location(location);
// 	case void =>
// 		return json::_null;
// 	};
// };

// fn serve_text_document_hover(s: *server, params: json::object) (json::object | json::_null | deserialize_error | error) = {
// 	const handler = s.vtable.text_document_hover as *text_document_hover;
// 	const params = unmarshal_hover_params(&params)?;
// 	match (handler(s, &params)?) {
// 	case let hover: hover =>
// 		return marshal_hover(&hover);
// 	case void =>
// 		return json::_null;
// 	};
// };

fn serve_text_document_did_change(s: *server, params: json::object) (void | deserialize_error | error) = {
	const handler = s.vtable.text_document_did_change as *text_document_did_change;
	const params = deserialize_did_change_text_params(&params)?;
	return handler(s, &params);
};

fn serve_text_document_did_close(s: *server, params: json::object) (void | deserialize_error | error) = {
	const handler = s.vtable.text_document_did_close as *text_document_did_close;
	const params = deserialize_did_close_text_params(&params)?;
	return handler(s, &params);
};

fn serve_text_document_did_open(s: *server, params: json::object) (void | deserialize_error | error) = {
	const handler = s.vtable.text_document_did_open as *text_document_did_open;
	const params = deserialize_did_open_text_params(&params)?;
	return handler(s, &params);
};

export fn to_response(reqid: (i32 | str), result: (json::object | json::_null)) rpc::response = {
	return rpc::response {
		id = reqid,
		result = result,
		error = void,
	};
};

export fn getobj(val: ([]json::value | json::object | void)) (json::object | error) = {
	match (val) {
	case let obj: json::object =>
		return obj;
	case =>
		return rpc::error {
			code = rpc::INVALID_PARAMS,
			message = "Invalid params",
			data = void,
		};
	};
};
