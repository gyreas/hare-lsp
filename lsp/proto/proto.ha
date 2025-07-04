use encoding::json;
use encoding::utf8;
use strings;

export def HARELS_CONTENT_TYPE: str = "application/hare-jsonrpc";

export type message = struct {
	headers: headers,
	// content could be io::handle instead?
	content: str,
};

export fn message_fromjson(obj: json::object) message = {
	const content = json::dumpstr(obj);
	const length = len(content);
	return message {
		headers = headers {
			content_length = length,
			content_type = strings::dup(HARELS_CONTENT_TYPE)!,
		},
		content = content
	};
};

export type headers = struct {
	content_length: size,
	content_type: str,
};

// Returned when more data is needed to parse a full message
export type more = void;

// Returned when the Content-Length header is missing in the header part of the
// message
export type missing_content_length = !void;

// Returned when the Content-Length header couldn't be parsed as a string
export type invalid_content_length = !void;

// Any part of an header, esp. Content-Length, is malformed
export type malformed_header = !void;

// All possible parser errors
export type error = !(missing_content_length | malformed_header | invalid_content_length | utf8::invalid);

export fn strerror(err: error) str = {
	match (err) {
	case malformed_header =>
		return "Message has a malformed or incorrect header";
	case invalid_content_length =>
		return "Content-Length header has an invalid value";
	case missing_content_length =>
		return "Message is missing a Content-Length header";
	case utf8::invalid =>
		return "Invalid utf8";
	};
};
