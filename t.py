import sys

import pytest
import pytest_lsp
from lsprotocol.types import (
    Range,
    Position,
    ClientCapabilities,
    TextDocumentItem,
    InitializeParams,
    DidOpenTextDocumentParams,
    DidCloseTextDocumentParams,
    DidChangeTextDocumentParams,
    TextDocumentIdentifier,
    VersionedTextDocumentIdentifier,
    TextDocumentContentChangeEvent_Type1,
    TextDocumentContentChangeEvent_Type2,
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
    client.text_document_did_close(
        params=DidCloseTextDocumentParams(
            text_document=TextDocumentIdentifier(
                uri="file:///home/saed/Projects/hare-lsp/a-file-that-must-not-be-named.file",
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


@pytest.mark.asyncio
async def test_didChange(client: LanguageClient):
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
    client.text_document_did_change(
        params=DidChangeTextDocumentParams(
            text_document=VersionedTextDocumentIdentifier(
                version=0,
                uri="file:///home/saed/Projects/hare-lsp/a-file-that-must-not-be-named.file",
            ),
            content_changes=[
                TextDocumentContentChangeEvent_Type2(
                    text="This i1s acting - Sia1",
                ),
                TextDocumentContentChangeEvent_Type2(
                    text="This i4444s acting - Sia4444",
                ),
            ],
        )
    )
    client.text_document_did_change(
        params=DidChangeTextDocumentParams(
            text_document=VersionedTextDocumentIdentifier(
                version=0,
                uri="file:///home/saed/Projects/hare-lsp/a-file-that-must-not-be-named.file",
            ),
            content_changes=[
                TextDocumentContentChangeEvent_Type1(
                    text="(This is acting)",
                    range=Range(
                        start=Position(line=0, character=5),
                        end=Position(line=0, character=11),
                    ),
                ),
                TextDocumentContentChangeEvent_Type1(
                    text="(This is acting)",
                    range=Range(
                        start=Position(line=0, character=14),
                        end=Position(line=0, character=20),
                    ),
                ),
            ],
        )
    )
    assert False
