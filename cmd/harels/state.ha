use encoding::json;
use fmt;
use io;
use lsp::proto;
use lsp;
use net::uri;
use os;
use rt;
use vfs::overlay;

const server_vt = lsp::vtable {
	shutdown                 = &handle_shutdown,
	exit                     = &handle_exit,

	text_document_definition = null,
	text_document_hover      = null,
	text_document_did_change = &handle_did_change,
	text_document_did_close  = &handle_did_close,
	text_document_did_open   = &handle_did_open,
};

type state = struct {
	server: lsp::server,
	in: *rt::pollfd,
	out: *rt::pollfd,
	parser: proto::parser,
	fs: overlay::overlayfs,
	project_root: uri::uri,
};

fn newstate(in: *rt::pollfd, out: *rt::pollfd, workspace_root: uri::uri) state = state {
	server = lsp::server {
		vtable = &server_vt,
		shutdown = false,
	},
	in = in,
	out = out,
	parser = proto::newparser(in.fd),
	project_root = workspace_root,
	fs = overlay::new("/tmp", uri::string(&workspace_root)!),
};

fn project_getroot(params: *lsp::initialize_params) uri::uri = {
	let root: (uri::uri | void) = match (params.workspace_folders) {
	case let wsf: []lsp::workspace_folder =>
		yield if (len(wsf) > 0) {
			yield wsf[0].uri;
		};
	case void =>
		let u = match (params.root_uri) {
		case let u: uri::uri =>
			yield u;
		case void =>
			yield void;
		};

		match (params.root_path) {
		case (json::_null | void) =>
			u = void;
		case let rp: str =>
			u = uri::parse(rp)!;
		};
		yield u;
	};

	if (root is void) {
		root = uri::uri {
			scheme = "file",
			host = os::getcwd(),
			...
		};
	};
	return root as uri::uri;
};

fn handle_shutdown(s: *lsp::server) (void | lsp::error) = {
	loginfo("(server shutdown)");
	return;
};

fn handle_exit(s: *lsp::server) void = {
	loginfo("(server exited)");
	let code = *(&!s.shutdown: uintptr: *int);
	os::exit(code);
};

fn handle_did_change(s: *lsp::server, params: *lsp::did_change_text_params) (void | lsp::error) = {
	loginfo("(textDocument/didChange) {}", uri::string(&params.text_document.uri)!);
};

fn handle_did_close(s: *lsp::server, params: *lsp::did_close_text_params) (void | lsp::error) = {
	loginfo("(textDocument/didClose) {}", uri::string(&params.text_document.uri)!);
};

fn handle_did_open(s: *lsp::server, params: *lsp::did_open_text_params) (void | lsp::error) = {
	loginfo("(textDocument/didOpen) {}", uri::string(&params.text_document.uri)!);
};
