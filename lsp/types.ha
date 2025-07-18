use bufio;
use encoding::json;
use fmt;
use io;
use net::uri;
use strings;

export type hover = struct {
	contents: markup_content,
	range: (range | void),
};

export type location = struct {
	uri: uri::uri,
	range: range,
};

export type markup_content = struct {
	kind: markup_kind,
	value: str,
};

export type markup_kind = str;

export def markup_kind_plaintext: markup_kind = "plaintext";
export def markup_kind_markdown: markup_kind = "markdown";

export type message_type = enum u8 {
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	LOG = 4,
};

export type position = struct {
	line: u32,
	character: u32,
};

export type progress_token = (i32 | str);

export type range = struct {
	start: position,
	end: position,
};

// TODO: Could include range length..
export type text_document_content_change_event = struct {
	text: str,
	range: (range | void),
};

export type text_document_identifier = struct {
	uri: uri::uri,
};

export type versioned_text_document_identifier = struct {
	version: i32,
	uri: uri::uri,
};

export type text_document_item = struct {
	uri: uri::uri,
	language_id: str,
	version: int,
	text: str,
};

export type workspace_folder = struct {
	uri: uri::uri,
	name: str,
};

