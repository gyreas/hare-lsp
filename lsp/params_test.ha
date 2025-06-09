use encoding::json;
use fmt;
use net::uri;

@test fn deserialize_did_close_text_params() void = {
	const input = `{"textDocument":{"uri":"file:///path/to/file.ha"}}`;
	let val = json::loadstr(input)! as json::object;
	defer json::finish(val);
	const params = deserialize_did_close_text_params(&val)!;
	const expected = did_close_text_params {
		text_document = text_document_identifier {
			uri = uri::parse("file:///path/to/file.ha")!,
		},
	};
	test_text_document_identifier(&params.text_document, &expected.text_document);
};

@test fn deserialize_hover_params() void = {
	const input = `{
		"workDoneToken":"1d546990-40a3-4b77-b134-46622995f6ae",
		"position": {
			"line": 9,
			"character": 5
		},
		"textDocument":{"uri":"file:///path/to/file.ha"}
	}`;
	let val = json::loadstr(input)! as json::object;
	defer json::finish(val);
	const params = deserialize_hover_params(&val)!;
	const expected = hover_params {
		work_done_token = "1d546990-40a3-4b77-b134-46622995f6ae",
		position = position {
			line = 9,
			character = 5,
		},
		text_document = text_document_identifier {
			uri = uri::parse("file:///path/to/file.ha")!,
		},
	};
	test_work_done_token(params.work_done_token, expected.work_done_token);
	test_text_document_identifier(&params.text_document, &expected.text_document);
	test_position(&params.position, &expected.position);
};

fn test_work_done_token(wdta: (progress_token | void), wdtb: (progress_token | void)) void = {
	let want: (i32 | str) = "";
	let got: (i32 | str) = "";
	let passed = false;

	match (wdta) {
	case void =>
		want = "void";
		match (wdtb) {
		case void => passed = true;
		case i32 => got = "i32";
		case str => got = "str";
		};
	case i32 =>
		want = wdta as i32;
		match (wdtb) {
		case i32 => got = wdtb as i32; passed = wdta as i32 == wdtb as i32;
		case void => want = "i32"; got = "void";
		case str => want = "i32"; got = "str";
		};
	case str =>
		want = wdta as str;
		match (wdtb) {
		case str => got = wdtb as str; passed = wdta as str == wdtb as str;
		case void => got = "void";
		case i32 => got = "i32";
		};
	};
	if (!passed) {
		fmt::errorfln("=== want {}\n=== got {}", want, got)!;
		abort();
	};
};

fn test_position(pa: *position, pb: *position) void = {
	if (pa.line != pb.line) {
		fmt::errorfln("=== want {}\n=== got {}", pa.character, pb.character)!;
		abort();
	};
	if (pa.character != pb.character) {
		fmt::errorfln("=== want {}\n=== got {}", pa.character, pb.character)!;
		abort();
	};
};

fn test_text_document_identifier(tida: *text_document_identifier, tidb: *text_document_identifier) void = {
	let ua = uri::string(&tida.uri)!;
	let ub = uri::string(&tidb.uri)!;
	defer {
		uri::finish(&tida.uri);
		uri::finish(&tidb.uri);
		free(ua);
		free(ub);
	};
	if (ua != ub) {
		fmt::errorfln("=== want '{}'\n=== got '{}'", ua, ub)!;
		abort();
	};
};
