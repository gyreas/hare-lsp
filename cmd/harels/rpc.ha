use rpc;

// when textDocument/didOpen notifies on an already opened document
def DOCUMENT_ALREADY_OPENED: rpc::error_code = -32640;
// when textDocument/didClose notifies on a document that wasn't already opened
def DOCUMENT_NOT_OPENED: rpc::error_code = -32641;
