use encoding::json;
use rpc;

export type stopbuggingmeerr = !void;
export type deserialize_error = !(stopbuggingmeerr | rpc::deserialize_error);

export type position_encoding = str;

export def POS_ENC_UTF8: position_encoding = "utf-8";
export def POS_ENC_UTF16: position_encoding = "utf-16";
export def POS_ENC_UTF32: position_encoding = "utf-32";

export type text_document_sync_kind = enum u8 {
	NONE = 0,
	FULL = 1,
	INCREMENTAL = 2,
};

export type general_client_capabilities = struct {
	position_encoding: []position_encoding,
};

export type definition_client_capabilities = struct {
	dynamic_registration: (bool | void),
};

export type text_document_client_capabilities = struct {
	definition: (definition_client_capabilities | void),
};

export type client_capabilities = struct {
	general: (general_client_capabilities | void),

	text_document: (text_document_client_capabilities | void),
};

export type server_capabilities = struct {
	position_encoding: (position_encoding | void),

	text_document_sync: (text_document_sync_kind | void),

	// TODO: Missing DefinitionOptions
	definition_provider: (bool | void),
	// TODO: Missing HoverOptions
	hover_provider: (bool | void),
};

export type server_info = struct {
	name: str,
	version: (str | void),
};

export type initialize_result = struct {
	capabilities: server_capabilities,
	server_info: (server_info | void),
};

export fn strerror(err: deserialize_error) str = {
	match (err) {
	case let err: rpc::deserialize_error =>
		return rpc::strerror(err);
	case =>
		return "lsp deserialize error";
	};
};
