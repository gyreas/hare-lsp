use encoding::json;

fn deserialize_general_client_capabilities(obj: *json::object)
(general_client_capabilities | deserialize_error) = {
	// TODO
	return general_client_capabilities {
		position_encoding = [POS_ENC_UTF8],
	};
};

fn deserialize_definition_client_capabilities(obj: *json::object) (definition_client_capabilities | deserialize_error) = {
	const dynreg = trybool(obj, "dynamicRegistration")?;
	return definition_client_capabilities {
		dynamic_registration = dynreg,
	};
};

fn deserialize_text_document_client_capabilities(obj: *json::object) (text_document_client_capabilities | deserialize_error) = {
	const definition = match(tryobject(obj, "definition")?) {
	case let obj: json::object =>
		yield deserialize_definition_client_capabilities(&obj)?;
	case void =>
		yield void;
	};

	return text_document_client_capabilities {
		definition = definition,
	};
};

fn deserialize_client_capabilities(obj: *json::object) (client_capabilities | deserialize_error) = {
	const general = match (tryobject(obj, "general")?) {
	case let obj: json::object =>
		yield deserialize_general_client_capabilities(&obj)?;
	case void =>
		yield void;
	};

	const text_document = match (tryobject(obj, "textDocument")?) {
	case let obj: json::object =>
		yield deserialize_text_document_client_capabilities(&obj)?;
	case void =>
		yield void;
	};

	return client_capabilities {
		general = general,
		text_document = text_document,
	};
};

fn serialize_server_capabilities(cap: *server_capabilities) json::object = {
	let obj = json::newobject();

	match (cap.position_encoding) {
	case let encoding: position_encoding =>
		json::set(&obj, "positionEncoding", encoding: str)!;
	case void => void;
	};

	match (cap.text_document_sync) {
	case let kind: text_document_sync_kind =>
		json::set(&obj, "textDocumentSync", kind: u8: f64)!;
	case void => void;
	};

	match (cap.definition_provider) {
	case let b: bool =>
		json::set(&obj, "definitionProvider", b)!;
	case void => void;
	};

	match (cap.hover_provider) {
	case let b: bool =>
		json::set(&obj, "hoverProvider", b)!;
	case void => void;
	};

	return obj;
};

export fn serialize_initialize_result(init: *initialize_result) json::object = {
	let obj = json::newobject();

	let cap = serialize_server_capabilities(&init.capabilities);
	defer json::finish(cap);

	json::set(&obj, "capabilities", cap)!;

	match (init.server_info) {
	case let server_info: server_info =>
		let info = json::newobject();
		defer json::finish(info);

		json::set(&info, "name", server_info.name)!;
		match (server_info.version) {
		case let version: str =>
			json::set(&info, "version", version)!;
		case void => void;
		};

		json::set(&obj, "serverInfo", info)!;
	case void => void;
	};

	return obj;
};
