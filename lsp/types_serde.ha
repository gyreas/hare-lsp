use bufio;
use encoding::json;
use fmt;
use io;
use net::uri;
use strings;
use rpc;

export fn serialize_hover(h: *hover) json::object = {
	let obj = json::newobject();

	const contents = serialize_markup_content(&h.contents);
	defer json::finish(contents);

	match (h.range) {
	case let range: range =>
		const range = serialize_range(range);
		defer json::finish(range);
		json::set(&obj, "range", range)!;
	case void => void;
	};

	json::set(&obj, "contents", contents)!;

	return obj;
};

export fn serialize_location(loc: location) json::object = {
	let obj = json::newobject();

	let uri = uri::string(&loc.uri)!;
	defer free(uri);

	let range = serialize_range(loc.range);
	defer json::finish(range);

	json::set(&obj, "uri", uri)!;
	json::set(&obj, "range", range)!;

	return obj;
};

fn serialize_markup_content(m: *markup_content) json::object = {
	let obj = json::newobject();
	json::set(&obj, "kind", m.kind)!;
	json::set(&obj, "value", m.value)!;
	return obj;
};

fn deserialize_markup_kind(val: json::value) (markup_kind | deserialize_error) = {
	const s = match (val) {
	case let s: str =>
		yield s;
	case =>
		return stopbuggingmeerr;
	};

	if (s == markup_kind_plaintext) {
		return markup_kind_plaintext: markup_kind;
	};

	if (s == markup_kind_markdown) {
		return markup_kind_markdown: markup_kind;
	};

	return stopbuggingmeerr;
};

fn serialize_message_type(m: message_type) f64 = {
	return m: u8: f64;
};

fn deserialize_position(obj: *json::object) (position | deserialize_error) = {
	const line = getfloat(obj, "line")?: u32;
	const character = getfloat(obj, "character")?: u32;
	return position {
		line = line,
		character = character,
	};
};

fn serialize_position(pos: position) json::object = {
	let obj = json::newobject();
	json::set(&obj, "line", pos.line: f64)!;
	json::set(&obj, "character", pos.character: f64)!;
	return obj;
};

export fn deserialize_range(obj: *json::object) (range | deserialize_error) = {
	let start = getobject(obj, "start")?;
	let end = getobject(obj, "end")?;
	return range {
		start = deserialize_position(&start)?,
		end = deserialize_position(&end)?,
	};
};

export fn serialize_range(range: range) json::object = {
	let obj = json::newobject();

	let start = serialize_position(range.start);
	defer json::finish(start);

	let end = serialize_position(range.end);
	defer json::finish(end);

	json::set(&obj, "start", start)!;
	json::set(&obj, "end", end)!;

	return obj;
};

fn deserialize_text_document_content_change_event(obj: *json::object) (text_document_content_change_event | deserialize_error) = {
	let range = match (tryobject(obj, "range")?) {
	case let range: json::object =>
		yield deserialize_range(&range)?;
	case void =>
		yield void;
	};
	return text_document_content_change_event {
		text = strings::dup(getstr(obj, "text")?)!,
		range = range,
	};
};

fn deserialize_text_document_identifier(obj: *json::object) (text_document_identifier | deserialize_error) = {
	const uri = match (uri::parse(getstr(obj, "uri")?)) {
	case let uri: uri::uri =>
		yield uri;
	case uri::invalid =>
		return stopbuggingmeerr;
	};

	return text_document_identifier {
		uri = uri,
	};
};

fn deserialize_text_document_item(obj: *json::object) (text_document_item | deserialize_error) = {
	const uri = match (uri::parse(getstr(obj, "uri")?)) {
	case let uri: uri::uri =>
		yield uri;
	case uri::invalid =>
		return stopbuggingmeerr;
	};

	return text_document_item {
		uri = uri,
		language_id = strings::dup(getstr(obj, "languageId")?)!,
		version = getfloat(obj, "version")?: i32,
		text = strings::dup(getstr(obj, "text")?)!,
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
		name = strings::dup(name)!,
	};
};
