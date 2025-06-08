use encoding::json;
use fmt;
use io;
use memio;
use strings;

export fn writestr(m: *message) str = {
	let buf = memio::dynamic();
	assert(write(&buf, m) is size);
	return strings::fromutf8_unsafe(memio::buffer(&buf));
};

export fn write(sink: io::handle, m: *message) (size | io::error) = {
	assert(m.headers.content_length == len(m.content));
	let n = 0z;
	if (len(m.headers.content_type) > 0) {
		n += fmt::fprintf(sink, "Content-Type: {}\r\n", m.headers.content_type)?;
	};
	n += fmt::fprintf(sink, "Content-Length: {}\r\n", m.headers.content_length)?;
	n += fmt::fprintf(sink, "\r\n")?;
	n += fmt::fprintf(sink, "{}", m.content)?;
	return n;
};

@test fn write() void = {
	// TODO:
	void;
};
