use bufio;
use bytes;
use encoding::json;
use encoding::utf8;
use fmt;
use io;
use memio;
use os;
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
	in: io::handle,
	// TODO: use memio
	buf: []u8,
	pbuf: []u8,
	needs_lf: bool,

	ringb: memio::stream, // Internal
};

// Initializes a LSP parser. The caller must call [[finish]] when done with
// parsing messages.
export fn newparser(in: *io::stream) parser = {
	return parser {
		state = header,
		in = in,
		needs_lf = false,
		ringb = memio::dynamic(),
		...
	};
};

export fn finish(p: parser) void = {
	free(memio::buffer(&p.ringb));
};

// Attempts to parse an LSP message from the parser's buffer. Returns [[more]]
// if more data is needed for a complete message. It can be used over streaming I/O
// such as network or some async stream etc.
//
// [[example]]
// 	let p = newparser(os::stdin);
// 	for (true) match (next(&p)) {
// 	case more => continue;
// 	case let m: message => handle_message(m);
//	case let e: error => handle_error(e);
// 	};
// 
// Messages returned by [[next]] must be freed with [[message_finish]] by the
// caller.
export fn next(p: *parser) (message | more | error | io::error) = {
	for (p.state is header) {
		if (p.needs_lf) {
			match (bufio::read_byte(p.in)?) {
			case io::EOF =>
				// still nothing yet
				return more;
			case let b: u8 =>
				if (b != '\n') {
					return malformed_header;
				};
				p.needs_lf = false;
				memio::appendrune(&p.ringb, '\n')!;
			};
		} else {
			if (read_fragmented(p)? is more) {
				return more;
			};
		};

		let b = memio::buffer(&p.ringb);
		if (len(b) > 3) {
			let ringb = b[len(b)-3..];
			b = ringb;
			p.ringb = memio::dynamic();
			io::write(&p.ringb, b)!;
		};
		if (bytes::equal(b, ['\n', '\r', '\n'])) {
			if (p.headers.content_length == 0) {
				return missing_content_length;
			};
			p.state = content;
			continue;
		};
		if (utf8::validate(p.buf) is utf8::invalid) {
			return utf8::invalid;
		};
		next_header(p)?;
	};

	assert(p.state is content);

	static let read = 0z;
	if (read == 0z) {
		p.pbuf = alloc([0...], p.headers.content_length)!;
	};
	match (io::readall(p.in, p.pbuf[read..])) {
	case io::EOF =>
		// not done
		return more;
	case let r: size =>
		read += r;
	case let e: io::error =>
		match (e) {
		case => return e;
		case let ur: io::underread =>
			read += ur: size;
			return more;
		};
	};
	assert(read == p.headers.content_length);
	defer { read = 0z; reset(p); };
	return message {
		headers = p.headers,
		content = strings::fromutf8(p.pbuf)!,
	};
};

fn read_fragmented(p: *parser) (void | more | error | io::error) = {
	match (read_tok(p.in, '\r')) {
	case io::EOF =>
		// although this is EOF, it might just be a seekable stream, or
		// an unfilled stream, so spin on it until it gives something or up
		return more;
	case let fragment: []u8 =>
		defer free(fragment);
		let l = len(fragment);

		io::write(&p.ringb, if (l > 3) fragment[l-3..] else fragment)!;

		match (bufio::read_byte(p.in)?) {
		case io::EOF =>
			// nothing yet
			if (l == 1 && fragment[0] == '\r') {
				p.needs_lf = true;
				return more;
			};
			if (fragment[l-1] == '\r') {
				p.needs_lf = true;
				append(p.buf, fragment[..(l-1)]...)!;
			} else {
				p.needs_lf = false;
				append(p.buf, fragment...)!;
			};
			return more;
		case let b: u8 =>
			if (b != '\n') {
				return malformed_header;
			};
			p.needs_lf = false;
			memio::appendrune(&p.ringb, '\n')!;
			append(p.buf, fragment[..(l-1)]...)!;
		};
	};
};

// reads upto the delimeter, includes the delimeter
fn read_tok(h: io::handle, delim: u8) ([]u8 | io::EOF | io::error) = {
	let buf: []u8 = [];
	let ok = false;
	defer if (!ok) free(buf);

	for (true) match (bufio::read_byte(h)?) {
	case let b: u8 =>
		append(buf, b)?;
		if (b == delim) {
			break;
		};
	case io::EOF =>
		if (len(buf) == 0) {
			return io::EOF;
		};
		break;
	};
	ok = true;
	return buf;
};

fn reset(p: *parser) void = {
	p.headers = headers { ... };
	p.state = header;
	p.ringb = memio::dynamic();
	free(p.buf); p.buf = [];
	p.pbuf = [];
	p.needs_lf = false;
};

fn next_header(p: *parser) (void | error) = {
	let line = strings::fromutf8_unsafe(p.buf);
	let (key, v) = strings::cut(line, ":");
	let val = strings::trim(v);

	defer { free(p.buf);
		p.buf = [];
	};
	if (key == "Content-Length") {
		match (strconv::stoi32(val)) {
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
