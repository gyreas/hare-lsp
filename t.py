import sys

import pytest
import pytest_lsp
from lsprotocol.types import (
    ClientCapabilities,
    TextDocumentItem,
    InitializeParams,
    DidOpenTextDocumentParams,
    TextDocumentIdentifier,
)
from pytest_lsp import ClientServerConfig, LanguageClient


@pytest_lsp.fixture(
    config=ClientServerConfig(server_command=["build/harels"]),
)
async def client(lsp_client: LanguageClient):
    # Setup
    params = InitializeParams(capabilities=ClientCapabilities())
    result = await lsp_client.initialize_session(params)
    print(f"result={result}", file=sys.stderr)

    yield

    # Teardown
    await lsp_client.shutdown_session()


@pytest.mark.asyncio
async def test_init(client: LanguageClient):
    pass


@pytest.mark.asyncio
async def test_didOpen(client: LanguageClient):
    client.text_document_did_open(
        params=DidOpenTextDocumentParams(
            text_document=TextDocumentItem(
                uri="file:///home/saed/Projects/hare-lsp/a-file-that-must-not-be-named.file",
                language_id="hare",
                text="just a file, really\n",
                version=0,
            )
        )
    )
    client.text_document_did_open(
        params=DidOpenTextDocumentParams(
            text_document=TextDocumentItem(
                uri="file:///home/saed/Projects/hare-lsp/a-file-that-must-not-be-named.file",
                language_id="hare",
                text="just a file, really acte\n",
                version=1,
            )
        )
    )
