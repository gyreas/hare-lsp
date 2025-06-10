use encoding::json;
use fmt;
use io;
use lsp::proto;
use lsp;
use net::uri;
use os;
use rt;

const server_vt = lsp::vtable {
	initialize               = &handle_initialize,
	shutdown                 = &handle_shutdown,
	initialized              = &handle_initialized,
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
	project_root: uri::uri,
};

fn newstate(in: *rt::pollfd, out: *rt::pollfd) state = state {
	project_root = uri::parse("file://root")!,
	server = lsp::server {
		vtable = &server_vt,
		initialized = false,
		shutdown = false,
	},
	in = in,
	out = out,
	parser = proto::newparser(in.fd),
};

fn handle_initialize(s: *lsp::server, params: *lsp::initialize_params) (lsp::initialize_result | lsp::error) = {
	let s = s: *state;

	let hasroot = false;
	if (!(params.workspace_folders is void)) {
		let wsf = params.workspace_folders as []lsp::workspace_folder;
		if (len(wsf) > 0) {
			s.project_root = wsf[0].uri;
			hasroot = true;
		};
	} else if (!(params.root_uri is void)) {
		s.project_root = params.root_uri as uri::uri;
		hasroot = true;
	} else if (!(params.root_path is void)) {
		match (params.root_path as (str | json::_null)) {
		case json::_null => void;
		case let rp: str =>
			s.project_root = uri::parse(rp)!;
			hasroot = true;
		};
	};
	if (!hasroot) {
		s.project_root = uri::parse(os::getcwd())!;
	};

	loginfo("(initialize) workspace root is '{}'", uri::string(&s.project_root)!);

	return lsp::initialize_result {
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

fn handle_initialized(s: *lsp::server, params: *lsp::initialized_params) (void | lsp::error) = {
	return;
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
