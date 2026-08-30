from __future__ import annotations

import json
import logging
from datetime import UTC, datetime

_SAFE_FIELDS = (
    "request_id",
    "method",
    "route",
    "status_code",
    "duration_ms",
    "error_type",
)


class JsonLogFormatter(logging.Formatter):
    """Emit operational fields only; request bodies and credentials are never serialized."""

    def format(self, record: logging.LogRecord) -> str:
        document: dict[str, object] = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "event": record.getMessage(),
        }
        for field in _SAFE_FIELDS:
            value = getattr(record, field, None)
            if value is not None:
                document[field] = value
        if record.exc_info is not None:
            error_type = record.exc_info[0]
            if error_type is not None:
                document["error_type"] = error_type.__name__
        return json.dumps(document, separators=(",", ":"), ensure_ascii=False)


def configure_app_logging(*, level: str) -> None:
    logger = logging.getLogger("planit")
    logger.setLevel(level)
    logger.propagate = False
    handler = next(
        (item for item in logger.handlers if getattr(item, "_planit_json", False)),
        None,
    )
    if handler is None:
        handler = logging.StreamHandler()
        handler._planit_json = True  # type: ignore[attr-defined]
        logger.addHandler(handler)
    handler.setFormatter(JsonLogFormatter())
    handler.setLevel(level)
