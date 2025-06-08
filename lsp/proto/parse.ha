use bufio;
use bytes;
use encoding::json;
use encoding::utf8;
use fmt;
use io;
use rpc;
use strconv;
use strings;

export def SERVER_NOT_INITIALIZED: rpc::error_code = -32002;

export type state = (header | content); // Internal use.
export type header = void;
export type content = void;

// Will parse LSP messages with [[next]]. The buffer is meant to be used by the
// caller directly to add data in it as data arrives (eg: from the network).
// (Until I find a better way of doing it anyway)
export type parser = struct {
	state: state,
	headers: headers,
	buf: []u8,
};

// Initializes a LSP parser. The caller must call [[finish]] when done with
// parsing messages.
export fn newparser() parser = {
	return parser {
		state = header,
		buf = [],
		...
	};
};

export fn finish(p: parser) void = {
	free(p.buf);
};

// Attempts to parse an LSP message from the parser's buffer. Returns [[more]]
// if more data is needed in the buffer.
//
// Messages returned by [[next]] must be freed with [[message_finish]] by the
// caller.
export fn next(p: *parser) (message | more | error) = {
	for (true) {
		if (p.state is content) {
			break;
		};

		let i = match (bytes::index(p.buf, strings::toutf8("\r\n"))) {
		case let i: size =>
			yield i;
		case void =>
			return more;
		};

		// FIXME: The spec defines the header part as using ascii encoding
		const line = match (strings::fromutf8(p.buf[..i])) {
		case let s: str =>
			yield s;
		case utf8::invalid =>
			return utf8::invalid;
		};

		next_header(p, line)?;
		delete(p.buf[..i+2]);
	};
	if (p.state is content) {
		const length = p.headers.content_length: size;
		if (len(p.buf) < length) {
			return more;
		};
		defer {
			delete(p.buf[..length]);
			reset(p);
		};

		const cnt = match (strings::fromutf8(p.buf[..length])) {
		case let s: str =>
			yield s;
		case utf8::invalid =>
			return utf8::invalid;
		};

		return message {
			headers = p.headers,
			content = strings::dup(cnt)!,
		};
	};
	abort(); // unreachable
};

fn reset(p: *parser) void = {
	p.headers = headers { ... };
	p.state = header;
};

fn next_header(p: *parser, line: str) (void | error) = {
	if (line == "") {
		if (p.headers.content_length == 0) {
			return missing_content_length;
		};

		p.state = content;
		return;
	};

	let kv = strings::cut(line, ":");
	const key = kv.0, val = strings::ltrim(kv.1);

	if (key == "Content-Length") {
		match (strconv::stoi32(val, 10)) {
		case let length: i32 =>
			p.headers.content_length = length: size;
			return;
		case =>
			return invalid_content_length;
		};
	};

	if (key == "Content-Type") {
		// TODO: Eventually, for now I don't really care..
		// Only 'utf-8' or 'utf8' is supported currently in the
		// specification
		return;
	};
};

export fn message_finish(m: message) void = {
	free(m.headers.content_type);
	free(m.content);
};
