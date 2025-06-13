import sys

import pytest
import pytest_lsp
from lsprotocol.types import (
    ClientCapabilities,
    InitializeParams,
    GeneralClientCapabilities,
    # TextDocumentIdentifier,
)
from pytest_lsp import ClientServerConfig, LanguageClient


@pytest_lsp.fixture(
    config=ClientServerConfig(server_command=["build/harels"]),
)
async def client(client_: LanguageClient):
    # Setup
    params = InitializeParams(
        capabilities=ClientCapabilities(
            general=GeneralClientCapabilities(position_encodings=["utf-8"])
        ),
    )
    print(params)
    result = await client_.initialize_session(params)
    print(f"initializeResult: {result}", file=sys.stderr)

    yield

    # Teardown
    await client_.shutdown_session()


@pytest.mark.asyncio
async def test_initialization(client: LanguageClient):
    pass


# @pytest.mark.asyncio
# async def test_didOpen(client: LanguageClient):
#     result = await client.text_document_did_open()
