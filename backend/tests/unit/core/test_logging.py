from __future__ import annotations

import json
import logging

from app.core.logging import JsonLogFormatter


def test_json_logging_keeps_only_safe_operational_context() -> None:
    record = logging.LogRecord(
        name="planit.http",
        level=logging.INFO,
        pathname=__file__,
        lineno=10,
        msg="request_complete",
        args=(),
        exc_info=None,
    )
    record.request_id = "safe-id"  # type: ignore[attr-defined]
    record.method = "GET"  # type: ignore[attr-defined]
    record.route = "/api/v1/transactions/{transaction_id}"  # type: ignore[attr-defined]
    record.authorization = "Bearer never-log-this"  # type: ignore[attr-defined]
    record.request_body = {"note": "private receipt"}  # type: ignore[attr-defined]

    document = json.loads(JsonLogFormatter().format(record))

    assert document["event"] == "request_complete"
    assert document["route"] == "/api/v1/transactions/{transaction_id}"
    assert "authorization" not in document
    assert "request_body" not in document
    assert "never-log-this" not in json.dumps(document)
