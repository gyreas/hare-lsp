use encoding::json;

export def V: i32 = -44;

export type did_change_text_params = struct {
	// TODO: Should be a versioned_text_document_item
	text_document: text_document_identifier,
	content_changes: text_document_content_change_event_iterator,
};

export type did_close_text_params = struct {
	text_document: text_document_identifier,
};

export type did_open_text_params = struct {
	text_document: text_document_item,
};

export type hover_params = struct {
	work_done_progress_params,
	text_document_position_params,
};

export type initialize_params = struct {
	work_done_progress_params,

	process_id: (i32 | json::_null),

	root_path: (str | json::_null | void),

	initialization_options: (json::value | void),

	capabilities: client_capabilities,
};

export type initialized_params = struct {
	noop: int,
};

export type log_message_params = struct {
	_type: message_type,
	message: str,
};

export type text_document_position_params = struct {
	text_document: text_document_identifier,
	position: position,
};

export type work_done_progress_params = struct {
	work_done_token: (progress_token | void),
};
