use encoding::json;
use errors;
use fmt;
use fs;
use io;
use lsp::proto;
use lsp;
use net::uri;
use os;
use paths;
use rpc;
use rt;
use strings;
use temp;
use vfs::memfs;

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
	conn: connection,
	memdocs: memdocs,
	fs: memfs::memfs,
	project_root: uri::uri,
};

fn newstate(conn: connection, workspace_root: uri::uri) state = {
	let root = paths::fromuri(&workspace_root);
	// fmt::errorfln("workspace root = {}", root)!;

	return state {
		server = lsp::server {
			vtable = &server_vt,
			shutdown = false,
		},
		conn = conn,
		project_root = workspace_root,
		memdocs = newmemdocs(),
		fs = memfs::new(),
	};
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

		if (params.root_path is str) {
			let rp = params.root_path as str;
			u = uri::parse(rp)!;
		};
		yield u;
	};

	if (root is void) {
		root = uri::uri {
			scheme = "file",
			host = "",
			path = os::getcwd(),
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

	let s = s: *state;
	let path = paths::fromuri(&params.text_document.uri)!;
	let vpath = memfs::newvfspath(path);

	fmt::errorfln("[didOpen] resolved path = {}", paths::string(&path))!;
	if (memdocs_contains(&s.memdocs, &vpath)) {
		let s = fmt::asprintf("document '{}' already opened", paths::string(&path))!;
		fmt::errorln("[didOpen]", s)!;
		return rpc::error {
			code = DOCUMENT_ALREADY_OPENED,
			message = s,
			data = void,
		};
	};

	let docdata = newdocdata(params.text_document.version, params.text_document.text);
	memdocs_insert(&s.memdocs, &vpath, docdata)!;
	if (!memfs::set_file_contents(&s.fs, &vpath, params.text_document.text)) {
		abort();
	};
};
