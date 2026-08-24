import pytest
from app.application.idempotency import hash_request


def test_request_hash_is_canonical_for_object_key_order() -> None:
    first = hash_request({"amount": "12.5000", "metadata": {"b": 2, "a": 1}})
    second = hash_request({"metadata": {"a": 1, "b": 2}, "amount": "12.5000"})

    assert first == second
    assert len(first) == 64


def test_request_hash_rejects_binary_floating_point_at_any_depth() -> None:
    with pytest.raises(TypeError, match="Binary floating point is forbidden"):
        hash_request({"lines": [{"amount": 0.1}]})
