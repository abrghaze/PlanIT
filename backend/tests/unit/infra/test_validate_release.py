from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[4]
SCRIPT = ROOT / "infra" / "scripts" / "validate-release.py"
SPEC = importlib.util.spec_from_file_location("validate_release", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def test_repository_release_versions_are_consistent() -> None:
    assert MODULE.validate(ROOT, "v0.10.0") == "0.10.0"


def test_release_tag_must_match_version() -> None:
    with pytest.raises(ValueError, match="must equal"):
        MODULE.validate(ROOT, "v9.9.9")
