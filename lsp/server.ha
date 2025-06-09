use encoding::json;
use fmt;
use lsp::proto;
use rpc;

export type error = !rpc::error;

export type initialize = fn (s: *server, params: *initialize_params) (initialize_result | error);

// requests
export type shutdown = fn (s: *server) (void | error);
export type text_document_definition = fn (s: *server, params: *text_document_position_params) (location | void | error);
export type text_document_hover = fn (s: *server, params: *hover_params) (hover | void | error);

// notifications
export type exit = fn (s: *server) void;
export type initialized = fn (s: *server, params: *initialized_params) (void | error);
export type text_document_did_change = fn (s: *server, params: *did_change_text_params) (void | error);
export type text_document_did_close = fn (s: *server, params: *did_close_text_params) (void | error);
export type text_document_did_open = fn (s: *server, params: *did_open_text_params) (void | error);

export type server = struct {
	vtable: *vtable,

	initialized: bool,
	shutdown: bool,
};

export type vtable = struct {
	initialize: *initialize,

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

	// The initialized notification is sent from the client to the server
	// after the client received the result of the initialize request but
	// before the client is sending any other request or notification to the
	// server. The server can use the initialized notification for example
	// to dynamically register capabilities. The initialized notification
	// may only be sent once.
	// More info here:
	// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#initialized
	initialized: nullable *initialized,

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

// export fn serve_notification(s: *server, notif: rpc::notification) (void | error) = {
// 	match (_serve_notification(s, notif)) {
// 	case let result: (void | error) =>
// 		return result;
// 	case unmarshalerr =>
// 		return rpc::error {
// 			code = rpc::INVALID_PARAMS,
// 			message = "Invalid params",
// 			data = void,
// 		};
// 	};
// };

// fn _serve_notification(s: *server, notif: rpc::notification) (void | unmarshalerr | error) = {
// 	// Drop all notifications except exit notifications
// 	if (!s.initialized && notif.method != "exit") {
// 		return;
// 	};

// 	if (notif.method == "exit") {
// 		return s.vtable.exit(s);
// 	};

// 	if (notif.method == "initialized") {
// 		match (s.vtable.initialized) {
// 		case *initialized =>
// 			return serve_initialized(s, getobj(notif.params)?)?;
// 		case null => void;
// 		};
// 	};

// 	if (notif.method == "textDocument/didChange") {
// 		match (s.vtable.text_document_did_change) {
// 		case *text_document_did_change =>
// 			return serve_text_document_did_change(s, getobj(notif.params)?)?;
// 		case null => void;
// 		};
// 	};

// 	if (notif.method == "textDocument/didClose") {
// 		match (s.vtable.text_document_did_close) {
// 		case *text_document_did_close =>
// 			return serve_text_document_did_close(s, getobj(notif.params)?)?;
// 		case null => void;
// 		};
// 	};

// 	if (notif.method == "textDocument/didOpen") {
// 		match (s.vtable.text_document_did_open) {
// 		case *text_document_did_open =>
// 			return serve_text_document_did_open(s, getobj(notif.params)?)?;
// 		case null => void;
// 		};
// 	};

// 	return rpc::error {
// 		code = rpc::METHOD_NOT_FOUND,
// 		message = "Method not found",
// 		data = void,
// 	};
// };

// export fn serve_request(s: *server, req: rpc::request) (rpc::response | error) = {
// 	match (_serve_request(s, req)) {
// 	case let result: (rpc::response | error) =>
// 		return result;
// 	case unmarshalerr =>
// 		return rpc::error {
// 			code = rpc::INVALID_PARAMS,
// 			message = "Invalid params",
// 			data = void,
// 		};
// 	};
// };

// fn _serve_request(s: *server, req: rpc::request) (rpc::response | unmarshalerr | error) = {
// 	if (!s.initialized) {
// 		if (req.method != "initialize") {
// 			return rpc::error {
// 				code = protocol::SERVER_NOT_INITIALIZED,
// 				message = "Server not initialized",
// 				data = void,
// 			};
// 		};

// 		const result = serve_initialize(s, getobj(req.params)?)?;
// 		s.initialized = true;
// 		return to_response(req, result);
// 	};

// 	if (s.shutdown) {
// 		return rpc::error {
// 			code = rpc::INVALID_REQUEST,
// 			message = "Server is shutdown",
// 			data = void,
// 		};
// 	};

// 	if (req.method == "initialize") {
// 		// Does not seem to be specified in the spec so let's just
// 		// return an error
// 		return rpc::error {
// 			code = rpc::INVALID_REQUEST,
// 			message = "Server is already initialized",
// 			data = void,
// 		};
// 	};

// 	if (req.method == "textDocument/definition") {
// 		match (s.vtable.text_document_definition) {
// 		case *text_document_definition =>
// 			const result = serve_text_document_definition(s, getobj(req.params)?)?;
// 			return to_response(req, result);
// 		case null => void;
// 		};

// 	};

// 	if (req.method == "textDocument/hover") {
// 		match (s.vtable.text_document_hover) {
// 		case *text_document_hover =>
// 			const result = serve_text_document_hover(s, getobj(req.params)?)?;
// 			return to_response(req, result);
// 		case null => void;
// 		};

// 	};

// 	if (req.method == "shutdown") {
// 		s.shutdown = true;
// 		s.vtable.shutdown(s)?;
// 		return to_response(req, json::_null);
// 	};

// 	return rpc::error {
// 		code = rpc::METHOD_NOT_FOUND,
// 		message = "Method not found",
// 		data = void,
// 	};
// };

// fn serve_initialize(s: *server, params: json::object) (json::object | unmarshalerr | error) = {
// 	const params = unmarshal_initialize_params(&params)?;
// 	const result = s.vtable.initialize(s, &params)?;
// 	return marshal_initialize_result(&result);
// };

// fn serve_text_document_definition(s: *server, params: json::object) (json::object | json::_null | unmarshalerr | error) = {
// 	const handler = s.vtable.text_document_definition as *text_document_definition;
// 	const params = unmarshal_text_document_position_params(&params)?;
// 	match (handler(s, &params)?) {
// 	case let location: location =>
// 		return marshal_location(location);
// 	case void =>
// 		return json::_null;
// 	};
// };

// fn serve_text_document_hover(s: *server, params: json::object) (json::object | json::_null | unmarshalerr | error) = {
// 	const handler = s.vtable.text_document_hover as *text_document_hover;
// 	const params = unmarshal_hover_params(&params)?;
// 	match (handler(s, &params)?) {
// 	case let hover: hover =>
// 		return marshal_hover(&hover);
// 	case void =>
// 		return json::_null;
// 	};
// };

// fn serve_initialized(s: *server, params: json::object) (void | unmarshalerr | error) = {
// 	const handler = s.vtable.initialized as *initialized;
// 	let params = unmarshal_initialized_params(&params)?;
// 	return handler(s, &params);
// };

// fn serve_text_document_did_change(s: *server, params: json::object) (void | unmarshalerr | error) = {
// 	const handler = s.vtable.text_document_did_change as *text_document_did_change;
// 	const params = unmarshal_did_change_text_params(&params)?;
// 	return handler(s, &params);
// };

// fn serve_text_document_did_close(s: *server, params: json::object) (void | unmarshalerr | error) = {
// 	const handler = s.vtable.text_document_did_close as *text_document_did_close;
// 	const params = unmarshal_did_close_text_params(&params)?;
// 	return handler(s, &params);
// };

// fn serve_text_document_did_open(s: *server, params: json::object) (void | unmarshalerr | error) = {
// 	const handler = s.vtable.text_document_did_open as *text_document_did_open;
// 	const params = unmarshal_did_open_text_params(&params)?;
// 	return handler(s, &params);
// };

// fn to_response(req: rpc::request, result: (json::object | json::_null)) rpc::response = {
// 	return rpc::response {
// 		id = req.id,
// 		result = result,
// 		error = void,
// 	};
// };

// fn getobj(val: ([]json::value | json::object | void)) (json::object | error) = {
// 	match (val) {
// 	case let obj: json::object =>
// 		return obj;
// 	case =>
// 		return rpc::error {
// 			code = rpc::INVALID_PARAMS,
// 			message = "Invalid params",
// 			data = void,
// 		};
// 	};
// };
