from __future__ import annotations

import json
from collections.abc import Mapping, Sequence
from typing import cast


def _assert_json_safe(value: object, *, path: str) -> None:
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        raise TypeError(f"Binary floating point is forbidden in JSON contracts at {path}.")
    if isinstance(value, Mapping):
        for key, nested in value.items():
            if not isinstance(key, str):
                raise TypeError(f"JSON object keys must be strings at {path}.")
            _assert_json_safe(nested, path=f"{path}.{key}")
        return
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        for index, nested in enumerate(value):
            _assert_json_safe(nested, path=f"{path}[{index}]")
        return
    raise TypeError(f"Unsupported JSON value {type(value).__name__} at {path}.")


def canonical_json(payload: Mapping[str, object]) -> str:
    _assert_json_safe(payload, path="$")
    return json.dumps(
        dict(payload),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )


def normalize_json_object(payload: Mapping[str, object]) -> dict[str, object]:
    decoded = cast(object, json.loads(canonical_json(payload)))
    if not isinstance(decoded, dict):
        raise TypeError("Expected a JSON object.")
    return cast(dict[str, object], decoded)
