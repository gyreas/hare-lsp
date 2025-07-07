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
	let root = paths::fromuri(&workspace_root)!;
	loginfo("workspace root = {}", paths::string(&root));

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
	let root: (uri::uri | void) = void;
	match (params.workspace_folders) {
	case let wsf: []lsp::workspace_folder =>
		if (len(wsf) > 0) {
			root = wsf[0].uri;
		};
	case void =>
		root = params.root_uri;
		if (params.root_path is str) {
			let rp = params.root_path as str;
			root = uri::parse(rp)!;
		};
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

	let s = s: *state;
	let path = paths::fromuri(&params.text_document.uri)!;
	let vpath = memfs::newvfspath(path);

	loginfo("[didChange] resolved path = {}", paths::string(&path));

	let memdoc = memdocs_get(&s.memdocs, &vpath) as *document_data;

	loginfo("[didChange] pre: '{}'", memdoc.data);

	let newdata = apply_document_changes(memdoc.data, params.content_changes);
	// memdoc.version = params.text_document.version;
	loginfo("[didChange] post: '{}'", newdata);
	memdoc.data = newdata;
};

fn handle_did_close(s: *lsp::server, params: *lsp::did_close_text_params) (void | lsp::error) = {
	loginfo("(textDocument/didClose) {}", uri::string(&params.text_document.uri)!);

	let s = s: *state;
	let path = paths::fromuri(&params.text_document.uri)!;
	let vpath = memfs::newvfspath(path);

	loginfo("[didClose] resolved path = {}", paths::string(&path));

	// remove it from memory
	match (memdocs_remove(&s.memdocs, &vpath)) {
	case void =>
		loginfo("[didClose] removed '{}'", paths::string(&path));
		loginfo("[didClose] number of documents: {}", memdocs_count(&s.memdocs));
	case memdocs_error =>
		// maybe we're being trolled by the client
		let s = fmt::asprintf("document '{}' was never opened", paths::string(&path))!;
		logerr("[didClose] {}", s);
		return rpc::error {
			code = DOCUMENT_NOT_OPENED,
			message = s,
			data = void,
		};
	};
};

fn handle_did_open(s: *lsp::server, params: *lsp::did_open_text_params) (void | lsp::error) = {
	loginfo("(textDocument/didOpen) {}", uri::string(&params.text_document.uri)!);

	let s = s: *state;
	let path = paths::fromuri(&params.text_document.uri)!;
	let vpath = memfs::newvfspath(path);

	loginfo("[didOpen] resolved path = {}", paths::string(&path));
	if (memdocs_contains(&s.memdocs, &vpath)) {
		let s = fmt::asprintf("document '{}' already opened", paths::string(&path))!;
		loginfo("[didOpen] {}", s);
		return rpc::error {
			code = DOCUMENT_ALREADY_OPENED,
			message = s,
			data = void,
		};
	};

	let docdata = newdocdata(params.text_document.version, params.text_document.text);
	let docscount = memdocs_count(&s.memdocs);
	memdocs_insert(&s.memdocs, &vpath, docdata)!;
	assert(memfs::set_file_contents(&s.fs, &vpath, params.text_document.text));
	assert(memdocs_count(&s.memdocs) > docscount, "should be higher");

	loginfo("[didOpen] number of documents: {}", memdocs_count(&s.memdocs));
};
