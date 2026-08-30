from __future__ import annotations

import pytest
from app.domain.errors import DomainError
from app.integrations.banking import DisabledBankTransactionProvider
from app.integrations.ocr import DisabledReceiptOcrProvider


@pytest.mark.parametrize(
    "provider",
    [DisabledReceiptOcrProvider(), DisabledBankTransactionProvider()],
)
async def test_optional_automation_fails_closed_without_a_provider(provider: object) -> None:
    with pytest.raises(DomainError) as raised:
        if isinstance(provider, DisabledReceiptOcrProvider):
            await provider.suggest(content=b"image", mime_type="image/jpeg")
        else:
            assert isinstance(provider, DisabledBankTransactionProvider)
            await provider.fetch(connection_reference="none", since=None)
    assert raised.value.code == "AUTOMATION_PROVIDER_UNAVAILABLE"
