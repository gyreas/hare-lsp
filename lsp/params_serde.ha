use encoding::json;
use net::uri;
use rpc;

export fn deserialize_did_change_text_params(obj: *json::object) (did_change_text_params | deserialize_error) = {
	const text_document = deserialize_text_document_identifier(&getobject(obj, "textDocument")?)?;
	const content_changes = getarray(obj, "contentChanges")?;
	assert(len(content_changes) > 0, "the client trolled so hard I crashed");

	let casted_content_changes = alloc(
		[text_document_content_change_event {range = void,...}...],
		len(content_changes)
	)!;
	for (let j = 0z; j < len(content_changes); j += 1) {
		let content_change = &(content_changes[j]: json::object);
		casted_content_changes[j] = deserialize_text_document_content_change_event(content_change)?;
	};

	return did_change_text_params {
		text_document = text_document,
		content_changes = casted_content_changes,
	};
};

export fn deserialize_did_close_text_params(obj: *json::object) (did_close_text_params | deserialize_error) = {
	const text_document = deserialize_text_document_identifier(&getobject(obj, "textDocument")?)?;
	return did_close_text_params {
		text_document = text_document,
	};
};

export fn deserialize_did_open_text_params(obj: *json::object) (did_open_text_params | deserialize_error) = {
	const text_document = deserialize_text_document_item(&getobject(obj, "textDocument")?)?;
	return did_open_text_params {
		text_document = text_document,
	};
};

export fn deserialize_hover_params(obj: *json::object) (hover_params | deserialize_error) = {
	const progress = deserialize_work_done_progress_params(obj)?;
	const text_document_position = deserialize_text_document_position_params(obj)?;
	return hover_params {
		work_done_token = progress.work_done_token,
		text_document = text_document_position.text_document,
		position = text_document_position.position,
	};
};

export fn deserialize_initialize_params(obj: *json::object) (initialize_params | deserialize_error) = {
	const progress = deserialize_work_done_progress_params(obj)?;
	const process_id = match (tryintnull(obj, "processId")?) {
	case let process_id: (i32 | json::_null) =>
		yield process_id;
	case void =>
		return rpc::invalid_json;
	};

	const options = match (json::get(obj, "initializationOptions")) {
	case let val: *json::value =>
		yield *val;
	case void => yield void;
	};

	let root_path: (str | json::_null | void) = void;
	let root_uri: (uri::uri | void) = void;
	const ws_folders = match (tryarraynull(obj, "workspaceFolders")?) {
	case (void | json::_null) =>
		match (trystrnull(obj, "rootUri")?) {
		case void => root_path = trystrnull(obj, "rootPath")?;
		case let ru: str => root_uri = uri::parse(ru)!;
		case => void;
		};
	case let a: []json::value =>
		let wsf: []workspace_folder = [];
		for (let f .. a) {
			let f = f as json::object;
			append(wsf, deserialize_workspace_folder(&f)?)!;
		};
		yield wsf;
	};

	return initialize_params {
		work_done_token = progress.work_done_token,
		process_id = process_id,
		root_path = root_path,
		root_uri = root_uri,
		workspace_folders = ws_folders,
		initialization_options = options,
		// TODO: deserialize remaining configurations from the object
		capabilities = client_capabilities {
			general = void,
			text_document = void,
		},
	};
};

export fn deserialize_initialized_params(obj: *json::object) (initialized_params | deserialize_error) = {
	return initialized_params {
		noop = 1,
	};
};

export fn serialize_log_message_params(l: *log_message_params) json::object = {
	let obj = json::newobject();
	json::set(&obj, "type", serialize_message_type(l._type))!;
	json::set(&obj, "message", l.message)!;
	return obj;
};

export fn deserialize_text_document_position_params(obj: *json::object) (text_document_position_params | deserialize_error) = {
	const text_document = deserialize_text_document_identifier(&getobject(obj, "textDocument")?)?;
	const position = deserialize_position(&getobject(obj, "position")?)?;
	return text_document_position_params {
		text_document = text_document,
		position = position,
	};
};

export fn deserialize_work_done_progress_params(obj: *json::object) (work_done_progress_params | deserialize_error) = {
	const token = match (json::get(obj, "workDoneToken")) {
	case let val: *json::value =>
		yield match (*val) {
		case let s: str => yield s: progress_token;
		case let f: f64 => yield f: i32: progress_token;
		case json::_null => yield void;
		case => return stopbuggingmeerr;
		};
	case void => yield void;
	};
	return work_done_progress_params {
		work_done_token = token,
	};
};

fn serialize_work_done_token_params(p: *work_done_progress_params, obj: *json::object) void = {
	match (p.work_done_token) {
	case let token: progress_token =>
			match (token) {
			case let number: i32 =>
				json::set(obj, "workDoneToken", number: f64)!;
			case let s: str =>
				json::set(obj, "workDoneToken", s)!;
			};
	case void => void;
	// FIXME: WHy do we need this when not initializing?
	case => void;
	};
};

export fn deserialize_workspace_folder(obj: *json::object) (workspace_folder | deserialize_error) = {
	let uri = match (trystr(obj, "uri")?) {
	case let u: str => yield u;
	case void => return rpc::invalid_json;
	};

	let name = match (trystr(obj, "name")?) {
	case let n: str => yield n;
	case void => return rpc::invalid_json;
	};

	return workspace_folder {
		uri = uri::parse(uri)!,
		name = name,
	};
};
