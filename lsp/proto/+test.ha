use bufio;
use bytes;
use fmt;
use io;
use rpc;
use strconv;
use strings;

@test fn multi_try_parse() void = {
	const p = newparser();
	defer finish(p);

	append(p.buf, strings::toutf8("Content-L")...)!;
	assert(next(&p) is more);
	append(p.buf, strings::toutf8("ength: 10\r\n")...)!;
	assert(next(&p) is more);
	append(p.buf, strings::toutf8("\r\nabcdefhijkContent-Length: 6\r\n\r\nqwerty")...)!;

 	match (next(&p)) {
 	case let m: message =>
 		assert(m.headers.content_length == 10);
 		assert(m.content == "abcdefhijk");
		message_finish(m);
 	case let err: error =>
 		fmt::errorln("Unexpected error:", strerror(err))!;
 		abort();
 	case more =>
 		abort();
 	};
 
 	match (next(&p)) {
 	case let m: message =>
 		assert(m.headers.content_length == 6);
 		assert(m.content == "qwerty");
		message_finish(m);
 	case let err: error =>
 		fmt::errorln("Unexpected error:", strerror(err))!;
 		abort();
 	case more =>
 		abort();
 	};
};
