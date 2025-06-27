use fmt;
use path;
use net::uri;
use strings;

export type error = !(path::error | uri_not_file);
export type uri_not_file = !void;

export type abspathbuf = struct {
	buf: path::buffer,
};

export fn from(path: (*path::buffer | str)) abspathbuf = {
	let path = match (path) {
	case str => yield path as str;
	case let p: *path::buffer => yield path::string(p);
	};

	if (!path::abs(path)) {
		fmt::fatalf("expected absolute path, got {}", path);
	};
	return abspathbuf {
		buf = path::init(path)!,
	};
};

export fn fromuri(uri: *uri::uri) (abspathbuf | error) = {
	if (uri.scheme != "file" && uri.host as str != "") return uri_not_file;
	return from(uri.path);
};

export fn pop(this: *abspathbuf) (str | void) = {
	 return path::pop(this);
};

export fn push(this: *abspathbuf, suffix: (*path::buffer | str)) (str | path::error) = {
	let suf = match (suffix) {
	case str => yield suffix as str;
	case let p: *path::buffer => yield path::string(p);
	};

	return if (path::abs(suffix)) path::set(this, suf)
	else path::push(this, suf);
};

export fn string(this: *abspathbuf) str =
	path::string(&this.buf);

export fn strerror(e: error) str = match (e) {
	case uri_not_file => yield "URI is not a file";
	case let e: path::error => yield path::strerror(e);
};
