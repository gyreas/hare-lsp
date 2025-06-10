use bufio;
use bytes;
use fmt;
use io;
use memio;
use rpc;
use strconv;
use strings;

fn pushs(m: *io::stream, s: str) void = {
	let off = io::seek(m, 0, io::whence::CUR)!;
	fmt::fprint(m, s)!;
	io::seek(m, off, io::whence::SET)!;
};

@test fn garbage_at_start() void = {
	let buf = memio::dynamic();
	let p = newparser(&buf);

	memio::reset(&buf);
	pushs(&buf, "Content-Length: 1\r\n\r\np");
	assert(next(&p) is message);

	pushs(&buf, "this is garbage");
	assert(next(&p) is (io::error | error));
};

@test fn garbage_header() void = {
	let buf = memio::dynamic();
	let p = newparser(&buf);

	memio::reset(&buf);
	pushs(&buf, "Content-Long: 1\r\n\r\np");
	assert(next(&p) is (io::error | error));
};

@test fn multi_try_parse() void = {
	let buf = memio::dynamic();
	let p = newparser(&buf);

	pushs(&buf, "Content-L");
	assert(next(&p) is more);
	assert(bytes::equal(p.buf, strings::toutf8("Content-L")));

	pushs(&buf, "ength: 4\r");
	assert(next(&p) is more);
	assert(p.needs_lf);
	pushs(&buf, "\n");
	assert(next(&p) is more);
	assert(!p.needs_lf);

	pushs(&buf, "Content-");
	assert(next(&p) is more);
	pushs(&buf, "Type:");
	assert(next(&p) is more);
	pushs(&buf, " ");
	assert(next(&p) is more);
	pushs(&buf, "application/hare-jsonrpc");
	assert(next(&p) is more);
	pushs(&buf, "\r");
	assert(next(&p) is more);
	assert(p.needs_lf);
	assert(bytes::equal(p.buf, strings::toutf8("Content-Type: application/hare-jsonrpc")));
	pushs(&buf, "\n");
	assert(next(&p) is more);

	pushs(&buf, "\r");
	assert(next(&p) is more);
	assert(p.needs_lf);
	pushs(&buf, "\n");
	assert(next(&p) is more);
	assert(p.state is content);
	pushs(&buf, "gyreContent-Length: 6\r\n\r\nqwertyContent-Length");

	match (next(&p)) {
	case let m: message =>
		assert(m.headers.content_length == 4);
		assert(m.content == "gyre");
		assert(len(p.buf) == 0);
		message_finish(m);
	case let e: error =>
		fmt::errorln("Unexpected error: ", strerror(e))!;
		abort();
	case more =>
		abort();
	};

	match (next(&p)) {
	case let m: message =>
		assert(m.headers.content_length == 6);
		assert(m.content == "qwerty");
		assert(len(p.buf) == 0);
		message_finish(m);
	case let e: error =>
		fmt::errorln("Unexpected error: ", strerror(e))!;
		abort();
	case more =>
		abort();
	};
	assert(p.state is header);

	assert(next(&p) is more);
	pushs(&buf, ": 7");
	assert(next(&p) is more);
	assert(bytes::equal(p.buf, strings::toutf8("Content-Length: 7")));
	pushs(&buf, "\r\n");
	assert(next(&p) is more);
	pushs(&buf, "Content-Type");
	assert(next(&p) is more);
	assert(bytes::equal(p.buf, strings::toutf8("Content-Type")));
	pushs(&buf, ": app/mimetype\r\n");
	assert(next(&p) is more);
	assert(bytes::equal(p.buf, []));

	pushs(&buf, "\r\n");
	assert(next(&p) is more);
	assert(bytes::equal(p.buf, []));

	pushs(&buf, "harepls");
	match (next(&p)) {
	case let m: message =>
		assert(m.headers.content_length == 7);
		assert(m.content == "harepls");
		message_finish(m);
	case let e: error =>
		fmt::errorln("Unexpected error: ", strerror(e))!;
		abort();
	case more =>
		abort();
	};
	assert(next(&p) is more);
};
